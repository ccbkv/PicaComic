import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'package:pica_comic/base.dart';
import 'package:pica_comic/foundation/comic_source/comic_source.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/image_manager.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/foundation/platform_utils.dart';
import 'package:pica_comic/foundation/sqlite_connection.dart';
import 'package:pica_comic/network/jm_network/jm_image.dart';
import 'package:pica_comic/network/eh_network/eh_main_network.dart';
import 'package:pica_comic/network/webdav.dart';
import 'package:pica_comic/utils/android_widget.dart';
import 'package:pica_comic/utils/ohos_widget.dart';
import 'package:sqlite3/sqlite3.dart';

part "image_favorites.dart";

abstract mixin class HistoryMixin {
  String get title;

  String? get subTitle;

  String get cover;

  String get target;

  Object? get maxPage => null;

  HistoryType get historyType;
}

final class HistoryType {
  static HistoryType get picacg => const HistoryType(0);

  static HistoryType get ehentai => const HistoryType(1);

  static HistoryType get jmComic => const HistoryType(2);

  static HistoryType get hitomi => const HistoryType(3);

  static HistoryType get htmanga => const HistoryType(4);

  static HistoryType get nhentai => const HistoryType(5);

  final int value;

  String get name {
    if (value >= 0 && value <= 5) {
      return ["picacg", "ehentai", "jm", "hitomi", "htmanga", "nhentai"][value];
    } else {
      return ComicSource.fromIntKey(value)?.name ?? "Unknown";
    }
  }

  const HistoryType(this.value);

  @override
  bool operator ==(Object other) =>
      other is HistoryType && other.value == value;

  @override
  int get hashCode => value.hashCode;

  ComicSource? get comicSource {
    if (value >= 0 && value <= 5) {
      return ComicSource.find(name);
    } else {
      return ComicSource.fromIntKey(value);
    }
  }
}

base class History extends LinkedListEntry<History> {
  HistoryType type;

  DateTime time;

  String title;

  String subtitle;

  String cover;

  /// 标记为0表示没有阅读位置记录
  int ep;

  int page;

  String target;

  Set<int> readEpisode;

  int? maxPage;

  History(this.type, this.time, this.title, this.subtitle, this.cover, this.ep,
      this.page, this.target, [Set<int>? readEpisode, this.maxPage])
      : readEpisode =
            readEpisode == null ? <int>{} : Set<int>.from(readEpisode);

  History.fromModel(
      {required HistoryMixin model,
      required this.ep,
      required this.page,
      Set<int>? readEpisode,
      DateTime? time})
      : type = model.historyType,
        title = model.title,
        subtitle = model.subTitle ?? '',
        cover = model.cover,
        target = model.target,
        time = time ?? DateTime.now(),
        readEpisode =
            readEpisode == null ? <int>{} : Set<int>.from(readEpisode);

  Map<String, dynamic> toMap() => {
        "type": type.value,
        "time": time.millisecondsSinceEpoch,
        "title": title,
        "subtitle": subtitle,
        "cover": cover,
        "ep": ep,
        "page": page,
        "target": target,
        "readEpisode": readEpisode.toList(),
        "max_page": maxPage
      };

  History.fromMap(Map<String, dynamic> map)
      : type = HistoryType(map["type"]),
        time = DateTime.fromMillisecondsSinceEpoch(map["time"]),
        title = map["title"],
        subtitle = map["subtitle"],
        cover = map["cover"],
        ep = map["ep"],
        page = map["page"],
        target = map["target"],
        readEpisode = Set<int>.from(
            (map["readEpisode"] as List<dynamic>?)?.toSet() ?? const <int>{}),
        maxPage = map["max_page"];

  @override
  String toString() {
    return 'NewHistory{type: $type, time: $time, title: $title, subtitle: $subtitle, cover: $cover, ep: $ep, page: $page, target: $target}';
  }

  History.fromRow(Row row)
      : type = HistoryType(row["type"]),
        time = DateTime.fromMillisecondsSinceEpoch(row["time"]),
        title = row["title"],
        subtitle = row["subtitle"],
        cover = row["cover"],
        ep = row["ep"],
        page = row["page"],
        target = row["target"],
        readEpisode = Set<int>.from((row["readEpisode"] as String)
            .split(',')
            .where((element) => element != "")
            .map((e) => int.parse(e))),
        maxPage = row["max_page"];

  static Future<History> findOrCreate(
    HistoryMixin model, {
    int ep = 0,
    int page = 0,
  }) async {
    var history = await HistoryManager().find(model.target);
    if (history != null) {
      return history;
    }
    history = History.fromModel(model: model, ep: ep, page: page);
    HistoryManager().addHistory(history);
    return history;
  }

  static Future<History> createIfNull(
      History? history, HistoryMixin model) async {
    if (history != null) {
      return history;
    }
    history = History.fromModel(model: model, ep: 0, page: 0);
    HistoryManager().addHistory(history);
    return history;
  }
}

