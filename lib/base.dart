import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/network/jm_network/jm_network.dart';
import 'package:pica_comic/network/download.dart';
import 'package:pica_comic/network/webdav.dart';
import 'package:pica_comic/utils/extensions.dart';
import 'package:pica_comic/utils/io_tools.dart';
import 'package:pica_comic/utils/notification.dart';
import 'package:pica_comic/foundation/history.dart';
import 'package:pica_comic/foundation/local_favorites.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'foundation/def.dart';
export 'foundation/def.dart';

String get pathSep => Platform.pathSeparator;

var downloadManager = DownloadManager();

class Appdata {
  ///搜索历史
  List<String> searchHistory = [];
  Set<String> favoriteTags = {};

  ///历史记录管理器, 可以通过factory构造函数访问, 也可以通过这里访问
  var history = HistoryManager();

  ///设置
  List<String> settings = [
    "1", //0 点击屏幕左右区域翻页
    "dd", //1 排序方式
    "1", //2 启动时检查更新
    "0", //3 Api请求地址, 为0时表示使用哔咔官方Api, 为1表示使用转发服务器
    "1", //4 宽屏时显示前进后退关闭按钮
    "1", //5 是否显示头像框
    "1", //6 启动时签到
    "1", //7 使用音量键翻页
    "0", //8 代理设置, 0代表使用系统代理
    "1", //9 翻页方式: 1从左向右,2从右向左,3从上至下,4从上至下(连续)
    "0", //10 是否第一次使用
    "0", //11 收藏夹浏览方式, 0为正常浏览, 1为分页浏览
    "0", //12 阻止屏幕截图
    "0", //13 需要生物识别
    "1", //14 阅读器中保持屏幕常亮
    "1", //15 Jm自动选择域名
    "0", //16 Jm分类漫画排序模式, 值为 ComicsOrder 的索引
    "0", //17 Jm分流
    "0", //18 夜间模式降低图片亮度
    "0", //19 Jm搜索漫画排序模式, 值为 ComicsOrder 的索引
    "0", //20 Eh画廊站点, 1表示e-hentai, 2表示exhentai
    "111111", //21 启用的漫画源
    "", //22 下载目录, 仅Windows端, 为空表示使用App数据目录
    "0", //23 初始页面,
    "0", //24 当前页面状态（用于恢复应用状态）
    "0", //25 漫画列表显示模式
    "00", //26 已下载页面排序模式: 时间, 漫画名, 作者名, 大小
    "0", //27 颜色
    "2", //28 预加载页数
    "0", //29 eh优先加载原图
    "1", //30 picacg收藏夹新到旧
    "https://www.wnacg.com", //31 绅士漫画域名
    "0", //32  深色模式: 0-跟随系统, 1-禁用, 2-启用
    "5", //33 自动翻页时间
    "1000", //34 缓存数量限制
    "500", //35 缓存大小限制
    "1", //36 翻页动画
    "0", //37 禁漫图片分流
    "0", //38 高刷新率
    "0", //39 nhentai搜索排序
    "25", //40 点按翻页识别范围(0-50),
    "0", //41 阅读器图片布局方式, 0-contain, 1-fitWidth, 2-fitHeight
    "0", //42 禁漫收藏夹排序模式, 0-最新收藏, 1-最新更新
    "1", //43 限制图片宽度
    "0,1.0", //44 comic display type
    "", //45 webdav
    "0", //46 webdav version
    "0", //47 eh warning
    "https://nhentai.net", //48 nhentai domain (deprecated)
    "1", //49 阅读器中双击放缩
    "", //50 language, empty=system
    "", //51 默认收藏夹
    "1", //52 favorites
    "0", //53 本地收藏添加位置(尾/首)
    "0", //54 阅读后移动本地收藏(否/尾/首)
    "1", //55 长按缩放
    "https://18comic.vip", //56 jm domain
    "1", //57 show page info in reader
    "0", //58 hosts
    "012345678", //59 explore page(废弃)
    "0", //60 action when local favorite is tapped
    "0", //61 check link in clipboard
    "10000", //62 漫画信息页面工具栏: "快速收藏".tl, "复制标题".tl, "复制链接".tl, "分享".tl, "搜索相似".tl
    "0", //63 初始搜索目标
    "0", //64 启用侧边翻页
    "0", //65 本地收藏显示数量
    "0", //66 缩略图布局: 覆盖, 容纳
    "picacg,ehentai,jm,htmanga,nhentai", //67 分类页面
    "picacg,ehentai,jm,htmanga,nhentai", //68 收藏页面
    "0", //69 自动添加语言筛选
    "0", //70 反转点按识别
    "1", // 71 关联网络收藏夹后每次刷新拉取几页
    "1", //72 漫画块显示收藏状态
    "0", //73 漫画块显示阅读位置
    "1.0", //74 图片收藏大小
    "", //75 eh profile
    "0", //76 阅读器内固定屏幕方向: 0-禁用, 1-横屏, 2-竖屏
    "picacg,Eh主页,Eh热门,禁漫主页,禁漫最新,hitomi,绅士漫画,nhentai", //77 探索页面
    "0", //78 已下载的eh漫画优先显示副标题
    "6", //79 下载并行
    "1", //80 启动时检查自定义漫画源的更新
    "0", //81 使用深色背景
    "111111", //82 内置漫画源启用状态,
    "1", //83 完全隐藏屏蔽的作品
    "0", //84 纯黑色模式
    "www.cdntwice.org,www.cdnsha.org,www.cdnaspa.cc,www.cdnntr.cc", //85 jm api domains
    "https://cdn-msp.jmapiproxy3.cc", //86 jm image url
    "gold-usergeneratedcontent.net", //87 hitomi cdn url
    "0", //88
    "2.0.11", //89 jm app version
    "0", //90
    "0", //91 Fluent UI
    "1", //92 显示章节评论
    "0", //93 在搜索列表中隐藏已阅读项目
    "100", //94 已读项目隐藏阈值
    "0", //95 阅读器中始终显示状态栏
    "0", //96 主页历史记录样式, 0-封面, 1-文本
    "0", //97 多标签或门搜索(实验性)
    "0", //98 在阅读器中显示时间和电量信息
    "0", //99 章节末尾显示评论
    "", //100 webdav disableSyncFields

  ];

