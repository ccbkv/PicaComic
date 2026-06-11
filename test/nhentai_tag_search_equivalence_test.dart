import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const _baseUrl = 'https://nhentai.net/api/v2';

class _TagCase {
  const _TagCase({
    required this.tagId,
    required this.tagName,
  });

  final int tagId;
  final String tagName;
}

Never _failForDioException({
  required String apiName,
  required _TagCase tagCase,
  required DioException error,
}) {
  final details = StringBuffer()
    ..writeln('Failed to request nhentai $apiName API.')
    ..writeln('tagName=${tagCase.tagName}, tagId=${tagCase.tagId}')
    ..writeln('type=${error.type}');

  final response = error.response;
  if (response != null) {
    details
      ..writeln('statusCode=${response.statusCode}')
      ..writeln('response=${response.data}');
  }

  final innerError = error.error;
  if (innerError != null) {
    details.writeln('error=$innerError');
  }

  details.writeln(
    'Likely network issue: DNS, proxy, TUN, firewall, or upstream timeout.',
  );

  fail(details.toString());
}

Future<Map<String, dynamic>> _getJson(
  Dio dio, {
  required String path,
  required Map<String, dynamic> queryParameters,
  required String apiName,
  required _TagCase tagCase,
}) async {
  try {
    final response = await dio.get<Map<String, dynamic>>(
      '$_baseUrl/$path',
      queryParameters: queryParameters,
    );
    return response.data ?? <String, dynamic>{};
  } on DioException catch (error) {
    _failForDioException(
      apiName: apiName,
      tagCase: tagCase,
      error: error,
    );
  }
}

List<int> _extractIds(Map<String, dynamic> body) {
  final result = body['result'] as List<dynamic>? ?? const [];
  return result
      .map((item) => (item as Map<String, dynamic>)['id'] as int)
      .toList();
}

Future<List<int>> _fetchIdsFromSearch(
  Dio dio, {
  required _TagCase tagCase,
  required String tagName,
  required String sort,
  required int page,
}) async {
  final body = await _getJson(
    dio,
    path: 'search',
    queryParameters: {
      'query': 'tag:"$tagName"',
      'sort': sort,
      'page': page,
    },
    apiName: 'search',
    tagCase: tagCase,
  );
  return _extractIds(body);
}

Future<List<int>> _fetchIdsFromTagged(
  Dio dio, {
  required _TagCase tagCase,
  required int tagId,
  required String sort,
  required int page,
}) async {
  final body = await _getJson(
    dio,
    path: 'galleries/tagged',
    queryParameters: {
      'tag_id': tagId,
      'sort': sort,
      'page': page,
    },
    apiName: 'tagged',
    tagCase: tagCase,
  );
  return _extractIds(body);
}

void main() {
  group('nhentai tag search equivalence', () {
    const tagCases = <_TagCase>[
      _TagCase(tagId: 14283, tagName: 'anal'),
      _TagCase(tagId: 2937, tagName: 'big breasts'),
    ];

    late Dio dio;

    setUp(() {
      dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: const {
            'Accept': 'application/json',
            'Referer': 'https://nhentai.net/',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
          },
          validateStatus: (status) => status == 200,
        ),
      );
    });

    for (final tagCase in tagCases) {
      test(
        'search API matches tagged API for "${tagCase.tagName}"',
        () async {
          const sort = 'date';
          const page = 1;

          final searchIds = await _fetchIdsFromSearch(
            dio,
            tagCase: tagCase,
            tagName: tagCase.tagName,
            sort: sort,
            page: page,
          );
          final taggedIds = await _fetchIdsFromTagged(
            dio,
            tagCase: tagCase,
            tagId: tagCase.tagId,
            sort: sort,
            page: page,
          );

          expect(searchIds, isNotEmpty);
          expect(taggedIds, isNotEmpty);
          expect(searchIds, orderedEquals(taggedIds));
        },
        timeout: const Timeout(Duration(seconds: 30)),
      );
    }
  });
}
