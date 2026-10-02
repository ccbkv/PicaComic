import 'dart:io';

import 'package:pica_comic/foundation/log.dart';
import 'package:sqlite3/sqlite3.dart';

/// 多设备同步的合并工具。
///
/// 旧版的 WebDAV 同步是"整库覆盖"：下载时直接用备份里的
/// `local_favorite.db` 覆盖本机，导致"两台手机各自收藏、各自上传"时
/// 必然互相覆盖丢失数据。
///
/// 这里提供按条目合并的实现：以 (target, type) 为主键做并集，
/// 同一条目保留 `time` 较新的那条记录；文件夹（SQLite 表）也做并集。
/// 这样 A 机收藏的、B 机没收藏的，合并后两边都会保留。
class SyncMerge {
  /// 最近一次收藏合并实际新增/更新的条目数。
  /// 用于决定合并后是否需要把结果回传服务器（0 表示本机已是超集）。
  static int lastMergedCount = 0;

  /// 表名不是收藏文件夹，需要单独处理。
  static const Set<String> _metaTables = {'folder_sync', 'folder_order'};

  /// 收藏表的标准列（旧版本可能缺部分列，这里统一按需补齐）。
  static const List<String> _favoriteColumns = [
    'target',
    'name',
    'author',
    'type',
    'tags',
    'cover_path',
    'time',
    'last_update_time',
    'has_new_update',
    'last_check_time',
    'display_order',
  ];

  /// 合并两个收藏数据库。
  ///
  /// [localPath]   - 本机数据库（作为合并基准，合并结果写回它）
  /// [backupPath]  - 备份（从 WebDAV 下载下来的）数据库
  ///
  /// 返回被新增/更新的条目数。返回 0 表示没有任何变化。
  static int mergeFavoriteDb({
    required String localPath,
    required String backupPath,
  }) {
    if (!File(backupPath).existsSync()) {
      return 0;
    }
    if (!File(localPath).existsSync()) {
      // 本机没有收藏库，直接把备份拿来用即可。
      File(backupPath).copySync(localPath);
      return -1; // -1 表示"整体采用备份"
    }

    Database? localDb;
    Database? backupDb;
    var changed = 0;
    try {
      localDb = sqlite3.open(localPath);
      backupDb = sqlite3.open(backupPath);

      final backupTables = _tables(backupDb);
      final localTables = _tables(localDb);

      // 1. 文件夹并集：备份里有、本机没有的文件夹 -> 建表
      for (final table in backupTables) {
        if (_metaTables.contains(table)) continue;
        if (!localTables.contains(table)) {
          _createFavoriteTable(localDb, table);
        }
      }

      // 2. 逐表合并条目
      for (final table in backupTables) {
        if (_metaTables.contains(table)) continue;
        if (!_tables(localDb).contains(table)) {
          _createFavoriteTable(localDb, table);
        }
        changed += _mergeTable(localDb, backupDb, table);
      }

      // 3. folder_order 并集（保留已有顺序，缺失的补 0）
      if (backupTables.contains('folder_order')) {
        _mergeFolderOrder(localDb, backupDb);
      }
    } catch (e, s) {
      LogManager.addLog(
          LogLevel.error, "SyncMerge", "mergeFavoriteDb failed: $e\n$s");
    } finally {
      backupDb?.dispose();
      localDb?.dispose();
    }
    return changed;
  }

  /// 合并单张表，返回新增/更新条数。
  static int _mergeTable(Database localDb, Database backupDb, String table) {
    var count = 0;
    final rows = backupDb.select('select * from "$table";');
    // 备份里的列可能比本机少，先对齐列。
    _ensureColumns(localDb, table);

    for (final row in rows) {
      final target = row['target'] as String?;
      final type = row['type'] as int?;
      if (target == null || type == null) continue;

      // 本机已有的同一条目
      final exist = localDb.select(
        'select * from "$table" where target == ? and type == ?;',
        [target, type],
      );

      if (exist.isEmpty) {
        // 本机没有 -> 直接插入（补上所有列，缺的给 null / 默认值）
        _insertRow(localDb, table, row);
        count++;
        continue;
      }

      // 两边都有 -> 保留 time 较新的
      // 注意：绝不能因为 time 为空就误判为更旧而丢弃备份数据
      final localTime = exist.first['time'] as String?;
      final backupTime = row['time'] as String?;
      if (_isNewer(backupTime, localTime)) {
        _updateRow(localDb, table, row);
        count++;
      }
    }
    return count;
  }

  /// a 是否比 b 新。时间格式为 "yyyy-MM-dd HH:mm:ss"，可直接字符串比较。
  static bool _isNewer(String? a, String? b) {
    if (a == null || a.isEmpty) return false;
    if (b == null || b.isEmpty) return true;
    return a.compareTo(b) > 0;
  }

