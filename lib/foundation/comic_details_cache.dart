import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/comic_source/comic_source.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/foundation/sqlite_connection.dart';

/// Device-local cache of the latest comic details returned by a source.
/// Tags, chapter names and chapter groups can be restored synchronously without
/// another source request. The cache is included in local data backups.
class ComicDetailsCache {
  static ComicDetailsCache? _instance;

  factory ComicDetailsCache() =>
      _instance ??= ComicDetailsCache._open('${App.dataPath}/details_cache.db');

  @visibleForTesting
  static ComicDetailsCache openForTesting(String path) =>
      ComicDetailsCache._open(path);

  @visibleForTesting
  static int maxEntries = 2000;

  late final Database _db;

  ComicDetailsCache._open(String path) {
    _db = openSqliteDatabase(path);
    _db.execute('''
      CREATE TABLE IF NOT EXISTS details_cache (
        source_key TEXT NOT NULL,
        comic_id TEXT NOT NULL,
        data TEXT NOT NULL,
        time INTEGER NOT NULL,
        PRIMARY KEY (source_key, comic_id)
      );
    ''');
    _prune();
  }

  void close() {
    _db.dispose();
    if (identical(_instance, this)) _instance = null;
  }

  static bool isCacheable(String sourceKey) => sourceKey != 'local';

  ComicInfoData? find(String sourceKey, String comicId) {
    if (!isCacheable(sourceKey)) return null;
    try {
      final rows = _db.select(
        'SELECT data FROM details_cache WHERE source_key = ? AND comic_id = ?;',
        [sourceKey, comicId],
      );
      if (rows.isEmpty) return null;
      final details = ComicInfoData.fromJson(
        jsonDecode(rows.first[0] as String) as Map<String, dynamic>,
      );
      _db.execute(
        'UPDATE details_cache SET time = ? '
        'WHERE source_key = ? AND comic_id = ?;',
        [DateTime.now().millisecondsSinceEpoch, sourceKey, comicId],
      );
      return details;
    } catch (e) {
      try {
        _db.execute(
          'DELETE FROM details_cache WHERE source_key = ? AND comic_id = ?;',
          [sourceKey, comicId],
        );
      } catch (_) {}
      Log.warning('ComicDetailsCache', 'Dropped bad cache entry: $e');
      return null;
    }
  }

  void update(String sourceKey, String comicId, ComicInfoData details) {
    if (!isCacheable(sourceKey)) return;
    try {
      final encoded = jsonEncode(details.toJson());
      final rows = _db.select(
        'SELECT data FROM details_cache WHERE source_key = ? AND comic_id = ?;',
        [sourceKey, comicId],
      );
      if (rows.isNotEmpty && rows.first[0] == encoded) return;
      _db.execute(
        'INSERT OR REPLACE INTO details_cache '
        '(source_key, comic_id, data, time) VALUES (?, ?, ?, ?);',
        [sourceKey, comicId, encoded, DateTime.now().millisecondsSinceEpoch],
      );
    } catch (e) {
      Log.warning('ComicDetailsCache', 'Cache write failed: $e');
    }
  }

  void _prune() {
    try {
      final count =
          _db.select('SELECT COUNT(*) FROM details_cache;').first[0] as int;
      if (count <= maxEntries) return;
      _db.execute(
        'DELETE FROM details_cache WHERE rowid IN ('
        'SELECT rowid FROM details_cache ORDER BY time ASC, rowid ASC LIMIT ?'
        ');',
        [count - maxEntries],
      );
    } catch (_) {}
  }
}
