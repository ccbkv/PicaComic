part of "history.dart";

// 直接用history.db了, 没必要再加一个favorites.db

class ImageFavorite {
  /// unique id for the comic
  final String id;

  final String imagePath;

  final String title;

  final int ep;

  final int page;

  final Map<String, dynamic> otherInfo;

  const ImageFavorite(
      this.id, this.imagePath, this.title, this.ep, this.page, this.otherInfo);
}

class ImageFavoriteManager {
  static List<ImageFavorite> _cache = [];

  static String get _dbPath => HistoryManager()._dbPath;

  static bool get _available => HistoryManager()._ensureDbAvailable();

  /// 检查表image_favorites是否存在, 不存在则创建
  static Future<void> init() async {
    if (!_available) {
      _cache = [];
      return;
    }
    await DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      db.execute("CREATE TABLE IF NOT EXISTS image_favorites ("
          "id TEXT,"
          "title TEXT NOT NULL,"
          "cover TEXT NOT NULL,"
          "ep INTEGER NOT NULL,"
          "page INTEGER NOT NULL,"
          "other TEXT NOT NULL,"
          "PRIMARY KEY (id, ep, page)"
          ");");
    });
    _cache = await DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      return db
          .select("select * from image_favorites;")
          .map(_imageFavoriteFromRow)
          .toList();
    });
  }

  static Future<void> add(ImageFavorite favorite) async {
    if (!_available) {
      return;
    }
    final values = [
      favorite.id,
      favorite.title,
      favorite.imagePath,
      favorite.ep,
      favorite.page,
      jsonEncode(favorite.otherInfo),
    ];
    await DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      db.execute("""
        insert into image_favorites(id, title, cover, ep, page, other)
        values(?, ?, ?, ?, ?, ?);
      """, values);
    });
    _cache.add(favorite);
    Webdav.uploadData();
    Future.microtask(
        () => StateController.findOrNull(tag: "me_page")?.update());
  }

  static List<ImageFavorite> getAll() => List.of(_cache);

  /// 根据关键词搜索图片收藏
  static List<ImageFavorite> search(String keyword) {
    if (keyword.isEmpty) return getAll();
    final lowerKeyword = keyword.toLowerCase();
    return _cache
        .where((favorite) =>
            favorite.title.toLowerCase().contains(lowerKeyword) ||
            favorite.id.toLowerCase().contains(lowerKeyword))
        .toList();
  }

  /// 按漫画ID分组获取图片收藏
  static Map<String, List<ImageFavorite>> getGroupedByComic() {
    final grouped = <String, List<ImageFavorite>>{};
    for (final favorite in _cache) {
      grouped.putIfAbsent(favorite.id, () => []).add(favorite);
    }
    return grouped;
  }

  /// 批量删除图片收藏
  static Future<void> deleteMultiple(Iterable<ImageFavorite> favorites) async {
    if (!_available) {
      return;
    }
    final items = favorites.toList();
    if (items.isEmpty) return;
    final keys = [
      for (final favorite in items) [favorite.id, favorite.ep, favorite.page],
    ];
    await DatabaseGateway.instance.isolateOp(_dbPath, (db) {
      for (final key in keys) {
        db.execute("""
          delete from image_favorites
          where id = ? and ep = ? and page = ?;
        """, key);
      }
    });
    final removed = items
        .map((favorite) => (favorite.id, favorite.ep, favorite.page))
        .toSet();
    _cache.removeWhere((favorite) =>
        removed.contains((favorite.id, favorite.ep, favorite.page)));
    Webdav.uploadData();
    Future.microtask(
        () => StateController.findOrNull(tag: "me_page")?.update());
  }

  static Future<void> delete(ImageFavorite favorite) {
    return deleteMultiple([favorite]);
  }

  static bool exist(String id, int ep, int page) {
    return _cache.any((favorite) =>
        favorite.id == id && favorite.ep == ep && favorite.page == page);
  }

  static int get length => _cache.length;
}

ImageFavorite _imageFavoriteFromRow(Row row) {
  return ImageFavorite(
    row["id"],
    row["cover"],
    row["title"],
    row["ep"],
    row["page"],
    jsonDecode(row["other"]),
  );
}