  static void _insertRow(Database db, String table, Row row) {
    final cols = <String>[];
    final placeholders = <String>[];
    final values = <Object?>[];
    for (final col in _favoriteColumns) {
      cols.add(col);
      placeholders.add('?');
      values.add(row.keys.contains(col) ? row[col] : null);
    }
    // 保证 display_order 不为 null（旧数据可能缺失）
    final orderIndex = _favoriteColumns.indexOf('display_order');
    if (values[orderIndex] == null) {
      values[orderIndex] = _nextOrder(db, table);
    }
    db.execute(
      'insert or replace into "$table" (${cols.join(",")}) '
      'values (${placeholders.join(",")});',
      values,
    );
  }

  static void _updateRow(Database db, String table, Row row) {
    final sets = <String>[];
    final values = <Object?>[];
    for (final col in _favoriteColumns) {
      if (col == 'target' || col == 'type') continue;
      if (!row.keys.contains(col)) continue;
      sets.add('$col = ?');
      values.add(row[col]);
    }
    if (sets.isEmpty) return;
    values.add(row['target']);
    values.add(row['type']);
    db.execute(
      'update "$table" set ${sets.join(",")} '
      'where target == ? and type == ?;',
      values,
    );
  }

  static int _nextOrder(Database db, String table) {
    final r = db.select('select max(display_order) as m from "$table";');
    final m = r.isEmpty ? null : r.first['m'] as int?;
    return (m ?? 0) + 1;
  }

  static void _mergeFolderOrder(Database localDb, Database backupDb) {
    try {
      final rows = backupDb.select('select * from folder_order;');
      for (final row in rows) {
        final name = row['folder_name'];
        if (name == null) continue;
        // 本机已有顺序就不覆盖，只补缺失的
        final exist = localDb.select(
          'select * from folder_order where folder_name == ?;',
          [name],
        );
        if (exist.isEmpty) {
          localDb.execute(
            'insert or replace into folder_order (folder_name, order_value) '
            'values (?, ?);',
            [name, row['order_value'] ?? 0],
          );
        }
      }
    } catch (e) {
      // folder_order 表可能不存在，忽略
    }
  }

  static List<String> _tables(Database db) {
    return db
        .select("SELECT name FROM sqlite_master WHERE type='table';")
        .map((e) => e['name'] as String)
        .toList();
  }

  static void _createFavoriteTable(Database db, String name) {
    db.execute('''
      create table if not exists "$name"(
        target text,
        name TEXT,
        author TEXT,
        type int,
        tags TEXT,
        cover_path TEXT,
        time TEXT,
        last_update_time TEXT DEFAULT NULL,
        has_new_update INTEGER DEFAULT 0,
        last_check_time INTEGER DEFAULT NULL,
        display_order int,
        primary key (target, type)
      );
    ''');
  }

  /// 补齐旧版本缺失的列，避免 insert 时列不存在。
  static void _ensureColumns(Database db, String table) {
    final cols = db
        .select('PRAGMA table_info("$table");')
        .map((e) => e['name'] as String)
        .toSet();
    if (!cols.contains('last_update_time')) {
      db.execute(
          'ALTER TABLE "$table" ADD COLUMN last_update_time TEXT DEFAULT NULL;');
    }
    if (!cols.contains('has_new_update')) {
      db.execute(
          'ALTER TABLE "$table" ADD COLUMN has_new_update INTEGER DEFAULT 0;');
    }
    if (!cols.contains('last_check_time')) {
      db.execute(
          'ALTER TABLE "$table" ADD COLUMN last_check_time INTEGER DEFAULT NULL;');
    }
    if (!cols.contains('display_order')) {
      db.execute('ALTER TABLE "$table" ADD COLUMN display_order int;');
    }
  }

  /// 合并 comic_source 目录：本机已有的文件保留，备份里新增的补进去。
  ///
  /// 返回新增文件数。
  static int mergeComicSource({
    required String localDir,
    required String backupDir,
  }) {
    final backup = Directory(backupDir);
    if (!backup.existsSync()) return 0;
    final local = Directory(localDir);
    if (!local.existsSync()) {
      local.createSync(recursive: true);
    }
    var count = 0;
    for (final entity in backup.listSync(recursive: true)) {
      if (entity is! File) continue;
      final relative = entity.path
          .substring(backup.path.length)
          .replaceFirst(RegExp(r'^[\\/]+'), '');
      final targetFile = File('${local.path}/$relative');
      if (!targetFile.existsSync()) {
        targetFile.parent.createSync(recursive: true);
        entity.copySync(targetFile.path);
        count++;
      }
    }
    return count;
  }

  /// 合并目录（用于 chapter_comments / comic_comments / local_add_comic）。
  ///
  /// 这是纯文件目录，按相对路径补充，本机已有的不覆盖。
  static int mergeDirectory({
    required String localDir,
    required String backupDir,
  }) {
    return mergeComicSource(localDir: localDir, backupDir: backupDir);
  }
}
