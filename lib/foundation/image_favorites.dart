part of "history.dart";

// 直接用history.db了, 没必要再加一个favorites.db

class ImageFavorite{
  /// unique id for the comic
  final String id;

  final String imagePath;

  final String title;

  final int ep;

  final int page;

  final Map<String, dynamic> otherInfo;

  const ImageFavorite(this.id, this.imagePath, this.title, this.ep, this.page, this.otherInfo);
}

class ImageFavoriteManager{
  static Database get _db => HistoryManager()._db;

  /// 检查表image_favorites是否存在, 不存在则创建
  static void init(){
    _db.execute("CREATE TABLE IF NOT EXISTS image_favorites ("
        "id TEXT,"
        "title TEXT NOT NULL,"
        "cover TEXT NOT NULL,"
        "ep INTEGER NOT NULL,"
        "page INTEGER NOT NULL,"
        "other TEXT NOT NULL,"
        "PRIMARY KEY (id, ep, page)"
        ");");
  }

  static void add(ImageFavorite favorite){
    _db.execute("""
      insert into image_favorites(id, title, cover, ep, page, other)
      values(?, ?, ?, ?, ?, ?);
    """, [favorite.id, favorite.title, favorite.imagePath, favorite.ep, favorite.page, jsonEncode(favorite.otherInfo)]);
    Webdav.uploadData();
    Future.microtask(() => StateController.findOrNull(tag: "me_page")?.update());
  }

  static List<ImageFavorite> getAll(){
    var res = _db.select("select * from image_favorites;");
    return res.map((e) =>
        ImageFavorite(e["id"], e["cover"], e["title"], e["ep"], e["page"], jsonDecode(e["other"]))).toList();
  }

  /// 根据关键词搜索图片收藏
  static List<ImageFavorite> search(String keyword) {
    if (keyword.isEmpty) return getAll();
    
    var res = _db.select("""
      select * from image_favorites 
      where title like ? or id like ?
    """, ['%$keyword%', '%$keyword%']);
    
    return res.map((e) =>
        ImageFavorite(e["id"], e["cover"], e["title"], e["ep"], e["page"], jsonDecode(e["other"]))).toList();
  }

  /// 按漫画ID分组获取图片收藏
  static Map<String, List<ImageFavorite>> getGroupedByComic() {
    var allFavorites = getAll();
    var grouped = <String, List<ImageFavorite>>{};
    
    for (var favorite in allFavorites) {
      if (!grouped.containsKey(favorite.id)) {
        grouped[favorite.id] = [];
      }
      grouped[favorite.id]!.add(favorite);
    }
    
    return grouped;
  }

  /// 批量删除图片收藏
  static void deleteMultiple(Iterable<ImageFavorite> favorites) {
    for (var favorite in favorites) {
      _db.execute("""
        delete from image_favorites
        where id = ? and ep = ? and page = ?;
      """, [favorite.id, favorite.ep, favorite.page]);
    }
    Webdav.uploadData();
  }

  static void delete(ImageFavorite favorite){
    _db.execute("""
      delete from image_favorites
      where id = ? and ep = ? and page = ?;
    """, [favorite.id, favorite.ep, favorite.page]);
    Webdav.uploadData();
  }

  static bool exist(String id, int ep, int page) {
    var res = _db.select("""
      select * from image_favorites
      where id = ? and ep = ? and page = ?;
    """, [id, ep, page]);
    return res.isEmpty ? false : true;
  }

  static int get length {
    var res = _db.select("select count(*) from image_favorites;");
    return res.first.values.first! as int;
  }
}
