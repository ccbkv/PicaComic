import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pica_comic/base.dart';
import 'package:pica_comic/foundation/comic_source/comic_source.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/image_manager.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/foundation/sqlite_connection.dart';
import 'package:pica_comic/network/download.dart';
import 'package:pica_comic/network/eh_network/eh_main_network.dart';
import 'package:pica_comic/network/eh_network/eh_models.dart';
import 'package:pica_comic/network/eh_network/get_gallery_id.dart';
import 'package:pica_comic/network/hitomi_network/hitomi_models.dart';
import 'package:pica_comic/network/htmanga_network/models.dart';
import 'package:pica_comic/network/jm_network/jm_image.dart';
import 'package:pica_comic/network/jm_network/jm_models.dart';
import 'package:pica_comic/network/nhentai_network/models.dart';
import 'package:pica_comic/network/picacg_network/models.dart';
import 'package:pica_comic/pages/favorites/main_favorites_page.dart';
import 'package:pica_comic/utils/extensions.dart';
import 'package:sqlite3/sqlite3.dart';
import 'dart:io';
import '../network/base_comic.dart';
import '../network/webdav.dart';

String getCurTime() {
  return DateTime.now()
      .toIso8601String()
      .replaceFirst("T", " ")
      .substring(0, 19);
}

final class FavoriteType {
  final int key;

  const FavoriteType(this.key);

  static FavoriteType get picacg => const FavoriteType(0);

  static FavoriteType get ehentai => const FavoriteType(1);

  static FavoriteType get jm => const FavoriteType(2);

  static FavoriteType get hitomi => const FavoriteType(3);

  static FavoriteType get htManga => const FavoriteType(4);

  static FavoriteType get nhentai => const FavoriteType(6);

  // Recognize both legacy and script records without changing stored types.
  List<int> get _compatibleKeys {
    const legacyKeys = {
      'picacg': 0,
      'ehentai': 1,
      'jm': 2,
      'hitomi': 3,
      'htmanga': 4,
      'nhentai': 6,
    };
    for (final entry in legacyKeys.entries) {
      final scriptKey = entry.key.hashCode;
      if (key == entry.value || key == scriptKey) {
        return {key, entry.value, scriptKey}.toList();
      }
    }
    return [key];
  }

  ComicType get comicType {
    if (key >= 0 && key <= 6) {
      return ComicType.values[key];
    }
    return ComicType.other;
  }

  ComicSource get comicSource {
    if (key <= 6) {
      var key = comicType.name.toLowerCase();
      return ComicSource.find(key) ?? (throw "Comic Source Not Found: $key");
    }
    return ComicSource.sources
            .firstWhereOrNull((element) => element.intKey == key) ??
        (throw "Comic Source Not Found");
  }

  String get name {
    if (comicType != ComicType.other) {
      return comicType.name;
    } else {
      try {
        return comicSource.name;
      } catch (e) {
        return "**Unknown**";
      }
    }
  }

  @override
  bool operator ==(Object other) {
    return other is FavoriteType && other.key == key;
  }

  @override
  int get hashCode => key.hashCode;
}

class FavoriteItem {
  String name;
  String author;
  FavoriteType type;
  List<String> tags;
  String target;
  String coverPath;
  String time = getCurTime();

  bool get available {
    if (type.key <= 6 && type.key >= 0) {
      return true;
    }
    return ComicSource.sources
            .firstWhereOrNull((element) => element.intKey == type.key) !=
        null;
  }

  String toDownloadId() {
    try {
      // Local files remain accessible after uninstalling their source.
      final key = type.comicType != ComicType.other
          ? type.comicType.name.toLowerCase()
          : const ['picacg', 'ehentai', 'jm', 'hitomi', 'htmanga', 'nhentai']
                  .firstWhereOrNull((key) => key.hashCode == type.key) ??
              type.comicSource.key;
      final legacyId = switch (key) {
        "picacg" => target,
        "ehentai" => getGalleryId(target),
        "jm" => "jm$target",
        "hitomi" => RegExp(r"\d+(?=\.html)").hasMatch(target)
            ? "hitomi${RegExp(r"\d+(?=\.html)").firstMatch(target)?[0]}"
            : target,
        "htmanga" => "Ht$target",
        "nhentai" => "nhentai$target",
        _ => "$key-$target"
      };
      final downloads = DownloadManager();
      if (downloads.isExists(legacyId)) return legacyId;
      final source = ComicSource.find(key);
      final customId =
          source == null ? "$key-$target" : downloads.generateId(key, target);
      return downloads.isExists(customId) ? customId : legacyId;
    } catch (e) {
      return "**Invalid ID**";
    }
  }

  FavoriteItem({
    required this.target,
    required this.name,
    required this.coverPath,
    required this.author,
    required this.type,
    required this.tags,
  });

  FavoriteItem.fromPicacg(ComicItemBrief comic)
      : name = comic.title,
        author = comic.author,
        type = FavoriteType.picacg,
        tags = comic.tags,
        target = comic.id,
        coverPath = comic.path;

  FavoriteItem.fromEhentai(EhGalleryBrief comic)
      : name = comic.title,
        author = comic.uploader,
        type = FavoriteType.ehentai,
        tags = comic.tags,
        target = comic.link,
        coverPath = comic.coverPath;

  FavoriteItem.fromJmComic(JmComicBrief comic)
      : name = comic.name,
        author = comic.author,
        type = FavoriteType.jm,
        tags = [],
        target = comic.id,
        coverPath = getJmCoverUrl(comic.id);

