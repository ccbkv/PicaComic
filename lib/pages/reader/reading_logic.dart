part of 'comic_reading_page.dart';

/// 连续滚动模式下切换章节所需的持续滑动距离(逻辑像素)。
///
/// 与原实现的手感保持一致: 原先按 `fABValue -= dy / 3` 累计并在 58 处触发,
/// 即需要约 174px 的持续位移。
const double _kChargeDistance = 180;

/// 键盘 / 点击翻页 / 自动翻页等离散操作每次折算的蓄力距离(约 3 次充满)。
const double _kDiscreteChargeStep = _kChargeDistance / 3;

/// 鼠标滚轮每格折算的蓄力距离(约 5 格充满)。
///
/// 不直接使用 `scrollDelta.dy` —— 各平台与触控板的数值差异很大, 固定步长
/// 才能保证手感一致。
const double _kWheelChargeStep = _kChargeDistance / 5;

/// 章节边界蓄力状态机(仅用于连续滚动模式)。
///
/// 滚动到章节边界后继续朝同一方向滑动会累积蓄力距离, 累计到
/// [_kChargeDistance] 时切换章节, 中途停止则进度自动回落。
/// 相比原先直接用 [ComicReadingPageLogic.fABValue] 计数的做法, 这里:
/// - 用带容差的比较代替 `pixels == maxScrollExtent` 的浮点严格相等判断;
/// - 不依赖悬浮按钮状态(showFloatingButtonValue), 按钮只负责显示进度;
/// - 停止滑动约 2 秒后进度自动回落, 而不是只在松手时清零;
/// - 触摸拖动 / 鼠标滚轮 / 键盘翻页共用同一套进度;
/// - 上一章与下一章各持有一个实例, 两个方向都可用。
class ChapterEndCharge {
  /// 已累计的滑动距离(逻辑像素)。
  ///
  /// 直接累加像素而不是累加 0~1 的比例, 避免浮点误差随事件数量放大 ——
  /// 触摸拖动一次切章会产生上百个 pointer move 事件。
  double _charged = 0;

  /// 上次推进进度的时间
  DateTime _lastChargeTime = DateTime.now();

  Timer? _decayTimer;

  /// 进度变化回调(参数为 0~1 的进度值), 用于刷新 UI
  void Function(double value)? onChanged;

  /// 是否正在蓄力(已累计了滑动距离)
  bool get isActive => _charged > 0;

  /// 当前进度(0~1)
  double get value => (_charged / _kChargeDistance).clamp(0.0, 1.0);

  /// 停止操作后进度开始回落的延时
  static const Duration _decayDelay = Duration(milliseconds: 2000);

  /// 推进蓄力进度。[pixels] 为本次操作的滑动距离(逻辑像素)。
  ///
  /// 距离严格按实际位移累计且不设下限 —— 触摸拖动每秒会产生几十个
  /// pointer move 事件, 单次位移往往只有 1~2px, 一旦给增量设下限就会在
  /// 极短的位移内把进度推满, 造成误切章。
  /// 非正数(反向滑动 / 无位移)直接忽略。
  ///
  /// 返回 true 表示已充满并应触发切章(由调用方执行跳转)。
  bool advance(double pixels) {
    if (pixels <= 0) {
      return false;
    }
    final now = DateTime.now();
    if (_charged > 0 && now.difference(_lastChargeTime) > _decayDelay) {
      // 距上次蓄力已超过回落时长, 视为重新开始
      _charged = 0;
      onChanged?.call(0);
    }
    _lastChargeTime = now;
    _cancelDecay();
    _charged += pixels;
    if (_charged >= _kChargeDistance) {
      reset();
      return true;
    }
    onChanged?.call(value);
    return false;
  }

  /// 启动回落计时: 停止蓄力约 2 秒后进度归零
  void scheduleDecay() {
    if (_charged <= 0) {
      return;
    }
    _cancelDecay();
    _decayTimer = Timer(_decayDelay, reset);
  }

  /// 立即归零(切章 / 重载 / 滚离边界等场景)
  void reset() {
    _cancelDecay();
    if (_charged != 0) {
      _charged = 0;
      onChanged?.call(0);
    }
    _lastChargeTime = DateTime.now();
  }

