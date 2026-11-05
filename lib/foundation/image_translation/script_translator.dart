import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:pica_comic/network/app_dio.dart';
import 'package:pica_comic/utils/translations.dart';

import 'llm_translator.dart';

/// Each call owns its runtime and requests, separate from comic-source scripts.
abstract class ScriptTranslator {
  static const template = '''
// Input: texts (string[]), sourceLang, targetLang, glossary, provider.
// Output: {texts: string[], glossary?: {source: translation}}.
// Keep exactly one translation per input, in the same order.
async function translate({texts, sourceLang, targetLang, glossary, provider}) {
    const response = await Network.sendRequest(
        'POST', provider.url,
        {'Content-Type': 'application/json',
         'Authorization': 'Bearer ' + provider.key},
        JSON.stringify({texts, source: sourceLang, target: targetLang})
    );
    if (response.status !== 200) throw new Error('HTTP ' + response.status);
    const data = JSON.parse(response.body);
    // Adapt this field to your API's response.
    return {texts: data.translations};
}
''';

  static Future<LlmTranslationResult> translate(
    LlmProvider provider,
    List<String> texts,
    String sourceLang,
    String targetLang, {
    Map<String, String> glossary = const {},
    Duration timeout = LlmTranslator.requestTimeout,
    Dio? client,
  }) async {
    if (texts.isEmpty) return const LlmTranslationResult([], {});
    final init = await rootBundle.loadString('assets/init.js');
    final engine = FlutterQjs(
      timeout: 1000,
      memoryLimit: 64 * 1024 * 1024,
      // The awaited result reports errors without printing script contents.
      hostPromiseRejectionHandler: (_) {},
    );
    final dio = client ??
        (Dio(
          BaseOptions(
            responseType: ResponseType.plain,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: timeout,
            validateStatus: (_) => true,
          ),
        )..httpClientAdapter = AppHttpAdapter(false));
    final cancel = CancelToken();
    final stop = Completer<void>();
    final requests = <Future<void>>[];
    Future<dynamic>? result;
    engine.dispatch();
    try {
      Future<Map<String, dynamic>> request(dynamic message) async {
        if (message is! Map || message['method'] != 'http') {
          throw Exception(
            'Only Network requests are available in translation scripts'.tl,
          );
        }
        final url = message['url']?.toString() ?? '';
        if (!LlmTranslator.isValidBaseUrl(url)) {
          throw Exception('Enter a valid API URL'.tl);
        }
        try {
          final response = await dio.request<dynamic>(
            url,
            data: message['data'],
            cancelToken: cancel,
            options: Options(
              method: message['http_method']?.toString() ?? 'GET',
              headers: Map<String, dynamic>.from(message['headers'] ?? {}),
              responseType: message['bytes'] == true
                  ? ResponseType.bytes
                  : ResponseType.plain,
            ),
          );
          return {
            'status': response.statusCode,
            'headers': response.headers.map,
            'body': message['bytes'] == true
                ? Uint8List.fromList(List<int>.from(response.data))
                : response.data,
          };
        } on DioException {
          // Do not expose request headers or payloads in a script error.
          throw Exception('Translation API request failed'.tl);
        }
      }

      final setter =
          engine.evaluate('(send) => { globalThis.sendMessage = send; }')
              as JSInvokable;
      try {
        setter([
          (dynamic message) {
            final future = request(message);
            requests.add(future.then<void>((_) {}, onError: (Object _) {}));
            return future;
          },
        ]);
      } finally {
        setter.free();
      }
      engine.evaluate(init, name: '<init>');
      final function = engine.evaluate('''
        (() => {
          ${provider.script}
          if (typeof translate !== 'function') throw new Error(${jsonEncode('Define function translate(input)'.tl)});
          return (input, stop) => Promise.race([
            Promise.resolve().then(() => translate(input)), stop
          ]).then(value => JSON.stringify(value));
        })()
      ''', name: '<translation>') as JSInvokable;
      try {
        result = Future<dynamic>.value(
          function([
            {
              'texts': texts,
              'sourceLang': sourceLang,
              'targetLang': targetLang,
              'glossary': glossary,
              'provider': {
                'url': provider.url,
                'key': provider.key,
                'model': provider.model,
              },
            },
            stop.future,
          ]),
        );
      } finally {
        function.free();
      }
      final output = await result.timeout(timeout);
      if (output is! String) throw const FormatException();
      return parse(jsonDecode(output), texts.length);
    } on TimeoutException {
      throw Exception('Translation script timed out'.tl);
    } on FormatException {
      throw Exception('Translation script returned an invalid result'.tl);
    } finally {
      // Settle Dart-backed promises before freeing their native runtime.
      cancel.cancel();
      stop.complete();
      await Future.wait(requests);
      try {
        await result;
      } catch (_) {}
      dio.close(force: true);
      try {
        engine.close();
      } finally {
        engine.port.close();
      }
    }
  }

  static LlmTranslationResult parse(dynamic output, int count) {
    final texts =
        output is List ? output : (output is Map ? output['texts'] : null);
    if (texts is! List ||
        texts.length != count ||
        texts.any((item) => item is! String)) {
      throw Exception(
        'Translation script must return one string per input text'.tl,
      );
    }
    final names = output is Map ? output['glossary'] : null;
    if (names != null &&
        (names is! Map ||
            names.entries.any((e) => e.key is! String || e.value is! String))) {
      throw Exception('Translation script returned an invalid glossary'.tl);
    }
    return LlmTranslationResult(texts.cast<String>(), {
      if (names is Map)
        for (final entry in names.entries)
          if (LlmTranslator.isValidGlossaryTerm(entry.key, entry.value))
            (entry.key as String).trim(): (entry.value as String).trim(),
    });
  }
}
