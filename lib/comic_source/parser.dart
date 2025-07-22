part of comic_source;

class ComicSourceParseException implements Exception {
  final String message;

  ComicSourceParseException(this.message);

  @override
  String toString() {
    return message;
  }
}

class ComicSourceParser {
  /// comic source key
  String? _key;

  String? _name;

  Future<ComicSource> createAndParse(String js, String fileName) async {
    if (!fileName.endsWith("js")) {
      fileName = "$fileName.js";
    }
    var file = File("${App.dataPath}/comic_source/$fileName");
    if (file.existsSync()) {
      int i = 0;
      while (file.existsSync()) {
        file = File("${App.dataPath}/comic_source/$fileName($i).js");
        i++;
      }
    }
    await file.writeAsString(js);
    try {
      return await parse(js, file.path);
    } catch (e) {
      await file.delete();
      rethrow;
    }
  }

  Future<ComicSource> parse(String js, String filePath) async {
    js = js.replaceAll("\r\n", "\n");
    var line1 = js
        .split('\n')
        .firstWhereOrNull((element) => element.removeAllBlank.isNotEmpty);
    if (line1 == null ||
        !line1.startsWith("class ") ||
        !line1.contains("extends ComicSource")) {
      throw ComicSourceParseException("Invalid Content");
    }
    var className = line1.split("class")[1].split("extends ComicSource").first;
    className = className.trim();
    await JsEngine().runCode("""
      (() => {
        $js
        this['temp'] = new $className()
      }).call()
    """);
    _name = (await JsEngine().runCode("this['temp'].name")).stringResult ??
        (throw ComicSourceParseException('name is required'));
    var key = (await JsEngine().runCode("this['temp'].key")).stringResult ??
        (throw ComicSourceParseException('key is required'));
    var version =
        (await JsEngine().runCode("this['temp'].version")).stringResult ??
            (throw ComicSourceParseException('version is required'));
    var minAppVersion =
        (await JsEngine().runCode("this['temp'].minAppVersion")).stringResult;
    var url = (await JsEngine().runCode("this['temp'].url")).stringResult;
    var matchBriefIdRegex =
        (await JsEngine().runCode("this['temp'].comic.matchBriefIdRegex"))
            .stringResult;
    if (minAppVersion != null) {
      if (compareSemVer(minAppVersion, appVersion.split('-').first)) {
        throw ComicSourceParseException(
            "minAppVersion $minAppVersion is required");
      }
    }
    for (var source in ComicSource.sources) {
      if (source.key == key) {
        throw ComicSourceParseException("key($key) already exists");
      }
    }
    _key = key;
    _checkKeyValidation();

    await JsEngine().runCode("""
      ComicSource.sources.$_key = this['temp'];
    """);

    final account = await _loadAccountConfig();
    final explorePageData = await _loadExploreData();
    final categoryPageData = await _loadCategoryData();
    final categoryComicsData = await _loadCategoryComicsData();
    final searchData = await _loadSearchData();
    final loadComicFunc = _parseLoadComicFunc();
    final loadComicPagesFunc = _parseLoadComicPagesFunc();
    final getImageLoadingConfigFunc = _parseImageLoadingConfigFunc();
    final getThumbnailLoadingConfigFunc = _parseThumbnailLoadingConfigFunc();
    final favoriteData = await _loadFavoriteData();
    final commentsLoader = _parseCommentsLoader();
    final sendCommentFunc = _parseSendCommentFunc();

    var source = ComicSource(
        _name!,
        key,
        account,
        categoryPageData,
        categoryComicsData,
        favoriteData,
        explorePageData,
        searchData,
        [],
        loadComicFunc,
        loadComicPagesFunc,
        getImageLoadingConfigFunc as Map<String, dynamic> Function(String imageKey, String comicId, String epId)?,
        getThumbnailLoadingConfigFunc as Map<String, dynamic> Function(String imageKey)?,
        matchBriefIdRegex,
        filePath,
        url ?? "",
        version ?? "1.0.0",
        commentsLoader as CommentsLoader?,
        sendCommentFunc as SendCommentFunc?);

    await source.loadData();

    Future.delayed(const Duration(milliseconds: 50), () {
      JsEngine().runCode("ComicSource.sources.$_key.init()").then((_) {});
    });

    return source;
  }