class HistoryManager {
  static HistoryManager? cache;

  HistoryManager.create();

  factory HistoryManager() =>
      cache == null ? (cache = HistoryManager.create()) : cache!;

  late final String _dbPath = "${App.dataPath}/history.db";
  bool _dbAvailable = false;
  bool _dbWarningIssued = false;
  Timer? _ohosWidgetSyncDebounce;
  final Map<String, String> _ohosWidgetCoverDataCache = {};
  Map<String, History> _historyCache = {};

  bool _ensureDbAvailable() {
    if (_dbAvailable) {
      return true;
    }
    if (!_dbWarningIssued) {
      _dbWarningIssued = true;
      LogManager.addLog(LogLevel.warning, "HistoryManager",
          "History database is unavailable on this platform. Functions that rely on it will be no-ops.");
    }
    return false;
  }

  int get length => _historyCache.length;

  Future<void> tryUpdateDb() async {
    final file = File("${App.dataPath}/history_temp.db");
    if (!await file.exists()) {
      LogManager.addLog(
          LogLevel.info, "HistoryManager.tryUpdateDb", "db file not exist");
      return;
    }
    final imported = await DatabaseGateway.instance.isolateOp(file.path, (db) {
      final histories = db.select("""
        select * from history
        order by time DESC;
      """).map((element) => History.fromRow(element)).toList();
      final images = db
          .select("select * from image_favorites;")
          .map((e) => ImageFavorite(e["id"], e["cover"], e["title"], e["ep"],
              e["page"], jsonDecode(e["other"])))
          .toList();
      return (histories: histories, images: images);
    });

    var skips = 0;
    for (final history in imported.histories) {
      if (findSync(history.target) == null) {
        await addHistory(history);
        LogManager.addLog(
            LogLevel.info, "HistoryManager", "merge history ${history.target}");
      } else {
        skips++;
      }
    }
    LogManager.addLog(LogLevel.info, "HistoryManager",
        "merge history, skipped $skips, added ${imported.histories.length - skips}");

    skips = 0;
    await ImageFavoriteManager.init();
    for (final image in imported.images) {
      if (ImageFavoriteManager.exist(image.id, image.ep, image.page)) {
        skips++;
      } else {
        await ImageFavoriteManager.add(image);
        LogManager.addLog(LogLevel.info, "HistoryManager",
            "merge favorite image ep ${image.ep} page ${image.page} @ ${image.id}");
      }
    }
    LogManager.addLog(LogLevel.info, "HistoryManager",
        "merge favorite images, skipped $skips, added ${imported.images.length - skips}");
    await file.delete();
  }

  Future<void> init() async {
    try {
      await DatabaseGateway.instance.isolateOp(_dbPath, (db) {
        db.execute("""
          create table if not exists history  (
            target text primary key,
            title text,
            subtitle text,
            cover text,
            time int,
            type int,
            ep int,
            page int,
            readEpisode text,
            max_page int
          );
        """);
        final res = db.select("PRAGMA table_info(history);");
        if (res.every((row) => row["name"] != "max_page")) {
          db.execute("alter table history add column max_page int;");
        }
      });
      _dbAvailable = true;
      await updateCache();
    } catch (e, s) {
      _dbAvailable = false;
      LogManager.addLog(LogLevel.error, "HistoryManager",
          "Failed to open history database: $e\n$s");
      return;
    }

    // 迁移早期版本的数据
    final file = File("${App.dataPath}/history.json");
    if (await file.exists()) {
      await readDataFromJson(jsonDecode(await file.readAsString()));
      await file.delete();
    }

    await ImageFavoriteManager.init();
    unawaited(syncOhosWidgetHistory());
  }

