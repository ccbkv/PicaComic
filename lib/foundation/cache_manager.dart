import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/sqlite_connection.dart';
import 'package:pica_comic/utils/io_extensions.dart';

class CacheManager {
  static String get cachePath => '${App.cachePath}/cache';

  static CacheManager? instance;

  final String _dbPath = '${App.dataPath}/cache.db';
  late final Future<void> _ready;
  final Map<String, String?> _types = {};

  int? _currentSize;

  /// size in bytes
  int get currentSize => _currentSize ?? 0;

  int dir = 0;

  int _limitSize = 2 * 1024 * 1024 * 1024;

  int get limitSize => _limitSize;

  CacheManager._create() {
    Directory(cachePath).createSync(recursive: true);
    _ready = _init();
    compute((path) => Directory(path).size, cachePath)
        .then((value) => _currentSize = value);
  }

  Future<void> _init() async {
    await DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      db.execute('''
        CREATE TABLE IF NOT EXISTS cache (
          key TEXT PRIMARY KEY NOT NULL,
          dir TEXT NOT NULL,
          name TEXT NOT NULL,
          expires INTEGER NOT NULL,
          type TEXT
        )
      ''');
      // 旧版本的表中没有type字段，需要添加
      try {
        db.execute('ALTER TABLE cache ADD COLUMN type TEXT');
      } catch (e) {
        // ignore
      }
    });
    final rows = await DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      return db
          .select('SELECT key, type FROM cache')
          .map((row) => <String, Object?>{
                'key': row['key'],
                'type': row['type'],
              })
          .toList();
    });
    _types
      ..clear()
      ..addEntries(rows.map(
          (row) => MapEntry(row['key'] as String, row['type'] as String?)));
  }

  factory CacheManager() => instance ??= CacheManager._create();

  /// set cache size limit in MB
  void setLimitSize(int size) {
    _limitSize = size * 1024 * 1024;
  }

  void setType(String key, String? type) {
    _types[key] = type;
    unawaited(
        _ready.then((_) => DatabaseGateway.instance.isolateOp(_dbPath, (db) {
              db.execute('''
            UPDATE cache
            SET type = ?
            WHERE key = ?
          ''', [type, key]);
            })));
  }

  String? getType(String key) => _types[key];

  Future<void> writeCache(String key, Uint8List data,
      [int duration = 7 * 24 * 60 * 60 * 1000]) async {
    await _ready;
    this.dir++;
    this.dir %= 100;
    var dir = this.dir;
    var name = md5.convert(Uint8List.fromList(key.codeUnits)).toString();
    var file = File('$cachePath/$dir/$name');
    while (await file.exists()) {
      name = md5.convert(Uint8List.fromList(name.codeUnits)).toString();
      file = File('$cachePath/$dir/$name');
    }
    await file.create(recursive: true);
    await file.writeAsBytes(data);
    var expires = DateTime.now().millisecondsSinceEpoch + duration;
    await _saveRecord(key, dir.toString(), name, expires);
    if (_currentSize != null) {
      _currentSize = _currentSize! + data.length;
    }
    if (_currentSize != null && _currentSize! > _limitSize) {
      await checkCache();
    }
  }

  Future<void> _saveRecord(
      String key, String dir, String name, int expires) async {
    await _ready;
    await DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      db.execute('''
        INSERT OR REPLACE INTO cache (key, dir, name, expires)
        VALUES (?, ?, ?, ?)
      ''', [key, dir, name, expires]);
    });
    _types.remove(key);
  }

  Future<CachingFile> openWrite(String key) async {
    await _ready;
    this.dir++;
    this.dir %= 100;
    var dir = this.dir;
    var name = md5.convert(Uint8List.fromList(key.codeUnits)).toString();
    var file = File('$cachePath/$dir/$name');
    while (await file.exists()) {
      name = md5.convert(Uint8List.fromList(name.codeUnits)).toString();
      file = File('$cachePath/$dir/$name');
    }
    await file.create(recursive: true);
    return CachingFile._(key, dir.toString(), name, file);
  }

  Future<String?> findCache(String key) async {
    await _ready;
    final row = await DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      final rows = db.select('''
        SELECT key, dir, name, type FROM cache
        WHERE key = ?
      ''', [key]);
      if (rows.isEmpty) return null;
      final row = rows.first;
      return <String, Object?>{
        'key': row['key'],
        'dir': row['dir'],
        'name': row['name'],
        'type': row['type'],
      };
    });
    if (row == null) {
      _types.remove(key);
      return null;
    }
    _types[key] = row['type'] as String?;
    var file = File('$cachePath/${row['dir']}/${row['name']}');
    if (await file.exists()) {
      return file.path;
    }
    return null;
  }

  Future<List<Map<String, Object?>>> _queryRows(
      String sql, List<Object?> params) async {
    await _ready;
    return DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      return db
          .select(sql, params)
          .map((row) => <String, Object?>{
                'key': row['key'],
                'dir': row['dir'],
                'name': row['name'],
                'expires': row['expires'],
                'type': row['type'],
              })
          .toList();
    });
  }

  Future<void> _execute(String sql, List<Object?> params) async {
    await _ready;
    await DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      db.execute(sql, params);
    });
  }

  bool _isChecking = false;

  Future<void> checkCache() async {
    if (_isChecking) {
      return;
    }
    _isChecking = true;
    try {
      await _ready;
      final now = DateTime.now().millisecondsSinceEpoch;
      final expired = await _queryRows('''
        SELECT * FROM cache
        WHERE expires < ?
      ''', [now]);
      for (final row in expired) {
        var file = File('$cachePath/${row['dir']}/${row['name']}');
        if (await file.exists()) {
          await file.delete();
        }
        _types.remove(row['key']);
      }
      await _execute('''
        DELETE FROM cache
        WHERE expires < ?
      ''', [now]);

      final count = await DatabaseGateway.instance.isolateOp(_dbPath, (db) {
        return db.select('SELECT COUNT(*) FROM cache').first[0] as int;
      });
      var remaining = count;
      _currentSize = await compute((path) => Directory(path).size, cachePath);

      while ((_currentSize != null && _currentSize! > _limitSize) ||
          remaining > 2000) {
        final rows = await _queryRows('''
          SELECT * FROM cache
          ORDER BY expires ASC
          limit 10
        ''', const []);
        if (rows.isEmpty) break;
        for (final row in rows) {
          final key = row['key'] as String;
          var file = File('$cachePath/${row['dir']}/${row['name']}');
          var fileSize = 0;
          if (await file.exists()) {
            fileSize = await file.length();
            await file.delete();
          }
          await _execute('DELETE FROM cache WHERE key = ?', [key]);
          _types.remove(key);
          if (_currentSize != null) {
            _currentSize = _currentSize! - fileSize;
          }
          remaining--;
          if (_currentSize != null && _currentSize! <= _limitSize) {
            break;
          }
        }
      }
    } finally {
      _isChecking = false;
    }
  }

  Future<void> delete(String key) async {
    final rows = await _queryRows('''
      SELECT * FROM cache
      WHERE key = ?
    ''', [key]);
    if (rows.isEmpty) {
      return;
    }
    final row = rows.first;
    var file = File('$cachePath/${row['dir']}/${row['name']}');
    var fileSize = 0;
    if (await file.exists()) {
      fileSize = await file.length();
      await file.delete();
    }
    await _execute('DELETE FROM cache WHERE key = ?', [key]);
    _types.remove(key);
    if (_currentSize != null) {
      _currentSize = _currentSize! - fileSize;
    }
  }

  /// Deletes every cache entry whose key starts with [prefix], returning the
  /// number removed.
  Future<int> deleteByPrefix(String prefix) async {
    var escapedPrefix = _escapeLike(prefix);
    final rows = await _queryRows('''
      SELECT * FROM cache
      WHERE key LIKE ? ESCAPE '\\'
    ''', ['$escapedPrefix%']);
    for (final row in rows) {
      var file = File('$cachePath/${row['dir']}/${row['name']}');
      if (await file.exists()) {
        var fileSize = await file.length();
        await file.delete();
        if (_currentSize != null) {
          _currentSize = _currentSize! - fileSize;
        }
      }
      _types.remove(row['key']);
    }
    await _execute('''
      DELETE FROM cache
      WHERE key LIKE ? ESCAPE '\\'
    ''', ['$escapedPrefix%']);
    return rows.length;
  }

  /// Escapes LIKE wildcards so they are matched literally in a prefix.
  static String _escapeLike(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');

  Future<void> clear() async {
    await _ready;
    await Directory(cachePath).delete(recursive: true);
    Directory(cachePath).createSync(recursive: true);
    await _execute('DELETE FROM cache', const []);
    _types.clear();
    _currentSize = 0;
  }

  Future<void> deleteKeyword(String keyword) async {
    final rows = await _queryRows('''
      SELECT * FROM cache
      WHERE key LIKE ?
    ''', ['%$keyword%']);
    for (final row in rows) {
      final key = row['key'] as String;
      var file = File('$cachePath/${row['dir']}/${row['name']}');
      var fileSize = 0;
      if (await file.exists()) {
        fileSize = await file.length();
        await file.delete();
      }
      await _execute('DELETE FROM cache WHERE key = ?', [key]);
      _types.remove(key);
      if (_currentSize != null) {
        _currentSize = _currentSize! - fileSize;
      }
    }
  }
}

class CachingFile {
  CachingFile._(this.key, this.dir, this.name, this.file);

  final String key;

  final String dir;

  final String name;

  final File file;

  final List<int> _buffer = [];

  Future<void> writeBytes(List<int> data) async {
    _buffer.addAll(data);
    if (_buffer.length > 1024 * 1024) {
      await file.writeAsBytes(_buffer, mode: FileMode.append);
      _buffer.clear();
    }
  }

  Future<void> close() async {
    if (_buffer.isNotEmpty) {
      await file.writeAsBytes(_buffer, mode: FileMode.append);
    }
    await CacheManager()._saveRecord(key, dir, name,
        DateTime.now().millisecondsSinceEpoch + 7 * 24 * 60 * 60 * 1000);
    await CacheManager().checkCache();
  }

  Future<void> cancel() async {
    await file.deleteIgnoreError();
  }

  void reset() {
    _buffer.clear();
    if (file.existsSync()) {
      file.deleteSync();
    }
  }
}
