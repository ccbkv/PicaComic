import 'dart:io';

import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:pica_comic/request/clients/trace_client.dart';
import 'package:pica_comic/pages/search/image_search_module.dart';
import 'package:pica_comic/request/config/api_endpoints.dart';

class TraceApi {
  static final TraceClient _client = TraceClient.instance;
  static const String _sauceNaoBaseUrl = 'https://saucenao.com';
  static const String _resultContentColumnClass = 'resultcontentcolumn';
  static const String _resultImageClass = 'resultimage';
  static const String _resultMatchInfoClass = 'resultmatchinfo';
  static const String _resultSimilarityInfoClass = 'resultsimilarityinfo';
  static const String _resultTableClass = 'resulttable';
  static const String _resultTitleClass = 'resulttitle';
  static const String _serverErrorClass = 'servererror';
  static const String _lookupPrefix =
      'https://saucenao.com/info.php?lookup_type=';

  ///根据图片搜索番剧信息
  static Future<ImageSearchItem> searchAnimeByImageFile(File imageFile,
      {String apiKey = '', List<int> databases = const []}) async {
    final bytes = await imageFile.readAsBytes();

    final data = await _client.post(
      ApiEndpoints.traceApi,
      queryParameters: _buildQueryParameters(apiKey, databases),
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: imageFile.uri.pathSegments.isNotEmpty
              ? imageFile.uri.pathSegments.last
              : 'image.jpg',
        ),
      }),
    );
    return _mapSauceNaoResponse(data);
  }

  ///根据图片URL搜索番剧信息
  static Future<ImageSearchItem> searchAnimeByImageUrl(String imageUrl,
      {String apiKey = '', List<int> databases = const []}) async {
    final data = await _client.post(
      ApiEndpoints.traceApi,
      queryParameters: _buildQueryParameters(apiKey, databases),
      data: FormData.fromMap({'url': imageUrl}),
    );
    return _mapSauceNaoResponse(data);
  }

  static Map<String, dynamic> _buildQueryParameters(
    String apiKey,
    List<int> databases,
  ) {
    final queryParameters = <String, dynamic>{
      'output_type': 0,
      'numres': 10,
      'hide': 0,
    };
    if (apiKey.trim().isNotEmpty) {
      queryParameters['api_key'] = apiKey.trim();
    }
    if (databases.isEmpty) {
      queryParameters['db'] = 999;
    } else {
      queryParameters['dbs[]'] = databases;
    }
    return queryParameters;
  }

  static ImageSearchItem _mapSauceNaoResponse(dynamic responseData) {
    final document = html_parser.parse(responseData?.toString() ?? '');
    final results = document
        .getElementsByClassName(_resultTableClass)
        .map(_mapSauceNaoResult)
        .whereType<ResultItem>()
        .toList();

    final serverErrors = document.getElementsByClassName(_serverErrorClass);
    final message = _firstNonEmpty([
      serverErrors.isEmpty ? null : serverErrors.first.text,
      results.isEmpty ? '未找到匹配结果' : null,
    ]);

    return ImageSearchItem(
      frameCount: results.length,
      error: message,
      result: results,
    );
  }

  static ResultItem? _mapSauceNaoResult(dom.Element result) {
    final resultMatchInfo = _firstElementByClass(result, _resultMatchInfoClass);
    final resultContentColumns =
        result.getElementsByClassName(_resultContentColumnClass);
    final similarityString = resultMatchInfo
        ?.getElementsByClassName(_resultSimilarityInfoClass)
        .firstOrNull
        ?.text;
    final thumbnail = _extractThumbnail(result);

    if (thumbnail == null || thumbnail == 'images/static/hidden.png') {
      return null;
    }

    final columns = resultContentColumns
        .map(_elementToPlainText)
        .where((item) => item.isNotEmpty)
        .toList();
    final titleBlock =
        _firstElementByClass(result, _resultTitleClass)?.let(_elementToPlainText);
    final titleLines = titleBlock == null
        ? const <String>[]
        : titleBlock
            .split('\n')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
    final title = titleLines.isEmpty ? null : titleLines.first;
    if (titleLines.length > 1) {
      columns.insert(0, titleLines.sublist(1).join(' / '));
    }

    final extUrls = <String>[];
    final urlElements = <dom.Element>[
      if (resultMatchInfo != null) resultMatchInfo,
      ...resultContentColumns,
    ];
    for (final element in urlElements) {
      for (final anchor in element.getElementsByTagName('a')) {
        final href = anchor.attributes['href']?.trim() ?? '';
        if (href.isEmpty || href.startsWith(_lookupPrefix)) {
          continue;
        }
        final normalizedUrl = _normalizeUrl(href);
        if (normalizedUrl != null && !extUrls.contains(normalizedUrl)) {
          extUrls.add(normalizedUrl);
        }
      }
    }

    final similarityValue = similarityString == null
        ? null
        : double.tryParse(similarityString.replaceAll('%', '').trim())
            ?.clamp(0.0, 100.0);
    final similarity = similarityValue == null ? null : similarityValue / 100;

    return ResultItem(
      filename: title,
      episode: columns.isEmpty ? null : columns.first,
      similarity: similarity,
      image: _normalizeUrl(thumbnail),
      source: columns.length > 1 ? columns[1] : null,
      sourceUrl: extUrls.isEmpty ? null : extUrls.first,
      video: extUrls.isEmpty ? null : extUrls.first,
    );
  }

  static dom.Element? _firstElementByClass(dom.Element root, String className) {
    final elements = root.getElementsByClassName(className);
    return elements.isEmpty ? null : elements.first;
  }

  static String? _extractThumbnail(dom.Element result) {
    final resultImage = _firstElementByClass(result, _resultImageClass);
    if (resultImage == null) {
      return null;
    }
    final images = resultImage.getElementsByTagName('img');
    if (images.isEmpty) {
      return null;
    }
    final image = images.first;
    for (final key in ['data-src2', 'data-src', 'src']) {
      final value = image.attributes[key]?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static String _elementToPlainText(dom.Element element) {
    final buffer = StringBuffer();

    void visit(dom.Node node) {
      if (node is dom.Text) {
        buffer.write(node.text);
        return;
      }

      if (node is! dom.Element) {
        return;
      }

      final name = node.localName?.toLowerCase();
      if (name == 'li') {
        buffer.write('\n * ');
      } else if (name == 'dt') {
        buffer.write('  ');
      } else if (name == 'strong') {
        buffer.write(' ');
      } else if (const {'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'tr'}
          .contains(name)) {
        buffer.write('\n');
      }

      for (final child in node.nodes) {
        visit(child);
      }

      if (const {'br', 'dd', 'dt', 'p', 'h1', 'h2', 'h3', 'h4', 'h5'}
          .contains(name)) {
        buffer.write('\n');
      }
    }

    for (final node in element.nodes) {
      visit(node);
    }

    return buffer
        .toString()
        .replaceAll('\r', '')
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .join('\n');
  }

  static String? _normalizeUrl(String? value) {
    if (value == null) {
      return null;
    }
    final url = value.trim();
    if (url.isEmpty) {
      return null;
    }
    if (url.startsWith('//')) {
      return 'https:$url';
    }
    if (url.startsWith('/')) {
      return '$_sauceNaoBaseUrl$url';
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return '$_sauceNaoBaseUrl/$url';
    }
    return url;
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static String? _stringifyValue(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is List) {
      final values = value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
      return values.isEmpty ? null : values.join(' / ');
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

extension<T> on T {
  R let<R>(R Function(T value) transform) => transform(this);
}
