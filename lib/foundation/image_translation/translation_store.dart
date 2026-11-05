import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/image_translation/translation_types.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/foundation/sqlite_connection.dart';
import 'package:sqlite3/sqlite3.dart';

/// Persistent store of finished per-page translation text: the recognized
/// regions and their translated strings for one page, under one language pair.
///
/// This is the durable source of truth for translations — NOT a cache. The
/// rendered page image stays in [CacheManager] (re-derivable from these regions
/// at any time, free to LRU-evict); the text here is what lets a page
/// re-render — or render on another device — without paying for OCR or an LLM
/// request again. Nothing here expires; the user clears it explicitly.
///
/// Rows are keyed by the page's translation [cacheKey], the same composed
/// string the reader/pre-translation paths already use — it embeds
/// `sourceLang>targetLang`, the comic, the chapter and the image, and is built
/// to form deletable scope prefixes (see [ImageTranslationService.cacheKeyFor]).
/// Keying on it avoids parsing components back out (image keys are URLs that may
/// contain the field separator) and reuses the existing prefix scopes verbatim
/// for per-comic / per-chapter deletion.
///
/// It lives in its own database file so it rides the WebDAV/backup pipeline like
/// every other store: exporting the file and merging it on another device
/// carries a comic's translations across. Import merges (INSERT OR IGNORE) so
/// two devices that translated different chapters keep both halves.
class TranslationChapterIdentity {
  const TranslationChapterIdentity({
    required this.scopePrefix,
    required this.sourceKey,
    required this.comicId,
    required this.chapterId,
    required this.sourceLang,
    required this.targetLang,
    this.comicTitle = '',
    this.comicCover = '',
    this.chapterTitle = '',
  });

  final String scopePrefix;
  final String sourceKey;
  final String comicId;
  final String chapterId;
  final String sourceLang;
  final String targetLang;
  final String comicTitle;
  final String comicCover;
  final String chapterTitle;
}

class StoredTranslationChapter {
  const StoredTranslationChapter({
    required this.identity,
    required this.pageCount,
    required this.updatedAt,
  });

  final TranslationChapterIdentity identity;
  final int pageCount;
  final DateTime updatedAt;
}

class StoredTranslationComic {
  const StoredTranslationComic({
    required this.sourceKey,
    required this.comicId,
    required this.sourceLang,
    required this.targetLang,
    required this.title,
    required this.cover,
    required this.chapterCount,
    required this.pageCount,
    required this.updatedAt,
  });

  final String sourceKey;
  final String comicId;
  final String sourceLang;
  final String targetLang;
  final String title;
  final String cover;
  final int chapterCount;
  final int pageCount;
  final DateTime updatedAt;
}

typedef _TranslationStoreSnapshot = ({
  List<List<Object?>> pages,
  List<List<Object?>> chapters,
});

class _TranslationPageSnapshot {
  const _TranslationPageSnapshot(this.regions, this.time);

  final Object? regions;
  final int? time;
}

class TranslationStore with ChangeNotifier {
  static TranslationStore? _cache;

  TranslationStore.create();

  factory TranslationStore() => _cache ??= TranslationStore.create();

  late String _dbPath;

  final _pages = <String, _TranslationPageSnapshot>{};
  final _chapterIndex = <String, StoredTranslationChapter>{};
  var _snapshotVersion = 0;

  Timer? _notifyTimer;

  bool isInitialized = false;