  /// 隐式数据, 用于存储一些不需要用户设置的数据, 此数据通常为某些组件的状态, 此设置不应当被同步
  List<String> implicitData = [
    "1;;", //收藏夹状态
    "0", // 双页模式下第一页显示单页
    "0", // 点击关闭按钮时不显示提示
    webUA, // UA
    "title", // 图片收藏排序方式
    "timeAsc", // 按时间升序
    "timeDesc", // 按时间降序
    "maxFavorites", // 按收藏数量
    "favoritesCompareComicPages", // 收藏数比上总页数
    "all", // 图片收藏时间筛选
    "lastWeek", // 最近一周
    "lastMonth", // 最近一个月
    "lastHalfYear", // 最近半年
    "lastYear", // 最近一年
    "0", // 图片收藏数量筛选
    "1", //15 webdav autoSync
  ];

  void writeFavoriteTags() async {
    if (Platform.isAndroid) {
      try {
        var externalDirectory = await getExternalStorageDirectory();
        if (externalDirectory != null) {
          var file = File("${externalDirectory.path}/favoriteTags.txt");
          if (!await file.exists()) {
            await file.create();
          }
          await file.writeAsString(favoriteTags.join('\n'));
        }
      } catch (e) {
        LogManager.addLog(LogLevel.error, "Appdata.writeFavoriteTags",
            "Failed to write favorite tags: $e");
      }
    } else {
      var s = await SharedPreferences.getInstance();
      await s.setStringList("favoriteTags", favoriteTags.toList());
    }
  }

  void readFavoriteTags() async {
    if (Platform.isAndroid) {
      try {
        var externalDirectory = await getExternalStorageDirectory();
        if (externalDirectory != null) {
          var file = File("${externalDirectory.path}/favoriteTags.txt");
          if (await file.exists()) {
            var data = (await file.readAsString()).split('\n');
            favoriteTags = data.toSet();
          } else {
            writeFavoriteTags();
          }
        }
      } catch (e) {
        LogManager.addLog(LogLevel.error, "Appdata.readFavoriteTags",
            "Failed to read favorite tags: $e");
        writeFavoriteTags();
      }
    } else {
      var s = await SharedPreferences.getInstance();
      favoriteTags = (s.getStringList("favoriteTags") ?? []).toSet();
    }
  }

  Future<int?> readLastCheckUpdate() async {
    if (Platform.isAndroid) {
      try {
        var externalDirectory = await getExternalStorageDirectory();
        if (externalDirectory != null) {
          var file = File("${externalDirectory.path}/lastCheckUpdate.txt");
          if (await file.exists()) {
            var content = await file.readAsString();
            return int.tryParse(content);
          }
        }
      } catch (e) {
        LogManager.addLog(LogLevel.error, "Appdata.readLastCheckUpdate",
            "Failed to read lastCheckUpdate: $e");
      }
      return null;
    } else {
      var s = await SharedPreferences.getInstance();
      return s.getInt("lastCheckUpdate");
    }
  }

  void writeLastCheckUpdate(int time) async {
    if (Platform.isAndroid) {
      try {
        var externalDirectory = await getExternalStorageDirectory();
        if (externalDirectory != null) {
          var file = File("${externalDirectory.path}/lastCheckUpdate.txt");
          if (!await file.exists()) {
            await file.create();
          }
          await file.writeAsString(time.toString());
        }
      } catch (e) {
        LogManager.addLog(LogLevel.error, "Appdata.writeLastCheckUpdate",
            "Failed to write lastCheckUpdate: $e");
      }
    } else {
      var s = await SharedPreferences.getInstance();
      await s.setInt("lastCheckUpdate", time);
    }
  }

  void writeSearchHistory() async {
    if (Platform.isAndroid) {
      try {
        var externalDirectory = await getExternalStorageDirectory();
        if (externalDirectory != null) {
          var file = File("${externalDirectory.path}/searchHistory.txt");
          if (!await file.exists()) {
            await file.create();
          }
          await file.writeAsString(searchHistory.join('\n'));
        }
      } catch (e) {
        LogManager.addLog(LogLevel.error, "Appdata.writeSearchHistory",
            "Failed to write search history: $e");
      }
    } else {
      var s = await SharedPreferences.getInstance();
      await s.setStringList("search", searchHistory);
    }
  }