  /// 退出阅读器时释放计时器, 不触发回调(此时 UI 已销毁)
  void dispose() {
    _cancelDecay();
    onChanged = null;
    _charged = 0;
  }

  void _cancelDecay() {
    _decayTimer?.cancel();
    _decayTimer = null;
  }
}

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

  /// 蓄力切到下一章
  final chapterEndCharge = ChapterEndCharge();

  /// 蓄力切到上一章
  final chapterStartCharge = ChapterEndCharge();

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

  /// 已滚动到章末且存在下一章 —— 此时继续向上滑动进入蓄力而不是直接切章
  bool get isAtChapterEnd =>
      isContinuousMode &&
      data.hasEp &&
      order < (data.eps?.length ?? 1) &&
      isAtScrollEnd;

  /// 已滚动到章首且存在上一章 —— 此时继续向下滑动进入蓄力而不是直接切章
  bool get isAtChapterStart =>
      isContinuousMode && data.hasEp && order > 1 && isAtScrollStart;

  /// 推进「下一章」蓄力, [pixels] 为本次操作折算的滑动像素。
  /// 返回 true 表示已充满并已切章。
  bool chargeForNextChapter(double pixels) {
    if (!isAtChapterEnd) {
      return false;
    }
    // 两个方向共用悬浮按钮显示进度, 同一时刻只允许一个方向在蓄力
    chapterStartCharge.reset();
    _ensureFloatingButton(1);
    if (chapterEndCharge.advance(pixels)) {
      jumpToNextChapter();
      return true;
    }
    return false;
  }

  /// 推进「上一章」蓄力, [pixels] 为本次操作折算的滑动像素。
  /// 返回 true 表示已充满并已切章。
  bool chargeForLastChapter(double pixels) {
    if (!isAtChapterStart) {
      return false;
    }
    chapterEndCharge.reset();
    _ensureFloatingButton(-1);
    if (chapterStartCharge.advance(pixels)) {
      jumpToLastChapter();
      return true;
    }
    return false;
  }

  /// 让悬浮按钮指向正在蓄力的方向。
  ///
  /// 不能直接用 [showFloatingButton] —— 它只在按钮当前隐藏时才生效, 而本章
  /// 内容不足一屏时首末位置重合, 两个方向都可蓄力, 按钮需要跟着切换朝向;
  /// 另外此时列表从未滚动过, 不会有 ScrollUpdateNotification 把按钮显示出来。
  void _ensureFloatingButton(int value) {
    if (showFloatingButtonValue != value) {
      showFloatingButtonValue = value;
      update();
    }
  }

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
      var newIndex = itemScrollListener.itemPositions.value.first.index + 1;
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

  ///是否应该显示悬浮按钮, 为-1表示显示上一章, 为0表示不显示, 为1表示显示下一章
  int showFloatingButtonValue = 0;

  double fABValue = 0;

  void showFloatingButton(int value) {
    if (value == 0) {
      if (showFloatingButtonValue != 0) {
        showFloatingButtonValue = 0;
        fABValue = 0;
        update();
      }
    }
    if (value == 1 && showFloatingButtonValue == 0) {
      showFloatingButtonValue = 1;
      update();
    } else if (value == -1 && showFloatingButtonValue == 0 && order != 1) {
      showFloatingButtonValue = -1;
      update();
    }
  }

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
    chapterEndCharge.reset();
    chapterStartCharge.reset();
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
    // 连续滚动模式滚到章末时, 离散翻页操作先蓄力, 充满才切章
    if (isAtChapterEnd) {
      chargeForNextChapter(_kDiscreteChargeStep);
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
    // 连续滚动模式滚到章首时, 离散翻页操作先蓄力, 充满才切章
    if (isAtChapterStart) {
      chargeForLastChapter(_kDiscreteChargeStep);
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
    showFloatingButtonValue = 0;
    chapterEndCharge.reset();
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
    showFloatingButtonValue = 0;
    chapterStartCharge.reset();
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
    showFloatingButtonValue = 0;
    chapterEndCharge.reset();
    chapterStartCharge.reset();
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
