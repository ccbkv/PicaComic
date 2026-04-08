part of 'comic_reading_page.dart';

extension ToolBar on ComicReadingPage {
  bool get isReversed => appdata.settings[9] == "2" || appdata.settings[9] == "6";

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
                    IconButton.filledTonal(
                        onPressed: () => !isReversed
                            ? logic.jumpToLastChapter()
                            : logic.jumpToNextChapter(),
                        icon: const Icon(Icons.first_page)),
                    Expanded(
                      child: buildSlider(logic),
                    ),
                    IconButton.filledTonal(
                        onPressed: () => !isReversed
                            ? logic.jumpToNextChapter()
                            : logic.jumpToLastChapter(),
                        icon: const Icon(Icons.last_page)),
                    const SizedBox(
                      width: 8,
                    ),
                  ],
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final buttons = <Widget>[
                      Tooltip(
                        message: "收藏图片".tl,
                        child: IconButton(
                          icon: const Icon(Icons.favorite_outline),
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
                                      .elementAt(logic.index - 1);
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
                                if (!ImageFavoriteManager.exist(id, logic.order, logic.index)) {
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
                      ),
                      if (App.isWindows)
                        Tooltip(
                          message: "${"全屏".tl}(F12)",
                          child: IconButton(
                            icon: const Icon(Icons.fullscreen),
                            onPressed: () {
                              logic.fullscreen();
                            },
                          ),
                        ),
                      if (App.isAndroid && appdata.settings[76] == "0")
                        Tooltip(
                          message: "屏幕方向".tl,
                          child: IconButton(
                            icon: () {
                              if (logic.rotation == null) {
                                return const Icon(Icons.screen_rotation_alt);
                              } else if (logic.rotation == false) {
                                return const Icon(Icons.screen_lock_portrait);
                              } else {
                                return const Icon(Icons.screen_lock_landscape);
                              }
                            }.call(),
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
                        ),
                      Tooltip(
                        message: "自动翻页".tl,
                        child: IconButton(
                          icon: logic.runningAutoPageTurning
                              ? const Icon(Icons.timer)
                              : const Icon(Icons.timer_sharp),
                          onPressed: () {
                            logic.runningAutoPageTurning =
                                !logic.runningAutoPageTurning;
                            logic.update();
                            logic.autoPageTurning();
                          },
                        ),
                      ),
                      if (showEps)
                        Tooltip(
                          message: "章节".tl,
                          child: IconButton(
                            icon: const Icon(Icons.library_books),
                            onPressed: openEpsDrawer,
                          ),
                        ),
                      Tooltip(
                        message: "保存图片".tl,
                        child: IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: saveCurrentImage,
                        ),
                      ),
                      Tooltip(
                        message: "分享".tl,
                        child: IconButton(
                          icon: const Icon(Icons.share),
                          onPressed: share,
                        ),
                      ),
                    ];

                    final small = (constraints.maxWidth - buttons.length * 50) < 120;

                    return Row(
                      children: [
                        if (!small)
                          Container(
                            height: 24,
                            padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(child: Text(text)),
                          ).paddingLeft(16),
                        const Spacer(),
                        for (var button in buttons)
                          if (!small)
                            button.paddingHorizontal(4)
                          else
                            ...[button, const Spacer()],
                        if (!small)
                          const SizedBox(width: 4),
                      ],
                    );
                  },
                )
              ],
            ),
          );

          child = Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 0.6,
                ),
              ),
            ),
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
        child: IconButton(
          iconSize: 24,
          icon: const Icon(Icons.close),
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
              ? Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                    bottom: BorderSide(
                     color: Colors.grey.toOpacity(0.5),
                     width: 0.5,
            ),
                    ),
                  ),
                  padding: EdgeInsets.only(
                    left: MediaQuery.of(context).padding.left,
                    right: MediaQuery.of(context).padding.right,
                  ),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                          child: Tooltip(
                            message: "返回".tl,
                            child: IconButton(
                              iconSize: 25,
                              icon: const Icon(Icons.arrow_back_outlined),
                              onPressed: () => App.globalBack(),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 50,
                            constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width - 75),
                            child: Builder(builder: (context) {
                              var epName = readingData.eps?.values.elementAtOrNull(
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
                            child: Tooltip(
                              message: "章节评论".tl,
                              child: IconButton(
                                iconSize: 25,
                                icon: const Icon(Icons.comment),
                                onPressed: () => _openChapterComments(context),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                          child: Tooltip(
                            message: "阅读设置".tl,
                            child: IconButton(
                              iconSize: 25,
                              icon: const Icon(Icons.settings),
                              onPressed: () => showSettings(context),
                            ),
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

  bool _shouldShowChapterComments() {
    if (!readingData.hasEp || readingData.eps == null || readingData.eps!.isEmpty) {
      return false;
    }

    var showChapterComments = appdata.settings.length > 92 && appdata.settings[92] == "1";
    if (!showChapterComments) return false;

    var source = ComicSource.find(readingData.sourceKey);
    if (source == null || source.chapterCommentsLoader == null) return false;

    return true;
  }

  bool _shouldShowChapterCommentsAtEnd() {
    if (!_shouldShowChapterComments()) return false;
    var readingMethod = ReadingMethod.values[int.parse(appdata.settings[9]) - 1];
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
  Widget buildPageInfoText(
      ComicReadingPageLogic comicReadingPageLogic, BuildContext context) {
    return Positioned(
      bottom: 13,
      left: 25,
      child: StateBuilder<ComicReadingPageLogic>(
        id: "ToolBar",
        builder: (logic) {
          var epName = readingData.eps?.values
                  .elementAtOrNull(comicReadingPageLogic.order - 1) ??
              "E1";
          if (epName.length > 8) {
            epName = "${epName.substring(0, 8)}...";
          }
          var text = readingData.hasEp
              ? "$epName : ${comicReadingPageLogic.index}/${comicReadingPageLogic.urls.length}"
              : "${comicReadingPageLogic.index}/${comicReadingPageLogic.urls.length}";
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

  Widget buildStatusInfo(
      ComicReadingPageLogic logic, BuildContext context) {
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
  late Battery _battery;
  late int _batteryLevel = 100;
  Timer? _timer;
  bool _hasBattery = false;
  BatteryState state = BatteryState.unknown;

  @override
  void initState() {
    super.initState();
    _battery = Battery();
    _checkBatteryAvailability();
  }

  void _checkBatteryAvailability() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      state = await _battery.batteryState;
      if (_batteryLevel > 0 && state != BatteryState.unknown) {
        setState(() {
          _hasBattery = true;
        });
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          _battery.batteryLevel.then((level) {
            if (_batteryLevel != level) {
              setState(() {
                _batteryLevel = level;
              });
            }
          });
        });
      }
    } catch (_) {}
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

    if (state == BatteryState.charging) {
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