  void readSearchHistory() async {
    if (Platform.isAndroid) {
      try {
        var externalDirectory = await getExternalStorageDirectory();
        if (externalDirectory != null) {
          var file = File("${externalDirectory.path}/searchHistory.txt");
          if (await file.exists()) {
            var data = (await file.readAsString()).split('\n');
            searchHistory = data;
          } else {
            writeSearchHistory();
          }
        }
      } catch (e) {
        LogManager.addLog(LogLevel.error, "Appdata.readSearchHistory",
            "Failed to read search history: $e");
        writeSearchHistory();
      }
    } else {
      var s = await SharedPreferences.getInstance();
      searchHistory = s.getStringList("search") ?? [];
    }
  }

  void writeImplicitData() async {
    if (Platform.isAndroid) {
      try {
        var externalDirectory = await getExternalStorageDirectory();
        if (externalDirectory != null) {
          var file = File("${externalDirectory.path}/implicitData.txt");
          if (!await file.exists()) {
            await file.create();
          }
          await file.writeAsString(implicitData.join('\n'));
        }
      } catch (e) {
        LogManager.addLog(LogLevel.error, "Appdata.writeImplicitData",
            "Failed to write implicit data: $e");
      }
    } else {
      var s = await SharedPreferences.getInstance();
      await s.setStringList("implicitData", implicitData);
    }
  }

  void readImplicitData() async {
    if (Platform.isAndroid) {
      try {
        var externalDirectory = await getExternalStorageDirectory();
        if (externalDirectory != null) {
          var file = File("${externalDirectory.path}/implicitData.txt");
          if (await file.exists()) {
            var data = (await file.readAsString()).split('\n');
            while (implicitData.length < data.length) {
              implicitData.add("");
            }
            for (int i = 0; i < data.length && i < implicitData.length; i++) {
              if (data[i] != null) {
                implicitData[i] = data[i];
              }
            }
          } else {
            writeImplicitData();
          }
        }
      } catch (e) {
        LogManager.addLog(LogLevel.error, "Appdata.readImplicitData",
            "Failed to read implicit data: $e");
        writeImplicitData();
      }
    } else {
      try {
        var s = await SharedPreferences.getInstance();
        var data = s.getStringList("implicitData");
        if (data == null) {
          writeImplicitData();
          return;
        }

        // 确保implicitData数组有足够的元素
        while (implicitData.length < data.length) {
          implicitData.add("");
        }

        // 安全复制数据
        for (int i = 0; i < data.length && i < implicitData.length; i++) {
          if (data[i] != null) {
            implicitData[i] = data[i];
          }
        }
      } catch (e) {
        LogManager.addLog(LogLevel.error, "Appdata.readImplicitData",
            "Failed to read implicit data: $e");
        // 发生错误时，重新初始化数据
        writeImplicitData();
      }
    }
  }

  void writeBlockingKeyword() async {
    if (Platform.isAndroid) {
      try {
        var externalDirectory = await getExternalStorageDirectory();
        if (externalDirectory != null) {
          var file = File("${externalDirectory.path}/blockingKeyword.txt");
          if (!await file.exists()) {
            await file.create();
          }
          await file.writeAsString(blockingKeyword.join('\n'));
        }
      } catch (e) {
        LogManager.addLog(LogLevel.error, "Appdata.writeBlockingKeyword",
            "Failed to write blocking keyword: $e");
      }
    } else {
      var s = await SharedPreferences.getInstance();
      await s.setStringList("blockingKeyword", blockingKeyword);
    }
  }

  void readBlockingKeyword() async {
    if (Platform.isAndroid) {
      try {
        var externalDirectory = await getExternalStorageDirectory();
        if (externalDirectory != null) {
          var file = File("${externalDirectory.path}/blockingKeyword.txt");
          if (await file.exists()) {
            var data = (await file.readAsString()).split('\n');
            if(data.length == 1 && data[0].isEmpty){
              data.clear();
            }
            blockingKeyword = data;
          } else {
            writeBlockingKeyword();
          }
        }
      } catch (e) {
        LogManager.addLog(LogLevel.error, "Appdata.readBlockingKeyword",
            "Failed to read blocking keyword: $e");
        writeBlockingKeyword();
      }
    } else {
      var s = await SharedPreferences.getInstance();
      blockingKeyword = s.getStringList("blockingKeyword") ?? [];
    }
  }

  void writeJmBlockingKeyword() async {
    if (Platform.isAndroid) {
      try {
        var externalDirectory = await getExternalStorageDirectory();
        if (externalDirectory != null) {
          var file = File("${externalDirectory.path}/jmBlockingKeyword.txt");
          if (!await file.exists()) {
            await file.create();
          }
          await file.writeAsString(jmBlockingKeyword.join('\n'));
        }
      } catch (e) {
        LogManager.addLog(LogLevel.error, "Appdata.writeJmBlockingKeyword",
            "Failed to write jm blocking keyword: $e");
      }
    } else {
      var s = await SharedPreferences.getInstance();
      await s.setStringList("jmBlockingKeyword", jmBlockingKeyword);
    }
  }

  void readJmBlockingKeyword() async {
    if (Platform.isAndroid) {
      try {
        var externalDirectory = await getExternalStorageDirectory();
        if (externalDirectory != null) {
          var file = File("${externalDirectory.path}/jmBlockingKeyword.txt");
          if (await file.exists()) {
            var data = (await file.readAsString()).split('\n');
            if(data.length == 1 && data[0].isEmpty){
              data.clear();
            }
            jmBlockingKeyword = data;
          } else {
            writeJmBlockingKeyword();
          }
        }
      } catch (e) {
        LogManager.addLog(LogLevel.error, "Appdata.readJmBlockingKeyword",
            "Failed to read jm blocking keyword: $e");
        writeJmBlockingKeyword();
      }
    } else {
      var s = await SharedPreferences.getInstance();
      jmBlockingKeyword = s.getStringList("jmBlockingKeyword") ?? [];
    }
  }