  _checkKeyValidation() {
    // 仅允许数字和字母以及下划线
    if (!_key!.contains(RegExp(r"^[a-zA-Z0-9_]+$"))) {
      throw ComicSourceParseException("key $_key is invalid");
    }
  }

  Future<bool> _checkExists(String index) async {
    return (await JsEngine()
        .runCode("ComicSource.sources.$_key.$index !== null "
        "&& ComicSource.sources.$_key.$index !== undefined"))
        .stringResult ==
        'true';
  }

  Future<dynamic> _getValue(String index) async {
    return (await JsEngine().runCode("ComicSource.sources.$_key.$index"))
        .rawResult;
  }

  Future<AccountConfig?> _loadAccountConfig() async {
    if (!await _checkExists("account")) {
      return null;
    }

    Future<Res<bool>> login(account, pwd) async {
      try {
        await JsEngine().runCode("""
          ComicSource.sources.$_key.account.login(${jsonEncode(account)}, 
          ${jsonEncode(pwd)})
        """);
        var source =
        ComicSource.sources.firstWhere((element) => element.key == _key);
        source.data["account"] = <String>[account, pwd];
        source.saveData();
        return const Res(true);
      } catch (e, s) {
        log("$e\n$s", "Network", LogLevel.error);
        return Res.error(e.toString());
      }
    }

    void logout() async {
      await JsEngine().runCode("ComicSource.sources.$_key.account.logout()");
    }

    return AccountConfig(login, await _getValue("account.login.website"),
        await _getValue("account.registerWebsite"), logout);
  }

  Future<List<ExplorePageData>> _loadExploreData() async {
    if (!await _checkExists("explore")) {
      return const [];
    }
    var length =
        (await JsEngine().runCode("ComicSource.sources.$_key.explore.length"))
            .stringResult;
    var pages = <ExplorePageData>[];
    for (int i = 0; i < int.parse(length); i++) {
      final String title = await _getValue("explore[$i].title");
      final String type = await _getValue("explore[$i].type");
      Future<Res<List<ExplorePagePart>>> Function()? loadMultiPart;
      Future<Res<List<BaseComic>>> Function(int page)? loadPage;
      if (type == "singlePageWithMultiPart") {
        loadMultiPart = () async {
          try {
            var res = (await JsEngine()
                .runCode("ComicSource.sources.$_key.explore[$i].load()"))
                .rawResult;
            return Res(List.from(res.keys
                .map((e) => ExplorePagePart(
                e,
                (res[e] as List)
                    .map<CustomComic>((e) => CustomComic.fromJson(e, _key!))
                    .toList(),
                null))
                .toList()));
          } catch (e, s) {
            log("$e\n$s", "Data Analysis", LogLevel.error);
            return Res.error(e.toString());
          }
        };
      } else if (type == "multiPageComicList") {
        loadPage = (int page) async {
          try {
            var res = await JsEngine().runCode(
                "ComicSource.sources.$_key.explore[$i].load(${jsonEncode(page)})");
            return Res(
                List.generate(
                    (res.rawResult["comics"] as List).length,
                        (index) => CustomComic.fromJson(
                        res.rawResult["comics"][index], _key!)),
                subData: res.rawResult["maxPage"]);
          } catch (e, s) {
            log("$e\n$s", "Network", LogLevel.error);
            return Res.error(e.toString());
          }
        };
      }
      pages.add(ExplorePageData(
          title,
          switch (type) {
            "singlePageWithMultiPart" =>
            ExplorePageType.singlePageWithMultiPart,
            "multiPageComicList" => ExplorePageType.multiPageComicList,
            _ =>
            throw ComicSourceParseException("Unknown explore page type $type")
          },
          loadPage,
          loadMultiPart));
    }
    return pages;
  }

  Future<CategoryData?> _loadCategoryData() async {
    var doc = _getValue("category");

    if ((await doc)?["title"] == null) {
      return null;
    }

    final String title = (doc as Map<String, dynamic>)["title"] as String;
    final bool? enableRankingPage =
    (doc as Map<String, dynamic>)["enableRankingPage"] as bool?;

    var categoryParts = <BaseCategoryPart>[];

    for (var c in (doc as Map<String, dynamic>)["parts"] as List) {
      final String name = c["name"];
      final String type = c["type"];
      final List<String> tags = List.from(c["categories"]);
      final String itemType = c["itemType"];
      final List<String>? categoryParams =
      c["categoryParams"] == null ? null : List.from(c["categoryParams"]);
      if (type == "fixed") {
        categoryParts
            .add(FixedCategoryPart(name, tags, itemType, categoryParams));
      } else if (type == "random") {
        categoryParts.add(
            RandomCategoryPart(name, tags, c["randomNumber"] ?? 1, itemType));
      }
    }

    return CategoryData(
        title: title,
        categories: categoryParts,
        enableRankingPage: enableRankingPage ?? false,
        key: title);
  }