  FavoriteItem.fromHitomi(HitomiComicBrief comic)
      : name = comic.name,
        author = comic.artist,
        type = FavoriteType.hitomi,
        tags = List.generate(
            comic.tagList.length, (index) => comic.tagList[index].name),
        target = comic.link,
        coverPath = comic.cover;

  FavoriteItem.fromHtcomic(HtComicBrief comic)
      : name = comic.name,
        author = "${comic.pages}Pages",
        type = FavoriteType.htManga,
        tags = [],
        target = comic.id,
        coverPath = comic.image;

  FavoriteItem.fromNhentai(NhentaiComicBrief comic)
      : name = comic.title,
        author = "",
        type = FavoriteType.nhentai,
        tags = comic.tags,
        target = comic.id,
        coverPath = comic.cover;

  FavoriteItem.custom(CustomComic comic)
      : name = comic.title,
        author = comic.subTitle,
        type = FavoriteType(comic.sourceKey.hashCode),
        tags = comic.tags,
        target = comic.id,
        coverPath = comic.cover;

  Map<String, dynamic> toJson() => {
        "name": name,
        "author": author,
        "type": type.key,
        "tags": tags,
        "target": target,
        "coverPath": coverPath,
        "time": time
      };

  FavoriteItem.fromJson(Map<String, dynamic> json)
      : name = json["name"],
        author = json["author"],
        type = FavoriteType(json["type"]),
        tags = List<String>.from(json["tags"]),
        target = json["target"],
        coverPath = json["coverPath"],
        time = json["time"];

  FavoriteItem.fromRow(Row row) : this.fromMap(_rowToMap(row));

  FavoriteItem.fromMap(Map<String, dynamic> row)
      : name = row["name"],
        author = row["author"],
        type = FavoriteType(row["type"]),
        tags = (row["tags"] as String).split(","),
        target = row["target"],
        coverPath = row["cover_path"],
        time = row["time"] {
    tags.remove("");
  }

  factory FavoriteItem.fromBaseComic(BaseComic comic) {
    if (comic is ComicItemBrief) {
      return FavoriteItem.fromPicacg(comic);
    } else if (comic is EhGalleryBrief) {
      return FavoriteItem.fromEhentai(comic);
    } else if (comic is JmComicBrief) {
      return FavoriteItem.fromJmComic(comic);
    } else if (comic is HtComicBrief) {
      return FavoriteItem.fromHtcomic(comic);
    } else if (comic is NhentaiComicBrief) {
      return FavoriteItem.fromNhentai(comic);
    } else if (comic is CustomComic) {
      return FavoriteItem.custom(comic);
    }
    throw UnimplementedError();
  }

  @override
  bool operator ==(Object other) {
    return other is FavoriteItem &&
        other.target == target &&
        other.type == type;
  }

  @override
  int get hashCode => target.hashCode ^ type.hashCode;

  @override
  String toString() {
    var s = "FavoriteItem: $name $author $coverPath $hashCode $tags";
    if (s.length > 100) {
      return s.substring(0, 100);
    }
    return s;
  }
}

class FavoriteItemWithUpdateInfo extends FavoriteItem {
  String? updateTime;

  DateTime? lastCheckTime;

  bool hasNewUpdate;

  FavoriteItemWithUpdateInfo(
    FavoriteItem item,
    this.updateTime,
    this.hasNewUpdate,
    int? lastCheckTime,
  )   : lastCheckTime = lastCheckTime == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(lastCheckTime),
        super(
          target: item.target,
          name: item.name,
          coverPath: item.coverPath,
          author: item.author,
          type: item.type,
          tags: item.tags,
        );

  @override
  String get description {
    var updateTime = this.updateTime ?? "Unknown";
    var sourceName = type.name;
    return "$updateTime | $sourceName";
  }

  @override
  bool operator ==(Object other) {
    return other is FavoriteItemWithUpdateInfo &&
        other.updateTime == updateTime &&
        other.hasNewUpdate == hasNewUpdate &&
        super == other;
  }

  @override
  int get hashCode =>
      super.hashCode ^ updateTime.hashCode ^ hasNewUpdate.hashCode;
}

class FavoriteItemWithFolderInfo {
  FavoriteItem comic;
  String folder;

  FavoriteItemWithFolderInfo(this.comic, this.folder);

  @override
  bool operator ==(Object other) {
    return other is FavoriteItemWithFolderInfo &&
        other.comic == comic &&
        other.folder == folder;
  }

  @override
  int get hashCode => comic.hashCode ^ folder.hashCode;
}

class FolderSync {
  String folderName;
  String time = getCurTime();
  String key;
  String syncData; // 内容是 json, 存一下选中的文件夹 folderId
  FolderSync(this.folderName, this.key, this.syncData);

  Map<String, dynamic> get syncDataObj => jsonDecode(syncData);
}

extension SQL on String {
  String get toParam => replaceAll('\'', "''").replaceAll('"', "\"\"");
}

Map<String, dynamic> _rowToMap(Row row) {
  return <String, dynamic>{for (final key in row.keys) key: row[key]};
}

List<String> _getTablesWithDB(Database db) {
  return db
      .select("SELECT name FROM sqlite_master WHERE type='table';")
      .map((element) => element["name"] as String)
      .toList();
}