  void writeBlockedCommentWords() async {
    if (Platform.isAndroid) {
      try {
        var externalDirectory = await getExternalStorageDirectory();
        if (externalDirectory != null) {
          var file = File("${externalDirectory.path}/blockedCommentWords.txt");
          if (!await file.exists()) {
            await file.create();
          }
          await file.writeAsString(blockedCommentWords.join('\n'));
        }
      } catch (e) {
        LogManager.addLog(LogLevel.error, "Appdata.writeBlockedCommentWords",
            "Failed to write blocked comment words: $e");
      }
    } else {
      var s = await SharedPreferences.getInstance();
      await s.setStringList("blockedCommentWords", blockedCommentWords);
    }
  }

  void readBlockedCommentWords() async {
    if (Platform.isAndroid) {
      try {
        var externalDirectory = await getExternalStorageDirectory();
        if (externalDirectory != null) {
          var file = File("${externalDirectory.path}/blockedCommentWords.txt");
          if (await file.exists()) {
            var data = (await file.readAsString()).split('\n');
            if(data.length == 1 && data[0].isEmpty){
              data.clear();
            }
            blockedCommentWords = data;
          } else {
            writeBlockedCommentWords();
          }
        }
      } catch (e) {
        LogManager.addLog(LogLevel.error, "Appdata.readBlockedCommentWords",
            "Failed to read blocked comment words: $e");
        writeBlockedCommentWords();
      }
    } else {
      var s = await SharedPreferences.getInstance();
      blockedCommentWords = s.getStringList("blockedCommentWords") ?? [];
    }
  }

  ///屏蔽的关键词
  List<String> blockingKeyword = [];

  ///禁漫天堂专用屏蔽关键词
  List<String> jmBlockingKeyword = [];

  ///评论屏蔽词
  List<String> blockedCommentWords = [];

  ///是否第一次使用的判定, 用于显示提示
  List<String> firstUse = [
    "0", //屏蔽关键词1
    "0", //屏蔽关键词2(已废弃)
    "0", //漫画详情页
    "0", //是否进入过app
    "0", //显示本地收藏夹的管理提示
  ];

  ///阅读器设置
  List<String> readerSetting = [
    "1", //屏蔽关键词1
    "1", //屏蔽关键词2(已废弃)
    "1", //漫画详情页
    "0", //是否进入过app
    "1", //显示本地收藏夹的管理提示
  ];

  int getSearchMode() {
    var modes = ["dd", "da", "ld", "vd"];
    return modes.indexOf(settings[1]);
  }

  void setSearchMode(int mode) async {
    var modes = ["dd", "da", "ld", "vd"];
    settings[1] = modes[mode];
    updateSettings();
  }

  Future<void> readSettings() async {
    try {
      var settingsFile = File("${App.dataPath}/settings");

      List<String> st;

      if (settingsFile.existsSync()) {
        try {
          var json = jsonDecode(await settingsFile.readAsString());
          if (json is List) {
            st = List<String>.from(json);
          } else {
            st = [];
            LogManager.addLog(LogLevel.warning, "Appdata.readSettings",
                "Settings file contains invalid data format");
          }
        } catch (e) {
          LogManager.addLog(LogLevel.error, "Appdata.readSettings",
              "Failed to read settings file: $e");
          st = [];
        }
      } else {
        st = [];
      }

      for (int i = 0; i < st.length; i++) {
        if (i < settings.length) {
          settings[i] = st[i];
        } else {
          settings.add(st[i]);
        }
      }

      while (settings.length < 91) {
        settings.add("0");
      }

      if (settings[26].length < 2) {
        settings[26] += "0";
      }

      if (settings[10].isEmpty) {
        settings[10] = "0";
      }

      if (settings[13].isEmpty) {
        settings[13] = "0";
      }
    } catch (e) {
      LogManager.addLog(LogLevel.error, "Appdata.readSettings",
          "Critical error in readSettings: $e");
    }
  }

  Future<void> updateSettings([bool syncData = true]) async {
    var settingsFile = File("${App.dataPath}/settings");

    await settingsFile.writeAsString(jsonEncode(settings));

    if (syncData) {
      Webdav.uploadData();
    }
  }

  Future<void> writeFirstUse() async {
    var s = await SharedPreferences.getInstance();
    await s.setStringList("firstUse", firstUse);
  }

  void writeHistory() async {
    var s = await SharedPreferences.getInstance();
  }

  Future<void> writeData([bool sync = true]) async {
    writeImplicitData();
    if (sync) {
      Webdav.uploadData();
    }
    await updateSettings();
    if (!App.isAndroid) {
      var s = await SharedPreferences.getInstance();
      await s.setStringList("firstUse", firstUse);
    }
  }