  Future<CategoryComicsData?> _loadCategoryComicsData() async {
    if (!(await _checkExists("categoryComics"))) return null;
    var options = <CategoryComicsOptions>[];
    for (var element in (await _getValue("categoryComics.optionList") as List)) {
      LinkedHashMap<String, String> map = LinkedHashMap<String, String>();
      for (var option in element["options"]) {
        if (option.isEmpty || !option.contains("-")) {
          continue;
        }
        var split = option.split("-");
        var key = split.removeAt(0);
        var value = split.join("-");
        map[key] = value;
      }
      options.add(CategoryComicsOptions(
          map,
          List.from(element["notShowWhen"] ?? []),
          element["showWhen"] == null ? null : List.from(element["showWhen"])));
    }
    RankingData? rankingData;
    if (await _checkExists("categoryComics.ranking")) {
      var options = <String, String>{};
      for (var option in (await _getValue("categoryComics.ranking.options") as List)) {
        if (option.isEmpty || !option.contains("-")) {
          continue;
        }
        var split = option.split("-");
        var key = split.removeAt(0);
        var value = split.join("-");
        options[key] = value;
      }
      rankingData = RankingData(options, (option, page) async {
        try {
          var res = await JsEngine().runCode("""
            ComicSource.sources.$_key.categoryComics.ranking.load(
              ${jsonEncode(option)}, ${jsonEncode(page)})
          """);
          return Res(
              List.generate(
                  res.rawResult["comics"].length,
                      (index) => CustomComic.fromJson(
                      res.rawResult["comics"][index], _key!)),
              subData: res.rawResult["maxPage"]);
        } catch (e, s) {
          log("$e\n$s", "Network", LogLevel.error);
          return Res.error(e.toString());
        }
      });
    }
    return CategoryComicsData(options, (category, param, options, page) async {
      try {
        var res = await JsEngine().runCode("""
          ComicSource.sources.$_key.categoryComics.load(
            ${jsonEncode(category)}, 
            ${jsonEncode(param)}, 
            ${jsonEncode(options)}, 
            ${jsonEncode(page)}
          )
        """);
        return Res(
            List.generate(
                res.rawResult["comics"].length,
                    (index) => CustomComic.fromJson(
                    res.rawResult["comics"][index], _key!)),
            subData: res.rawResult["maxPage"]);
      } catch (e, s) {
        log("$e\n$s", "Network", LogLevel.error);
        return Res.error(e.toString());
      }
    }, rankingData: rankingData);
  }

  Future<SearchPageData?> _loadSearchData() async {
    if (!(await _checkExists("search"))) return null;
    var options = <SearchOptions>[];
    for (var element in (await _getValue("search.optionList") ?? []) as List) {
      LinkedHashMap<String, String> map = LinkedHashMap<String, String>();
      for (var option in element["options"]) {
        if (option.isEmpty || !option.contains("-")) {
          continue;
        }
        var split = option.split("-");
        var key = split.removeAt(0);
        var value = split.join("-");
        map[key] = value;
      }
      options.add(SearchOptions(map, element["label"]));
    }
    return SearchPageData(options, (keyword, page, searchOption) async {
      try {
        var res = await JsEngine().runCode("""
          ComicSource.sources.$_key.search.load(
            ${jsonEncode(keyword)}, ${jsonEncode(searchOption)}, ${jsonEncode(page)})
        """);
        return Res(
            List.generate(
                res.rawResult["comics"].length,
                    (index) => CustomComic.fromJson(
                    res.rawResult["comics"][index], _key!)),
            subData: res.rawResult["maxPage"]);
      } catch (e, s) {
        log("$e\n$s", "Network", LogLevel.error);
        return Res.error(e.toString());
      }
    });
  }