void _migrateFollowUpdatesFields(Database db, List<String> tables) {
  for (var table in tables) {
    var columns = db.select('PRAGMA table_info("$table");');
    var columnNames = columns.map((e) => e["name"] as String).toList();
    if (!columnNames.contains("last_update_time")) {
      db.execute(
          'ALTER TABLE "$table" ADD COLUMN last_update_time TEXT DEFAULT NULL;');
    }
    if (!columnNames.contains("has_new_update")) {
      db.execute(
          'ALTER TABLE "$table" ADD COLUMN has_new_update INTEGER DEFAULT 0;');
    }
    if (!columnNames.contains("last_check_time")) {
      db.execute(
          'ALTER TABLE "$table" ADD COLUMN last_check_time INTEGER DEFAULT NULL;');
    }
  }
}

void _checkAndCreate(Database db) {
  final tables = _getTablesWithDB(db);
  if (!tables.contains('folder_sync')) {
    db.execute("""
      create table folder_sync (
        folder_name text primary key,
        time TEXT,
        key TEXT,
        sync_data TEXT
      );
    """);
  }
  if (!tables.contains('folder_order')) {
    db.execute("""
      create table folder_order (
        folder_name text primary key,
        order_value int
      );
    """);
  }
  tables.remove('folder_sync');
  tables.remove('folder_order');
  if (tables.isEmpty) return;
  var testTable = tables.first;
  var res = db.select("""
    PRAGMA table_info("$testTable");
  """);
  bool shouldUpdate = false;
  for (var row in res) {
    if (row["name"] == "type" && row["pk"] == 0) {
      shouldUpdate = true;
      break;
    }
  }
  if (shouldUpdate) {
    for (var table in tables) {
      var tempName = "${table}_dw5d8g2_temp";
      db.execute("""
        CREATE TABLE "$tempName" AS SELECT * FROM "$table";
        DROP TABLE "$table";
        CREATE TABLE "$table" (
          target text,
          name TEXT,
          author TEXT,
          type int,
          tags TEXT,
          cover_path TEXT,
          time TEXT,
          display_order int,
          primary key (target, type)
        );
        INSERT INTO "$table" SELECT * FROM "$tempName";
        DROP TABLE "$tempName";
      """);
    }
  }
  _migrateFollowUpdatesFields(db, tables);
}

Map<String, dynamic> _readLocalFavoritesSnapshot(Database db) {
  final folders = _getTablesWithDB(db)
    ..remove('folder_sync')
    ..remove('folder_order');
  final savedFolderOrder = <String, int>{
    for (final row in db.select("SELECT * FROM folder_order"))
      row['folder_name'] as String: row['order_value'] as int? ?? 0,
  };
  final folderToOrder = <String, int>{
    for (final folder in folders) folder: savedFolderOrder[folder] ?? 0,
  };
  folders.sort((a, b) => folderToOrder[a]! - folderToOrder[b]!);
  final comics = <String, List<Map<String, dynamic>>>{};
  for (final folder in folders) {
    comics[folder] = db
        .select('select * from "$folder";')
        .map(_rowToMap)
        .toList(growable: true);
  }
  final folderSync = db
      .select("SELECT * FROM folder_sync")
      .map(_rowToMap)
      .toList(growable: true);
  return {
    'folders': folders,
    'comics': comics,
    'folderOrder': {...savedFolderOrder, ...folderToOrder},
    'folderSync': folderSync,
  };
}

Future<void> _updateReadRows(
  String path,
  List<Map<String, dynamic>> updates,
) {
  return DatabaseGateway.instance.isolateOp(path, (db) {
    db.execute("BEGIN TRANSACTION;");
    for (final update in updates) {
      final folder = update['folder'] as String;
      final order = update['order'] as int?;
      if (order == null) {
        db.execute("""
          UPDATE "$folder"
          SET time = ?
          WHERE target == ?;
        """, [update['time'], update['target']]);
      } else {
        db.execute("""
          UPDATE "$folder"
          SET display_order = ?, time = ?
          WHERE target == ?;
        """, [order, update['time'], update['target']]);
      }
    }
    db.execute("COMMIT;");
  });
}

class LocalFavoritesManager {
  factory LocalFavoritesManager() =>
      cache ?? (cache = LocalFavoritesManager._create());

  LocalFavoritesManager._create();

  static LocalFavoritesManager? cache;

  String get _dbPath => "${App.dataPath}/local_favorite.db";

  Map<String, List<Map<String, dynamic>>> _comics = {};
  List<String> _folderNames = [];
  Map<String, int> _folderOrder = {};
  List<Map<String, dynamic>> _folderSync = [];
  Future<void> _lastWrite = Future.value();

  final Set<String> _pendingTargets = {};
  final Map<String, FavoriteType> _pendingTypes = {};
  Timer? _debounceTimer;

  Future<void> init() async {
    final snapshot = await DatabaseGateway.instance
        .isolateOp<Map<String, dynamic>>(_dbPath, (db) {
      _checkAndCreate(db);
      return _readLocalFavoritesSnapshot(db);
    });
    _folderNames = List<String>.from(snapshot['folders'] as List);
    _comics = {
      for (final entry in (snapshot['comics'] as Map<String, dynamic>).entries)
        entry.key: List<Map<String, dynamic>>.from(entry.value as List),
    };
    _folderOrder = Map<String, int>.from(snapshot['folderOrder'] as Map);
    _folderSync = List<Map<String, dynamic>>.from(
        (snapshot['folderSync'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map)));
    _modifiedAfterLastCache = true;
    await readData();
  }