  Future<bool> readData() async {
    try {
      await readSettings();

      readFavoriteTags();

      readSearchHistory();

      readBlockingKeyword();

      readJmBlockingKeyword();

      readBlockedCommentWords();

      if (!App.isAndroid) {
        var s = await SharedPreferences.getInstance();
        var firstUseData = s.getStringList("firstUse");
        if (firstUseData != null) {
          for (int i = 0; i < firstUseData.length && i < firstUse.length; i++) {
            firstUse[i] = firstUseData[i];
          }
        }
      }

      try {
        readImplicitData();
      } catch (e) {
        LogManager.addLog(LogLevel.error, "Appdata.readData",
            "Failed to read implicit data: $e");
        writeImplicitData();
      }

      try {
        readComicSpecificSettings();
      } catch (e) {
        LogManager.addLog(LogLevel.error, "Appdata.readData",
            "Failed to read comic specific settings: $e");
      }

      while (settings.length < 91) {
        settings.add("0");
      }

      return firstUse.length > 3 ? firstUse[3] == "1" : false;
    } catch (e) {
      LogManager.addLog(
          LogLevel.error, "Appdata.readData", "Failed to read app data: $e");
      await _resetToDefaults();
      return false;
    }
  }

  /// 重置应用数据为默认值
  Future<void> _resetToDefaults() async {
    try {
      LogManager.addLog(LogLevel.info, "Appdata._resetToDefaults",
          "Resetting app data to defaults");

      // 重置所有数据为默认值
      searchHistory = [];
      favoriteTags = {};
      blockingKeyword = [];
      jmBlockingKeyword = [];

      // 确保firstUse有默认值
      while (firstUse.length < 5) {
        firstUse.add("0");
      }

      // 不强制设置firstUse[3]为"1"，保持默认值，确保全新安装可以显示开始界面

      // 重置隐式数据
      writeImplicitData();

      // 保存重置后的数据
      await writeData();

      LogManager.addLog(LogLevel.info, "Appdata._resetToDefaults",
          "Successfully reset app data");
    } catch (e) {
      LogManager.addLog(LogLevel.error, "Appdata._resetToDefaults",
          "Failed to reset app data: $e");
    }
  }

  Map<String, dynamic> toJson() => {
        "settings": settings,
        "firstUse": firstUse,
        "blockingKeywords": blockingKeyword,
        "favoriteTags": favoriteTags.toList(),
      };

  bool readDataFromJson(Map<String, dynamic> json) {
    try {
      var newSettings = List<String>.from(json["settings"]);
      var downloadPath = settings[22];
      var authRequired = settings[13];
      for (var i = 0; i < settings.length && i < newSettings.length; i++) {
        settings[i] = newSettings[i];
      }
      settings[22] = downloadPath;
      settings[13] = authRequired;
      var newFirstUse = List<String>.from(json["firstUse"]);
      for (var i = 0; i < firstUse.length && i < newFirstUse.length; i++) {
        firstUse[i] = newFirstUse[i];
      }
      if (json["history"] != null) {
        history.readDataFromJson(json["history"]);
      }
      // merge data
      blockingKeyword = Set<String>.from(
              ((json["blockingKeywords"] ?? []) + blockingKeyword) as List)
          .toList();
      favoriteTags =
          Set.from((json["favoriteTags"] ?? []) + List.from(favoriteTags));
      writeData(false);
      return true;
    } catch (e, s) {
      LogManager.addLog(LogLevel.error, "Appdata.readDataFromJson",
          "error reading appdata$e\n$s");
      readData();
      return false;
    }
  }

  final appSettings = _Settings();

  /// 漫画特定阅读设置
  Map<String, Map<String, dynamic>> _comicSpecificSettings = {};

  bool isComicSpecificSettingsEnabled(String comicId, String sourceKey) {
    return _comicSpecificSettings["$comicId@$sourceKey"]?.containsKey("enabled") == true &&
        _comicSpecificSettings["$comicId@$sourceKey"]!["enabled"] == true;
  }

  void setEnabledComicSpecificSettings(
    String comicId,
    String sourceKey,
    bool enabled,
  ) {
    var key = "$comicId@$sourceKey";
    _comicSpecificSettings.putIfAbsent(key, () => {});
    _comicSpecificSettings[key]!["enabled"] = enabled;
    _saveComicSpecificSettings();
  }

  /// 获取阅读设置，如果 comicId 不为 null 且启用了漫画特定设置，则返回漫画特定值，否则返回全局设置
  String getReaderSetting(String? comicId, String? sourceKey, int settingIndex) {
    if (comicId == null || sourceKey == null) {
      return settings[settingIndex];
    }
    if (!isComicSpecificSettingsEnabled(comicId, sourceKey)) {
      return settings[settingIndex];
    }
    var key = "$comicId@$sourceKey";
    var value = _comicSpecificSettings[key]?[settingIndex.toString()];
    if (value == null) {
      return settings[settingIndex];
    }
    return value.toString();
  }

  /// 设置阅读设置，如果 comicId 不为 null 且启用了漫画特定设置，则保存到漫画特定设置，否则保存到全局设置
  void setReaderSetting(String? comicId, String? sourceKey, int settingIndex, String value) {
    if (comicId != null && sourceKey != null && isComicSpecificSettingsEnabled(comicId, sourceKey)) {
      var key = "$comicId@$sourceKey";
      _comicSpecificSettings.putIfAbsent(key, () => {});
      _comicSpecificSettings[key]![settingIndex.toString()] = value;
      _saveComicSpecificSettings();
    } else {
      settings[settingIndex] = value;
    }
  }

  void _saveComicSpecificSettings() async {
    var file = File("${App.dataPath}/comic_specific_settings.json");
    await file.writeAsString(jsonEncode(_comicSpecificSettings));
  }

