import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pica_comic/foundation/image_translation/rate_limiter.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/network/app_dio.dart';

/// Translates recognized bubble texts through Google Translate's free endpoint,
/// which needs no account and no API key.
///
/// This exists for readers who have no LLM service to point the app at. It is
/// plain machine translation: no system prompt, no glossary, no cross-page
/// context — each line is translated on its own. Quality is below a decent LLM,
/// but setup is nothing.
///
/// The endpoint takes one request per batch of lines and answers with exactly
/// one result per line, in order. That 1:1 alignment is what the render stage
/// needs, so a response whose length does not match the request is rejected
/// rather than mapped onto the wrong bubbles.
abstract class PublicTranslator {
  static const _endpoint = 'https://translate.googleapis.com/translate_a/t';

  /// Selects the plain-text, one-result-per-line response shape. Paired with
  /// `sl=auto`, which lets the service detect the source language — the caller
  /// does not supply one.
  static const _client = 'dict-chrome-ex';

  /// Per-request caps. The service accepts far more, but a big request that
  /// fails takes every line in it down, and a page's bubbles are cheap to split.
  static const _maxLinesPerRequest = 64;
  static const _maxCharsPerRequest = 6000;

  static const _connectTimeout = Duration(seconds: 15);

  /// Hard transport-level bound per request. Responses normally land in a few
  /// seconds; this only has to stop a stalled socket from holding the caller's
  /// concurrency slot, which would otherwise freeze every page queued behind it.
  static const requestTimeout = Duration(seconds: 45);

  /// Wall-clock ceiling for one [translate] call including chunks and retries.
  static const totalBudget = Duration(minutes: 4);

  /// Translates [texts] into [targetLang], preserving order and length.
  ///
  /// [onSuccess] / [onRateLimited] report back to the caller's concurrency
  /// estimator so this engine backs off the same way the LLM path does.
  /// Throws when a chunk cannot be translated, so the caller fails the page and
  /// a later pass retries it.
  static Future<List<String>> translate(
    List<String> texts,
    String targetLang, {
    void Function()? onSuccess,
    void Function()? onRateLimited,
  }) async {
    if (texts.isEmpty) return const [];
    var target = _targetCode(targetLang);
    var giveUpAt = DateTime.now().add(totalBudget);
    var results = <String>[];
    for (var chunk in _chunks(texts)) {
      results.addAll(
        await _translateChunk(
          chunk,
          target,
          giveUpAt,
          onSuccess: onSuccess,
          onRateLimited: onRateLimited,
        ),
      );
    }
    if (results.length != texts.length) {
      throw Exception(
        'Public translation returned ${results.length} of ${texts.length} lines',
      );
    }
    return results;
  }

  /// Splits [texts] so no request carries too many lines or too much text.
  /// A single over-long line still goes out alone rather than being cut.
  @visibleForTesting
  static List<List<String>> chunksForTest(List<String> texts) => _chunks(texts);

  /// [_parse] for tests: alignment is the invariant that matters here, so the
  /// accepted shapes and the length check are pinned directly.
  @visibleForTesting
  static List<String> parseForTest(Object? body, int count) =>
      _parse(body, count);

  static List<List<String>> _chunks(List<String> texts) {
    var chunks = <List<String>>[];
    var current = <String>[];
    var chars = 0;
    for (var text in texts) {
      if (current.isNotEmpty &&
          (current.length >= _maxLinesPerRequest ||
              chars + text.length > _maxCharsPerRequest)) {
        chunks.add(current);
        current = <String>[];
        chars = 0;
      }
      current.add(text);
      chars += text.length;
    }
    if (current.isNotEmpty) chunks.add(current);
    return chunks;
  }

  static Future<List<String>> _translateChunk(
    List<String> texts,
    String target,
    DateTime giveUpAt, {
    void Function()? onSuccess,
    void Function()? onRateLimited,
  }) async {
    var dio = Dio(
      BaseOptions(
        connectTimeout: _connectTimeout,
        receiveTimeout: requestTimeout,
        responseType: ResponseType.plain,
        contentType: Headers.formUrlEncodedContentType,
        validateStatus: (status) => status != null && status < 500,
      ),
    )..httpClientAdapter = AppHttpAdapter(false);
    try {
      const maxAttempts = 4;
      Object? lastError;
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        HttpErrorClass? cls;
        Duration? retryAfter;
        try {
          var response = await dio.post(
            _endpoint,
            queryParameters: {'client': _client, 'sl': 'auto', 'tl': target},
            // Repeated `q` fields, one per line. Sent as a body rather than in
            // the query string so a page full of long bubbles cannot overrun the
            // URL length limit.
            data:
                [for (var t in texts) 'q=${Uri.encodeQueryComponent(t)}'].join(
              '&',
            ),
          );
          var status = response.statusCode ?? 0;
          if (status == 200) {
            var parsed = _parse(response.data, texts.length);
            onSuccess?.call();
            return parsed;
          }
          lastError = Exception('Translation endpoint returned $status');
          cls = classifyStatus(status);
          retryAfter = parseRetryAfter(response.headers.value('retry-after'));
        } on DioException catch (e) {
          lastError = e;
          var status = e.response?.statusCode;
          cls = status != null
              ? classifyStatus(status)
              : HttpErrorClass.transient;
          retryAfter = parseRetryAfter(
            e.response?.headers.value('retry-after'),
          );
          Log.warning('Image Translation', 'Public translation failed: $e');
        } catch (e) {
          lastError = e;
          cls = HttpErrorClass.transient;
          Log.warning('Image Translation', 'Public translation failed: $e');
        }
        if (cls == HttpErrorClass.clientError || cls == HttpErrorClass.fatal) {
          break;
        }
        if (cls == HttpErrorClass.rateLimited) {
          onRateLimited?.call();
        }
        var wait = backoff(attempt, retryAfter: retryAfter);
        if (DateTime.now().add(wait).isAfter(giveUpAt)) {
          break;
        }
        await Future.delayed(wait);
      }
      throw Exception('Public translation failed: $lastError');
    } finally {
      dio.close();
    }
  }

  /// Reads the response into [count] translations.
  ///
  /// Two shapes are returned depending on the request: `["译文", ...]` and
  /// `[["译文","ja"], ...]` (the detected source language rides along). Both are
  /// accepted; anything else, or a length mismatch, is an error — silently
  /// padding would put a translation on the wrong bubble.
  static List<String> _parse(Object? body, int count) {
    var raw = body is String ? body : jsonEncode(body);
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw Exception('Translation response is not JSON');
    }
    if (decoded is! List) {
      throw Exception('Unexpected translation response shape');
    }
    var results = <String>[];
    for (var item in decoded) {
      if (item is String) {
        results.add(_unescape(item));
      } else if (item is List && item.isNotEmpty && item.first is String) {
        results.add(_unescape(item.first as String));
      } else {
        throw Exception('Unexpected translation response entry');
      }
    }
    if (results.length != count) {
      throw Exception(
        'Translation response has ${results.length} entries, expected $count',
      );
    }
    return results;
  }

  /// The endpoint normally answers in plain text, but has been seen to escape
  /// a few characters. Undo those so the rendered page shows the character
  /// instead of an entity.
  static String _unescape(String text) {
    if (!text.contains('&')) return text;
    return text
        .replaceAll('&#39;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&');
  }

  /// Maps the app's target-language codes to the endpoint's. Only Chinese
  /// differs; everything else uses the same code.
  static String _targetCode(String targetLang) {
    return switch (targetLang) {
      'zh' => 'zh-CN',
      'zh-TW' => 'zh-TW',
      _ => targetLang,
    };
  }
}
