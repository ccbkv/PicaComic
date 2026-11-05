import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:pica_comic/foundation/sqlite_connection.dart';
import 'package:pica_comic/utils/extensions.dart';
import 'package:sqlite3/sqlite3.dart';

const _createCookiesTableSql = '''
  CREATE TABLE IF NOT EXISTS cookies (
    name TEXT NOT NULL,
    value TEXT NOT NULL,
    domain TEXT NOT NULL,
    path TEXT,
    expires INTEGER,
    secure INTEGER,
    httpOnly INTEGER,
    PRIMARY KEY (name, domain, path)
  );
''';

class CookieJarSql {
  final String path;

  late final Future<void> _ready;

  CookieJarSql(this.path) {
    _ready = init();
  }

  Future<void> init() async {
    try {
      await DatabaseGateway.instance.isolateOp(path, (db) {
        db.execute(_createCookiesTableSql);
      });
    } on SqliteException catch (e) {
      if (e.extendedResultCode != 26 &&
          e.message.contains('file is not a database') != true) {
        rethrow;
      }
      final broken = File(path);
      if (await broken.exists()) {
        await broken.delete();
      }
      await DatabaseGateway.instance.isolateOp(path, (db) {
        db.execute(_createCookiesTableSql);
      });
    }
  }

  Future<void> saveFromResponse(Uri uri, List<Cookie> cookies) async {
    await _ready;
    final uriString = uri.toString();
    final items = [
      for (final cookie in cookies)
        <String, dynamic>{
          'name': cookie.name,
          'value': cookie.value,
          'domain': cookie.domain,
          'path': cookie.path,
          'expires': cookie.expires?.millisecondsSinceEpoch,
          'secure': cookie.secure,
          'httpOnly': cookie.httpOnly,
        },
    ];
    await DatabaseGateway.instance.isolateOp(path, (db) {
      _saveFromResponse(db, Uri.parse(uriString), [
        for (final item in items)
          Cookie(item['name'] as String, item['value'] as String)
            ..domain = item['domain'] as String?
            ..path = item['path'] as String?
            ..expires = item['expires'] == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(item['expires'] as int)
            ..secure = item['secure'] as bool
            ..httpOnly = item['httpOnly'] as bool,
      ]);
    });
  }

  Future<List<Cookie>> loadForRequest(Uri uri) async {
    await _ready;
    final uriString = uri.toString();
    return DatabaseGateway.instance.isolateOp(path, (db) {
      return _loadForRequest(db, Uri.parse(uriString));
    });
  }

  Future<void> saveFromResponseCookieHeader(
      Uri uri, List<String> cookieHeader) {
    final cookies = cookieHeader.map(Cookie.fromSetCookieValue).toList();
    return saveFromResponse(uri, cookies);
  }

  Future<String> loadForRequestCookieHeader(Uri uri) async {
    final cookies = await loadForRequest(uri);
    final map = <String, Cookie>{};
    for (final cookie in cookies) {
      if (map.containsKey(cookie.name)) {
        if (cookie.domain![0] != '.' && map[cookie.name]!.domain![0] == '.') {
          map[cookie.name] = cookie;
        } else if (cookie.domain!.length > map[cookie.name]!.domain!.length) {
          map[cookie.name] = cookie;
        }
      } else {
        map[cookie.name] = cookie;
      }
    }
    return map.entries
        .map((cookie) => '${cookie.value.name}=${cookie.value.value}')
        .join('; ');
  }

  Future<void> delete(Uri uri, String name) async {
    await _ready;
    final domains = _getAcceptedDomains(uri.host);
    final uriPath = uri.path;
    await DatabaseGateway.instance.isolateOp(path, (db) {
      for (final domain in domains) {
        db.execute('''
          DELETE FROM cookies
          WHERE name = ? AND domain = ? AND path = ?;
        ''', [name, domain, uriPath]);
      }
    });
  }

  Future<void> deleteUri(Uri uri) async {
    await _ready;
    final domains = _getAcceptedDomains(uri.host);
    await DatabaseGateway.instance.isolateOp(path, (db) {
      for (final domain in domains) {
        db.execute('DELETE FROM cookies WHERE domain = ?;', [domain]);
      }
    });
  }