  Future<void> readComicSpecificSettings() async {
    try {
      var file = File("${App.dataPath}/comic_specific_settings.json");
      if (file.existsSync()) {
        var json = jsonDecode(await file.readAsString());
        if (json is Map) {
          _comicSpecificSettings = Map<String, Map<String, dynamic>>.from(
            json.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v))),
          );
        }
      }
    } catch (e) {
      LogManager.addLog(LogLevel.error, "Appdata.readComicSpecificSettings",
          "Failed to read comic specific settings: $e");
    }
  }
}

var appdata = Appdata();
var notifications = Notifications();

/// clear all data
Future<void> clearAppdata() async {
  var s = await SharedPreferences.getInstance();
  await s.clear();
  var settingsFile = File("${App.dataPath}/settings");
  if (await settingsFile.exists()) {
    await settingsFile.delete();
  }
  appdata.history.clearHistory();
  appdata = Appdata();
  await appdata.readData();
  await eraseCache();
  await JmNetwork().cookieJar.deleteAll();
  await LocalFavoritesManager().clearAll();
}

class _Settings {
  List<String> get _settings => appdata.settings;

  /// Theme color, index of [colors] (lib/foundation/def.dart)
  int get theme => int.parse(_settings[27]);

  set theme(int value) {
    appdata.settings[27] = value.toString();
  }

  /// Dark Mode, 0/1/2 (system/disabled/enable)
  int get darkMode => int.parse(appdata.settings[32]);

  set darkMode(int value) {
    appdata.settings[32] = value.toString();
  }

  /// 0/1 (detailed/brief)
  int get comicTileDisplayType =>
      int.parse(appdata.settings[44].split(',').first);

  set comicTileDisplayType(int v) {
    var values = appdata.settings[44].split(',');
    if (values.length != 2) {
      values = ['0', '1.0'];
    }
    values[0] = v.toString();
    appdata.settings[44] = values.join(',');
  }

  /// 0/1 (Continuous mode/Paging mode)
  int get comicsListDisplayType => int.parse(appdata.settings[25]);

  set comicsListDisplayType(int value) {
    appdata.settings[25] = value.toString();
  }

  /// build-in comic sources
  bool isComicSourceEnabled(String key) {
    var index = builtInSources.indexOf(key);
    if (index == -1) {
      throw "Not Found";
    }
    return appdata.settings[82][index] == '1';
  }

  void setComicSourceEnabled(String key, bool enabled) {
    var index = builtInSources.indexOf(key);
    if (index == -1) {
      throw "Not Found";
    }
    appdata.settings[82] =
        appdata.settings[82].setValueAt(enabled ? '1' : '0', index);
  }

  List<String> get jmApiDomains => appdata.settings[85].split(',');

  set jmApiDomains(List<String> domains) {
    appdata.settings[85] = domains.join(',');
  }

  String get jmImgUrlIndex =>
      int.parse(appdata.settings[37]) < 4 ? appdata.settings[37] : "0";

  List<String> get explorePages => appdata.settings[77].split(',');

  set explorePages(List<String> pages) {
    appdata.settings[77] = pages.join(',');
  }

  List<String> get categoryPages => appdata.settings[67].split(',');

  set categoryPages(List<String> pages) {
    appdata.settings[67] = pages.join(',');
  }

  String get initialSearchTarget => appdata.settings[63];

  set initialSearchTarget(String value) {
    appdata.settings[63] = value;
  }

  bool get reduceBrightnessInDarkMode => appdata.settings[18] == "1";

  set reduceBrightnessInDarkMode(bool value) {
    appdata.settings[18] = value ? "1" : "0";
  }

  bool get showPageInfoInReader => appdata.settings[57] == "1";

  set showPageInfoInReader(bool value) {
    appdata.settings[57] = value ? "1" : "0";
  }

  bool get showButtonsInReader => appdata.settings[4] == "1";

  set showButtonsInReader(bool value) {
    appdata.settings[4] = value ? "1" : "0";
  }

  bool get flipPageWithClick => appdata.settings[0] == "1";

  set flipPageWithClick(bool value) {
    appdata.settings[0] = value ? "1" : "0";
  }

  bool get useDarkBackground => appdata.settings[81] == "1";

  set useDarkBackground(bool value) {
    appdata.settings[81] = value ? "1" : "0";
  }

  bool get fullyHideBlockedWorks => appdata.settings[83] == "1";

  set fullyHideBlockedWorks(bool value) {
    appdata.settings[83] = value ? "1" : "0";
  }

  /// cache size limit in MB
  int get cacheLimit => int.tryParse(appdata.settings[35]) ?? 500;

  set cacheLimit(int value) {
    appdata.settings[35] = value.toString();
  }

  List<String> get networkFavorites => appdata.settings[68].split(',');

  set networkFavorites(List<String> pages) {
    appdata.settings[68] = pages.join(',');
  }

  bool get hideReadInList =>
      appdata.settings.length > 93 && appdata.settings[93] == "1";

  set hideReadInList(bool value) {
    while (appdata.settings.length <= 93) {
      appdata.settings.add("0");
    }
    appdata.settings[93] = value ? "1" : "0";
  }

  int get hideReadThresholdInList {
    if (appdata.settings.length <= 94) return 100;
    final value = int.tryParse(appdata.settings[94]) ?? 100;
    return value.clamp(0, 100);
  }

  set hideReadThresholdInList(int value) {
    while (appdata.settings.length <= 94) {
      appdata.settings.add("0");
    }
    appdata.settings[94] = value.clamp(0, 100).toString();
  }

  int get homePageHistoryDisplayType {
    while (appdata.settings.length <= 96) {
      appdata.settings.add("0");
    }
    return int.tryParse(appdata.settings[96]) ?? 0;
  }

