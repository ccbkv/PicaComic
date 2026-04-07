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

  Future<ComicSource> createAndParse(String js, String fileName) async{
    if(!fileName.endsWith("js")){
      fileName = "$fileName.js";
    }
    var file = File("${App.dataPath}/comic_source/$fileName");
    if(file.existsSync()){
      int i = 0;
      while(file.existsSync()){
        file = File("${App.dataPath}/comic_source/$fileName($i).js");
        i++;
      }
    }
    await file.writeAsString(js);
    try{
      return await parse(js, file.path);
    } catch (e) {
      await file.delete();
      rethrow;
    }
  }

  Future<ComicSource> parse(String js, String filePath) async {
    js = js.replaceAll("\r\n", "\n");
    var line1 = js.split('\n')
        .firstWhereOrNull((element) => element.trim().startsWith("class "));
    if(line1 == null || !line1.startsWith("class ") || !line1.contains("extends ComicSource")){
      throw ComicSourceParseException("Invalid Content");
    }
    var className = line1.split("class")[1].split("extends ComicSource").first;
    className = className.trim();
    JsEngine().runCode("""
      (() => {
        $js
        this['temp'] = new $className()
      }).call()
    """);
    _name = JsEngine().runCode("this['temp'].name")
        ?? (throw ComicSourceParseException('name is required'));
    var key = JsEngine().runCode("this['temp'].key")
        ?? (throw ComicSourceParseException('key is required'));
    var version = JsEngine().runCode("this['temp'].version")
        ?? (throw ComicSourceParseException('version is required'));
    var minAppVersion = JsEngine().runCode("this['temp'].minAppVersion");
    var url = JsEngine().runCode("this['temp'].url");
    var matchBriefIdRegex = JsEngine().runCode("this['temp'].comic.matchBriefIdRegex");
    // Check for enableTagsTranslate at root level or in comic config (Venera compatibility)
    var enableTagsTranslate = JsEngine().runCode("this['temp'].enableTagsTranslate") ?? 
                              JsEngine().runCode("this['temp'].comic?.enableTagsTranslate") ?? 
                              false;
    if(minAppVersion != null){
      if(compareSemVer(minAppVersion, appVersion.split('-').first)){
        throw ComicSourceParseException("minAppVersion $minAppVersion is required");
      }
    }
    // Remove existing source with same key to allow JS plugins to override built-in sources
    ComicSource.sources.removeWhere((source) => source.key == key);
    _key = key;
    _checkKeyValidation();

    JsEngine().runCode("""
      ComicSource.sources.$_key = this['temp'];
    """);

    final account = _loadAccountConfig();
    final explorePageData = _loadExploreData();
    final categoryPageData = _loadCategoryData();
    final categoryComicsData =
    _loadCategoryComicsData();
    final searchData = _loadSearchData();
    final loadComicFunc = _parseLoadComicFunc();
    final loadComicPagesFunc = _parseLoadComicPagesFunc();
    final getImageLoadingConfigFunc = _parseImageLoadingConfigFunc();
    final getThumbnailLoadingConfigFunc = _parseThumbnailLoadingConfigFunc();
    final favoriteData = _loadFavoriteData();
    final commentsLoader = _parseCommentsLoader();
    final sendCommentFunc = _parseSendCommentFunc();
    final chapterCommentsLoader = _parseChapterCommentsLoader();
    final sendChapterCommentFunc = _parseSendChapterCommentFunc();
    final veneraSettings = _parseVeneraSettings();

    var source = ComicSource.named(
        name: _name!,
        key: key,
        account: account,
        categoryData: categoryPageData,
        categoryComicsData: categoryComicsData,
        favoriteData: favoriteData,
        explorePages: explorePageData,
        searchPageData: searchData,
        settings: [],
        loadComicInfo: loadComicFunc,
        loadComicPages: loadComicPagesFunc,
        getImageLoadingConfig: getImageLoadingConfigFunc,
        getThumbnailLoadingConfig: getThumbnailLoadingConfigFunc,
        matchBriefIdReg: matchBriefIdRegex,
        filePath: filePath,
        url: url ?? "",
        version: version ?? "1.0.0",
        commentsLoader: commentsLoader,
        sendCommentFunc: sendCommentFunc,
        chapterCommentsLoader: chapterCommentsLoader,
        sendChapterCommentFunc: sendChapterCommentFunc,
        enableTagsTranslate: enableTagsTranslate,
        veneraSettings: veneraSettings);

    await source.loadData();

    Future.delayed(const Duration(milliseconds: 50), () {
      // Initialize apiDomains for JM source if not defined (Venera compatibility)
      JsEngine().runCode("""
        (function() {
          var temp = ComicSource.sources.$_key;
          if (temp && typeof temp.constructor !== 'undefined' && 
              typeof temp.constructor.apiDomains === 'undefined' &&
              typeof temp.constructor.fallbackServers !== 'undefined') {
            temp.constructor.apiDomains = temp.constructor.fallbackServers;
          }
        })()
      """);
      JsEngine().runCode("ComicSource.sources.$_key.init()");
    });

    return source;
  }

  _checkKeyValidation() {
    // 仅允许数字和字母以及下划线
    if (!_key!.contains(RegExp(r"^[a-zA-Z0-9_]+$"))) {
      throw ComicSourceParseException("key $_key is invalid");
    }
  }

  bool _checkExists(String index){
    return JsEngine().runCode("ComicSource.sources.$_key.$index !== null "
        "&& ComicSource.sources.$_key.$index !== undefined");
  }

  dynamic _getValue(String index) {
    return JsEngine().runCode("ComicSource.sources.$_key.$index");
  }

  AccountConfig? _loadAccountConfig() {
    if (!_checkExists("account")) {
      return null;
    }

    Future<Res<bool>> login(account, pwd) async {
      try {
        await JsEngine().runCode("""
          ComicSource.sources.$_key.account.login(${jsonEncode(account)}, 
          ${jsonEncode(pwd)})
        """);
        var source = ComicSource.sources
            .firstWhere((element) => element.key == _key);
        source.data["account"] = <String>[account, pwd];
        source.saveData();
        return const Res(true);
      } catch (e, s) {
        log("$e\n$s", "Network", LogLevel.error);
        return Res.error(e.toString());
      }
    }

    void logout(){
      JsEngine().runCode("ComicSource.sources.$_key.account.logout()");
    }

    return AccountConfig(
      login,
      _checkExists("account.login") ? _getValue("account.login.website") : null,
      _getValue("account.registerWebsite"),
      logout
    );
  }

  List<ExplorePageData> _loadExploreData() {
    if (!_checkExists("explore")) {
      return const [];
    }
    var length = JsEngine().runCode("ComicSource.sources.$_key.explore.length");
    var pages = <ExplorePageData>[];
    for (int i=0; i<length; i++) {
      final String title = _getValue("explore[$i].title");
      final String type = _getValue("explore[$i].type");
      Future<Res<List<ExplorePagePart>>> Function()? loadMultiPart;
      Future<Res<List<BaseComic>>> Function(int page)? loadPage;
      Future<Res<List<Object>>> Function(int index)? loadMixed;
      if (type == "singlePageWithMultiPart") {
        loadMultiPart = () async {
          try {
            var res = await JsEngine()
                .runCode("ComicSource.sources.$_key.explore[$i].load()");
            if (res == null || res is! Map) {
              return Res.error("Invalid response from explore load");
            }
            var keys = res.keys.toList();
            return Res(List.from(keys.map((e) {
              var comics = res[e];
              if (comics == null || comics is! List) {
                return ExplorePagePart(e, [], null);
              }
              return ExplorePagePart(
                e,
                comics.map<CustomComic>((e) => CustomComic.fromJson(e, _key!)).toList(),
                null);
            })));
          } catch (e, s) {
            log("$e\n$s", "Data Analysis", LogLevel.error);
            return Res.error(e.toString());
          }
        };
      } else if (type == "multiPageComicList") {
        loadPage = (int page) async {
          try {
            var res = await JsEngine()
                .runCode("ComicSource.sources.$_key.explore[$i].load(${jsonEncode(page)})");
            return Res(
                List.generate(res["comics"].length,
                        (index) => CustomComic.fromJson(res["comics"][index], _key!)),
                subData: res["maxPage"]);
          } catch (e, s) {
            log("$e\n$s", "Network", LogLevel.error);
            return Res.error(e.toString());
          }
        };
      } else if (type == "multiPartPage") {
        loadMultiPart = () async {
          try {
            var res = await JsEngine()
                .runCode("ComicSource.sources.$_key.explore[$i].load()");
            if (res == null || res is! List) {
              return Res.error("Invalid response from explore load");
            }
            return Res(List.from(res.map((e) {
              var comics = e['comics'];
              if (comics == null || comics is! List) {
                return ExplorePagePart(e['title'] ?? "", [], null);
              }
              return ExplorePagePart(
                e['title'] ?? "",
                comics.map<CustomComic>((e) => CustomComic.fromJson(e, _key!)).toList(),
                null);
            })));
          } catch (e, s) {
            log("$e\n$s", "Data Analysis", LogLevel.error);
            return Res.error(e.toString());
          }
        };
      } else if (type == "mixed") {
        loadMixed = (index) async {
          try {
            var res = await JsEngine()
                .runCode("ComicSource.sources.$_key.explore[$i].load(${jsonEncode(index)})");
            if (res == null || res is! Map) {
              return Res.error("Invalid response from explore load");
            }
            var list = <Object>[];
            var data = res['data'];
            if (data == null || data is! List) {
              return Res.error("Invalid data from explore load");
            }
            for (var item in data) {
              if (item is List) {
                list.add(item.map<CustomComic>((e) => CustomComic.fromJson(e, _key!)).toList());
              } else if (item is Map) {
                var comics = item['comics'];
                if (comics == null || comics is! List) {
                  list.add(ExplorePagePart(item['title'] ?? "", [], null));
                } else {
                  list.add(ExplorePagePart(
                    item['title'] ?? "",
                    comics.map<CustomComic>((e) => CustomComic.fromJson(e, _key!)).toList(),
                    null));
                }
              }
            }
            return Res(list, subData: res['maxPage']);
          } catch (e, s) {
            log("$e\n$s", "Network", LogLevel.error);
            return Res.error(e.toString());
          }
        };
      }
      pages.add(ExplorePageData.named(
          title: title,
          type: switch (type) {
            "singlePageWithMultiPart" =>
              ExplorePageType.singlePageWithMultiPart,
            "multiPageComicList" => ExplorePageType.multiPageComicList,
            "multiPartPage" => ExplorePageType.singlePageWithMultiPart,
            "mixed" => ExplorePageType.mixed,
            _ =>
              throw ComicSourceParseException("Unknown explore page type $type")
          },
          loadPage: loadPage,
          loadMultiPart: loadMultiPart,
          loadMixed: loadMixed));
    }
    return pages;
  }

  CategoryData? _loadCategoryData() {
    var doc = _getValue("category");

    if (doc?["title"] == null) {
      return null;
    }

    final String title = doc["title"];
    final bool? enableRankingPage = doc["enableRankingPage"];

    var categoryParts = <BaseCategoryPart>[];

    var parts = doc["parts"];
    if (parts == null || parts is! List) {
      return null;
    }

    for (var c in parts) {
      if (c == null || c is! Map) continue;
      final String name = c["name"] ?? "";
      final String type = c["type"] ?? "fixed";
      var categories = c["categories"];
      if (categories == null || categories is! List) continue;
      
      // Support venera format: categories is List<Map> with 'label' and 'target'
      if (categories.isNotEmpty && categories[0] is Map) {
        // Venera format: create CategoryItems with targets
        var categoryItems = categories.map<CategoryItem>((e) {
          var label = e['label']?.toString() ?? "";
          var target = e['target'] != null 
              ? PageJumpTarget.parse(_key!, e['target'])
              : null;
          return CategoryItem(label, target);
        }).toList();
        
        if (type == "fixed") {
          categoryParts.add(FixedCategoryPart.fromItems(
              name, categoryItems, "category"));
        }
      } else {
        // Picacomic format: categories is List<String>
        List<String> tags = List<String>.from(categories);
        final String itemType = c["itemType"] ?? "category";
        final List<String>? categoryParams =
            c["categoryParams"] == null ? null : List<String>.from(c["categoryParams"]);
        if (type == "fixed") {
          categoryParts
              .add(FixedCategoryPart(name, tags, itemType, categoryParams));
        } else if (type == "random") {
          categoryParts.add(
              RandomCategoryPart(name, tags, c["randomNumber"] ?? 1, itemType));
        }
      }
    }

    return CategoryData(
        title: title,
        categories: categoryParts,
        enableRankingPage: enableRankingPage ?? false,
        key: doc["key"] ?? title);
  }

  CategoryComicsData? _loadCategoryComicsData() {
    if (!_checkExists("categoryComics")) return null;
    var options = <CategoryComicsOptions>[];
    var optionList = _getValue("categoryComics.optionList");
    if (optionList != null && optionList is List) {
      for (var element in optionList) {
        if (element == null || element is! Map) continue;
        LinkedHashMap<String, String> map = LinkedHashMap<String, String>();
        var elementOptions = element["options"];
        if (elementOptions != null && elementOptions is List) {
          for (var option in elementOptions) {
            if (option is! String || option.isEmpty || !option.contains("-")) {
              continue;
            }
            var split = option.split("-");
            var key = split.removeAt(0);
            var value = split.join("-");
            map[key] = value;
          }
        }
        options.add(
            CategoryComicsOptions(
              map,
              List<String>.from(element["notShowWhen"] ?? []),
              element["showWhen"] == null ? null : List<String>.from(element["showWhen"])
            ));
      }
    }
    RankingData? rankingData;
    if(_checkExists("categoryComics.ranking")){
      var options = <String, String>{};
      for(var option in _getValue("categoryComics.ranking.options")){
        if(option.isEmpty || !option.contains("-")){
          continue;
        }
        var split = option.split("-");
        var key = split.removeAt(0);
        var value = split.join("-");
        options[key] = value;
      }
      rankingData = RankingData(options, (option, page) async{
        try {
          var res = await JsEngine().runCode("""
            ComicSource.sources.$_key.categoryComics.ranking.load(
              ${jsonEncode(option)}, ${jsonEncode(page)})
          """);
          return Res(
              List.generate(res["comics"].length,
                      (index) => CustomComic.fromJson(res["comics"][index], _key!)),
              subData: res["maxPage"]);
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
            List.generate(res["comics"].length,
                (index) => CustomComic.fromJson(res["comics"][index], _key!)),
            subData: res["maxPage"]);
      } catch (e, s) {
        log("$e\n$s", "Network", LogLevel.error);
        return Res.error(e.toString());
      }
    }, rankingData: rankingData);
  }

  SearchPageData? _loadSearchData() {
    if (!_checkExists("search")) return null;
    var options = <SearchOptions>[];
    var optionList = _getValue("search.optionList");
    if (optionList != null && optionList is List) {
      for (var element in optionList) {
        if (element == null || element is! Map) continue;
        LinkedHashMap<String, String> map = LinkedHashMap<String, String>();
        var elementOptions = element["options"];
        if (elementOptions != null && elementOptions is List) {
          for (var option in elementOptions) {
            if (option is! String || option.isEmpty || !option.contains("-")) {
              continue;
            }
            var split = option.split("-");
            var key = split.removeAt(0);
            var value = split.join("-");
            map[key] = value;
          }
        }
        options.add(SearchOptions(map, element["label"]));
      }
    }
    return SearchPageData(options, (keyword, page, searchOption) async {
      try {
        // Check if search.load exists, otherwise use search.loadNext (Venera compatibility)
        var hasLoad = _checkExists("search.load");
        String jsCode;
        if (hasLoad) {
          jsCode = """
            ComicSource.sources.$_key.search.load(
              ${jsonEncode(keyword)}, ${jsonEncode(searchOption)}, ${jsonEncode(page)})
          """;
        } else {
          // Venera uses loadNext with next token instead of page number
          jsCode = """
            ComicSource.sources.$_key.search.loadNext(
              ${jsonEncode(keyword)}, ${jsonEncode(searchOption)}, ${jsonEncode(page == 1 ? null : page.toString())})
          """;
        }
        var res = await JsEngine().runCode(jsCode);
        return Res(
            List.generate(res["comics"].length,
                (index) => CustomComic.fromJson(res["comics"][index], _key!)),
            subData: res["maxPage"]);
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
        if (res == null || res is! Map) {
          return Res.error("Invalid response from loadInfo");
        }
        var tags = <String, List<String>>{};
        var tagsData = res["tags"];
        if (tagsData is Map) {
          // Handle both Dart Map and JavaScript Map/Object
          for (var entry in tagsData.entries) {
            var key = entry.key.toString();
            var value = entry.value;
            if (value is List) {
              tags[key] = List<String>.from(value);
            } else if (value is Iterable) {
              tags[key] = value.map((e) => e.toString()).toList();
            } else {
              tags[key] = [value.toString()];
            }
          }
        }
        var recommend = res["recommend"];
        List<CustomComic>? recommendComics;
        if (recommend is List) {
          recommendComics = recommend.map((e) => CustomComic.fromJson(e, _key!)).toList();
        }
        // Handle chapters - support both flat Map<String, String> and nested Map<String, Map<String, String>>
        Map<String, String>? chapters;
        var chaptersData = res["chapters"];
        if (chaptersData is Map) {
          chapters = {};
          for (var entry in chaptersData.entries) {
            if (entry.value is Map) {
              // Nested map - flatten it
              (entry.value as Map).forEach((k, v) {
                chapters![k.toString()] = v.toString();
              });
            } else {
              // Flat map
              chapters[entry.key.toString()] = entry.value.toString();
            }
          }
          if (chapters.isEmpty) {
            chapters = null;
          }
        }
        // Check if comic has loadThumbnails function (Venera compatibility)
        Future<Res<List<String>>> Function(String, int)? thumbnailLoader;
        List<String>? initialThumbnails;
        int thumbnailMaxPage = res["thumbnailMaxPage"] ?? 1;
        var hasLoadThumbnails = _checkExists("comic.loadThumbnails");
        if (hasLoadThumbnails) {
          // If loadInfo didn't return thumbnails, call loadThumbnails to get initial thumbnails
          if (res["thumbnails"] == null || (res["thumbnails"] is List && (res["thumbnails"] as List).isEmpty)) {
            try {
              var thumbnailResult = await JsEngine().runCode("""
                ComicSource.sources.$_key.comic.loadThumbnails(${jsonEncode(id)}, null)
              """);
              if (thumbnailResult is Map && thumbnailResult["thumbnails"] is List) {
                initialThumbnails = List<String>.from(thumbnailResult["thumbnails"]);
                // Get max page from result if available
                if (thumbnailResult["next"] != null) {
                  // If there's a next page, estimate max pages (ehentai typically has 20-40 thumbs per page)
                  thumbnailMaxPage = 10; // Default to a reasonable number
                }
              }
            } catch (e) {
              // Ignore error, thumbnails will be loaded on demand
            }
          }

          thumbnailLoader = (String comicId, int page) async {
            // ThumbnailsData calls load(current + 1), so page 2 is first load
            // Convert to 0-based index for ehentai: page 2 -> "0", page 3 -> "1", etc.
            String? nextToken;
            if (page >= 2) {
              nextToken = (page - 2).toString();
            }
            var result = await JsEngine().runCode("""
              ComicSource.sources.$_key.comic.loadThumbnails(${jsonEncode(comicId)}, ${jsonEncode(nextToken)})
            """);
            if (result is Map && result["thumbnails"] is List) {
              return Res(List<String>.from(result["thumbnails"]));
            }
            return const Res.error("No thumbnails");
          };
        }

        return Res(ComicInfoData(
            res["title"] ?? "",
            res["subTitle"] ?? "",
            res["cover"] ?? "",
            res["description"] ?? "",
            tags,
            chapters,
            initialThumbnails ?? ListOrNull.from(res["thumbnails"]),
            thumbnailLoader,
            thumbnailMaxPage,
            recommendComics,
            _key!,
            id,
            isFavorite: res["isFavorite"],
            subId: res["subId"],
            stars: res["stars"] != null ? (res["stars"] as num).toDouble() : null,));
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
        if (res == null || res is! Map) {
          return Res.error("Invalid response from loadEp");
        }
        var images = res["images"];
        if (images == null || images is! List) {
          return Res.error("No images found");
        }
        return Res(List<String>.from(images));
      } catch (e, s) {
        log("$e\n$s", "Network", LogLevel.error);
        return Res.error(e.toString());
      }
    };
  }

  FavoriteData? _loadFavoriteData() {
    if (!_checkExists("favorites")) return null;

    final bool multiFolder = _getValue("favorites.multiFolder");

    Future<Res<T>> retryZone<T>(Future<Res<T>> Function() func) async{
      if(!ComicSource.find(_key!)!.isLogin){
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
      Future<Res<List<BaseComic>>> func() async{
        try {
          var res = await JsEngine().runCode("""
            ComicSource.sources.$_key.favorites.loadComics(
              ${jsonEncode(page)}, ${jsonEncode(folder)})
          """);
          return Res(
              List.generate(res["comics"].length,
                      (index) => CustomComic.fromJson(res["comics"][index], _key!)),
              subData: res["maxPage"]);
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

    if(multiFolder) {
      loadFolders = ([String? comicId]) async {
        Future<Res<Map<String, String>>> func() async{
          try {
            var res = await JsEngine().runCode("""
            ComicSource.sources.$_key.favorites.loadFolders(${jsonEncode(comicId)})
          """);
            List<String>? subData;
            if(res["favorited"] != null){
              subData = List.from(res["favorited"]);
            }
            return Res(Map.from(res["folders"]), subData: subData);
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

  CommentsLoader? _parseCommentsLoader(){
    if(!_checkExists("comic.loadComments")) return null;
    return (id, subId, page, replyTo) async {
      try {
        var res = await JsEngine().runCode("""
          ComicSource.sources.$_key.comic.loadComments(
            ${jsonEncode(id)}, ${jsonEncode(subId)}, ${jsonEncode(page)}, ${jsonEncode(replyTo)})
        """);
        if (res == null || res is! Map) {
          return Res.error("Invalid response from loadComments");
        }
        var comments = res["comments"];
        if (comments == null || comments is! List) {
          return Res([]);
        }
        return Res(
            comments.map((e) => Comment(
                e["userName"] ?? "", e["avatar"] ?? "", e["content"] ?? "", e["time"] ?? "", e["replyCount"] ?? 0, e["id"]?.toString() ?? ""
            )).toList(),
            subData: res["maxPage"]);
      } catch (e, s) {
        log("$e\n$s", "Network", LogLevel.error);
        return Res.error(e.toString());
      }
    };
  }

  SendCommentFunc? _parseSendCommentFunc(){
    if(!_checkExists("comic.sendComment")) return null;
    return (id, subId, content, replyTo) async {
      Future<Res<bool>> func() async{
        try {
          await JsEngine().runCode("""
            ComicSource.sources.$_key.comic.sendComment(
              ${jsonEncode(id)}, ${jsonEncode(subId)}, ${jsonEncode(content)}, ${jsonEncode(replyTo)})
          """);
          return const Res(true);
        } catch (e, s) {
          log("$e\n$s", "Network", LogLevel.error);
          return Res.error(e.toString());
        }
      }
      var res = await func();
      if(res.error && res.errorMessage!.contains("Login expired")){
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

  ChapterCommentsLoader? _parseChapterCommentsLoader(){
    if(!_checkExists("comic.loadChapterComments")) return null;
    return (comicId, epId, page, replyTo) async {
      try {
        var res = await JsEngine().runCode("""
          ComicSource.sources.$_key.comic.loadChapterComments(
            ${jsonEncode(comicId)}, ${jsonEncode(epId)}, ${jsonEncode(page)}, ${jsonEncode(replyTo)})
        """);
        if (res == null || res is! Map) {
          return Res.error("Invalid response from loadChapterComments");
        }
        var comments = res["comments"];
        if (comments == null || comments is! List) {
          return Res([]);
        }
        return Res(
            comments.map((e) => Comment(
                e["userName"] ?? "", e["avatar"] ?? "", e["content"] ?? "", e["time"] ?? "", e["replyCount"] ?? 0, e["id"]?.toString() ?? "",
                score: e["score"],
                isLiked: e["isLiked"],
                voteStatus: e["voteStatus"]
            )).toList(),
            subData: res["maxPage"]);
      } catch (e, s) {
        log("$e\n$s", "Network", LogLevel.error);
        return Res.error(e.toString());
      }
    };
  }

  SendChapterCommentFunc? _parseSendChapterCommentFunc(){
    if(!_checkExists("comic.sendChapterComment")) return null;
    return (comicId, epId, content, replyTo) async {
      try {
        var res = await JsEngine().runCode("""
          ComicSource.sources.$_key.comic.sendChapterComment(
            ${jsonEncode(comicId)}, ${jsonEncode(epId)}, ${jsonEncode(content)}, ${jsonEncode(replyTo)})
        """);
        if (res == null) {
          return Res.error("Invalid response from sendChapterComment");
        }
        return const Res(true);
      } catch (e, s) {
        log("$e\n$s", "Network", LogLevel.error);
        return Res.error(e.toString());
      }
    };
  }

  GetImageLoadingConfigFunc? _parseImageLoadingConfigFunc(){
    if(!_checkExists("comic.onImageLoad")){
      return null;
    }
    return (imageKey, comicId, ep) async {
      var res = await JsEngine().runCode("""
          ComicSource.sources.$_key.comic.onImageLoad(
            ${jsonEncode(imageKey)}, ${jsonEncode(comicId)}, ${jsonEncode(ep)})
        """);
      if(res is! Map) {
        Log.error("Network", "function onImageLoad return invalid data: ${res.runtimeType}");
        throw "function onImageLoad return invalid data";
      }
      return res as Map<String, dynamic>;
    };
  }

  GetThumbnailLoadingConfigFunc? _parseThumbnailLoadingConfigFunc(){
    if(!_checkExists("comic.onThumbnailLoad")){
      return null;
    }
    return (imageKey) async {
      var res = await JsEngine().runCode("""
          ComicSource.sources.$_key.comic.onThumbnailLoad(${jsonEncode(imageKey)})
        """);
      if(res is! Map) {
        Log.error("Network", "function onThumbnailLoad return invalid data");
        throw "function onThumbnailLoad return invalid data";
      }
      return res as Map<String, dynamic>;
    };
  }

  /// Parse venera format settings from JS
  Map<String, dynamic> _parseVeneraSettings() {
    var settings = _getValue("settings");
    if (settings == null || settings is! Map) {
      return const {};
    }
    // Convert to a simple Map<String, dynamic>
    var result = <String, dynamic>{};
    for (var entry in settings.entries) {
      if (entry.key is! String) continue;
      var value = entry.value;
      if (value is Map) {
        var settingMap = <String, dynamic>{};
        for (var e in value.entries) {
          if (e.key is String) {
            settingMap[e.key] = e.value;
          }
        }
        result[entry.key] = settingMap;
      }
    }
    return result;
  }
}