  Future<void> init() async {
    if (isInitialized) return;
    _dbPath = "${App.dataPath}/image_translation.db";
    final snapshot = await DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      db.execute(_createTableSql);
      db.execute(_createIndexTableSql);
      migrateSchema(db);
      migrateLegacyKeys(db);
      _backfillChapterIndex(db);
      return _readSnapshot(db);
    });
    _applySnapshot(snapshot);
    _snapshotVersion = 0;
    isInitialized = true;
  }

  /// Merges the rows of another translation database at [sourcePath] into this
  /// one without dropping local rows — the WebDAV/backup import path. A device
  /// that translated chapters 1-5 and one that did 6-10 end up with all ten, and
  /// where both hold the same page the local row wins (INSERT OR IGNORE). The
  /// source is opened read-only and disposed before returning. Tolerates a
  /// foreign/absent file: an incompatible table simply merges nothing.
  Future<int> mergeFrom(String sourcePath) async {
    if (!isInitialized) {
      throw StateError("TranslationStore is not initialized; cannot merge");
    }
    var merged = 0;
    try {
      merged = await DatabaseGateway.instance.isolateOp(_dbPath, (db) {
        return withDatabase(sourcePath, mode: OpenMode.readOnly, (src) {
          return _mergeDatabases(db, src);
        });
      });
      await _refreshSnapshot();
    } catch (e, s) {
      Log.error("TranslationStore", "merge failed: $e\n$s");
    }
    if (merged > 0 && isInitialized) _notifyChanged();
    return merged;
  }

  Future<void> _refreshSnapshot() async {
    while (isInitialized) {
      final version = _snapshotVersion;
      final snapshot = await DatabaseGateway.instance.isolateOp(
        _dbPath,
        _readSnapshot,
      );
      if (!isInitialized) return;
      if (version != _snapshotVersion) continue;
      _applySnapshot(snapshot);
      return;
    }
  }

  static const String _createTableSql = """
      create table if not exists translated_page (
        cache_key text primary key,
        regions text,
        time int
      );
    """;

  static const String _createIndexTableSql = """
      create table if not exists translated_chapter_index (
        scope_prefix text primary key,
        source_key text not null,
        comic_id text not null,
        chapter_id text not null,
        source_lang text not null,
        target_lang text not null,
        comic_title text not null default '',
        comic_cover text not null default '',
        chapter_title text not null default '',
        page_count int not null default 0,
        updated_at int not null default 0
      );
    """;

  static const _indexColumns = {
    'scope_prefix',
    'source_key',
    'comic_id',
    'chapter_id',
    'source_lang',
    'target_lang',
    'comic_title',
    'comic_cover',
    'chapter_title',
    'page_count',
    'updated_at',
  };

  /// Columns a foreign database must have for [mergeFrom] to read it.
  static const _requiredColumns = ["cache_key", "regions", "time"];

  static int _mergeDatabases(Database db, Database src) {
    final cols = src
        .select("PRAGMA table_info(translated_page);")
        .map((c) => c["name"] as String)
        .toSet();
    if (!_requiredColumns.every(cols.contains)) return 0;
    final rows = src.select(
      "select cache_key, regions, time from translated_page;",
    );
    final indexColumns = src
        .select("PRAGMA table_info(translated_chapter_index);")
        .map((c) => c["name"] as String)
        .toSet();
    final indexRows = _indexColumns.every(indexColumns.contains)
        ? src.select("select * from translated_chapter_index;")
        : null;
    var merged = 0;
    db.execute("BEGIN TRANSACTION;");
    try {
      for (final row in rows) {
        db.execute(_insertIgnoreSql, [
          row["cache_key"],
          row["regions"],
          row["time"],
        ]);
        merged++;
      }
      if (indexRows != null) {
        for (final row in indexRows) {
          _upsertChapterRow(
            db,
            [
              row['scope_prefix'],
              row['source_key'],
              row['comic_id'],
              row['chapter_id'],
              row['source_lang'],
              row['target_lang'],
              row['comic_title'],
              row['comic_cover'],
              row['chapter_title'],
            ],
            pageCount: row['page_count'] as int? ?? 0,
            updatedAt: row['updated_at'] as int? ?? 0,
          );
        }
      }
      migrateLegacyKeys(db);
      _backfillChapterIndex(db);
      _recountIndex(db);
      db.execute("COMMIT;");
    } catch (_) {
      db.execute("ROLLBACK;");
      rethrow;
    }
    return merged;
  }

  static _TranslationStoreSnapshot _readSnapshot(Database db) {
    final pages = db
        .select('select cache_key, regions, time from translated_page;')
        .map(
          (row) => <Object?>[
            row['cache_key'],
            row['regions'],
            row['time'],
          ],
        )
        .toList();
    final chapters = db
        .select(
          'select scope_prefix, source_key, comic_id, chapter_id, '
          'source_lang, target_lang, comic_title, comic_cover, '
          'chapter_title, page_count, updated_at '
          'from translated_chapter_index;',
        )
        .map(
          (row) => <Object?>[
            row['scope_prefix'],
            row['source_key'],
            row['comic_id'],
            row['chapter_id'],
            row['source_lang'],
            row['target_lang'],
            row['comic_title'],
            row['comic_cover'],
            row['chapter_title'],
            row['page_count'],
            row['updated_at'],
          ],
        )
        .toList();
    return (pages: pages, chapters: chapters);
  }

  /// Generation 1 keys carry no generation segment (`pageTranslation@ja>zh@…`),
  /// so generation-2 lookups (`pageTranslation@2@ja>zh@…`) miss them and the
  /// pages read as never translated. Rewrite those keys into the generation-2
  /// namespace instead of dropping the rows: the stored text is the expensive,
  /// non-reproducible part (OCR + a paid translation request) and is unaffected
  /// by the generation bump. What generation 1 lacks is per-line erase
  /// rectangles (`es`), and their absence is already handled downstream — the
  /// renderer falls back to the union [TranslatedRegion.eraseRect] and computes
  /// the actual stroke mask from the page pixels at render time, so a migrated
  /// row erases no more broadly than a fresh one.
  ///
  /// A generation-2 row for the same page already being present means the page
  /// was re-translated after the upgrade; that row is newer, so INSERT OR IGNORE
  /// keeps it and the legacy duplicate is dropped.
  @visibleForTesting
  static void migrateLegacyKeys(Database db) {
    db.execute(
      "insert or ignore into translated_page (cache_key, regions, time) "
      "select '$_currentPrefix' || $_tail, regions, time "
      "from translated_page where $_isLegacyKey;",
    );
    db.execute("delete from translated_page where $_isLegacyKey;");
  }

  static const _keyPrefix = 'pageTranslation@';

  /// Current generation prefix. Must stay in step with
  /// `TranslationConfig.cachePrefix`.
  static const _currentPrefix = '${_keyPrefix}2@';

  /// Everything after `pageTranslation@` — for a legacy key this is the whole
  /// `sourceLang>targetLang@source@comic@chapter@image` remainder.
  static const _tail = "substr(cache_key, length('$_keyPrefix') + 1)";

  /// The generation segment: the part of [_tail] before its first `@` — `ja>zh`
  /// for a legacy key, `2` for a current one. Matched as a whole segment so a
  /// future two-digit generation is not mistaken for a legacy key.
  static const _generation = "substr($_tail, 1, instr($_tail, '@') - 1)";

  /// A key belongs to generation 1 when its generation segment is not a number,
  /// i.e. the language pair sits where the generation number now goes. A key
  /// with no `@` at all is malformed rather than legacy and is left untouched.
  static const _isLegacyKey =
      "cache_key like '$_keyPrefix%' and $_generation glob '*[^0-9]*'";

  static final _currentKeyPattern = RegExp(
    r'^pageTranslation@2@([^@>]+)>([^@]+)@([^@]+)@([^@]+)@([^@]+)@',
  );

  static const Map<String, String> _expectedColumns = {
    "cache_key": "text",
    "regions": "text",
    "time": "int",
  };

  /// Normalize the on-disk `translated_page` table to our canonical schema — a
  /// restore/merge can meet a file a foreign app happens to name the same.
  /// Mirrors [ReadLaterManager.migrateSchema]: rebuild on structural
  /// divergence, additively backfill a column missing from an older own schema.
  @visibleForTesting
  static void migrateSchema(Database db) {
    final columns = db.select("PRAGMA table_info(translated_page);");
    final existing = columns.map((c) => c["name"] as String).toSet();
    final hasExtraColumn = existing.any(
      (c) => !_expectedColumns.containsKey(c),
    );
    final missingColumn = _expectedColumns.keys.any(
      (c) => !existing.contains(c),
    );
    if (hasExtraColumn) {
      _rebuildTable(db, existing);
      return;
    }
    if (missingColumn) {
      for (final entry in _expectedColumns.entries) {
        if (!existing.contains(entry.key)) {
          db.execute(
            "alter table translated_page add column ${entry.key} ${entry.value};",
          );
        }
      }
    }
  }

  static void _rebuildTable(Database db, Set<String> existing) {
    final carried = _expectedColumns.keys.where(existing.contains).toList();
    final columnList = carried.join(", ");
    db.execute("BEGIN TRANSACTION;");
    try {
      db.execute(
        "alter table translated_page rename to translated_page_legacy;",
      );
      db.execute(_createTableSql);
      if (carried.isNotEmpty) {
        db.execute(
          "insert or ignore into translated_page ($columnList) "
          "select $columnList from translated_page_legacy;",
        );
      }
      db.execute("drop table translated_page_legacy;");
      db.execute("COMMIT;");
    } catch (e, s) {
      db.execute("ROLLBACK;");
      Log.error("TranslationStore", "rebuild failed: $e\n$s");
    }
  }

  static const _insertReplaceSql = """
    insert or replace into translated_page (cache_key, regions, time)
    values (?, ?, ?);
  """;

  static const _insertIgnoreSql = """
    insert or ignore into translated_page (cache_key, regions, time)
    values (?, ?, ?);
  """;

  static List<Object?> _chapterValues(TranslationChapterIdentity chapter) => [
        chapter.scopePrefix,
        chapter.sourceKey,
        chapter.comicId,
        chapter.chapterId,
        chapter.sourceLang,
        chapter.targetLang,
        chapter.comicTitle,
        chapter.comicCover,
        chapter.chapterTitle,
      ];

  static void _putPage(
    Database db,
    String cacheKey,
    String regions,
    int timestamp,
    List<Object?>? chapter,
  ) {
    db.execute(_insertReplaceSql, [cacheKey, regions, timestamp]);
    if (chapter != null) {
      _upsertChapterRow(
        db,
        chapter,
        pageCount: _countByPrefix(db, chapter[0] as String),
        updatedAt: timestamp,
      );
    }
  }

  /// Stores the finished [regions] of one page. An empty list is valid and
  /// meaningful: it records "this page has no translatable text", so the page is
  /// never re-analyzed. A local write overwrites (INSERT OR REPLACE) — a
  /// re-translate must win over whatever was there.
  void put(
    String cacheKey,
    List<TranslatedRegion> regions, {
    TranslationChapterIdentity? chapter,
  }) {
    if (!isInitialized) return;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final encoded = jsonEncode([for (var r in regions) r.toJson()]);
    final chapterData = chapter == null ? null : _chapterValues(chapter);
    _pages[cacheKey] = _TranslationPageSnapshot(encoded, timestamp);
    _snapshotVersion++;
    if (chapter != null) {
      _upsertChapterSnapshot(
        chapter,
        pageCount: countByPrefix(chapter.scopePrefix),
        updatedAt: timestamp,
      );
      _notifyChanged();
    }
    _trackWrite(
      DatabaseGateway.instance.isolateOp(_dbPath, (db) {
        _putPage(db, cacheKey, encoded, timestamp, chapterData);
      }),
      'put',
    );
  }

  static void _recordExistingChapter(Database db, List<Object?> chapter) {
    final escaped = _escapeLike(chapter[0] as String);
    final stats = db.select(
      "select count(*) as page_count, max(time) as updated_at "
      "from translated_page where cache_key like ? escape '\\';",
      ['$escaped%'],
    ).first;
    final pages = stats['page_count'] as int? ?? 0;
    if (pages <= 0) return;
    _upsertChapterRow(
      db,
      chapter,
      pageCount: pages,
      updatedAt: stats['updated_at'] as int? ?? 0,
    );
  }

  int recordExistingChapter(TranslationChapterIdentity chapter) {
    if (!isInitialized) return 0;
    final stats = _pageStats(chapter.scopePrefix);
    final pages = stats.$1;
    if (pages <= 0) return 0;
    final changed = _upsertChapterSnapshot(
      chapter,
      pageCount: pages,
      updatedAt: stats.$2,
    );
    if (changed) {
      _snapshotVersion++;
      _notifyChanged();
    }
    final chapterData = _chapterValues(chapter);
    _trackWrite(
      DatabaseGateway.instance.isolateOp(_dbPath, (db) {
        _recordExistingChapter(db, chapterData);
      }),
      'recordExistingChapter',
    );
    return pages;
  }

  (int, int) _pageStats(String scopePrefix) {
    var pages = 0;
    int? updatedAt;
    for (final entry in _pages.entries) {
      if (!entry.key.startsWith(scopePrefix)) continue;
      pages++;
      final time = entry.value.time;
      if (time != null && (updatedAt == null || time > updatedAt)) {
        updatedAt = time;
      }
    }
    return (pages, updatedAt ?? 0);
  }

  bool _upsertChapterSnapshot(
    TranslationChapterIdentity chapter, {
    required int pageCount,
    required int updatedAt,
  }) {
    final previous = _chapterIndex[chapter.scopePrefix];
    if (previous == null) {
      _chapterIndex[chapter.scopePrefix] = StoredTranslationChapter(
        identity: chapter,
        pageCount: pageCount,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
      );
      return true;
    }
    final old = previous.identity;
    final previousTimestamp = previous.updatedAt.millisecondsSinceEpoch;
    if (previous.pageCount == pageCount &&
        previousTimestamp >= updatedAt &&
        (chapter.comicTitle.isEmpty || old.comicTitle == chapter.comicTitle) &&
        (chapter.comicCover.isEmpty || old.comicCover == chapter.comicCover) &&
        (chapter.chapterTitle.isEmpty ||
            old.chapterTitle == chapter.chapterTitle)) {
      return false;
    }
    _chapterIndex[chapter.scopePrefix] = StoredTranslationChapter(
      identity: TranslationChapterIdentity(
        scopePrefix: old.scopePrefix,
        sourceKey: old.sourceKey,
        comicId: old.comicId,
        chapterId: old.chapterId,
        sourceLang: old.sourceLang,
        targetLang: old.targetLang,
        comicTitle:
            chapter.comicTitle.isEmpty ? old.comicTitle : chapter.comicTitle,
        comicCover:
            chapter.comicCover.isEmpty ? old.comicCover : chapter.comicCover,
        chapterTitle: chapter.chapterTitle.isEmpty
            ? old.chapterTitle
            : chapter.chapterTitle,
      ),
      pageCount: pageCount,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        updatedAt > previousTimestamp ? updatedAt : previousTimestamp,
      ),
    );
    return true;
  }

  static bool _upsertChapterRow(
    Database db,
    List<Object?> chapter, {
    required int pageCount,
    required int updatedAt,
  }) {
    db.execute(
      """
      insert into translated_chapter_index (
        scope_prefix, source_key, comic_id, chapter_id,
        source_lang, target_lang, comic_title, comic_cover,
        chapter_title, page_count, updated_at
      ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      on conflict(scope_prefix) do update set
        page_count = excluded.page_count,
        updated_at = max(translated_chapter_index.updated_at, excluded.updated_at),
        comic_title = case when excluded.comic_title != ''
          then excluded.comic_title else translated_chapter_index.comic_title end,
        comic_cover = case when excluded.comic_cover != ''
          then excluded.comic_cover else translated_chapter_index.comic_cover end,
        chapter_title = case when excluded.chapter_title != ''
          then excluded.chapter_title else translated_chapter_index.chapter_title end
      where translated_chapter_index.page_count != excluded.page_count
        or translated_chapter_index.updated_at < excluded.updated_at
        or (excluded.comic_title != '' and
          translated_chapter_index.comic_title != excluded.comic_title)
        or (excluded.comic_cover != '' and
          translated_chapter_index.comic_cover != excluded.comic_cover)
        or (excluded.chapter_title != '' and
          translated_chapter_index.chapter_title != excluded.chapter_title);
      """,
      [...chapter, pageCount, updatedAt],
    );
    return (db.select('select changes();').first[0] as int) > 0;
  }

  /// Builds the query index for translations written before the index existed.
  /// Only the fixed chapter prefix is parsed; the remaining image key may
  /// contain any number of `@` separators and is deliberately left untouched.
  static void _backfillChapterIndex(Database db) {
    var grouped = <String,
        ({
      TranslationChapterIdentity identity,
      int pageCount,
      int updatedAt
    })>{};
    for (var row in db.select(
      'select cache_key, time from translated_page;',
    )) {
      var cacheKey = row['cache_key'] as String? ?? '';
      var match = _currentKeyPattern.firstMatch(cacheKey);
      if (match == null) continue;
      var scopePrefix = match.group(0)!;
      var sourceKey = match.group(3)!;
      var identity = TranslationChapterIdentity(
        scopePrefix: scopePrefix,
        sourceKey: sourceKey == 'null' ? 'local' : sourceKey,
        comicId: match.group(4)!,
        chapterId: match.group(5)!,
        sourceLang: match.group(1)!,
        targetLang: match.group(2)!,
      );
      var updatedAt = row['time'] as int? ?? 0;
      var previous = grouped[scopePrefix];
      grouped[scopePrefix] = (
        identity: identity,
        pageCount: (previous?.pageCount ?? 0) + 1,
        updatedAt: previous == null
            ? updatedAt
            : previous.updatedAt > updatedAt
                ? previous.updatedAt
                : updatedAt,
      );
    }
    for (var entry in grouped.values) {
      _upsertChapterRow(
        db,
        _chapterValues(entry.identity),
        pageCount: entry.pageCount,
        updatedAt: entry.updatedAt,
      );
    }
  }

  static int _countByPrefix(Database db, String scopePrefix) {
    final escaped = _escapeLike(scopePrefix);
    final rows = db.select(
      "select count(*) from translated_page "
      "where cache_key like ? escape '\\';",
      ['$escaped%'],
    );
    return rows.first[0] as int;
  }

  static void _recountIndex(Database db) {
    var rows = db.select('select scope_prefix from translated_chapter_index;');
    for (var row in rows) {
      var prefix = row['scope_prefix'] as String;
      var pages = _countByPrefix(db, prefix);
      if (pages == 0) {
        db.execute(
          'delete from translated_chapter_index where scope_prefix = ?;',
          [prefix],
        );
      } else {
        db.execute(
          'update translated_chapter_index set page_count = ? '
          'where scope_prefix = ?;',
          [pages, prefix],
        );
      }
    }
  }

  List<StoredTranslationChapter> get chapters {
    if (!isInitialized) return const [];
    final result =
        _chapterIndex.values.where((chapter) => chapter.pageCount > 0).toList();
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  List<StoredTranslationChapter> chaptersFor(
    String sourceKey,
    String comicId, {
    String? sourceLang,
    String? targetLang,
  }) {
    return chapters.where((chapter) {
      var identity = chapter.identity;
      return identity.sourceKey == sourceKey &&
          identity.comicId == comicId &&
          (sourceLang == null || identity.sourceLang == sourceLang) &&
          (targetLang == null || identity.targetLang == targetLang);
    }).toList();
  }

  List<StoredTranslationComic> get comics {
    var grouped = <String, List<StoredTranslationChapter>>{};
    for (var chapter in chapters) {
      var identity = chapter.identity;
      var key = '${identity.sourceLang}\u0000${identity.targetLang}\u0000'
          '${identity.sourceKey}\u0000${identity.comicId}';
      grouped.putIfAbsent(key, () => []).add(chapter);
    }
    var result = <StoredTranslationComic>[];
    for (var values in grouped.values) {
      var newest = values.first;
      var identity = newest.identity;
      result.add(
        StoredTranslationComic(
          sourceKey: identity.sourceKey,
          comicId: identity.comicId,
          sourceLang: identity.sourceLang,
          targetLang: identity.targetLang,
          title: values
              .map((e) => e.identity.comicTitle)
              .firstWhere((value) => value.isNotEmpty, orElse: () => ''),
          cover: values
              .map((e) => e.identity.comicCover)
              .firstWhere((value) => value.isNotEmpty, orElse: () => ''),
          chapterCount: values.length,
          pageCount: values.fold(0, (sum, item) => sum + item.pageCount),
          updatedAt: newest.updatedAt,
        ),
      );
    }
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  static void _updateComicMetadataInDatabase(
    Database db,
    String sourceKey,
    String comicId,
    String comicTitle,
    String comicCover,
    Map<String, String> chapterTitles,
  ) {
    if (comicTitle.isNotEmpty || comicCover.isNotEmpty) {
      db.execute(
        """
        update translated_chapter_index set
          comic_title = case when ? != '' then ? else comic_title end,
          comic_cover = case when ? != '' then ? else comic_cover end
        where source_key = ? and comic_id = ?;
        """,
        [comicTitle, comicTitle, comicCover, comicCover, sourceKey, comicId],
      );
    }
    for (var entry in chapterTitles.entries) {
      if (entry.value.isEmpty) continue;
      db.execute(
        'update translated_chapter_index set chapter_title = ? '
        'where source_key = ? and comic_id = ? and chapter_id = ?;',
        [entry.value, sourceKey, comicId, entry.key],
      );
    }
  }

  /// Fills display metadata for rows imported from an older database. The
  /// durable page keys intentionally do not carry titles or covers, so the
  /// detail page can supply them after resolving the comic from its source.
  void updateComicMetadata(
    String sourceKey,
    String comicId, {
    String comicTitle = '',
    String comicCover = '',
    Map<String, String> chapterTitles = const {},
  }) {
    if (!isInitialized) return;
    final titles = Map<String, String>.from(chapterTitles);
    var changed = false;
    for (final entry in _chapterIndex.entries.toList()) {
      final current = entry.value;
      final identity = current.identity;
      if (identity.sourceKey != sourceKey || identity.comicId != comicId) {
        continue;
      }
      final chapterTitle = titles[identity.chapterId] ?? '';
      final nextComicTitle =
          comicTitle.isEmpty ? identity.comicTitle : comicTitle;
      final nextComicCover =
          comicCover.isEmpty ? identity.comicCover : comicCover;
      final nextChapterTitle =
          chapterTitle.isEmpty ? identity.chapterTitle : chapterTitle;
      if (nextComicTitle == identity.comicTitle &&
          nextComicCover == identity.comicCover &&
          nextChapterTitle == identity.chapterTitle) {
        continue;
      }
      changed = true;
      _chapterIndex[entry.key] = StoredTranslationChapter(
        identity: TranslationChapterIdentity(
          scopePrefix: identity.scopePrefix,
          sourceKey: identity.sourceKey,
          comicId: identity.comicId,
          chapterId: identity.chapterId,
          sourceLang: identity.sourceLang,
          targetLang: identity.targetLang,
          comicTitle: nextComicTitle,
          comicCover: nextComicCover,
          chapterTitle: nextChapterTitle,
        ),
        pageCount: current.pageCount,
        updatedAt: current.updatedAt,
      );
    }
    if (changed) {
      _snapshotVersion++;
      _notifyChanged();
    }
    if (comicTitle.isEmpty &&
        comicCover.isEmpty &&
        titles.values.every((title) => title.isEmpty)) {
      return;
    }
    _trackWrite(
      DatabaseGateway.instance.isolateOp(_dbPath, (db) {
        _updateComicMetadataInDatabase(
          db,
          sourceKey,
          comicId,
          comicTitle,
          comicCover,
          titles,
        );
      }),
      'updateComicMetadata',
    );
  }

  void _applySnapshot(_TranslationStoreSnapshot snapshot) {
    _pages.clear();
    for (final row in snapshot.pages) {
      final cacheKey = row[0];
      if (cacheKey is! String) continue;
      _pages[cacheKey] = _TranslationPageSnapshot(row[1], row[2] as int?);
    }
    _chapterIndex.clear();
    for (final row in snapshot.chapters) {
      final chapter = _chapterFromValues(row);
      _chapterIndex[chapter.identity.scopePrefix] = chapter;
    }
  }

  static StoredTranslationChapter _chapterFromValues(List<Object?> row) {
    return StoredTranslationChapter(
      identity: TranslationChapterIdentity(
        scopePrefix: row[0] as String,
        sourceKey: row[1] as String,
        comicId: row[2] as String,
        chapterId: row[3] as String,
        sourceLang: row[4] as String,
        targetLang: row[5] as String,
        comicTitle: row[6] as String? ?? '',
        comicCover: row[7] as String? ?? '',
        chapterTitle: row[8] as String? ?? '',
      ),
      pageCount: row[9] as int? ?? 0,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row[10] as int? ?? 0),
    );
  }

  /// The stored regions for a page, or null when the page was never translated.
  /// An empty list means "translated, nothing to render" (the page has no text).
  List<TranslatedRegion>? get(String cacheKey) {
    if (!isInitialized) return null;
    try {
      final page = _pages[cacheKey];
      if (page == null) return null;
      var data = jsonDecode(page.regions as String);
      if (data is! List) return const [];
      return [
        for (var item in data)
          TranslatedRegion.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (e, s) {
      Log.error("TranslationStore", "get failed: $e\n$s");
      return null;
    }
  }

  static void _adoptLegacyKeyInDatabase(
    Database db,
    String legacyKey,
    String cacheKey,
    int fallbackTime,
  ) {
    final rows = db.select(
      "select regions, time from translated_page where cache_key = ?;",
      [legacyKey],
    );
    if (rows.isEmpty) return;
    db.execute(_insertIgnoreSql, [
      cacheKey,
      rows.first['regions'],
      rows.first['time'] as int? ?? fallbackTime,
    ]);
    db.execute("delete from translated_page where cache_key = ?;", [legacyKey]);
  }

  /// Moves a page stored under the pre-#287 transport-derived key to the stable
  /// page-ordinal [cacheKey] and returns its regions, or null when no such row
  /// exists. The rewrite happens once per page, on the first read that can still
  /// address the old key, so the work already paid for survives the key change
  /// without a blanket migration (an image key cannot be mapped back to a page
  /// number without re-listing the chapter).
  ///
  /// INSERT OR IGNORE keeps an existing stable row if one appeared meanwhile;
  /// the legacy row is dropped either way, so the adoption never repeats.
  List<TranslatedRegion>? adoptLegacyKey(String legacyKey, String cacheKey) {
    if (!isInitialized) return null;
    final legacy = _pages[legacyKey];
    if (legacy == null) return null;
    final fallbackTime = DateTime.now().millisecondsSinceEpoch;
    _pages.putIfAbsent(
      cacheKey,
      () => _TranslationPageSnapshot(
        legacy.regions,
        legacy.time ?? fallbackTime,
      ),
    );
    _pages.remove(legacyKey);
    _snapshotVersion++;
    _trackWrite(
      DatabaseGateway.instance.isolateOp(_dbPath, (db) {
        _adoptLegacyKeyInDatabase(db, legacyKey, cacheKey, fallbackTime);
      }),
      'adoptLegacyKey',
    );
    return get(cacheKey);
  }

  static void _deleteByPrefix(Database db, String scopePrefix) {
    // Escape LIKE wildcards in the prefix so a '%' or '_' inside a key can't
    // widen the match; '\' is the explicit escape char below.
    final escaped = _escapeLike(scopePrefix);
    db.execute(
      "delete from translated_page where cache_key like ? escape '\\';",
      ['$escaped%'],
    );
    db.execute(
      "delete from translated_chapter_index "
      "where scope_prefix like ? escape '\\';",
      ['$escaped%'],
    );
  }

  /// Deletes every stored page whose key starts with [scopePrefix] — the same
  /// comic/chapter scope prefixes the rendered-image cache is cleared by, so a
  /// re-translate or "clear" drops both levels in lockstep. Returns rows removed.
  int deleteByPrefix(String scopePrefix) {
    if (!isInitialized) return 0;
    final keys = _pages.keys
        .where((cacheKey) => cacheKey.startsWith(scopePrefix))
        .toList();
    for (final key in keys) {
      _pages.remove(key);
    }
    final oldChapterCount = _chapterIndex.length;
    _chapterIndex.removeWhere(
      (prefix, _) => prefix.startsWith(scopePrefix),
    );
    if (keys.isNotEmpty || oldChapterCount != _chapterIndex.length) {
      _snapshotVersion++;
    }
    _trackWrite(
      DatabaseGateway.instance.isolateOp(_dbPath, (db) {
        _deleteByPrefix(db, scopePrefix);
      }),
      'deleteByPrefix',
    );
    if (keys.isNotEmpty) _notifyChanged();
    return keys.length;
  }

  /// Wipes every stored translation across all comics.
  int clearAll() {
    if (!isInitialized) return 0;
    final removed = _pages.length;
    if (removed > 0 || _chapterIndex.isNotEmpty) _snapshotVersion++;
    _pages.clear();
    _chapterIndex.clear();
    _trackWrite(
      DatabaseGateway.instance.isolateOp(_dbPath, (db) {
        db.execute("delete from translated_page;");
        db.execute("delete from translated_chapter_index;");
      }),
      'clearAll',
    );
    if (removed > 0) _notifyChanged();
    return removed;
  }

  int get count => isInitialized ? _pages.length : 0;

  /// How many stored pages have a key starting with [scopePrefix] — the same
  /// comic/chapter scope prefixes [deleteByPrefix] uses. Lets the chapter picker
  /// mark a chapter as translated straight from the durable store (which rides
  /// the WebDAV/backup merge), independent of any device-local task record —
  /// so a chapter translated on another device shows as done here too.
  int countByPrefix(String scopePrefix) {
    if (!isInitialized) return 0;
    return _pageStats(scopePrefix).$1;
  }

  static String _escapeLike(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');

  void close() {
    if (!isInitialized) return;
    _notifyTimer?.cancel();
    _notifyTimer = null;
    isInitialized = false;
    _snapshotVersion++;
    _pages.clear();
    _chapterIndex.clear();
  }

  void _trackWrite(Future<void> write, String operation) {
    Future<void> observe() async {
      try {
        await write;
      } catch (e, s) {
        Log.error('TranslationStore', '$operation failed: $e\n$s');
      }
    }

    unawaited(observe());
  }

  void _notifyChanged() {
    _notifyTimer ??= Timer(const Duration(milliseconds: 250), () {
      _notifyTimer = null;
      notifyListeners();
    });
  }
}