  set homePageHistoryDisplayType(int value) {
    while (appdata.settings.length <= 96) {
      appdata.settings.add("0");
    }
    appdata.settings[96] = value == 1 ? "1" : "0";
  }

  bool get enableOrKeywordSearch {
    while (appdata.settings.length <= 97) {
      appdata.settings.add("0");
    }
    return appdata.settings[97] == "1";
  }

  set enableOrKeywordSearch(bool value) {
    while (appdata.settings.length <= 97) {
      appdata.settings.add("0");
    }
    appdata.settings[97] = value ? "1" : "0";
  }

  bool get enableClockAndBatteryInfoInReader {
    while (appdata.settings.length <= 98) {
      appdata.settings.add("0");
    }
    return appdata.settings[98] == "1";
  }

  set enableClockAndBatteryInfoInReader(bool value) {
    while (appdata.settings.length <= 98) {
      appdata.settings.add("0");
    }
    appdata.settings[98] = value ? "1" : "0";
  }

  bool get showChapterCommentsAtEnd {
    while (appdata.settings.length <= 99) {
      appdata.settings.add("0");
    }
    return appdata.settings[99] == "1";
  }

  set showChapterCommentsAtEnd(bool value) {
    while (appdata.settings.length <= 99) {
      appdata.settings.add("0");
    }
    appdata.settings[99] = value ? "1" : "0";
  }

  String get followUpdatesFolder {
    while (appdata.settings.length <= 101) {
      appdata.settings.add("");
    }
    return appdata.settings[101];
  }

  set followUpdatesFolder(String value) {
    while (appdata.settings.length <= 101) {
      appdata.settings.add("");
    }
    appdata.settings[101] = value;
  }

  bool get saveChapterCommentsOnDownload {
    while (appdata.settings.length <= 102) {
      appdata.settings.add("0");
    }
    return appdata.settings[102] == "1";
  }

  set saveChapterCommentsOnDownload(bool value) {
    while (appdata.settings.length <= 102) {
      appdata.settings.add("0");
    }
    appdata.settings[102] = value ? "1" : "0";
  }
}

class ChapterCommentsStorage {
  static String get _basePath => "${App.dataPath}/chapter_comments";

  static String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

  /// 保存评论，包含漫画名和章节名，只在内容变化时保存
  static Future<bool> saveComments({
    required String sourceKey,
    required String comicId,
    required String epId,
    required List<Map<String, dynamic>> comments,
    String? comicName,
    String? chapterTitle,
  }) async {
    var dir = Directory(
        "$_basePath/${_sanitize(sourceKey)}_${_sanitize(comicId)}");
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    var file = File("${dir.path}/${_sanitize(epId)}.json");
    
    // 检查现有文件内容
    if (await file.exists()) {
      try {
        var existingContent = await file.readAsString();
        var existingData = jsonDecode(existingContent) as Map<String, dynamic>;
        var existingComments = existingData['comments'] as List<dynamic>?;
        
        // 比较评论内容是否相同
        if (_commentsEqual(existingComments, comments)) {
          return false; // 内容相同，不需要保存
        }
      } catch (e) {
        // 读取失败时继续保存
      }
    }
    
    // 保留原有的锁定状态（如果存在）
    bool isLocked = false;
    if (await file.exists()) {
      try {
        var existingContent = await file.readAsString();
        var existingData = jsonDecode(existingContent) as Map<String, dynamic>;
        isLocked = existingData['isLocked'] == true;
      } catch (e) {
        // 忽略错误
      }
    }
    
    var data = {
      'sourceKey': sourceKey,
      'comicId': comicId,
      'epId': epId,
      'comicName': comicName,
      'chapterTitle': chapterTitle,
      'savedAt': DateTime.now().toIso8601String(),
      'isLocked': isLocked,
      'comments': comments,
    };
    
    await file.writeAsString(jsonEncode(data));
    return true; // 保存成功
  }

  /// 比较两个评论列表是否相等
  static bool _commentsEqual(List<dynamic>? a, List<Map<String, dynamic>> b) {
    if (a == null) return false;
    if (a.length != b.length) return false;
    
    for (var i = 0; i < a.length; i++) {
      var commentA = a[i] as Map<String, dynamic>;
      var commentB = b[i];
      
      // 比较关键字段
      if (commentA['id'] != commentB['id']) return false;
      if (commentA['content'] != commentB['content']) return false;
      if (commentA['userName'] != commentB['userName']) return false;
      if (commentA['time'] != commentB['time']) return false;
    }
    
    return true;
  }

  /// 加载评论，返回包含元数据的完整结构
  static Future<Map<String, dynamic>?> loadCommentsWithMeta(
      String sourceKey, String comicId, String epId) async {
    var file = File(
        "$_basePath/${_sanitize(sourceKey)}_${_sanitize(comicId)}/${_sanitize(epId)}.json");
    if (!await file.exists()) return null;
    try {
      var data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return data;
    } catch (e) {
      return null;
    }
  }

  /// 加载评论列表（仅用于兼容）
  static Future<List<Map<String, dynamic>>?> loadComments(
      String sourceKey, String comicId, String epId) async {
    var meta = await loadCommentsWithMeta(sourceKey, comicId, epId);
    if (meta == null) return null;
    var comments = meta['comments'];
    if (comments is List) {
      return comments.map((c) => Map<String, dynamic>.from(c as Map)).toList();
    }
    return null;
  }