  LoadComicFunc? _parseLoadComicFunc() {
    return (id) async {
      try {
        var res = await JsEngine().runCode("""
          ComicSource.sources.$_key.comic.loadInfo(${jsonEncode(id)})
        """);
        var tags = <String, List<String>>{};
        (res.rawResult["tags"] as Map<String, dynamic>?)
            ?.forEach((key, value) => tags[key] = List.from(value ?? const []));
        return Res(ComicInfoData(
          res.rawResult["title"],
          res.rawResult["subTitle"],
          res.rawResult["cover"],
          res.rawResult["description"],
          tags,
          res.rawResult["chapters"] == null
              ? null
              : Map.from(res.rawResult["chapters"]),
          ListOrNull.from(res.rawResult["thumbnails"]),
          // TODO: implement thumbnailLoader
          null,
          res.rawResult["thumbnailMaxPage"] ?? 1,
          (res.rawResult["recommend"] as List?)
              ?.map((e) => CustomComic.fromJson(e, _key!))
              .toList(),
          _key!,
          id,
          isFavorite: res.rawResult["isFavorite"],
          subId: res.rawResult["subId"],
        ));
      } catch (e, s) {
        log("$e\n$s", "Network", LogLevel.error);
        return Res.error(e.toString());
      }
    };
  }

  LoadComicPagesFunc? _parseLoadComicPagesFunc() {
    return (id, ep) async {
      try {
        var res = await JsEngine().runCode("""
          ComicSource.sources.$_key.comic.loadEp(${jsonEncode(id)}, ${jsonEncode(ep)})
        """);
        return Res(List.from(res.rawResult["images"]));
      } catch (e, s) {
        log("$e\n$s", "Network", LogLevel.error);
        return Res.error(e.toString());
      }
    };
  }

  Future<FavoriteData?> _loadFavoriteData() async {
    if (!(await _checkExists("favorites"))) return null;

    final bool multiFolder = _getValue("favorites.multiFolder") as bool;

    Future<Res<T>> retryZone<T>(Future<Res<T>> Function() func) async {
      if (!ComicSource.find(_key!)!.isLogin) {
        return const Res.error("Not login");
      }
      var res = await func();
      if (res.error && res.errorMessage!.contains("Login expired")) {
        var reLoginRes = await ComicSource.find(_key!)!.reLogin();
        if (!reLoginRes) {
          return const Res.error("Login expired and re-login failed");
        } else {
          return func();
        }
      }
      return res;
    }

    Future<Res<bool>> addOrDelFavFunc(comicId, folderId, isAdding) async {
      func() async {
        try {
          await JsEngine().runCode("""
            ComicSource.sources.$_key.favorites.addOrDelFavorite(
              ${jsonEncode(comicId)}, ${jsonEncode(folderId)}, ${jsonEncode(isAdding)})
          """);
          return const Res(true);
        } catch (e, s) {
          log("$e\n$s", "Network", LogLevel.error);
          return Res<bool>.error(e.toString());
        }
      }

      return retryZone(func);
    }

    Future<Res<List<BaseComic>>> loadComic(int page, [String? folder]) async {
      Future<Res<List<BaseComic>>> func() async {
        try {
          var res = await JsEngine().runCode("""
            ComicSource.sources.$_key.favorites.loadComics(
              ${jsonEncode(page)}, ${jsonEncode(folder)})
          """);
          return Res(
              List.generate(res.rawResult["comics"].length,
                      (index) => CustomComic.fromJson(res.rawResult["comics"][index], _key!)),
              subData: res.rawResult["maxPage"]);
        } catch (e, s) {
          log("$e\n$s", "Network", LogLevel.error);
          return Res.error(e.toString());
        }
      }

      return retryZone(func);
    }

    Future<Res<Map<String, String>>> Function([String? comicId])? loadFolders;

    Future<Res<bool>> Function(String name)? addFolder;

    Future<Res<bool>> Function(String key)? deleteFolder;

    if (multiFolder) {
      loadFolders = ([String? comicId]) async {
        Future<Res<Map<String, String>>> func() async {
          try {
            var res = await JsEngine().runCode("""
            ComicSource.sources.$_key.favorites.loadFolders(${jsonEncode(comicId)})
          """);
            List<String>? subData;
            if (res.rawResult["favorited"] != null) {
              subData = List.from(res.rawResult["favorited"]);
            }
            return Res(Map.from(res.rawResult["folders"]), subData: subData);
          } catch (e, s) {
            log("$e\n$s", "Network", LogLevel.error);
            return Res.error(e.toString());
          }
        }

        return retryZone(func);
      };
      addFolder = (name) async {
        try {
          await JsEngine().runCode("""
            ComicSource.sources.$_key.favorites.addFolder(${jsonEncode(name)})
          """);
          return const Res(true);
        } catch (e, s) {
          log("$e\n$s", "Network", LogLevel.error);
          return Res.error(e.toString());
        }
      };
      deleteFolder = (key) async {
        try {
          await JsEngine().runCode("""
            ComicSource.sources.$_key.favorites.deleteFolder(${jsonEncode(key)})
          """);
          return const Res(true);
        } catch (e, s) {
          log("$e\n$s", "Network", LogLevel.error);
          return Res.error(e.toString());
        }
      };
    }

    return FavoriteData(
      key: _key!,
      title: _name!,
      multiFolder: multiFolder,
      loadComic: loadComic,
      loadFolders: loadFolders,
      addFolder: addFolder,
      deleteFolder: deleteFolder,
      addOrDelFavorite: addOrDelFavFunc,
    );
  }