  Future<void> deleteAll() async {
    await _ready;
    await DatabaseGateway.instance.isolateOp(path, (db) {
      db.execute('DELETE FROM cookies;');
    });
  }

  void dispose() {
    // 数据库连接由各次后台任务自行关闭。
  }
}

void _saveFromResponse(Database db, Uri uri, List<Cookie> cookies) {
  final current = _loadForRequest(db, uri);
  for (final cookie in cookies) {
    final currentCookie = current.firstWhereOrNull((element) =>
        element.name == cookie.name &&
        (cookie.path == null || cookie.path!.startsWith(element.path!)));
    if (currentCookie != null) {
      cookie.domain = currentCookie.domain;
    }
    db.execute('''
      INSERT OR REPLACE INTO cookies (name, value, domain, path, expires, secure, httpOnly)
      VALUES (?, ?, ?, ?, ?, ?, ?);
    ''', [
      cookie.name,
      cookie.value,
      cookie.domain ?? uri.host,
      cookie.path ?? '/',
      cookie.expires?.millisecondsSinceEpoch,
      cookie.secure ? 1 : 0,
      cookie.httpOnly ? 1 : 0,
    ]);
  }
}

List<Cookie> _loadForRequest(Database db, Uri uri) {
  final cookies = <Cookie>[];
  for (final domain in _getAcceptedDomains(uri.host)) {
    cookies.addAll(_loadWithDomain(db, domain));
  }

  final now = DateTime.now();
  final expired = cookies
      .where(
          (cookie) => cookie.expires != null && cookie.expires!.isBefore(now))
      .toList();
  for (final cookie in expired) {
    db.execute('''
      DELETE FROM cookies
      WHERE name = ? AND domain = ? AND path = ?;
    ''', [cookie.name, cookie.domain, cookie.path]);
  }

  return cookies
      .where((cookie) =>
          !expired.contains(cookie) && _checkPathMatch(uri, cookie.path))
      .toList();
}

List<Cookie> _loadWithDomain(Database db, String domain) {
  final rows = db.select('''
    SELECT name, value, domain, path, expires, secure, httpOnly
    FROM cookies
    WHERE domain = ?;
  ''', [domain]);
  return rows
      .map((row) => Cookie(row['name'] as String, row['value'] as String)
        ..domain = row['domain'] as String
        ..path = row['path'] as String
        ..expires = row['expires'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row['expires'] as int)
        ..secure = row['secure'] == 1
        ..httpOnly = row['httpOnly'] == 1)
      .toList();
}

List<String> _getAcceptedDomains(String host) {
  final acceptedDomains = <String>[host];
  final hostParts = host.split('.');
  for (var i = 0; i < hostParts.length - 1; i++) {
    acceptedDomains.add('.${hostParts.sublist(i).join('.')}');
  }
  return acceptedDomains;
}

bool _checkPathMatch(Uri uri, String? cookiePath) {
  if (cookiePath == null || cookiePath == uri.path || cookiePath == '/') {
    return true;
  }
  return uri.path.startsWith(cookiePath);
}

class SingleInstanceCookieJar extends CookieJarSql {
  factory SingleInstanceCookieJar(String path) =>
      instance ??= SingleInstanceCookieJar._create(path);

  SingleInstanceCookieJar._create(super.path);

  static SingleInstanceCookieJar? instance;
}

class CookieManagerSql extends Interceptor {
  final CookieJarSql cookieJar;

  CookieManagerSql(this.cookieJar);

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final cookies = await cookieJar.loadForRequestCookieHeader(options.uri);
    if (cookies.isNotEmpty) {
      options.headers['cookie'] = cookies;
    }
    handler.next(options);
  }

  @override
  Future<void> onResponse(
      Response response, ResponseInterceptorHandler handler) async {
    await cookieJar.saveFromResponseCookieHeader(
        response.requestOptions.uri, response.headers['set-cookie'] ?? []);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err);
  }
}