  /// 获取所有保存的评论文件信息
  static Future<List<Map<String, dynamic>>> getAllSavedComments() async {
    var result = <Map<String, dynamic>>[];
    var baseDir = Directory(_basePath);
    if (!await baseDir.exists()) return result;

    await for (var entity in baseDir.list()) {
      if (entity is Directory) {
        await for (var file in entity.list()) {
          if (file is File && file.path.endsWith('.json')) {
            try {
              var content = await file.readAsString();
              var data = jsonDecode(content) as Map<String, dynamic>;
              
              // 计算文件大小
              var stat = await file.stat();
              data['fileSize'] = stat.size;
              data['filePath'] = file.path;
              
              result.add(data);
            } catch (e) {
              // 忽略无法解析的文件
            }
          }
        }
      }
    }
    
    // 按保存时间排序，最新的在前
    result.sort((a, b) {
      var aTime = a['savedAt'] ?? '';
      var bTime = b['savedAt'] ?? '';
      return bTime.toString().compareTo(aTime.toString());
    });
    
    return result;
  }

  /// 删除指定的评论文件
  static Future<bool> deleteComments(String sourceKey, String comicId, String epId) async {
    try {
      var file = File(
          "$_basePath/${_sanitize(sourceKey)}_${_sanitize(comicId)}/${_sanitize(epId)}.json");
      if (await file.exists()) {
        await file.delete();
        // 如果文件夹为空，删除文件夹
        var dir = Directory("$_basePath/${_sanitize(sourceKey)}_${_sanitize(comicId)}");
        var isEmpty = true;
        await for (var _ in dir.list()) {
          isEmpty = false;
          break;
        }
        if (isEmpty) {
          await dir.delete();
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// 删除整个漫画的所有评论
  static Future<bool> deleteComicComments(String sourceKey, String comicId) async {
    try {
      var dir = Directory("$_basePath/${_sanitize(sourceKey)}_${_sanitize(comicId)}");
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// 切换章节的锁定状态
  static Future<bool> toggleLock(String sourceKey, String comicId, String epId) async {
    try {
      var file = File(
          "$_basePath/${_sanitize(sourceKey)}_${_sanitize(comicId)}/${_sanitize(epId)}.json");
      if (!await file.exists()) return false;
      
      var content = await file.readAsString();
      var data = jsonDecode(content) as Map<String, dynamic>;
      var currentLock = data['isLocked'] == true;
      data['isLocked'] = !currentLock;
      data['savedAt'] = DateTime.now().toIso8601String();
      
      await file.writeAsString(jsonEncode(data));
      return !currentLock; // 返回新的锁定状态
    } catch (e) {
      return false;
    }
  }

  /// 获取章节的锁定状态
  static Future<bool> isLocked(String sourceKey, String comicId, String epId) async {
    try {
      var file = File(
          "$_basePath/${_sanitize(sourceKey)}_${_sanitize(comicId)}/${_sanitize(epId)}.json");
      if (!await file.exists()) return false;
      
      var content = await file.readAsString();
      var data = jsonDecode(content) as Map<String, dynamic>;
      return data['isLocked'] == true;
    } catch (e) {
      return false;
    }
  }

  /// 更新单条评论
  static Future<bool> updateComment(String sourceKey, String comicId, String epId, 
      String commentId, Map<String, dynamic> updatedComment) async {
    try {
      var file = File(
          "$_basePath/${_sanitize(sourceKey)}_${_sanitize(comicId)}/${_sanitize(epId)}.json");
      if (!await file.exists()) return false;
      
      var content = await file.readAsString();
      var data = jsonDecode(content) as Map<String, dynamic>;
      var comments = data['comments'] as List<dynamic>;
      
      var index = comments.indexWhere((c) => (c as Map<String, dynamic>)['id'] == commentId);
      if (index == -1) return false;
      
      comments[index] = updatedComment;
      data['savedAt'] = DateTime.now().toIso8601String();
      
      await file.writeAsString(jsonEncode(data));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 删除单条评论
  static Future<bool> deleteSingleComment(String sourceKey, String comicId, String epId, 
      String commentId) async {
    try {
      var file = File(
          "$_basePath/${_sanitize(sourceKey)}_${_sanitize(comicId)}/${_sanitize(epId)}.json");
      if (!await file.exists()) return false;
      
      var content = await file.readAsString();
      var data = jsonDecode(content) as Map<String, dynamic>;
      var comments = data['comments'] as List<dynamic>;
      
      var index = comments.indexWhere((c) => (c as Map<String, dynamic>)['id'] == commentId);
      if (index == -1) return false;
      
      comments.removeAt(index);
      data['savedAt'] = DateTime.now().toIso8601String();
      
      await file.writeAsString(jsonEncode(data));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 获取统计信息
  static Future<Map<String, dynamic>> getStats() async {
    var totalComics = 0;
    var totalChapters = 0;
    var totalSize = 0;
    
    var baseDir = Directory(_basePath);
    if (!await baseDir.exists()) {
      return {
        'totalComics': 0,
        'totalChapters': 0,
        'totalSize': 0,
      };
    }

    await for (var entity in baseDir.list()) {
      if (entity is Directory) {
        totalComics++;
        await for (var file in entity.list()) {
          if (file is File) {
            totalChapters++;
            totalSize += await file.length();
          }
        }
      }
    }

    return {
      'totalComics': totalComics,
      'totalChapters': totalChapters,
      'totalSize': totalSize,
    };
  }
}