  Future<void> readDataFromJson(List<dynamic> json) async {
    var history = LinkedList<History>();
    for (var h in json) {
      history.add(History.fromMap((h as Map<String, dynamic>)));
    }
    // do not clear previous history
    for (var element in history) {
      if (findSync(element.target) == null) await addHistory(element);
    }
    await vacuum();
    unawaited(syncOhosWidgetHistory());
  }

  void saveData() async {
    Webdav.uploadData();
  }

  /// add history. if exists, update time.
  ///
  /// This function would be called when user start reading.
  Future<void> addHistory(History newItem) async {
    if (!_ensureDbAvailable()) {
      return;
    }
    final item = newItem.toMap();
    final now = DateTime.now().millisecondsSinceEpoch;
    await DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      final res = db.select(
        "select * from history where target == ?;",
        [item['target']],
      );
      if (res.isEmpty) {
        db.execute("""
          insert into history (target, title, subtitle, cover, time, type, ep, page, readEpisode, max_page)
          values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """, [
          item['target'],
          item['title'],
          item['subtitle'],
          item['cover'],
          item['time'],
          item['type'],
          item['ep'],
          item['page'],
          (item['readEpisode'] as List).join(','),
          item['max_page'],
        ]);
      } else {
        db.execute(
          "update history set time = ? where target == ?;",
          [now, item['target']],
        );
      }
    });
    saveData();
    await updateCache();
    _scheduleOhosWidgetHistorySync();
  }

  ///退出阅读器时调用此函数, 修改阅读位置
  Future<void> saveReadHistory(History history,
      [bool updateMePage = true]) async {
    if (!_ensureDbAvailable()) {
      return;
    }
    final values = [
      DateTime.now().millisecondsSinceEpoch,
      history.ep,
      history.page,
      history.readEpisode.join(','),
      history.maxPage,
      history.target,
    ];
    await DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      db.execute("""
        update history
        set time = ?, ep = ?, page = ?, readEpisode = ?, max_page = ?
        where target == ?;
      """, values);
    });
    if (updateMePage) {
      scheduleMicrotask(() {
        StateController.findOrNull(tag: "me_page_history")?.update();
      });
    }
    await updateCache();
    _scheduleOhosWidgetHistorySync();
  }

  Future<void> clearHistory() async {
    if (!_ensureDbAvailable()) {
      return;
    }
    await DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      db.execute("delete from history;");
    });
    await updateCache();
    _scheduleOhosWidgetHistorySync();
  }

  Future<void> remove(String id) async {
    if (!_ensureDbAvailable()) {
      return;
    }
    await DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      db.execute("delete from history where target == ?;", [id]);
    });
    await updateCache();
    _scheduleOhosWidgetHistorySync();
  }

  void _scheduleOhosWidgetHistorySync() {
    unawaited(syncOhosWidgetHistory());
    if (!PlatformUtils.isOhos && !App.isAndroid) {
      return;
    }
    _ohosWidgetSyncDebounce?.cancel();
    _ohosWidgetSyncDebounce = Timer(const Duration(milliseconds: 800), () {
      unawaited(syncOhosWidgetHistory());
    });
  }

  Future<void> syncOhosWidgetHistory() async {
    if (!_ensureDbAvailable()) {
      await OhosWidgetService.instance.updateHistorySnapshot([]);
      return;
    }
    final histories = getRecent().take(6).toList();
    final existingCovers = _readOhosWidgetCoverSnapshotCache();
    final covers = await Future.wait(
      histories.map(
        (history) => _buildOhosWidgetCoverData(history).timeout(
          const Duration(seconds: 6),
          onTimeout: () => '',
        ),
      ),
    );
    final items =
        List<Map<String, Object?>>.generate(histories.length, (index) {
      final history = histories[index];
      final fallbackCover = existingCovers[_ohosWidgetCoverCacheKey(history)];
      return <String, Object?>{
        "title": history.title,
        "subtitle": history.subtitle,
        "cover": covers[index].isNotEmpty ? covers[index] : fallbackCover ?? '',
        "source": history.type.name,
        "progress": _formatOhosWidgetProgress(history),
        "time": _formatOhosWidgetTime(history.time),
        "target": history.target,
        "type": history.type.value,
        "ep": history.ep,
        "page": history.page,
      };
    });
    if (PlatformUtils.isOhos) {
      try {
        final snapshotFile =
            File("${App.dataPath}/widget_history_snapshot.json");
        snapshotFile.writeAsStringSync(_asciiJsonEncode(items));
      } catch (error, stack) {
        LogManager.addLog(
          LogLevel.error,
          "HistoryManager",
          "Failed to write OHOS widget history snapshot: $error\n$stack",
        );
      }
    }
    await OhosWidgetService.instance.updateHistorySnapshot(items);
    await AndroidWidgetService.instance.updateHistorySnapshot(items);
  }

  String _resolveOhosWidgetCoverUrl(History history) {
    if (history.cover.isNotEmpty) {
      return history.cover;
    }
    if (history.type == HistoryType.jmComic) {
      return getJmCoverUrl(history.target);
    }
    return '';
  }

  Future<String> _buildOhosWidgetCoverData(History history) async {
    if (!PlatformUtils.isOhos && !App.isAndroid) {
      return '';
    }
    final coverUrl = _resolveOhosWidgetCoverUrl(history);
    final sourceKey = history.type.comicSource?.key;
    if (coverUrl.isEmpty) {
      return '';
    }
    final cacheKey = _ohosWidgetCoverCacheKey(history);
    final cached = _ohosWidgetCoverDataCache[cacheKey];
    if (cached != null) {
      return cached;
    }
    try {
      DownloadProgress? finishedProgress;
      final stream = sourceKey == null
          ? ImageManager().getImage(coverUrl)
          : sourceKey == 'ehentai'
              ? await _getEhentaiWidgetCoverStream(coverUrl)
              : ImageManager().getCustomThumbnail(coverUrl, sourceKey);
      await for (final progress in stream) {
        if (progress.finished) {
          finishedProgress = progress;
        }
      }
      final imageBytes = finishedProgress?.data ??
          await finishedProgress?.getFile().readAsBytes();
      if (imageBytes == null || imageBytes.isEmpty) {
        return '';
      }
      final dataUri = await compute(_encodeOhosWidgetCoverDataUri, imageBytes);
      if (dataUri.isNotEmpty) {
        _ohosWidgetCoverDataCache[cacheKey] = dataUri;
      }
      return dataUri;
    } catch (error, stack) {
      LogManager.addLog(
        LogLevel.warning,
        "HistoryManager",
        "Failed to prepare OHOS widget cover: $coverUrl\n$error\n$stack",
      );
      return '';
    }
  }

  Future<Stream<DownloadProgress>> _getEhentaiWidgetCoverStream(
      String coverUrl) async {
    await EhNetwork().getCookies(false, coverUrl);
    return ImageManager().getImage(
      '$coverUrl#widget_cover',
      {
        'Cookie': EhNetwork().cookiesStr,
        'User-Agent': webUA,
        'Referer': EhNetwork().ehBaseUrl,
      },
    );
  }

  String _ohosWidgetCoverCacheKey(History history) =>
      '${history.type.value}:${history.target}';

  Map<String, String> _readOhosWidgetCoverSnapshotCache() {
    if (!PlatformUtils.isOhos && !App.isAndroid) {
      return const {};
    }
    try {
      final snapshotFile = File("${App.dataPath}/widget_history_snapshot.json");
      if (!snapshotFile.existsSync()) {
        return const {};
      }
      final parsed = jsonDecode(snapshotFile.readAsStringSync());
      if (parsed is! List) {
        return const {};
      }
      final covers = <String, String>{};
      for (final item in parsed) {
        if (item is! Map) {
          continue;
        }
        final target = item['target'];
        final type = item['type'];
        final cover = item['cover'];
        if (target is String &&
            target.isNotEmpty &&
            type is num &&
            cover is String &&
            cover.isNotEmpty) {
          covers['${type.toInt()}:$target'] = cover;
        }
      }
      _ohosWidgetCoverDataCache.addAll(covers);
      return covers;
    } catch (_) {
      return const {};
    }
  }

  String _asciiJsonEncode(Object? value) {
    final json = jsonEncode(value);
    final buffer = StringBuffer();
    for (final rune in json.runes) {
      if (rune <= 0x7f) {
        buffer.writeCharCode(rune);
      } else if (rune <= 0xffff) {
        buffer.write(r"\u");
        buffer.write(rune.toRadixString(16).padLeft(4, "0"));
      } else {
        final code = rune - 0x10000;
        final high = 0xd800 + (code >> 10);
        final low = 0xdc00 + (code & 0x3ff);
        buffer
          ..write(r"\u")
          ..write(high.toRadixString(16).padLeft(4, "0"))
          ..write(r"\u")
          ..write(low.toRadixString(16).padLeft(4, "0"));
      }
    }
    return buffer.toString();
  }

  String _formatOhosWidgetProgress(History history) {
    final page = history.page <= 0 ? 1 : history.page;
    final ep = history.ep <= 0 ? 1 : history.ep;
    if (history.maxPage != null && history.maxPage! > 0) {
      return "第$ep话 · $page/${history.maxPage}页";
    }
    return "第$ep话 · 第$page页";
  }

  String _formatOhosWidgetTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(time.year, time.month, time.day);
    final days = today.difference(date).inDays;
    if (days <= 0) {
      return "今天";
    }
    if (days == 1) {
      return "昨天";
    }
    if (days < 7) {
      return "$days天前";
    }
    return "${time.month}/${time.day}";
  }

  Future<History?> find(String target) async {
    return findSync(target);
  }

  Future<void> updateCache() async {
    if (!_ensureDbAvailable()) {
      _historyCache = {};
      return;
    }
    final histories = await DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      return db
          .select("select * from history order by time DESC;")
          .map((element) => History.fromRow(element))
          .toList();
    });
    _historyCache = {for (final history in histories) history.target: history};
  }

  History? findSync(String target) => _historyCache[target];

  List<History> getAll() => _historyCache.values.toList();

  Future<void> vacuum() async {
    if (!_ensureDbAvailable()) {
      return;
    }
    await DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      db.execute("vacuum;");
    });
  }

  /// 获取最近一周的阅读数据, 用于生成图表, List中的元素是当天阅读的漫画数量
  List<int> getWeekData(int days) {
    final start = DateTime.now().add(Duration(days: 1 - days));
    final histories = _historyCache.values
        .where((history) => history.time.isAfter(start))
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    final data = List<int>.filled(days, 0);
    for (final history in histories) {
      final index = DateTime.now().difference(history.time).inDays;
      if (index >= 0 && index < data.length) {
        data[index]++;
      }
    }
    return data.reversed.toList();
  }

  /// 获取最近阅读的漫画
  List<History> getRecent() => _historyCache.values.take(20).toList();

  /// 获取历史记录的数量
  int count() => _historyCache.length;

  /// Get plain search keyword from a keyword that may be polluted.
  static String getPlainSearchKeyword(String keyword) {
    // remove language filter
    // final languagePattern = RegExp(r'\s*language:\w+');
    // var result = keyword.replaceAll(languagePattern, '').trim();
    var result = keyword;

    // remove jm blocking keywords
    if (appdata.jmBlockingKeyword.isNotEmpty) {
      var words = result.trim().split(' ').where((s) => s.isNotEmpty);
      var userWords = <String>[];
      var jmBlockingSet = appdata.jmBlockingKeyword.toSet();
      for (var word in words) {
        if (word.startsWith('-') && jmBlockingSet.contains(word.substring(1))) {
          // is a blocking keyword, skip it
        } else {
          userWords.add(word);
        }
      }
      result = userWords.join(' ');
    }

    return result;
  }

  /// Add search history
  static void addSearchHistory(String keyword) {
    if (keyword.trim().isEmpty) return;

    if (appdata.searchHistory.contains(keyword)) {
      appdata.searchHistory.remove(keyword);
    }
    appdata.searchHistory.add(keyword);
    appdata.writeSearchHistory();
    appdata.writeHistory();
  }
}

String _encodeOhosWidgetCoverDataUri(Uint8List bytes) {
  final decoded = image.decodeImage(bytes);
  if (decoded == null) {
    return '';
  }
  final oriented = image.bakeOrientation(decoded);
  const targetWidth = 90;
  const targetHeight = 120;
  final scale = max(
    targetWidth / oriented.width,
    targetHeight / oriented.height,
  );
  final resized = image.copyResize(
    oriented,
    width: (oriented.width * scale).ceil(),
    height: (oriented.height * scale).ceil(),
    interpolation: image.Interpolation.average,
  );
  final cropped = image.copyCrop(
    resized,
    x: max(0, (resized.width - targetWidth) ~/ 2),
    y: max(0, (resized.height - targetHeight) ~/ 2),
    width: targetWidth,
    height: targetHeight,
  );
  final encoded = image.encodeJpg(cropped, quality: 68);
  return 'data:image/jpeg;base64,${base64Encode(encoded)}';
}