  void _runBackground(Future<void> operation, {bool upload = false}) {
    _lastWrite = () async {
      try {
        await operation;
        if (upload) {
          await saveData();
        }
      } catch (e, s) {
        LogManager.addLog(LogLevel.error, "LocalFavoritesManager", "$e\n$s");
      }
    }();
    unawaited(_lastWrite);
  }

  void _sortFolderNames() {
    _folderNames
        .sort((a, b) => (_folderOrder[a] ?? 0) - (_folderOrder[b] ?? 0));
  }

  void _resetSnapshot() {
    _comics.clear();
    _folderNames.clear();
    _folderOrder.clear();
    _folderSync.clear();
    _modifiedAfterLastCache = true;
  }

  void updateUI() {
    Future.microtask(
        () => StateController.findOrNull(tag: "me page")?.update());
    Future.microtask(
        () => StateController.findOrNull<FavoritesPageController>()?.update());
  }

  Future<List<String>> find(String target, FavoriteType type) async {
    final keys = type._compatibleKeys;
    return [
      for (final folder in _folderNames)
        if (_comics[folder]!.any(
            (row) => row['target'] == target && keys.contains(row['type'])))
          folder,
    ];
  }

  Future<List<String>> findWithModel(FavoriteItem item) async {
    return find(item.target, item.type);
  }

  Future<void> saveData() async {
    Webdav.uploadData();
  }

  /// read data from json file or temp db.
  ///
  /// This function will delete current database, then create a new one, finally
  /// import data.
  Future<void> readData() async {
    var file = File("${App.dataPath}/localFavorite");
    if (file.existsSync()) {
      Map<String, List<FavoriteItem>> allComics = {};
      try {
        var data = (const JsonDecoder().convert(file.readAsStringSync()))
            as Map<String, dynamic>;

        for (var key in data.keys.toList()) {
          Set<FavoriteItem> comics = {};
          for (var comic in data[key]!) {
            comics.add(FavoriteItem.fromJson(comic));
          }
          if (allComics.containsKey(key)) {
            comics.addAll(allComics[key]!);
          }
          allComics[key] = comics.toList();
        }

        await clearAll();

        for (var folder in allComics.keys) {
          createFolder(folder, true);
          var comics = allComics[folder]!;
          for (int i = 0; i < comics.length; i++) {
            addComic(folder, comics[i]);
          }
        }
        await _lastWrite;
      } catch (e, s) {
        LogManager.addLog(LogLevel.error, "IO", "$e\n$s");
      } finally {
        file.deleteSync();
      }
    } else if ((file = File("${App.dataPath}/local_favorite_temp.db"))
        .existsSync()) {
      final imported = await DatabaseGateway.instance
          .isolateOp<Map<String, dynamic>>(file.path, (db) {
        final tables = _getTablesWithDB(db);
        final hasFolderOrder = tables.contains('folder_order');
        final folders = List<String>.from(tables)
          ..remove('folder_sync')
          ..remove('folder_order');
        final tableFolders = List<String>.from(folders);
        final folderToOrder = <String, int>{};
        for (final folder in folders) {
          if (!hasFolderOrder) {
            folderToOrder[folder] = 0;
            continue;
          }
          final rows = db.select("""
            select * from folder_order
            where folder_name == ?;
          """, [folder]);
          folderToOrder[folder] =
              rows.isEmpty ? 0 : rows.first["order_value"] as int? ?? 0;
        }
        folders.sort((a, b) => folderToOrder[a]! - folderToOrder[b]!);
        final comics = <Map<String, dynamic>>[];
        final counts = <String, int>{};
        for (final folder in folders) {
          final rows = db.select('select * from "$folder";');
          counts[folder] = rows.length;
          for (final row in rows) {
            comics.add({'folder': folder, 'comic': _rowToMap(row)});
          }
        }
        return {
          'tableFolders': tableFolders,
          'hasFolderOrder': hasFolderOrder,
          'comics': comics,
          'counts': counts,
        };
      });

      LogManager.addLog(LogLevel.info, "LocalFavoritesManager.readData",
          "read folders from local database ${imported['tableFolders']}");
      if (imported['hasFolderOrder'] == false) {
        LogManager.addLog(LogLevel.info, "LocalFavoritesManager.readData",
            "temp local favorites db has no folder_order table, fallback to default order");
      }
      final counts = imported['counts'] as Map<String, dynamic>;
      for (final entry in counts.entries) {
        LogManager.addLog(LogLevel.info, "LocalFavoritesManager.readData",
            "read ${entry.key} gets ${entry.value} comics");
      }
      final res = imported['comics'] as List;
      var skips = 0;
      for (final item in res) {
        final data = item as Map<String, dynamic>;
        final folder = data['folder'] as String;
        final comic =
            FavoriteItem.fromMap(data['comic'] as Map<String, dynamic>);
        if (!folderNames.contains(folder)) {
          createFolder(folder);
        }
        if (!comicExists(folder, comic.target, comic.type.key)) {
          addComic(folder, comic);
          LogManager.addLog(LogLevel.info, "LocalFavoritesManager",
              "add comic ${comic.target} to $folder");
        } else {
          skips++;
        }
      }
      LogManager.addLog(LogLevel.info, "LocalFavoritesManager",
          "skipped $skips comics, total ${res.length}");
      await _lastWrite;
      file.deleteSync();
    } else {
      LogManager.addLog(LogLevel.info, "LocalFavoritesManager",
          "no local favorites db file found");
    }
  }

