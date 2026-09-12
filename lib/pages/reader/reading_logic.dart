part of 'comic_reading_page.dart';

extension PageControllerExtension on PageController {
  void animatedJumpToPage(int page) {
    final current = this.page?.round() ?? 0;
    if ((current - page).abs() > 1) {
      jumpToPage(page > current ? page - 1 : page + 1);
    }
    animateToPage(page,
        duration: const Duration(milliseconds: 300), curve: Curves.ease);
  }

  void jumpByDeviceType(int page) {
    if (StateController.find<ComicReadingPageLogic>().mouseScroll) {
      jumpToPage(page);
    } else {
      animatedJumpToPage(page);
    }
  }
}

class ComicReadingPageLogic extends StateController {
  ///控制页面, 用于非从上至下(连续)阅读方式
  late PageController pageController;

  ///用于从上至下(连续)阅读方式, 跳转至指定项目
  var itemScrollController = ItemScrollController();

  ///用于从上至下(连续)阅读方式, 获取当前滚动到的元素的序号
  var itemScrollListener = ItemPositionsListener.create();

  ///用于从上至下(连续)阅读方式, 控制滚动
  var scrollController = ScrollController(keepScrollOffset: true);

  ///用于从上至下(连续)阅读方式, 获取放缩大小
  PhotoViewController get photoViewController =>
      photoViewControllers[index] ?? photoViewControllers[0]!;

  var photoViewControllers = <int, PhotoViewController>{};

  ListenVolumeController? listenVolume;

  ScrollManager? scrollManager;

  String? errorMessage;

  void clearPhotoViewControllers() {
    photoViewControllers.forEach((key, value) => value.dispose());
    photoViewControllers.clear();
  }

  bool noScroll = false;

  bool mouseScroll = false;

  double currentScale = 1.0;

  bool get isCtrlPressed => HardwareKeyboard.instance.isControlPressed;

  List<bool> requestedLoadingItems = [];

  bool haveUsedInitialPage = false;

  bool isOnChapterCommentsPage = false;

  /// 当前是否为连续滚动阅读模式
  bool get isContinuousMode =>
      readingMethod == ReadingMethod.topToBottomContinuously;

  /// 是否已滚动到本章开头(带 2px 容差, 避免浮点严格相等判断失效)
  bool get isAtScrollStart =>
      scrollController.hasClients &&
      scrollController.position.pixels <=
          scrollController.position.minScrollExtent + 2;

  /// 是否已滚动到本章末尾(带 2px 容差)
  bool get isAtScrollEnd =>
      scrollController.hasClients &&
      scrollController.position.pixels >=
          scrollController.position.maxScrollExtent - 2;

  /// 已滚动到章末且存在下一章
  bool get isAtChapterEnd =>
      isContinuousMode &&
      data.hasEp &&
      order < (data.eps?.length ?? 1) &&
      isAtScrollEnd;

  /// 已滚动到章首且存在上一章
  bool get isAtChapterStart =>
      isContinuousMode && data.hasEp && order > 1 && isAtScrollStart;

  /// 双页模式下是否在第一页时显示单页
  bool get singlePageForFirstScreen => appdata.implicitData[1] == '1';

  var focusNode = FocusNode();

  static int _getIndex(int initPage) {
    if (appdata.settings[9] == "5" || appdata.settings[9] == "6") {
      return initPage % 2 == 1 ? initPage : initPage - 1;
    } else {
      return initPage;
    }
  }

  static int _getPage(int initPage) {
    if (appdata.settings[9] == "5" || appdata.settings[9] == "6") {
      return (initPage + 2) ~/ 2;
    } else {
      return initPage;
    }
  }

  ComicReadingPageLogic(
      this.order, this.data, int initialPage, this.updateHistory) {
    if (initialPage <= 0) {
      initialPage = 1;
    }
    pageController = _createPageController(_getPage(initialPage));
    _index = _getIndex(initialPage);
    order <= 0 ? order = 1 : order;
    itemScrollListener.itemPositions.addListener(() {
      if (itemScrollListener.itemPositions.value.isEmpty) {
        return;
      }
      var newIndex = (itemScrollListener.itemPositions.value.first.index + 1)
          .clamp(1, urls.isEmpty ? 1 : urls.length);
      if (newIndex != index) {
        index = newIndex;
        update(["ToolBar"]);
      }
    });
  }

