import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:pica_comic/base.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/network/cloudflare.dart';
import 'package:pica_comic/network/cookie_jar.dart';
import 'package:pica_comic/network/nhentai_network/tags.dart';
import 'package:pica_comic/network/res.dart';
import 'package:pica_comic/utils/extensions.dart';
import 'package:pica_comic/utils/time.dart';
import 'package:pica_comic/utils/translations.dart';
import 'package:pica_comic/pages/pre_search_page.dart';
import '../app_dio.dart';
import 'models.dart';

export 'models.dart';

class NhentaiNetwork {
  factory NhentaiNetwork() => _cache ?? (_cache = NhentaiNetwork._create());

  NhentaiNetwork._create();

  static NhentaiNetwork? _cache;

  SingleInstanceCookieJar? cookieJar;

  bool logged = false;

  String baseUrl = "https://nhentai.net";
  String apiUrl = "https://nhentai.net/api/v2";

  late Dio dio;

  Future<bool>? _refreshingFuture;

  Map<String, String> get _defaultHeaders => {
        'Accept': 'application/json',
        'Accept-Language': 'zh-CN,zh-TW;q=0.9,zh;q=0.8,en-US;q=0.7,en;q=0.6',
        'Referer': '$baseUrl/',
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) GSA/300.0.598994205 Mobile/15E148 Safari/604',
      };

  Future<void> init() async {
    cookieJar = SingleInstanceCookieJar.instance;
    refreshLoginState();
    dio = logDio(BaseOptions(
      headers: _defaultHeaders,
      validateStatus: (i) => i == 200 || i == 302 || i == 401,
    ));
    dio.interceptors.add(CookieManagerSql(cookieJar!));
    dio.interceptors.add(CloudflareInterceptor());
  }

  void logout() async {
    logged = false;
    cookieJar!.delete(Uri.parse(baseUrl), "access_token");
    cookieJar!.delete(Uri.parse(baseUrl), "refresh_token");
  }

  void refreshLoginState() {
    if (cookieJar == null) {
      logged = false;
      return;
    }
    final cookies = cookieJar!.loadForRequest(Uri.parse(baseUrl));
    for (var cookie in cookies) {
      if (cookie.name == 'access_token') {
        logged = true;
      }
    }
  }

  String? _getAccessToken() {
    if (cookieJar == null) {
      return null;
    }
    for (final cookie in cookieJar!.loadForRequest(Uri.parse(baseUrl))) {
      if (cookie.name == 'access_token' && cookie.value.isNotEmpty) {
        return cookie.value;
      }
    }
    return null;
  }

  String? _getRefreshToken() {
    if (cookieJar == null) {
      return null;
    }
    for (final cookie in cookieJar!.loadForRequest(Uri.parse(baseUrl))) {
      if (cookie.name == 'refresh_token' && cookie.value.isNotEmpty) {
        return cookie.value;
      }
    }
    return null;
  }

  Map<String, String>? _buildAuthHeaders() {
    final token = _getAccessToken();
    if (token == null) {
      return null;
    }
    return {..._defaultHeaders, 'Authorization': 'User $token'};
  }

  void _saveTokens(String accessToken, String refreshToken) {
    cookieJar?.saveFromResponse(Uri.parse(baseUrl), [
      Cookie('access_token', accessToken)
        ..domain = '.nhentai.net'
        ..path = '/',
      Cookie('refresh_token', refreshToken)
        ..domain = '.nhentai.net'
        ..path = '/',
    ]);
    refreshLoginState();
  }


  Future<bool> _refreshAccessToken() {
    _refreshingFuture ??= _doRefreshAccessToken().whenComplete(() {
      _refreshingFuture = null;
    });
    return _refreshingFuture!;
  }

  Future<bool> _doRefreshAccessToken() async {
    final refreshToken = _getRefreshToken();
    if (refreshToken == null) {
      return false;
    }
    try {
      final res = await dio.post<dynamic>('$apiUrl/auth/refresh', data: {'refresh_token': refreshToken},
        options: Options(headers: _defaultHeaders),
      );
      final data = res.data;
      if (data is! Map) {
        return false;
      }
      final accessToken = data['access_token']?.toString();
      final newRefreshToken = data['refresh_token']?.toString();
      if (accessToken == null || accessToken.isEmpty || newRefreshToken == null || newRefreshToken.isEmpty) {
        return false;
      }
      _saveTokens(accessToken, newRefreshToken);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Res<dynamic>> get(String url, {bool withAuth = false, bool retried = false}) async {
    if (cookieJar == null) {
      await init();
    }
    try {
      final headers = withAuth ? _buildAuthHeaders() : null;
      var res = await dio.get<dynamic>(url, options: Options(followRedirects: false, headers: headers),
      );
      if (res.statusCode == 302) {
        var path = res.headers["Location"]?.first ??
            res.headers["location"]?.first ??
            "";
        return get(Uri.parse(url).replace(path: path).toString(), withAuth: withAuth, retried: retried);
      }
      if (res.statusCode == 401) {
        if (withAuth && !retried) {
          final refreshed = await _refreshAccessToken();
          if (refreshed) {
            return get(url, withAuth: withAuth, retried: true);
          }
        }
        logged = false;
        return const Res(null, errorMessage: 'login required');
      }
      return Res(res.data);
    } catch (e) {
      return Res(null, errorMessage: e.toString());
    }
  }

  Future<Res<dynamic>> post(String url, dynamic data,{bool withAuth = false, bool retried = false}) async {
    if (cookieJar == null) {
      await init();
    }
    try {
      final headers = withAuth ? _buildAuthHeaders() : null;
      var res = await dio.post<dynamic>(url, data: data, options: Options(headers: headers));
      if (res.statusCode == 401 || res.statusCode == 403) {
        if (withAuth && !retried) {
          final refreshed = await _refreshAccessToken();
          if (refreshed) {
            return post(url, data, withAuth: withAuth, retried: true);
          }
        }
        logged = false;
        return const Res(null, errorMessage: 'login required');
      }
      return Res(res.data);
    } catch (e) {
      return Res(null, errorMessage: e.toString());
    }
  }

  Future<Res<dynamic>> delete(String url, {bool withAuth = false, bool retried = false}) async {
    if (cookieJar == null) {
      await init();
    }
    try {
      final headers = withAuth ? _buildAuthHeaders() : null;
      var res = await dio.delete<dynamic>(url, options: Options(headers: headers));
      if (res.statusCode == 401 || res.statusCode == 403) {
        if (withAuth && !retried) {
          final refreshed = await _refreshAccessToken();
          if (refreshed) {
            return delete(url, withAuth: withAuth, retried: true);
          }
        }
        logged = false;
        return const Res(null, errorMessage: 'login required');
      }
      return Res(res.data);
    } catch (e) {
      return Res(null, errorMessage: e.toString());
    }
  }

  String _getLanguageFromTagIds(List<int> tagIds) {
    // 12227 = English, 6346 = Japanese, 29963 = Chinese
    if (tagIds.contains(12227)) {
      return "English";
    } else if (tagIds.contains(6346)) {
      return "日本語";
    } else if (tagIds.contains(29963)) {
      return "中文";
    }
    return "Unknown";
  }

  List<String> _getTagsFromTagIds(List<int> tagIds) {
    var tags = <String>[];
    for (var tagId in tagIds) {
      var tagStr = tagId.toString();
      if (nhentaiTags[tagStr] != null) {
        tags.add(nhentaiTags[tagStr]!);
      }
    }
    return tags;
  }

  NhentaiComicBrief _convertGalleryItemToBrief(NhentaiGalleryListItemV2 item) {
    var lang = _getLanguageFromTagIds(item.tagIds);
    var tags = _getTagsFromTagIds(item.tagIds);
    return NhentaiComicBrief(
      item.englishTitle.isNotEmpty ? item.englishTitle : (item.japaneseTitle ?? item.id.toString()),
      item.coverUrl,
      item.id.toString(),
      lang,
      tags,
    );
  }

  List<T> removeNullValue<T extends Object>(List<T?> list) {
    while (list.remove(null)) {}
    return List.from(list);
  }

  Future<Res<NhentaiHomePageData>> getHomePage([int? page]) async {
    // 使用搜索API获取首页数据
    // 热门今日
    var popularTodayRes = await _searchApi("", 1, "popular-today");
    // 最新
    var latestRes = await _searchApi("", page ?? 1, "date");

    if (popularTodayRes.error && latestRes.error) {
      return Res(null, errorMessage: popularTodayRes.errorMessage ?? latestRes.errorMessage);
    }

    try {
      List<NhentaiComicBrief> popular = [];
      List<NhentaiComicBrief> latest = [];

      if (!popularTodayRes.error) {
        var response = NhentaiSearchResponseV2.fromJson(popularTodayRes.data);
        popular = response.result.map(_convertGalleryItemToBrief).toList();
      }

      if (!latestRes.error) {
        var response = NhentaiSearchResponseV2.fromJson(latestRes.data);
        latest = response.result.map(_convertGalleryItemToBrief).toList();
      }

      return Res(NhentaiHomePageData(popular, latest));
    } catch (e, s) {
      LogManager.addLog(LogLevel.error, "Data Analyse", "$e\n$s");
      return Res(null, errorMessage: "Failed to Parse Data: $e");
    }
  }

  Future<Res<bool>> loadMoreHomePageData(NhentaiHomePageData data) async {
    var res = await _searchApi("", data.page + 1, "date");
    if (res.error) {
      return Res.fromErrorRes(res);
    }
    try {
      var response = NhentaiSearchResponseV2.fromJson(res.data);
      var newComics = response.result.map(_convertGalleryItemToBrief).toList();
      data.latest.addAll(newComics);
      data.page++;
      return const Res(true);
    } catch (e, s) {
      LogManager.addLog(LogLevel.error, "Data Analyse", "$e\n$s");
      return Res(null, errorMessage: "Failed to Parse Data: $e");
    }
  }

  Future<Res<dynamic>> _searchApi(String query, int page, String sort) async {
    var encodedQuery = Uri.encodeComponent(query.isEmpty ? " " : query);
    var url = "$apiUrl/search?query=$encodedQuery&page=$page&sort=$sort";
    return await get(url);
  }

  Future<Res<List<NhentaiComicBrief>>> search(String keyword, int page,
      [NhentaiSort sort = NhentaiSort.recent]) async {
    var sortStr = switch (sort) {
      NhentaiSort.recent => "date",
      NhentaiSort.popularToday => "popular-today",
      NhentaiSort.popularWeek => "popular-week",
      NhentaiSort.popularMonth => "popular-month",
      NhentaiSort.popularAll => "popular",
    };

    var res = await _searchApi(keyword, page, sortStr);
    if (res.error) {
      return Res.fromErrorRes(res);
    }

    try {
      var response = NhentaiSearchResponseV2.fromJson(res.data);
      var comics = response.result.map(_convertGalleryItemToBrief).toList();

      Future.microtask(() {
        try {
          StateController.find<PreSearchController>().update();
        } catch (e) {
          //
        }
      });

      return Res(comics, subData: response.numPages);
    } catch (e, s) {
      LogManager.addLog(LogLevel.error, "Data Analyse", "$e\n$s");
      return Res(null, errorMessage: "Failed to Parse Data: $e");
    }
  }

  Future<Res<NhentaiComic>> getComicInfo(String id) async {
    // 如果是随机漫画，使用搜索API获取随机页码的漫画
    if (id == "") {
      // 先获取总页数
      var searchRes = await _searchApi("", 1, "date");
      if (searchRes.error) {
        return Res.fromErrorRes(searchRes);
      }
      try {
        var response = NhentaiSearchResponseV2.fromJson(searchRes.data);
        var totalPages = response.numPages;
        if (totalPages > 0) {
          // 生成随机页码 (1 到 totalPages)
          var randomPage = (DateTime.now().millisecondsSinceEpoch % totalPages) + 1;
          var randomRes = await _searchApi("", randomPage, "date");
          if (!randomRes.error) {
            var randomResponse = NhentaiSearchResponseV2.fromJson(randomRes.data);
            if (randomResponse.result.isNotEmpty) {
              // 从该页随机选择一个漫画
              var randomIndex = DateTime.now().millisecondsSinceEpoch % randomResponse.result.length;
              id = randomResponse.result[randomIndex].id.toString();
            }
          }
        }
      } catch (e) {
        // 忽略错误，继续尝试其他方式
      }
      if (id == "") {
        return Res(null, errorMessage: "Failed to get random comic");
      }
    }

    var res = await get("$apiUrl/galleries/$id");
    if (res.error) {
      return Res.fromErrorRes(res);
    }

    try {
      var gallery = NhentaiGalleryV2.fromJson(res.data);

      // 构建标签映射
      Map<String, List<String>> tags = {};
      for (var tag in gallery.tags) {
        var type = tag.type;
        var name = tag.name;

        if (type == "language" && (name == "translated" || name == "rewrite")) {
          continue;
        }

        var displayType = switch (type) {
          "tag" => "Tags",
          "artist" => "Artists",
          "group" => "Groups",
          "parody" => "Parodies",
          "character" => "Characters",
          "language" => "Languages",
          "category" => "Categories",
          _ => type.capitalizeFirst(),
        };

        tags.putIfAbsent(displayType, () => []);
        tags[displayType]!.add(name);
      }

      // 添加上传时间
      if (gallery.uploadDate > 0) {
        tags["时间".tl] = [timeToString(DateTime.fromMillisecondsSinceEpoch(gallery.uploadDate * 1000))];
      }

      // 获取缩略图
      var thumbnails = gallery.pages.map((p) => p.thumbnailUrl).toList();

      // 获取推荐漫画（使用搜索API获取相似内容）
      var recommendations = <NhentaiComicBrief>[];
      try {
        var tagQuery = gallery.tags
            .where((t) => t.type == "tag")
            .take(3)
            .map((t) => "tag:\"${t.name}\"")
            .join(" ");
        if (tagQuery.isNotEmpty) {
          var recRes = await _searchApi(tagQuery, 1, "popular");
          if (!recRes.error) {
            var recResponse = NhentaiSearchResponseV2.fromJson(recRes.data);
            recommendations = recResponse.result
                .where((item) => item.id.toString() != id)
                .take(6)
                .map(_convertGalleryItemToBrief)
                .toList();
          }
        }
      } catch (e) {
        // 忽略推荐获取失败
      }

      bool favorite = false;
      if (logged) {
        final favoriteRes = await checkFavorite(id);
        if (!favoriteRes.error && favoriteRes.data != null) {
          favorite = favoriteRes.data!;
        }
      }

      return Res(NhentaiComic(
        gallery.id.toString(),
        gallery.preferredTitle,
        gallery.subTitle ?? "",
        gallery.coverUrl,
        tags,
        favorite,
        thumbnails,
        recommendations,
        '',
      ));
    } catch (e, s) {
      LogManager.addLog(LogLevel.error, "Data Analyse", "$e\n$s");
      return Res(null, errorMessage: "Failed to Parse Data: $e");
    }
  }

  Future<Res<List<NhentaiComment>>> getComments(String id) async {
    var res = await get("$baseUrl/api/v2/galleries/$id/comments");
    if (res.error) {
      return Res.fromErrorRes(res);
    }
    try {
      // res.data 已经是 List<dynamic> 类型，直接使用
      var comments = <NhentaiComment>[];
      for (var c in res.data) {
        comments.add(NhentaiComment(
            c["poster"]["username"],
            "https://i3.nhentai.net/${c["poster"]["avatar_url"]}",
            c["body"],
            c["post_date"]));
      }
      return Res(comments);
    } catch (e, s) {
      LogManager.addLog(LogLevel.error, "Data Analyse", "$e\n$s");
      return Res(null, errorMessage: "Failed to Parse Data: $e");
    }
  }

  Future<Res<List<String>>> getImages(String id) async {
    // v2 API: 使用 galleries/{id} 端点获取漫画详情，从中提取页面图片 URL
    var res = await get("$apiUrl/galleries/$id");
    if (res.error) {
      return Res.fromErrorRes(res);
    }
    try {
      var gallery = NhentaiGalleryV2.fromJson(res.data);
      var images = gallery.pages.map((p) => p.imageUrl).toList();
      return Res(images);
    } catch (e, s) {
      LogManager.addLog(LogLevel.error, "Data Analyse", "$e\n$s");
      return Res(null, errorMessage: "Failed to Parse Data: $e");
    }
  }

  // 一页 25 个
  Future<Res<List<NhentaiComicBrief>>> getFavorites(int page) async {
    if (!logged) {
      return const Res(null, errorMessage: "login required");
    }
    var res = await get('$apiUrl/favorites?page=$page', withAuth: true);  
    if (res.error) {
      return Res.fromErrorRes(res);
    }
    try {
      final response = NhentaiSearchResponseV2.fromJson(res.data);
      final comics = response.result.map(_convertGalleryItemToBrief).toList();
      return Res(comics, subData: response.numPages);
    } catch (e, s) {
      LogManager.addLog(LogLevel.error, "Data Analyse", "$e\n$s");
      return Res(null, errorMessage: "Failed to Parse Data: $e");
    }
  }

  Future<Res<String>> getRandomFavoriteId() async {
    if (!logged) {
      return const Res(null, errorMessage: 'login required');
    }
    final res = await get('$apiUrl/favorites/random', withAuth: true);
    if (res.error) {
      return Res.fromErrorRes(res);
    }
    try {
      final response = res.data as Map<String, dynamic>;
      final idValue = response['id'];
      if (idValue != null) {
        return Res(idValue.toString());
      }
      return const Res(null, errorMessage: 'invalid random favorite response');
    } catch (e) {
      return Res(null, errorMessage: 'Failed to parse random favorite: $e');
    }
  }

  Future<Res<bool>> checkFavorite(String id) async {
    if (!logged) {
      return const Res(false);
    }
    final res = await get('$apiUrl/galleries/$id/favorite', withAuth: true);
    if (res.error) {
      return Res.fromErrorRes(res);
    }
    try {
      return Res((res.data['favorited'] ?? false) == true);
    } catch (e) {
      return Res(null, errorMessage: 'Failed to parse favorite state: $e');
    }
  }

  Future<Res<bool>> favoriteComic(String id, [String? _]) async {
    if (!logged) {
      return const Res(null, errorMessage: 'login required');
    }
    var res = await post('$apiUrl/galleries/$id/favorite', null, withAuth: true);
    if (res.error) {
      return Res.fromErrorRes(res);
    }
    try {
      return Res((res.data['favorited'] ?? true) == true);
    } catch (_) {
      return const Res(true);
    }
  }

  Future<Res<bool>> unfavoriteComic(String id, [String? _]) async {
    if (!logged) {
      return const Res(null, errorMessage: 'login required');
    }
    var res = await delete('$apiUrl/galleries/$id/favorite', withAuth: true);
    if (res.error) {
      return Res.fromErrorRes(res);
    }
    try {
      return Res((res.data['favorited'] ?? false) == false);
    } catch (_) {
      return const Res(true);
    }
  }

  Future<Res<List<NhentaiComicBrief>>> getCategoryComics(
      String path, int page, NhentaiSort sort) async {
    // 从path中提取标签类型和名称
    // path格式如: /tag/abc/, /artist/xyz/, /group/123/
    var parts = path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length < 2) {
      return Res(null, errorMessage: "Invalid path");
    }

    var type = parts[0]; // tag, artist, group, etc.
    var name = parts[1];

    var query = "$type:\"$name\"";
    var sortStr = switch (sort) {
      NhentaiSort.recent => "date",
      NhentaiSort.popularToday => "popular-today",
      NhentaiSort.popularWeek => "popular-week",
      NhentaiSort.popularMonth => "popular-month",
      NhentaiSort.popularAll => "popular",
    };

    var res = await _searchApi(query, page, sortStr);
    if (res.error) {
      return Res.fromErrorRes(res);
    }

    try {
      var response = NhentaiSearchResponseV2.fromJson(res.data);
      var comics = response.result.map(_convertGalleryItemToBrief).toList();

      Future.microtask(() {
        try {
          StateController.find<PreSearchController>().update();
        } catch (e) {
          //
        }
      });

      return Res(comics, subData: response.numPages);
    } catch (e, s) {
      LogManager.addLog(LogLevel.error, "Data Analyse", "$e\n$s");
      return Res(null, errorMessage: "Failed to Parse Data: $e");
    }
  }
}

enum NhentaiSort {
  recent(""),
  popularToday("&sort=popular-today"),
  popularWeek("&sort=popular-week"),
  popularMonth("&sort=popular-month"),
  popularAll("&sort=popular");

  final String value;

  const NhentaiSort(this.value);

  static NhentaiSort fromValue(String value) {
    switch (value) {
      case "":
        return NhentaiSort.recent;
      case "&sort=popular-today":
        return NhentaiSort.popularToday;
      case "&sort=popular-week":
        return NhentaiSort.popularWeek;
      case "&sort=popular-month":
        return NhentaiSort.popularMonth;
      case "&sort=popular":
        return NhentaiSort.popularAll;
      default:
        return NhentaiSort.recent;
    }
  }
}