  void updateOrder(Map<String, int> order) {
    _folderOrder.addAll(order);
    _sortFolderNames();
    final values = <List<Object>>[
      for (final entry in order.entries) [entry.key, entry.value],
    ];
    _runBackground(DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      db.execute("BEGIN TRANSACTION;");
      for (final value in values) {
        db.execute("""
          insert or replace into folder_order (folder_name, order_value)
          values (?, ?);
        """, value);
      }
      db.execute("COMMIT;");
    }));
  }

  FolderSync _folderSyncFromMap(Map<String, dynamic> row) {
    return FolderSync(row['folder_name'], row['key'], row['sync_data'])
      ..time = row['time'];
  }

  void updateFolderSyncTime(FolderSync folderSync) {
    final folderName = folderSync.folderName;
    final time = folderSync.time;
    for (final row in _folderSync) {
      if (row['folder_name'] == folderName) {
        row['time'] = time;
      }
    }
    _runBackground(DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      db.execute("""
        update folder_sync
        set time = ?
        where folder_name == ?
      """, [time, folderName]);
    }));
  }

  void insertFolderSync(FolderSync folderSync) {
    final values = <String>[
      folderSync.folderName,
      folderSync.time,
      folderSync.key,
      folderSync.syncData,
    ];
    _folderSync.add({
      'folder_name': values[0],
      'time': values[1],
      'key': values[2],
      'sync_data': values[3],
    });
    _runBackground(DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      db.execute("""
        insert into folder_sync (folder_name, time, key, sync_data)
        values (?, ?, ?, ?);
      """, values);
    }));
  }

  int count(String folderName) => _comics[folderName]?.length ?? 0;

  String _comicKey(String target, int type) => "$type\u0000$target";

  List<String> get folderNames => List.of(_folderNames);

  List<FolderSync> get folderSync =>
      _folderSync.map(_folderSyncFromMap).toList();

  /// 获取所有文件夹中的漫画总数
  int get totalComics {
    final uniqueComics = <String>{};
    for (final comics in _comics.values) {
      for (final row in comics) {
        uniqueComics.add(_comicKey(row["target"], row["type"]));
      }
    }
    return uniqueComics.length;
  }

  /// 获取指定文件夹中的漫画数量
  int folderComics(String folderName) => count(folderName);

  Iterable<int?> _displayOrders(String folder) =>
      (_comics[folder] ?? []).map((row) => row['display_order'] as int?);

  int maxValue(String folder) {
    final orders = _displayOrders(folder).whereType<int>().toList();
    return orders.isEmpty ? 0 : orders.reduce((a, b) => a > b ? a : b);
  }

  int minValue(String folder) {
    final orders = _displayOrders(folder).whereType<int>().toList();
    return orders.isEmpty ? 0 : orders.reduce((a, b) => a < b ? a : b);
  }

  int _compareDisplayOrder(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aOrder = a['display_order'] as int?;
    final bOrder = b['display_order'] as int?;
    if (aOrder == null) return bOrder == null ? 0 : -1;
    if (bOrder == null) return 1;
    return aOrder - bOrder;
  }

  List<FavoriteItem> getAllComics(String folder) {
    final rows = List<Map<String, dynamic>>.of(_comics[folder] ?? [])
      ..sort(_compareDisplayOrder);
    return rows.map(FavoriteItem.fromMap).toList();
  }

  void addTagTo(String folder, String target, String tag) {
    final rows = _comics[folder];
    if (rows == null) return;
    final prefix = '$tag,';
    for (final row in rows) {
      if (row['target'] == target) {
        row['tags'] = '$prefix${row['tags']}';
      }
    }
    _runBackground(
      DatabaseGateway.instance.isolateOp(_dbPath, (db) {
        db.execute("""
          update "$folder"
          set tags = ? || tags
          where target == ?
        """, [prefix, target]);
      }),
      upload: true,
    );
  }

  List<FavoriteItemWithFolderInfo> allComics() {
    var res = <FavoriteItemWithFolderInfo>[];
    final uniqueComics = <String>{};
    for (final folder in _folderNames) {
      for (final element in _comics[folder]!) {
        final key = _comicKey(element["target"], element["type"]);
        if (!uniqueComics.add(key)) {
          continue;
        }
        res.add(
          FavoriteItemWithFolderInfo(FavoriteItem.fromMap(element), folder),
        );
      }
    }
    return res;
  }

  /// create a folder
  String createFolder(String name, [bool renameWhenInvalidName = false]) {
    if (name.isEmpty) {
      if (renameWhenInvalidName) {
        int i = 0;
        while (folderNames.contains(i.toString())) {
          i++;
        }
        name = i.toString();
      } else {
        throw "name is empty!";
      }
    }
    if (folderNames.contains(name)) {
      if (renameWhenInvalidName) {
        var prevName = name;
        int i = 0;
        while (folderNames.contains(i.toString())) {
          i++;
        }
        name = prevName + i.toString();
      } else {
        throw Exception("Folder is existing");
      }
    }
    _comics[name] = [];
    _folderOrder.putIfAbsent(name, () => 0);
    _folderNames.add(name);
    _sortFolderNames();
    _runBackground(
      DatabaseGateway.instance.isolateOp(_dbPath, (db) {
        db.execute("""
          create table "$name"(
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
        """);
      }),
      upload: true,
    );
    return name;
  }

  bool comicExists(String folder, String target, int type) {
    return _comics[folder]
            ?.any((row) => row['target'] == target && row['type'] == type) ??
        false;
  }

  FavoriteItem getComic(String folder, String target, FavoriteType type) {
    final rows = _comics[folder];
    if (rows == null) {
      throw Exception("Table '$folder' does not exist");
    }
    final row = rows.firstWhere(
      (row) => row['target'] == target && row['type'] == type.key,
      orElse: () => throw Exception("Comic not found"),
    );
    return FavoriteItem.fromMap(row);
  }

  /// add comic to a folder
  ///
  /// This method will download cover to local, to avoid problems like changing url
  void addComic(String folder, FavoriteItem comic, [int? order]) async {
    _modifiedAfterLastCache = true;
    if (!folderNames.contains(folder)) {
      throw Exception("Folder does not exists");
    }
    final rows = _comics[folder];
    if (rows == null) {
      throw Exception("Table '$folder' does not exist");
    }
    if (rows.any((row) => row['target'] == comic.target)) {
      return;
    }
    final displayOrder = order ??
        (appdata.settings[53] == "0"
            ? maxValue(folder) + 1
            : minValue(folder) - 1);
    final row = <String, dynamic>{
      'target': comic.target,
      'name': comic.name,
      'author': comic.author,
      'type': comic.type.key,
      'tags': comic.tags.join(','),
      'cover_path': comic.coverPath,
      'time': comic.time,
      'last_update_time': null,
      'has_new_update': 0,
      'last_check_time': null,
      'display_order': displayOrder,
    };
    rows.add(row);
    final values = <Object?>[
      row['target'],
      row['name'],
      row['author'],
      row['type'],
      row['tags'],
      row['cover_path'],
      row['time'],
      displayOrder,
    ];
    _runBackground(
      DatabaseGateway.instance.isolateOp(_dbPath, (db) {
        db.execute("""
          insert into "$folder" (target, name, author, type, tags, cover_path, time, display_order)
          values (?, ?, ?, ?, ?, ?, ?, ?);
        """, values);
      }),
      upload: true,
    );
    updateUI();
    try {
      var file =
          (await (ImageManager().getImage(comic.coverPath)).last).getFile();
      var path =
          "${(await getApplicationSupportDirectory()).path}${pathSep}favoritesCover";
      var directory = Directory(path);
      if (!directory.existsSync()) {
        directory.createSync();
      }
      var hash =
          md5.convert(const Utf8Encoder().convert(comic.coverPath)).toString();
      file.copySync("$path$pathSep$hash.jpg");
    } catch (e) {
      //忽略
    }
  }

  /// get comic cover
  Future<File> getCover(FavoriteItem item) async {
    var path = "${App.dataPath}/favoritesCover";
    var hash =
        md5.convert(const Utf8Encoder().convert(item.coverPath)).toString();
    var file = File("$path/$hash.jpg");
    if (file.existsSync()) {
      return file;
    }
    if (item.coverPath.startsWith("file://")) {
      var data = DownloadManager()
          .getCover(item.coverPath.replaceFirst("file://", ""));
      file.createSync(recursive: true);
      file.writeAsBytesSync(data.readAsBytesSync());
      return file;
    }
    try {
      if (EhNetwork().cookiesStr == "") {
        await EhNetwork().getCookies(false);
      }
      var res = await (ImageManager().getImage(item.coverPath, {
        if (item.type == FavoriteType.ehentai) "cookie": EhNetwork().cookiesStr,
        if (item.type == FavoriteType.hitomi) "Referer": "https://hitomi.la/"
      }).last);
      file.createSync(recursive: true);
      file.writeAsBytesSync(res.getFile().readAsBytesSync());
      return file;
    } catch (e) {
      await Future.delayed(const Duration(seconds: 5));
      rethrow;
    }
  }

  /// delete a folder
  void deleteFolder(String name) {
    _modifiedAfterLastCache = true;
    _comics.remove(name);
    _folderNames.remove(name);
    _folderSync.removeWhere((row) => row['folder_name'] == name);
    _runBackground(DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      db.execute("""
        delete from folder_sync where folder_name == ?;
      """, [name]);
      db.execute("""
        drop table "$name";
      """);
    }));
  }

  void checkAndDeleteCover(FavoriteItem item) async {
    if ((await find(item.target, item.type)).isEmpty) {
      (await getCover(item)).deleteSync();
    }
  }

  void deleteComic(String folder, FavoriteItem comic) {
    _modifiedAfterLastCache = true;
    deleteComicWithTarget(folder, comic.target, comic.type);
    checkAndDeleteCover(comic);
  }

  void deleteComicWithTarget(String folder, String target, FavoriteType type) {
    _modifiedAfterLastCache = true;
    final rows = _comics[folder];
    if (rows == null) return;
    final keys = type._compatibleKeys;
    rows.removeWhere(
        (row) => row['target'] == target && keys.contains(row['type']));
    _runBackground(
      DatabaseGateway.instance.isolateOp(_dbPath, (db) {
        db.execute("""
          delete from "$folder"
          where target == ? and type in (${List.filled(keys.length, '?').join(',')});
        """, [target, ...keys]);
      }),
      upload: true,
    );
  }

  Future<void> clearAll() async {
    _debounceTimer?.cancel();
    _pendingTargets.clear();
    _pendingTypes.clear();
    _resetSnapshot();
    await DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      final tables = _getTablesWithDB(db);
      db.execute("BEGIN TRANSACTION;");
      try {
        for (final table in tables) {
          db.execute('DROP TABLE "$table";');
        }
        _checkAndCreate(db);
        db.execute("COMMIT;");
      } catch (_) {
        db.execute("ROLLBACK;");
        rethrow;
      }
    });
    saveData();
  }

  void reorder(List<FavoriteItem> newFolder, String folder) async {
    if (!folderNames.contains(folder)) {
      throw Exception("Failed to reorder: folder not found");
    }
    deleteFolder(folder);
    createFolder(folder);
    for (int i = 0; i < newFolder.length; i++) {
      addComic(folder, newFolder[i], i);
    }
    updateUI();
  }

  void rename(String before, String after) {
    if (folderNames.contains(after)) {
      throw "Name already exists!";
    }
    if (after.contains('"')) {
      throw "Invalid name";
    }
    if (!_comics.containsKey(before)) {
      throw Exception("Table '$before' does not exist");
    }
    final renamedComics = <String, List<Map<String, dynamic>>>{};
    for (final entry in _comics.entries) {
      renamedComics[entry.key == before ? after : entry.key] = entry.value;
    }
    _comics = renamedComics;
    _folderNames[_folderNames.indexOf(before)] = after;
    _sortFolderNames();
    final hasFolderSync = _folderSync.isNotEmpty;
    for (final row in _folderSync) {
      if (row['folder_name'] == before) {
        row['folder_name'] = after;
      }
    }
    _runBackground(
      DatabaseGateway.instance.isolateOp(_dbPath, (db) {
        db.execute("""
          ALTER TABLE "$before"
          RENAME TO "$after";
        """);
        if (hasFolderSync) {
          db.execute("""
            UPDATE folder_sync
            set folder_name = ?
            where folder_name == ?
          """, [after, before]);
        }
      }),
      upload: true,
    );
  }

  void onReadEnd(String target, FavoriteType type) async {
    _modifiedAfterLastCache = true;
    _pendingTargets.add(target);
    _pendingTypes[target] = type;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (_pendingTargets.isEmpty) return;
      final targets = List<String>.from(_pendingTargets);
      _pendingTargets.clear();
      bool isModified = false;
      final updates = <Map<String, dynamic>>[];
      for (final t in targets) {
        final pendingType = _pendingTypes[t]!;
        for (final folder in _folderNames) {
          final rows = _comics[folder]!;
          final exists = rows.any(
              (row) => row['target'] == t && row['type'] == pendingType.key);
          if (!exists) continue;
          isModified = true;
          final newTime = getCurTime();
          final int? newOrder = switch (appdata.settings[54]) {
            "1" => maxValue(folder) + 1,
            "2" => minValue(folder) - 1,
            _ => null,
          };
          for (final row in rows) {
            if (row['target'] == t) {
              if (newOrder != null) row['display_order'] = newOrder;
              row['time'] = newTime;
            }
          }
          updates.add({
            'folder': folder,
            'target': t,
            'time': newTime,
            'order': newOrder,
          });
        }
        _pendingTypes.remove(t);
      }
      _runBackground(
        _updateReadRows(_dbPath, updates),
        upload: true,
      );
      if (isModified) {
        updateUI();
      }
    });
  }

  String folderToJsonString(String folderName) {
    final rows = _comics[folderName];
    if (rows == null) {
      return '{"error": "Table does not exist"}';
    }

    var data = <String, dynamic>{};
    data["info"] = "Generated by PicaComic.";
    data["website"] = "https://github.com/ccbkv/PicaComic";
    data["name"] = folderName;
    data["comics"] =
        rows.map((row) => FavoriteItem.fromMap(row).toJson()).toList();
    return const JsonEncoder().convert(data);
  }

  (bool, String) loadFolderData(String dataString) {
    try {
      var data =
          const JsonDecoder().convert(dataString) as Map<String, dynamic>;
      final name_ = data["name"] as String;
      var name = name_;
      int i = 0;
      while (folderNames.contains(name)) {
        name = name_ + i.toString();
        i++;
      }
      createFolder(name);
      for (var json in data["comics"]) {
        addComic(name, FavoriteItem.fromJson(json));
      }
      return (false, "");
    } catch (e, s) {
      LogManager.addLog(LogLevel.error, "IO", "Failed to load data.\n$e\n$s");
      return (true, e.toString());
    }
  }

  bool _matchesLike(String value, String keyword) {
    final pattern = keyword.runes.map((rune) {
      final character = String.fromCharCode(rune);
      return switch (character) {
        '%' => '.*',
        '_' => '.',
        _ => RegExp.escape(character),
      };
    }).join();
    return RegExp('.*$pattern.*', caseSensitive: false, dotAll: true)
        .hasMatch(value);
  }

  List<FavoriteItemWithFolderInfo> search(String keyword) {
    var keywordList = keyword.split(" ");
    keyword = keywordList.first;
    var comics = <FavoriteItemWithFolderInfo>[];
    for (var table in _folderNames) {
      for (final row in _comics[table]!) {
        if (_matchesLike(row['name'], keyword) ||
            _matchesLike(row['author'], keyword) ||
            _matchesLike(row['tags'], keyword)) {
          comics.add(
              FavoriteItemWithFolderInfo(FavoriteItem.fromMap(row), table));
        }
      }
      if (comics.length > 200) {
        break;
      }
    }

    bool test(FavoriteItemWithFolderInfo comic, String keyword) {
      if (comic.comic.name.contains(keyword)) {
        return true;
      } else if (comic.comic.author.contains(keyword)) {
        return true;
      } else if (comic.comic.tags.any((element) => element.contains(keyword))) {
        return true;
      }
      return false;
    }

    for (var i = 1; i < keywordList.length; i++) {
      comics =
          comics.where((element) => test(element, keywordList[i])).toList();
    }

    return comics;
  }

  void editTags(String target, String folder, List<String> tags) {
    final value = tags.join(",");
    for (final row in _comics[folder] ?? <Map<String, dynamic>>[]) {
      if (row['target'] == target) row['tags'] = value;
    }
    _runBackground(DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      db.execute("""
        update "$folder"
        set tags = ?
        where target == ?;
      """, [value, target]);
    }));
  }

  final _cachedFavoritedTargets = <String, bool>{};

  bool isExist(String target) {
    if (_modifiedAfterLastCache) {
      _cacheFavoritedTargets();
    }
    return _cachedFavoritedTargets.containsKey(target);
  }

  bool _modifiedAfterLastCache = true;

  void _cacheFavoritedTargets() {
    _modifiedAfterLastCache = false;
    _cachedFavoritedTargets.clear();
    for (final rows in _comics.values) {
      for (final row in rows) {
        _cachedFavoritedTargets[row["target"]] = true;
      }
    }
  }

  void updateInfo(String folder, FavoriteItem comic, [bool notify = true]) {
    final target = comic.target;
    final type = comic.type.key;
    final values = <Object?>[
      comic.name,
      comic.author,
      comic.coverPath,
      comic.tags.join(","),
      target,
      type,
    ];
    for (final row in _comics[folder] ?? <Map<String, dynamic>>[]) {
      if (row['target'] == target && row['type'] == type) {
        row['name'] = values[0];
        row['author'] = values[1];
        row['cover_path'] = values[2];
        row['tags'] = values[3];
      }
    }
    _runBackground(DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      db.execute("""
        update "$folder"
        set name = ?, author = ?, cover_path = ?, tags = ?
        where target == ? and type == ?;
      """, values);
    }));
    if (notify) {
      updateUI();
    }
  }

  void prepareTableForFollowUpdates(String folder) {
    if (!folderNames.contains(folder)) return;
    final tables = [folder];
    _runBackground(DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      _migrateFollowUpdatesFields(db, tables);
    }));
  }

  int countUpdates(String folder) {
    return _comics[folder]?.where((row) => row['has_new_update'] == 1).length ??
        0;
  }

  List<FavoriteItemWithUpdateInfo> getComicsWithUpdatesInfo(String folder) {
    final rows = _comics[folder];
    if (rows == null) return [];
    return rows
        .map(
          (row) => FavoriteItemWithUpdateInfo(
            FavoriteItem.fromMap(row),
            row['last_update_time'],
            row['has_new_update'] == 1,
            row['last_check_time'],
          ),
        )
        .toList();
  }

  void markAsRead(String id, FavoriteType type) {
    var folder = appdata.appSettings.followUpdatesFolder.isEmpty
        ? null
        : appdata.appSettings.followUpdatesFolder;
    if (folder == null || !folderNames.contains(folder)) return;
    final typeKey = type.key;
    for (final row in _comics[folder]!) {
      if (row['target'] == id && row['type'] == typeKey) {
        row['has_new_update'] = 0;
      }
    }
    _runBackground(DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      db.execute("""
        update "$folder"
        set has_new_update = 0
        where target == ? and type == ?;
      """, [id, typeKey]);
    }));
  }

  void updateUpdateTime(
    String folder,
    String target,
    FavoriteType type,
    String updateTime,
  ) {
    final typeKey = type.key;
    final rows = _comics[folder];
    if (rows == null) {
      throw Exception("Table '$folder' does not exist");
    }
    final row = rows.firstWhere(
      (row) => row['target'] == target && row['type'] == typeKey,
    );
    final oldTime = row['last_update_time'];
    final hasNewUpdate = oldTime != updateTime;
    final checkTime = DateTime.now().millisecondsSinceEpoch;
    row['last_update_time'] = updateTime;
    row['has_new_update'] = hasNewUpdate ? 1 : 0;
    row['last_check_time'] = checkTime;
    _runBackground(DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      db.execute("""
        update "$folder"
        set last_update_time = ?, has_new_update = ?, last_check_time = ?
        where target == ? and type == ?;
      """, [updateTime, hasNewUpdate ? 1 : 0, checkTime, target, typeKey]);
    }));
  }

  void updateCheckTime(
    String folder,
    String target,
    FavoriteType type,
  ) {
    final checkTime = DateTime.now().millisecondsSinceEpoch;
    final typeKey = type.key;
    for (final row in _comics[folder] ?? <Map<String, dynamic>>[]) {
      if (row['target'] == target && row['type'] == typeKey) {
        row['last_check_time'] = checkTime;
      }
    }
    _runBackground(DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      db.execute("""
        update "$folder"
        set last_check_time = ?
        where target == ? and type == ?;
      """, [checkTime, target, typeKey]);
    }));
  }
}