  PageController _createPageController(int initialPage) {
    final controller = PageController(initialPage: initialPage);
    controller.addListener(() {
      _syncIndexFromPageController();
    });
    return controller;
  }

  void _syncIndexFromPageController() {
    if (urls.isEmpty ||
        readingMethod == ReadingMethod.topToBottomContinuously ||
        !pageController.hasClients) {
      return;
    }
    final page = pageController.page?.round();
    if (page == null) {
      return;
    }
    int? newIndex;
    if (readingMethod.isTwoPage) {
      if (page <= 0) {
        return;
      }
      newIndex = singlePageForFirstScreen
          ? (page * 2 - 2).clamp(1, urls.length)
          : page * 2 - 1;
    } else {
      if (page <= 0 || page > urls.length) {
        return;
      }
      newIndex = page;
    }
    if (newIndex >= 1 && newIndex <= urls.length && newIndex != index) {
      index = newIndex;
    }
  }

  final void Function() updateHistory;

  ReadingData data;

  bool isLoading = true;

  ///旋转方向: null-跟随系统, false-竖向, true-横向
  bool? rotation;

  ///当前的页面, 0和最后一个为空白页, 用于进行章节跳转
  late int _index;

  ///当前的页面, 0和最后一个为空白页, 用于进行章节跳转
  int get index => _index;

  ///当前的页面, 0和最后一个为空白页, 用于进行章节跳转
  set index(int value) {
    if (_index == value) {
      return;
    }
    _index = value;
    for (var element in _indexChangeCallbacks) {
      element(value);
    }
    updateHistory();
    update(["ToolBar"]);
  }

  final _indexChangeCallbacks = <void Function(int)>[];

  void Function(int)? continuationIndexCallback;

  void addIndexChangeCallback(void Function(int) callback) {
    _indexChangeCallbacks.add(callback);
  }

  void removeIndexChangeCallback(void Function(int) callback) {
    _indexChangeCallbacks.remove(callback);
  }

  ///当前的章节位置, 从1开始
  int order;

  ///工具栏是否打开
  bool tools = false;

  ///是否显示设置窗口
  bool showSettings = false;

  ///所有的图片链接
  var urls = <String>[];

  void reload() {
    index = 1;
    isOnChapterCommentsPage = false;
    pageController = _createPageController(1);
    isLoading = true;
    requestedLoadingItems = [];
    update();
  }

  void change() {
    isLoading = !isLoading;
    update();
  }

  ReadingMethod get readingMethod =>
      ReadingMethod.values[int.parse(appdata.settings[9]) - 1];

  void jumpToNextPage() {
    if (isAtChapterEnd) {
      jumpToNextChapter();
      return;
    }
    if (readingMethod.index < 3) {
      pageController.jumpToPage(index + 1);
    } else if (readingMethod == ReadingMethod.topToBottomContinuously) {
      scrollController.jumpTo(scrollController.position.pixels + 600);
    } else {
      pageController.jumpToPage(pageController.page!.round() + 1);
    }
  }

  void jumpToLastPage() {
    if (isAtChapterStart) {
      jumpToLastChapter();
      return;
    }
    if (readingMethod.index < 3) {
      pageController.jumpToPage(index - 1);
    } else if (readingMethod == ReadingMethod.topToBottomContinuously) {
      scrollController.jumpTo(scrollController.position.pixels - 600);
    } else {
      pageController.jumpToPage(pageController.page!.round() - 1);
    }
  }

  void jumpToPage(int i, [bool updateWidget = false]) {
    i = i.clamp(1, length);
    if (readingMethod == ReadingMethod.topToBottomContinuously) {
      itemScrollController.jumpTo(index: i - 1);
    } else if (!readingMethod.isTwoPage) {
      pageController.jumpToPage(i);
    } else {
      var page = singlePageForFirstScreen ? i ~/ 2 + 1 : (i + 1) ~/ 2;
      pageController.jumpToPage(page);
    }
    if (index != i) {
      index = i;
    }
    if (updateWidget) {
      update(["ToolBar"]);
    }
  }

  void jumpByDeviceType(int page) {
    Future.microtask(() {
      if (mouseScroll) {
        pageController.jumpToPage(page);
      } else {
        pageController.animatedJumpToPage(page);
      }
    });
  }

