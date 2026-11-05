part of 'comic_reading_page.dart';

extension ToolBar on ComicReadingPage {
  bool get isReversed =>
      appdata.settings[9] == "2" || appdata.settings[9] == "6";

  Widget _buildToolIconButton({
    required BuildContext context,
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
    double iconSize = 24,
  }) {
    final button = enableLiquidGlassUi
        ? GlassIconActionButton(
            icon: icon,
            tooltip: tooltip,
            onTap: onPressed,
            size: 40,
          )
        : IconButton(
            iconSize: iconSize,
            icon: Icon(icon),
            onPressed: onPressed,
          );
    return Tooltip(
      message: tooltip,
      child: button,
    );
  }

  Widget _buildToolbarJumpButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    if (enableLiquidGlassUi) {
      return GlassIconActionButton(
        icon: icon,
        tooltip: "",
        onTap: onPressed,
        size: 40,
      );
    }
    return IconButton.filledTonal(
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }

  Widget _buildToolbarSurface({
    required BuildContext context,
    required Widget child,
    required EdgeInsetsGeometry padding,
    required bool top,
  }) {
    if (enableLiquidGlassUi) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          8 + MediaQuery.of(context).padding.left,
          top ? 8 : 0,
          8 + MediaQuery.of(context).padding.right,
          top ? 0 : 8,
        ),
        child: GlassSurfaceLite(
          borderRadius: 26,
          padding: padding,
          child: child,
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: top
              ? BorderSide.none
              : BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 0.6,
                ),
          bottom: top
              ? BorderSide(
                  color: Colors.grey.toOpacity(0.5),
                  width: 0.5,
                )
              : BorderSide.none,
        ),
      ),
      padding: padding,
      child: child,
    );
  }

  ///构建底部工具栏
  Widget buildBottomToolBar(
      ComicReadingPageLogic logic, BuildContext context, bool showEps) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: StateBuilder<ComicReadingPageLogic>(
        id: "ToolBar",
        builder: (logic) {
          var text = "E${logic.order} : P${logic.index}";
          if (logic.order == 0) {
            text = "P${logic.index}";
          }

          Widget child = SizedBox(
            height: 105 + MediaQuery.of(context).padding.bottom,
            child: Column(
              children: [
                const SizedBox(
                  height: 8,
                ),
                Row(
                  children: [
                    const SizedBox(
                      width: 8,
                    ),
                    _buildToolbarJumpButton(
                      context: context,
                      icon: Icons.first_page,
                      onPressed: () => !isReversed
                          ? logic.jumpToLastChapter()
                          : logic.jumpToNextChapter(),
                    ),
                    Expanded(
                      child: buildSlider(logic),
                    ),
                    _buildToolbarJumpButton(
                      context: context,
                      icon: Icons.last_page,
                      onPressed: () => !isReversed
                          ? logic.jumpToNextChapter()
                          : logic.jumpToLastChapter(),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                  ],
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final buttons = <Widget>[
                      _buildToolIconButton(
                        context: context,
                        tooltip: "收藏图片".tl,
                        icon: Icons.favorite_outline,
                        onPressed: () async {
                          try {
                            final id =
                                "${logic.data.sourceKey}-${logic.data.id}";
                            var image = await _persistentCurrentImage();
                            if (image != null) {
                              image = image.split("/").last;
                              var otherInfo = <String, dynamic>{};
                              if (logic.data.type == ReadingType.ehentai) {
                                otherInfo["gallery"] =
                                    (logic.data as EhReadingData)
                                        .gallery
                                        .toJson();
                              } else if (logic.data.type ==
                                  ReadingType.hitomi) {
                                otherInfo["hitomi"] =
                                    (readingData as HitomiReadingData)
                                        .images
                                        .map((e) => e.toMap())
                                        .toList();
                                otherInfo["galleryId"] = readingData.id;
                              } else if (logic.data.type == ReadingType.jm) {
                                otherInfo["jmEpNames"] =
                                    readingData.eps!.values.toList();
                                otherInfo["epsId"] = readingData.eps!.keys
                                        .elementAtOrNull(logic.order - 1) ??
                                    readingData.id;
                                otherInfo["bookId"] = readingData.id;
                              }
                              if (logic.data.type != ComicType.other) {
                                otherInfo["eps"] =
                                    readingData.eps?.keys.toList() ?? [];
                              } else {
                                otherInfo["eps"] = readingData.eps;
                              }
                              otherInfo["url"] = logic.urls[logic.index - 1];
                              otherInfo["epTotalPages"] = logic.urls.length;
                              var favorite = ImageFavorite(
                                  id,
                                  image,
                                  readingData.title,
                                  logic.order,
                                  logic.index,
                                  otherInfo);
                              if (!ImageFavoriteManager.exist(
                                  id, logic.order, logic.index)) {
                                ImageFavoriteManager.add(favorite);
                                showToast(message: "已添加至图片收藏".tl);
                              } else {
                                ImageFavoriteManager.delete(favorite);
                                showToast(message: "已取消图片收藏".tl);
                              }
                            }
                          } catch (e) {
                            showToast(message: e.toString());
                          }
                        },
                      ),
                      if (App.isWindows)
                        _buildToolIconButton(
                          context: context,
                          tooltip: "${"全屏".tl}(F12)",
                          icon: Icons.fullscreen,
                          onPressed: () {
                            logic.fullscreen();
                          },
                        ),
                      if (App.isAndroid && appdata.settings[76] == "0")
                        _buildToolIconButton(
                          context: context,
                          tooltip: "屏幕方向".tl,
                          icon: logic.rotation == null
                              ? Icons.screen_rotation_alt
                              : logic.rotation == false
                                  ? Icons.screen_lock_portrait
                                  : Icons.screen_lock_landscape,
                          onPressed: () {
                            if (logic.rotation == null) {
                              logic.rotation = false;
                              logic.update();
                              SystemChrome.setPreferredOrientations([
                                DeviceOrientation.portraitUp,
                                DeviceOrientation.portraitDown,
                              ]);
                            } else if (logic.rotation == false) {
                              logic.rotation = true;
                              logic.update();
                              SystemChrome.setPreferredOrientations([
                                DeviceOrientation.landscapeLeft,
                                DeviceOrientation.landscapeRight
                              ]);
                            } else {
                              logic.rotation = null;
                              logic.update();
                              SystemChrome.setPreferredOrientations(
                                  DeviceOrientation.values);
                            }
                          },
                        ),
                      _buildToolIconButton(
                        context: context,
                        tooltip: "自动翻页".tl,
                        icon: logic.runningAutoPageTurning
                            ? Icons.timer
                            : Icons.timer_sharp,
                        onPressed: () {
                          logic.runningAutoPageTurning =
                              !logic.runningAutoPageTurning;
                          logic.update();
                          logic.autoPageTurning();
                        },
                      ),
                      if (showEps)
                        _buildToolIconButton(
                          context: context,
                          tooltip: "章节".tl,
                          icon: Icons.library_books,
                          onPressed: openEpsDrawer,
                        ),
                      _buildToolIconButton(
                        context: context,
                        tooltip: "保存图片".tl,
                        icon: Icons.download,
                        onPressed: saveCurrentImage,
                      ),
                      _buildToolIconButton(
                        context: context,
                        tooltip: "分享".tl,
                        icon: Icons.share,
                        onPressed: share,
                      ),
                    ];

                    final small =
                        (constraints.maxWidth - buttons.length * 50) < 120;
                    final pageTag = enableLiquidGlassUi
                        ? GlassChipTag(label: text)
                        : Container(
                            height: 24,
                            padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .tertiaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(child: Text(text)),
                          );

                    if (enableLiquidGlassUi && small) {
                      return Row(
                        children: [
                          const SizedBox(width: 8),
                          Flexible(
                            fit: FlexFit.loose,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 84),
                              child: pageTag,
                            ),
                          ),
                          const SizedBox(width: 4),
                          for (var button in buttons)
                            button.paddingHorizontal(2),
                          const SizedBox(width: 4),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        if (!small) pageTag.paddingLeft(16),
                        const Spacer(),
                        for (var button in buttons)
                          if (!small)
                            button.paddingHorizontal(4)
                          else ...[button, const Spacer()],
                        if (!small) const SizedBox(width: 4),
                      ],
                    );
                  },
                )
              ],
            ),
          );

          child = _buildToolbarSurface(
            context: context,
            top: false,
            padding: EdgeInsets.only(
              left: MediaQuery.of(context).padding.left,
              right: MediaQuery.of(context).padding.right,
            ),
            child: child,
          );

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            reverseDuration: const Duration(milliseconds: 150),
            switchInCurve: Curves.fastOutSlowIn,
            transitionBuilder: (Widget child, Animation<double> animation) {
              var tween = Tween<Offset>(
                  begin: const Offset(0, 1), end: const Offset(0, 0));
              return SlideTransition(
                position: tween.animate(animation),
                child: child,
              );
            },
            child: logic.tools
                ? child
                : const SizedBox(
                    width: 0,
                    height: 0,
                  ),
          );
        },
      ),
    );
  }

  Widget buildSlider(ComicReadingPageLogic logic) {
    if (logic.tools &&
        logic.index != 0 &&
        logic.index != logic.urls.length + 1) {
      return CustomSlider(
        value: logic.index.toDouble(),
        min: 1,
        reversed: isReversed,
        max: logic.urls.length.toDouble(),
        divisions: (logic.urls.length - 1).clamp(2, 1 << 16),
        onChanged: (i) {
          if (logic.readingMethod == ReadingMethod.topToBottomContinuously) {
            logic.jumpToPage(i.toInt());
            logic.index = i.toInt();
            logic.update();
          } else {
            logic.index = i.toInt();
            logic.jumpToPage(i.toInt());
            logic.update();
          }
        },
      );
    } else {
      return const SizedBox(
        height: 0,
      );
    }
  }

  Iterable<Widget> buildButtons(
      ComicReadingPageLogic logic, BuildContext context) sync* {
    if (context.width > context.height &&
        appdata.appSettings.showButtonsInReader) {
      if (appdata.settings[9] != "4" &&
          logic.readingMethod != ReadingMethod.topToBottom) {
        yield Positioned(
          left: 12,
          top: MediaQuery.of(context).size.height / 2 - 25,
          child: Button.icon(
            icon: const Icon(Icons.keyboard_arrow_left),
            onPressed: () {
              if (appdata.appSettings.flipPageWithClick) {
                return;
              }
              switch (logic.readingMethod) {
                case ReadingMethod.rightToLeft:
                case ReadingMethod.twoPageReversed:
                  logic.jumpToNextPage();
                default:
                  logic.jumpToLastPage();
              }
            },
            size: 24,
          ),
        );
      }
      if (appdata.settings[9] != "4" &&
          logic.readingMethod != ReadingMethod.topToBottom) {
        yield Positioned(
          right: 12,
          top: MediaQuery.of(context).size.height / 2 - 25,
          child: Button.icon(
            icon: const Icon(Icons.keyboard_arrow_right),
            onPressed: () {
              if (appdata.settings[0] == "1") {
                return;
              }
              switch (logic.readingMethod) {
                case ReadingMethod.rightToLeft:
                case ReadingMethod.twoPageReversed:
                  logic.jumpToLastPage();
                default:
                  logic.jumpToNextPage();
              }
            },
            size: 24,
          ),
        );
      }
      yield Positioned(
        left: 4,
        top: 4 + MediaQuery.of(context).padding.top,
        child: _buildToolIconButton(
          context: context,
          tooltip: "关闭".tl,
          icon: Icons.close,
          onPressed: () => App.globalBack(),
        ),
      );
    }
  }

  ///构建顶部工具栏
  Widget buildTopToolBar(
      ComicReadingPageLogic comicReadingPageLogic, BuildContext context) {
    return Positioned(
      top: 0,
      child: StateBuilder<ComicReadingPageLogic>(
        id: "ToolBar",
        builder: (logic) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          reverseDuration: const Duration(milliseconds: 150),
          switchInCurve: Curves.fastOutSlowIn,
          child: comicReadingPageLogic.tools
              ? _buildToolbarSurface(
                  context: context,
                  top: true,
                  padding: EdgeInsets.only(
                    left: MediaQuery.of(context).padding.left,
                    right: MediaQuery.of(context).padding.right,
                  ),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width -
                        MediaQuery.of(context).padding.left -
                        MediaQuery.of(context).padding.right,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                          child: _buildToolIconButton(
                            context: context,
                            tooltip: "返回".tl,
                            icon: Icons.arrow_back_outlined,
                            onPressed: () => App.globalBack(),
                            iconSize: 25,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 50,
                            constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width - 75),
                            child: Builder(builder: (context) {
                              var epName = readingData.eps?.values
                                  .elementAtOrNull(
                                      comicReadingPageLogic.order - 1);
                              if (epName == null) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    readingData.title,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                );
                              } else {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      readingData.title,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    Text(
                                      epName,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                );
                              }
                            }),
                          ),
                        ),
                        //const Spacer(),

                        if (_shouldShowChapterComments())
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
                            child: _buildToolIconButton(
                              context: context,
                              tooltip: "章节评论".tl,
                              icon: Icons.comment,
                              onPressed: () => _openChapterComments(context),
                              iconSize: 25,
                            ),
                          ),
                        ...buildTranslationControls(
                            comicReadingPageLogic, context),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                          child: _buildToolIconButton(
                            context: context,
                            tooltip: "阅读设置".tl,
                            icon: Icons.settings,
                            onPressed: () => showSettings(context),
                            iconSize: 25,
                          ),
                        ),
                      ],
                    ),
                  ).paddingTop(MediaQuery.of(context).padding.top),
                )
              : const SizedBox(
                  width: 0,
                  height: 0,
                ),
          transitionBuilder: (Widget child, Animation<double> animation) {
            var tween = Tween<Offset>(
                begin: const Offset(0, -1), end: const Offset(0, 0));
            return SlideTransition(
              position: tween.animate(animation),
              child: child,
            );
          },
        ),
      ),
    );
  }

  ({List<String> cacheKeys, InpaintMode mode})? _currentTranslationTargets(
      ComicReadingPageLogic logic) {
    if (!ImageTranslationService.enabledFor(
            logic.data.id, logic.data.sourceKey) ||
        logic.urls.isEmpty) {
      return null;
    }

    var pages = <int>{};
    if (logic.isContinuousMode) {
      for (var position in logic.itemScrollListener.itemPositions.value) {
        var page = position.index + 1;
        if (page >= 1 && page <= logic.urls.length) pages.add(page);
      }
    }
    if (pages.isEmpty && logic.index >= 1 && logic.index <= logic.urls.length) {
      pages.add(logic.index);
      if (logic.readingMethod.isTwoPage &&
          !(logic.index == 1 && logic.singlePageForFirstScreen) &&
          logic.index < logic.urls.length) {
        pages.add(logic.index + 1);
      }
    }
    if (pages.isEmpty) return null;

    var data = logic.data;
    var eid = data.hasEp
        ? data.eps?.keys.elementAtOrNull(logic.order - 1) ?? '0'
        : '0';
    return (
      cacheKeys: [
        for (var page in pages)
          ImageTranslationService.cacheKeyFor(
              data.sourceKey, data.id, eid, page),
      ],
      mode: TranslationConfig.of(data.id, data.sourceKey).mode,
    );
  }

  /// 与 Venera 一致：原图/译文切换、失败重试和当前屏幕页面的翻译进度。
  List<Widget> buildTranslationControls(
      ComicReadingPageLogic logic, BuildContext context) {
    if (!ImageTranslationService.enabledFor(
        logic.data.id, logic.data.sourceKey)) {
      return const [];
    }
    var service = ImageTranslationService.instance;
    var targets = _currentTranslationTargets(logic);
    var widgets = <Widget>[];

    widgets.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
        child: _buildToolIconButton(
          context: context,
          tooltip: logic.showOriginalPages
              ? "Show translated".tl
              : "Show original".tl,
          icon:
              logic.showOriginalPages ? Icons.translate : Icons.image_outlined,
          onPressed: logic.toggleShowOriginalPages,
        ),
      ),
    );

    if (targets != null && !logic.showOriginalPages) {
      PageTranslationStatus statusOf(String key) =>
          service.statusOf(key, targets.mode);
      var failed = [
        for (var key in targets.cacheKeys)
          if (statusOf(key) == PageTranslationStatus.failed) key,
      ];
      if (failed.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
            child: Tooltip(
              message: service.errorOf(failed.first, targets.mode) ??
                  "Translation failed".tl,
              child: IconButton(
                icon: Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => _retryTranslation(logic, failed, targets.mode),
              ),
            ),
          ),
        );
      } else if (targets.cacheKeys.any(
        (key) => statusOf(key) == PageTranslationStatus.translating,
      )) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  void _retryTranslation(
      ComicReadingPageLogic logic, List<String> cacheKeys, InpaintMode mode) {
    var service = ImageTranslationService.instance;
    var error = service.errorOf(cacheKeys.first, mode);
    for (var key in cacheKeys) {
      service.clearFailure(key, mode);
    }
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    logic.refreshTranslatedImages();
    logic.update(["ToolBar"]);
    if (error != null) showToast(message: error);
  }

  bool _shouldShowChapterComments() {
    if (!readingData.hasEp ||
        readingData.eps == null ||
        readingData.eps!.isEmpty) {
      return false;
    }

    var showChapterComments =
        appdata.settings.length > 92 && appdata.settings[92] == "1";
    if (!showChapterComments) return false;

    var source = ComicSource.find(readingData.sourceKey);
    if (source == null || source.chapterCommentsLoader == null) return false;

    return true;
  }

  bool _shouldShowChapterCommentsAtEnd() {
    if (!_shouldShowChapterComments()) return false;
    var readingMethod =
        ReadingMethod.values[int.parse(appdata.settings[9]) - 1];
    if (readingMethod != ReadingMethod.leftToRight &&
        readingMethod != ReadingMethod.rightToLeft &&
        readingMethod != ReadingMethod.topToBottom) {
      return false;
    }
    return appdata.settings.length > 99 && appdata.settings[99] == "1";
  }

  void _openChapterComments(BuildContext context) {
    var source = ComicSource.find(readingData.sourceKey);
    if (source == null) return;

    var logic = StateController.find<ComicReadingPageLogic>();
    var epId = readingData.eps!.keys.elementAt(logic.order - 1);
    var chapterTitle = readingData.eps!.values.elementAt(logic.order - 1);

    showSideBar(
      context,
      ChapterCommentsPage(
        comicId: readingData.id,
        epId: epId,
        source: source,
        comicTitle: readingData.title,
        chapterTitle: chapterTitle,
      ),
    );
  }

  ///显示当前的章节和页面位置
  Widget buildPageInfoText(ComicReadingPageLogic _, BuildContext context) {
    return Positioned(
      bottom: 13,
      left: 25,
      child: StateBuilder<ComicReadingPageLogic>(
        id: "ToolBar",
        builder: (logic) {
          var epName =
              readingData.eps?.values.elementAtOrNull(logic.order - 1) ?? "E1";
          if (epName.length > 8) {
            epName = "${epName.substring(0, 8)}...";
          }
          var text = readingData.hasEp
              ? "$epName : ${logic.index}/${logic.urls.length}"
              : "${logic.index}/${logic.urls.length}";
          return Stack(
            children: [
              Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 1.4
                    ..color = (useDarkBackground ||
                            Theme.of(context).brightness == Brightness.dark)
                        ? Colors.black
                        : Colors.white,
                ),
              ),
              Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: useDarkBackground ? Colors.white : null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget buildStatusInfo(ComicReadingPageLogic logic, BuildContext context) {
    return Positioned(
      bottom: 13,
      right: 25,
      child: Row(
        children: [
          _ClockWidget(),
          const SizedBox(width: 10),
          _BatteryWidget(),
        ],
      ),
    );
  }
}

class _BatteryWidget extends StatefulWidget {
  @override
  _BatteryWidgetState createState() => _BatteryWidgetState();
}

class _BatteryWidgetState extends State<_BatteryWidget> {
  late int _batteryLevel = 100;
  Timer? _timer;
  bool _hasBattery = false;
  bool _isCharging = false;

  @override
  void initState() {
    super.initState();
    _checkBatteryAvailability();
  }

  void _checkBatteryAvailability() async {
    final status = await _readBatteryStatus();
    if (!mounted || status == null) {
      return;
    }
    setState(() {
      _batteryLevel = status.$1;
      _isCharging = status.$2;
      _hasBattery = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      final status = await _readBatteryStatus();
      if (!mounted || status == null) {
        return;
      }
      if (_batteryLevel != status.$1 || _isCharging != status.$2) {
        setState(() {
          _batteryLevel = status.$1;
          _isCharging = status.$2;
        });
      }
    });
  }

  Future<(int, bool)?> _readBatteryStatus() async {
    if (OhosBatteryBridge.isSupported) {
      final status = await OhosBatteryBridge.read();
      if (status == null) {
        return null;
      }
      return (status.level, status.charging);
    }
    try {
      final battery = Battery();
      final level = await battery.batteryLevel;
      final state = await battery.batteryState;
      if (level <= 0 && state == BatteryState.unknown) {
        return null;
      }
      final charging =
          state == BatteryState.charging || state == BatteryState.full;
      return (level, charging);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasBattery) {
      return const SizedBox.shrink();
    }
    return _batteryInfo(_batteryLevel);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _batteryInfo(int batteryLevel) {
    IconData batteryIcon;
    Color batteryColor = Theme.of(context).colorScheme.onSurface;

    if (_isCharging) {
      batteryIcon = Icons.battery_charging_full;
    } else if (batteryLevel >= 96) {
      batteryIcon = Icons.battery_full_sharp;
    } else if (batteryLevel >= 84) {
      batteryIcon = Icons.battery_6_bar_sharp;
    } else if (batteryLevel >= 72) {
      batteryIcon = Icons.battery_5_bar_sharp;
    } else if (batteryLevel >= 60) {
      batteryIcon = Icons.battery_4_bar_sharp;
    } else if (batteryLevel >= 48) {
      batteryIcon = Icons.battery_3_bar_sharp;
    } else if (batteryLevel >= 36) {
      batteryIcon = Icons.battery_2_bar_sharp;
    } else if (batteryLevel >= 24) {
      batteryIcon = Icons.battery_1_bar_sharp;
    } else if (batteryLevel >= 12) {
      batteryIcon = Icons.battery_0_bar_sharp;
    } else {
      batteryIcon = Icons.battery_alert_sharp;
      batteryColor = Colors.red;
    }

    return Row(
      children: [
        Icon(
          batteryIcon,
          size: 16,
          color: batteryColor,
          shadows: List.generate(9, (index) {
            if (index == 4) {
              return null;
            }
            double offsetX = (index % 3 - 1) * 0.8;
            double offsetY = ((index / 3).floor() - 1) * 0.8;
            return Shadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black
                  : Colors.white,
              offset: Offset(offsetX, offsetY),
            );
          }).whereType<Shadow>().toList(),
        ),
        Stack(
          children: [
            Text(
              '$batteryLevel%',
              style: TextStyle(
                fontSize: 14,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.4
                  ..color = Theme.of(context).brightness == Brightness.dark
                      ? Colors.black
                      : Colors.white,
              ),
            ),
            Text('$batteryLevel%'),
          ],
        ),
      ],
    );
  }
}

class _ClockWidget extends StatefulWidget {
  @override
  _ClockWidgetState createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<_ClockWidget> {
  late String _currentTime;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _currentTime = _getCurrentTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final time = _getCurrentTime();
      if (_currentTime != time) {
        setState(() {
          _currentTime = time;
        });
      }
    });
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          _currentTime,
          style: TextStyle(
            fontSize: 14,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = Theme.of(context).brightness == Brightness.dark
                  ? Colors.black
                  : Colors.white,
          ),
        ),
        Text(_currentTime),
      ],
    );
  }
}
