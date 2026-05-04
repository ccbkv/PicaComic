import 'dart:convert';
import 'dart:io';

const _tagRequests = <_TagRequest>[
  _TagRequest('tag', 5),
  _TagRequest('character', 9),
  _TagRequest('parody', 4),
];

const _baseUrl = 'https://nhentai.net/api/v2/tags';
const _defaultOutputPath = 'lib/network/nhentai_network/tags.dart';
const _defaultRequestDelay = Duration(milliseconds: 3000);

void main() async {
  await generateNhentaiTags();
}

Future<void> generateNhentaiTags({
  String outputPath = _defaultOutputPath,
  Duration requestDelay = _defaultRequestDelay,
}) async {
  final tags = await fetchNhentaiTagMappings(
    requestDelay: requestDelay,
  );
  final fileContent = buildNhentaiTagsFileContent(tags);
  await File(outputPath).writeAsString(fileContent);
  stdout.writeln(
    'Generated ${tags.length} nhentai tags to '
    '${File(outputPath).absolute.path}',
  );
}

Future<List<NhentaiTagRecord>> fetchNhentaiTagMappings({
  Duration requestDelay = _defaultRequestDelay,
}) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = const Duration(seconds: 15);

  try {
    final tags = <NhentaiTagRecord>[];
    for (final request in _tagRequests) {
      tags.addAll(
        await _fetchTagsByType(
          client,
          request.type,
          maxPages: request.maxPages,
          requestDelay: requestDelay,
        ),
      );
    }
    tags.sort((left, right) {
      final countCompare = right.count.compareTo(left.count);
      if (countCompare != 0) {
        return countCompare;
      }
      return left.id.compareTo(right.id);
    });
    return tags;
  } finally {
    client.close(force: true);
  }
}

String buildNhentaiTagsFileContent(List<NhentaiTagRecord> tags) {
  final groupedTags = <String, List<NhentaiTagRecord>>{};
  for (final tag in tags) {
    groupedTags.putIfAbsent(tag.type, () => []).add(tag);
  }

  final buffer = StringBuffer();
  _writeTagMap(
    buffer,
    'nhentaiTags',
    groupedTags['tag'] ?? const [],
  );
  _writeTagMap(
    buffer,
    'nhentaiCharacterTags',
    groupedTags['character'] ?? const [],
  );
  _writeTagMap(
    buffer,
    'nhentaiParodyTags',
    groupedTags['parody'] ?? const [],
  );
  return buffer.toString();
}

void _writeTagMap(
  StringBuffer buffer,
  String variableName,
  List<NhentaiTagRecord> tags,
) {
  buffer.writeln('const Map<String, String> $variableName = {');
  for (final tag in tags) {
    buffer.writeln('  ${jsonEncode(tag.id)}: ${jsonEncode(tag.name)},');
  }
  buffer.writeln('};');
  buffer.writeln();
}

Future<List<NhentaiTagRecord>> _fetchTagsByType(
  HttpClient client,
  String type, {
  required int maxPages,
  Duration requestDelay = _defaultRequestDelay,
}) async {
  final tags = <NhentaiTagRecord>[];
  var page = 1;
  int? numPages;

  while ((numPages == null || page <= numPages) && page <= maxPages) {
    final data = await _requestTagPage(
      client,
      type,
      page,
      requestDelay: requestDelay,
    );
    final result = (data['result'] as List).cast<Map<String, dynamic>>();
    numPages ??= (data['num_pages'] as num?)?.toInt() ?? page;

    for (final item in result) {
      tags.add(
        NhentaiTagRecord(
          id: item['id'].toString(),
          name: item['name'] as String,
          type: item['type'] as String,
          count: (item['count'] as num).toInt(),
        ),
      );
    }

    if (result.isEmpty) {
      break;
    }
    page++;
    if (page <= numPages && page <= maxPages) {
      await Future<void>.delayed(requestDelay);
    }
  }

  return tags;
}

Future<Map<String, dynamic>> _requestTagPage(
  HttpClient client,
  String type,
  int page, {
  required Duration requestDelay,
}) async {
  final uri = Uri.parse('$_baseUrl/$type').replace(
    queryParameters: {
      'sort': 'popular',
      'page': '$page',
      'per_page': '100',
    },
  );

  for (var attempt = 1; attempt <= 5; attempt++) {
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode == HttpStatus.ok) {
      return jsonDecode(body) as Map<String, dynamic>;
    }

    if (response.statusCode == HttpStatus.tooManyRequests && attempt < 5) {
      final retryAfter = response.headers.value(HttpHeaders.retryAfterHeader);
      final delaySeconds = int.tryParse(retryAfter ?? '') ?? 10 * attempt;
      await Future<void>.delayed(Duration(seconds: delaySeconds));
      continue;
    }

    throw HttpException(
      'Failed to fetch nhentai tags: ${response.statusCode} $body',
      uri: uri,
    );
  }

  throw HttpException('Failed to fetch nhentai tags after retries', uri: uri);
}

class NhentaiTagRecord {
  final String id;
  final String name;
  final String type;
  final int count;

  const NhentaiTagRecord({
    required this.id,
    required this.name,
    required this.type,
    required this.count,
  });
}

class _TagRequest {
  final String type;
  final int maxPages;

  const _TagRequest(this.type, this.maxPages);
}