  void jumpToNextChapter() {
    var eps = data.eps;
    if (!data.hasEp || order == eps?.length) {
      if (readingMethod != ReadingMethod.topToBottomContinuously) {
        if (readingMethod.index < 3) {
          jumpByDeviceType(urls.length);
        } else if (readingMethod == ReadingMethod.twoPage) {
          jumpByDeviceType((urls.length % 2 + urls.length) ~/ 2);
        }
      } else {
        jumpToPage(urls.length);
        index = urls.length;
        update(["ToolBar"]);
      }
      return;
    }
    order += 1;
    urls = [];
    isLoading = true;
    tools = false;
    index = 1;
    isOnChapterCommentsPage = false;
    pageController = _createPageController(1);
    requestedLoadingItems = [];
    clearPhotoViewControllers();
    update();
  }

  void jumpToChapter(int index) {
    order = index;
    urls = [];
    isLoading = true;
    tools = false;
    this.index = 1;
    isOnChapterCommentsPage = false;
    pageController = _createPageController(1);
    requestedLoadingItems = [];
    clearPhotoViewControllers();
    update();
  }

  void jumpToLastChapter() {
    if (order == 1 || !data.hasEp) {
      if (readingMethod != ReadingMethod.topToBottomContinuously) {
        jumpByDeviceType(1);
      } else {
        jumpToPage(1);
        index = 1;
        update(["ToolBar"]);
      }
      return;
    }

    order -= 1;
    urls = [];
    isLoading = true;
    tools = false;
    isOnChapterCommentsPage = false;
    pageController = _createPageController(1);
    index = 1;
    requestedLoadingItems = [];
    clearPhotoViewControllers();
    update();
  }

  ///当前章节的长度
  int get length => urls.length;

  /// 是否处于自动翻页状态
  bool runningAutoPageTurning = false;

  /// 自动翻页
  void autoPageTurning() async {
    if (index == urls.length - 1) {
      runningAutoPageTurning = false;
      update();
      return;
    }
    int sec = int.parse(appdata.settings[33]);
    for (int i = 0; i < sec * 10; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!runningAutoPageTurning) {
        return;
      }
    }
    jumpToNextPage();
    autoPageTurning();
  }

  void refresh_() {
    pageController = _createPageController(1);
    itemScrollController = ItemScrollController();
    itemScrollListener = ItemPositionsListener.create();
    scrollController = ScrollController(keepScrollOffset: true);
    clearPhotoViewControllers();
    noScroll = false;
    currentScale = 1.0;
    index = 1;
    urls.clear();
    isLoading = true;
    tools = false;
    showSettings = false;
    requestedLoadingItems = [];
    update();
  }

  bool isFullScreen = false;
  Rect? _preFullscreenRect;
  bool _wasMaximized = false;

  void fullscreen() async {
    if (App.isDesktop) {
      if (isFullScreen) {
        isFullScreen = false;
        await windowManager.setFullScreen(false);
        if (_wasMaximized) {
          await windowManager.maximize();
        } else if (_preFullscreenRect != null) {
          await windowManager.setBounds(_preFullscreenRect!);
        }
      } else {
        isFullScreen = true;
        _wasMaximized = await windowManager.isMaximized();
        if (!_wasMaximized) {
          _preFullscreenRect = await windowManager.getBounds();
        }
        await windowManager.setFullScreen(true);
      }
    } else {
      const channel = MethodChannel("pica_comic/full_screen");
      channel.invokeMethod("set", !isFullScreen);
      isFullScreen = !isFullScreen;
    }
    WindowFrame.of(App.globalContext!).setWindowFrame(!isFullScreen);
    focusNode.requestFocus();
  }

  void handleKeyboard(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      bool reverse = appdata.settings[9] == "2" || appdata.settings[9] == "6";
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowDown:
        case LogicalKeyboardKey.arrowRight:
          reverse ? jumpToLastPage() : jumpToNextPage();
        case LogicalKeyboardKey.arrowUp:
        case LogicalKeyboardKey.arrowLeft:
          reverse ? jumpToNextPage() : jumpToLastPage();
        case LogicalKeyboardKey.f12:
          fullscreen();
      }
    }
  }

  late final void Function() openEpsView;
}