  Future<Future<Res> Function(dynamic id, dynamic subId, dynamic page, dynamic replyTo)?> _parseCommentsLoader() async {
    if (!(await _checkExists("comic.loadComments"))) return null;
    return (id, subId, page, replyTo) async {
      try {
        var res = (await JsEngine().runCode("""
          ComicSource.sources.$_key.comic.loadComments(
            ${jsonEncode(id)}, ${jsonEncode(subId)}, ${jsonEncode(page)}, ${jsonEncode(replyTo)})
        """)).rawResult;
        return Res(
            (res["comments"] as List)
                .map((e) => Comment(e["userName"], e["avatar"], e["content"],
                e["time"], e["replyCount"], e["id"].toString()))
                .toList(),
            subData: res["maxPage"]);
      } catch (e, s) {
        log("$e\n$s", "Network", LogLevel.error);
        return Res.error(e.toString());
      }
    };
  }

  Future<Future<Res> Function(dynamic id, dynamic subId, dynamic content, dynamic replyTo)?> _parseSendCommentFunc() async {
    if (!(await _checkExists("comic.sendComment"))) return null;
    return (id, subId, content, replyTo) async {
      Future<Res<bool>> func() async {
        try {
          (await JsEngine().runCode("""
            ComicSource.sources.$_key.comic.sendComment(
              ${jsonEncode(id)}, ${jsonEncode(subId)}, ${jsonEncode(content)}, ${jsonEncode(replyTo)})
          """));
          return const Res(true);
        } catch (e, s) {
          log("$e\n$s", "Network", LogLevel.error);
          return Res.error(e.toString());
        }
      }

      var res = await func();
      if (res.error && res.errorMessage!.contains("Login expired")) {
        var reLoginRes = await ComicSource.find(_key!)!.reLogin();
        if (!reLoginRes) {
          return const Res.error("Login expired and re-login failed");
        } else {
          return func();
        }
      }
      return res;
    };
  }

  Future<Future<Map<String, dynamic>> Function(dynamic imageKey, dynamic comicId, dynamic ep)?> _parseImageLoadingConfigFunc() async {
    if (!(await _checkExists("comic.onImageLoad"))) {
      return null;
    }
    return (imageKey, comicId, ep) async {
      return (await JsEngine().runCode("""
          ComicSource.sources.$_key.comic.onImageLoad(
            ${jsonEncode(imageKey)}, ${jsonEncode(comicId)}, ${jsonEncode(ep)})
        """)).rawResult as Map<String, dynamic>;
    };
  }

  Future<Future<Map<String, dynamic>> Function(dynamic imageKey)?> _parseThumbnailLoadingConfigFunc() async {
    if (!(await _checkExists("comic.onThumbnailLoad"))) {
      return null;
    }
    return (imageKey) async {
      var res = (await JsEngine().runCode("""
          ComicSource.sources.$_key.comic.onThumbnailLoad(${jsonEncode(imageKey)})
        """)).rawResult;
      if (res is! Map) {
        Log.error("Network", "function onThumbnailLoad return invalid data");
        throw "function onThumbnailLoad return invalid data";
      }
      return res as Map<String, dynamic>;
    };
  }
}
