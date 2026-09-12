library pica_reader;

import 'package:liquid_glass_widgets/widgets/shared/adaptive_liquid_glass_layer.dart';
import 'package:pica_comic/utils/show_delayed_dialog.dart';
import 'dart:async';
import 'dart:io';
import 'package:battery_plus/battery_plus.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:pica_comic/foundation/comic_source/comic_source.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/components/custom_slider.dart';
import 'package:pica_comic/components/scrollable_list/src/item_positions_listener.dart';
import 'package:pica_comic/components/scrollable_list/src/scrollable_positioned_list.dart';
import 'package:window_manager/window_manager.dart';
import 'package:pica_comic/components/window_frame.dart';
import 'package:pica_comic/foundation/image_loader/base_image_provider.dart';
import 'package:pica_comic/foundation/image_loader/file_image_loader.dart';
import 'package:pica_comic/foundation/image_loader/stream_image_provider.dart';
import 'package:pica_comic/foundation/image_loader/cached_image.dart';
import 'package:pica_comic/foundation/local_favorites.dart';
import 'package:pica_comic/network/download.dart';
import 'package:pica_comic/network/eh_network/eh_models.dart' as eh;
import 'package:pica_comic/network/eh_network/get_gallery_id.dart';
import 'package:pica_comic/base.dart';
import 'package:pica_comic/network/htmanga_network/htmanga_main_network.dart';
import 'package:pica_comic/network/jm_network/jm_models.dart' as jm;
import 'package:pica_comic/network/jm_network/jm_image.dart';
import 'package:pica_comic/network/nhentai_network/nhentai_main_network.dart';
import 'package:pica_comic/network/res.dart';
import 'package:pica_comic/pages/comic_page.dart';
import 'package:pica_comic/pages/follow_updates_page.dart';
import 'package:pica_comic/utils/keep_screen_on.dart';
import 'package:pica_comic/foundation/image_manager.dart';
import 'package:pica_comic/foundation/history.dart';
import 'package:pica_comic/utils/save_image.dart';
import 'package:pica_comic/utils/time.dart';
import 'package:pica_comic/network/jm_network/jm_network.dart';
import '../../foundation/app.dart';
import '../../foundation/platform_utils.dart';
import '../../foundation/ui_mode.dart';
import '../../network/hitomi_network/hitomi_models.dart';
import '../../utils/extensions.dart';
import '../../utils/key_down_event.dart';
import '../../utils/ohos_continuation.dart';
import '../../utils/ohos_battery.dart';
import '../../utils/ohos_decor.dart';
import '../../utils/ohos_device_info.dart';
import 'package:pica_comic/network/picacg_network/methods.dart' as picacg;
import 'package:pica_comic/utils/translations.dart';

import '../jm/jm_comments_page.dart';
import 'package:pica_comic/network/cloudflare.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

part 'eps_view.dart';

part 'chapter_comments.dart';

part 'image_view.dart';

part 'image.dart';

part 'touch_control.dart';

part 'reading_logic.dart';

part 'tool_bar.dart';

part 'reading_type.dart';

part 'reading_settings.dart';

part 'reading_data.dart';

part 'continuation.dart';

void _setReaderSystemUi({required bool showBars}) {
  final alwaysShowStatusBar =
      appdata.settings.length > 95 && appdata.settings[95] == "1";
  final mode = showBars || alwaysShowStatusBar
      ? SystemUiMode.edgeToEdge
      : (PlatformUtils.isOhos
          ? SystemUiMode.immersiveSticky
          : SystemUiMode.immersive);
  SystemChrome.setEnabledSystemUIMode(mode);
}

void _restoreAppOrientations() {
  if (App.isAndroid || App.isIOS) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  } else if (OhosDeviceInfoBridge.shouldLockAppPortrait) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  } else {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }
}

///阅读器
class ComicReadingPage extends StatelessWidget {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final ReadingData readingData;

  late final History history = _findOrCreateHistory(readingData);

  final int initialPage;

  final int initialEp;

  ReadingType get type => readingData.type;

  ComicReadingPage(this.readingData, this.initialPage, this.initialEp,
      {super.key}) {
    StateController.put(ComicReadingPageLogic(
        initialEp,
        readingData,
        initialPage,
        () => _updateHistory(
            StateController.find<ComicReadingPageLogic>(), false)));
  }

  ComicReadingPage.picacg(
      String target, this.initialEp, List<String> eps, String title,
      {super.key,
      this.initialPage = 1,
      String historySubTitle = '',
      String historyCover = ''})
      : readingData = PicacgReadingData(
          title,
          target,
          eps,
          historySubTitle: historySubTitle,
          historyCover: historyCover,
        ) {
    StateController.put(ComicReadingPageLogic(
        initialEp,
        readingData,
        initialPage,
        () => _updateHistory(
            StateController.find<ComicReadingPageLogic>(), false)));
  }

  ComicReadingPage.ehentai(eh.Gallery gallery,
      {super.key, this.initialPage = 1})
      : initialEp = 1,
        readingData = EhReadingData(gallery) {
    StateController.put(ComicReadingPageLogic(
        1,
        readingData,
        initialPage,
        () => _updateHistory(
            StateController.find<ComicReadingPageLogic>(), false)));
  }

  ComicReadingPage.jmComic(jm.JmComicInfo comic, this.initialEp,
      {super.key, this.initialPage = 1})
      : readingData = JmReadingData(
          comic.name,
          comic.id,
          comic.series.values.toList(),
          comic.epNames,
        ) {
    StateController.put(ComicReadingPageLogic(
        initialEp,
        readingData,
        initialPage,
        () => _updateHistory(
            StateController.find<ComicReadingPageLogic>(), false)));
  }

  ComicReadingPage.hitomi(HitomiComic comic, String link,
      {super.key, this.initialPage = 1})
      : initialEp = 1,
        readingData = HitomiReadingData(
          comic.title,
          comic.target,
          comic.files,
          link,
          historySubTitle: comic.subTitle,
          historyCover: comic.cover,
        ) {
    StateController.put(ComicReadingPageLogic(
        initialEp,
        readingData,
        initialPage,
        () => _updateHistory(
            StateController.find<ComicReadingPageLogic>(), false)));
  }

  ComicReadingPage.htmanga(String target, String title,
      {super.key,
      this.initialPage = 1,
      String historySubTitle = '',
      String historyCover = ''})
      : initialEp = 1,
        readingData = HtReadingData(
          title,
          target,
          historySubTitle: historySubTitle,
          historyCover: historyCover,
        ) {
    StateController.put(ComicReadingPageLogic(
        initialEp,
        readingData,
        initialPage,
        () => _updateHistory(
            StateController.find<ComicReadingPageLogic>(), false)));
  }

  ComicReadingPage.nhentai(String target, String title,
      {super.key,
      this.initialPage = 1,
      String historySubTitle = '',
      String historyCover = ''})
      : initialEp = 1,
        readingData = NhentaiReadingData(
          title,
          target,
          historySubTitle: historySubTitle,
          historyCover: historyCover,
        ) {
    StateController.put(ComicReadingPageLogic(
        initialEp,
        readingData,
        initialPage,
        () => _updateHistory(
            StateController.find<ComicReadingPageLogic>(), false)));
  }

  _updateHistory(ComicReadingPageLogic? logic, bool updateMePage) {
    if (readingData.hasEp) {
      if (logic!.order == 1 && logic.index == 1) {
        history.ep = 0;
        history.page = 0;
      } else {
        if (logic.order == readingData.eps?.length &&
            logic.index == logic.length) {
          history.ep = logic.order;
          history.page = logic.length;
        } else {
          history.ep = logic.order;
          history.page = logic.index;
        }
      }
    } else {
      if (logic!.index == 1) {
        history.ep = 0;
        history.page = 0;
      } else if (logic.index == logic.length) {
        history.ep = 0;
        history.page = logic.length;
      } else {
        history.ep = 1;
        history.page = logic.index;
      }
    }
    history.maxPage = logic.length;
    HistoryManager().saveReadHistory(history, updateMePage);
  }

  History _findOrCreateHistory(ReadingData readingData) {
    final historyManager = HistoryManager();
    final target = readingData.historyTarget;
    final history = historyManager.findSync(target);
    if (history != null) {
      return history;
    }
    final newHistory = History(
      readingData.historyType,
      DateTime.now(),
      readingData.title,
      readingData.historySubTitle,
      readingData.historyCover,
      0,
      0,
      target,
    );
    unawaited(historyManager.addHistory(newHistory));
    return newHistory;
  }

  bool get useDarkBackground => appdata.appSettings.useDarkBackground;

  @override
  Widget build(BuildContext context) {
    return StateBuilder<ComicReadingPageLogic>(initState: (logic) {
      _setReaderSystemUi(showBars: false);
      if (supportsKeepScreenOn && appdata.settings[14] == "1") {
        setKeepScreenOn();
      }
      if (appdata.settings[76] == "1") {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight
        ]);
      } else if (appdata.settings[76] == "2") {
        SystemChrome.setPreferredOrientations(
            [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
      } else if (App.isMobile) {
        SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      }
      //进入阅读器时清除内存中的缓存, 并且增大限制
      BaseImageProvider.clearCache();
      BaseImageProvider.setCacheSizeLimit(100 * 1024 * 1024);
      logic.openEpsView = openEpsDrawer;
      logic.continuationIndexCallback ??= (_) {
        unawaited(syncReaderContinuationState(readingData, logic));
      };
      logic.addIndexChangeCallback(logic.continuationIndexCallback!);
      unawaited(syncReaderContinuationState(readingData, logic));
      OhosDecorBridge.holdDecorDark(this);
      if (useDarkBackground) {}
    }, dispose: (logic) {
      //清除缓存并减小最大缓存
      BaseImageProvider.clearCache();
      BaseImageProvider.setCacheSizeLimit(50 * 1024 * 1024);
      logic.clearPhotoViewControllers();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      _restoreAppOrientations();
      if (logic.listenVolume != null) {
        logic.listenVolume!.stop();
      }
      if (logic.continuationIndexCallback != null) {
        logic.removeIndexChangeCallback(logic.continuationIndexCallback!);
        logic.continuationIndexCallback = null;
      }
      unawaited(clearReaderContinuationState());
      if (supportsKeepScreenOn && appdata.settings[14] == "1") {
        cancelKeepScreenOn();
      }
      logic.runningAutoPageTurning = false;
      ComicImage.clear();
      StateController.remove<ComicReadingPageLogic>();
      // 更新本地收藏
      LocalFavoritesManager()
          .onReadEnd(readingData.favoriteId, readingData.favoriteType);
      LocalFavoritesManager()
          .markAsRead(readingData.favoriteId, readingData.favoriteType);
      updateFollowUpdatesUI();
      // 保存历史记录
      _updateHistory(logic, true);
      // 退出全屏
      if (logic.isFullScreen) {
        logic.fullscreen();
      }
      if (!DownloadManager().isDownloading) {
        ImageManager.clearTasks();
      }
      // 更新漫画详情页面
      Future.microtask(() {
        if (BaseComicPage.tagsStack.isNotEmpty) {
          BaseComicPage.tagsStack.last.updateHistory(history);
        }
      });
      OhosDecorBridge.releaseDecorDark(this);
      if (useDarkBackground) {}
    }, builder: (logic) {
      Widget reader = Scaffold(
        backgroundColor: useDarkBackground ? Colors.black : null,
        endDrawerEnableOpenDragGesture: false,
        key: _scaffoldKey,
        endDrawer: Drawer(
          child: buildEpsView(),
        ),
        body: StateBuilder<ComicReadingPageLogic>(builder: (logic) {
          if (logic.isLoading) {
            history.readEpisode.add(logic.order);
            loadInfo(logic);
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (logic.urls.isNotEmpty) {
            if (logic.readingMethod == ReadingMethod.topToBottomContinuously &&
                !logic.haveUsedInitialPage &&
                initialPage != 0) {
              Future.microtask(() {
                logic.jumpToPage(initialPage);
                logic.haveUsedInitialPage = true;
              });
            }
            //监听音量键
            if (appdata.settings[7] == "1") {
              if (logic.listenVolume == null) {
                logic.listenVolume = ListenVolumeController(
                    () => logic.jumpToLastPage(), () => logic.jumpToNextPage());
                logic.listenVolume!.listenVolumeChange();
              }
            } else if (logic.listenVolume != null) {
              logic.listenVolume!.stop();
              logic.listenVolume = null;
            }

            if (appdata.settings[9] == "4") {
              logic.scrollManager ??= ScrollManager(logic);
            }

            var body = Listener(
              onPointerMove: TapController.onPointerMove,
              onPointerUp: TapController.onTapUp,
              onPointerDown: TapController.onTapDown,
              behavior: HitTestBehavior.translucent,
              onPointerCancel: TapController.onTapCancel,
              child: Stack(
                children: [
                  buildComicView(
                    logic,
                    context,
                    readingData.id,
                  ),
                  if (MediaQuery.of(context).platformBrightness ==
                          Brightness.dark &&
                      appdata.appSettings.reduceBrightnessInDarkMode)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: ColoredBox(
                          color: Colors.black.withOpacity(0.2),
                        ),
                      ),
                    ),
                  if (appdata.appSettings.showPageInfoInReader &&
                      !logic.isOnChapterCommentsPage)
                    buildPageInfoText(logic, context),
                  if (appdata.appSettings.enableClockAndBatteryInfoInReader &&
                      !logic.isOnChapterCommentsPage)
                    buildStatusInfo(logic, context),
                  if (!logic.isOnChapterCommentsPage)
                    buildBottomToolBar(logic, context, readingData.hasEp),
                  if (!logic.isOnChapterCommentsPage)
                    ...buildButtons(logic, context),
                  if (!logic.isOnChapterCommentsPage)
                    buildTopToolBar(logic, context),
                ],
              ),
            );

            return KeyboardListener(
              focusNode: logic.focusNode,
              autofocus: true,
              onKeyEvent: logic.handleKeyboard,
              child: body,
            );
          } else {
            return buildErrorView(logic, context);
          }
        }),
      );
      if (PlatformUtils.isOhos) {
        reader = MediaQuery.removeViewPadding(
          context: context,
          removeTop: true,
          removeLeft: true,
          removeRight: true,
          removeBottom: true,
          child: reader,
        );
      }
      return DefaultTextStyle.merge(
        style: TextStyle(
          color: useDarkBackground ? Colors.white : null,
          fontSize: 16,
        ),
        child: reader,
      );
    });
  }

  Widget buildErrorView(ComicReadingPageLogic logic, BuildContext context) {
    return SafeArea(
        child: Stack(
      children: [
        Positioned(
          left: 8,
          top: 12,
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back,
            ),
            onPressed: () => App.globalBack(),
          ),
        ),
        Positioned(
          top: MediaQuery.of(App.globalContext!).size.height / 2 - 80,
          left: 0,
          right: 0,
          child: const Align(
            alignment: Alignment.topCenter,
            child: Icon(
              Icons.error_outline,
              size: 60,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: MediaQuery.of(App.globalContext!).size.height / 2 - 10,
          child: Align(
            alignment: Alignment.topCenter,
            child: Text(
              logic.errorMessage ?? "未知错误".tl,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: MediaQuery.of(App.globalContext!).size.height / 2 + 30,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 250,
              height: 40,
              child: Builder(
                builder: (context) {
                  // 检查是否是 Cloudflare 错误
                  final cfe =
                      CloudflareException.fromString(logic.errorMessage ?? "");
                  if (cfe != null) {
                    // Cloudflare 错误：显示验证按钮和切换章节按钮
                    return Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              passCloudflare(cfe, () {
                                logic.change();
                              });
                            },
                            child: Text("验证".tl),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              if (!readingData.hasEp) {
                                showToast(message: "没有其它章节".tl);
                                return;
                              }
                              if (MediaQuery.of(context).size.width > 600) {
                                showSideBar(
                                  context,
                                  buildEpsView(),
                                  title: null,
                                  addTopPadding: true,
                                  width: 400,
                                );
                              } else {
                                showModalBottomSheet(
                                  context: context,
                                  useSafeArea: false,
                                  builder: (context) {
                                    return buildEpsView();
                                  },
                                );
                              }
                            },
                            child: Text("切换章节".tl),
                          ),
                        ),
                      ],
                    );
                  } else {
                    // 普通错误：显示重试和切换章节按钮
                    return Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              logic.change();
                            },
                            child: Text("重试".tl),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              if (!readingData.hasEp) {
                                showToast(message: "没有其它章节".tl);
                                return;
                              }
                              if (MediaQuery.of(context).size.width > 600) {
                                showSideBar(
                                  context,
                                  buildEpsView(),
                                  title: null,
                                  addTopPadding: true,
                                  width: 400,
                                );
                              } else {
                                showModalBottomSheet(
                                  context: context,
                                  useSafeArea: false,
                                  builder: (context) {
                                    return buildEpsView();
                                  },
                                );
                              }
                            },
                            child: Text("切换章节".tl),
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
            ),
          ),
        ),
      ],
    ));
  }

  void loadInfo(ComicReadingPageLogic logic) async {
    logic.urls = [];
    var res = await readingData.loadEp(logic.order);
    if (res.error) {
      logic.errorMessage = res.errorMessage;
    } else {
      logic.urls = res.data;
    }
    logic.isLoading = false;
    logic.update();
  }

  Widget buildEpsView() {
    return EpsView(readingData);
  }

  void openEpsDrawer() {
    var context = App.globalContext!;
    showSideBar(
      context,
      buildEpsView(),
      title: null,
      width: 400,
      addTopPadding: true,
    );
  }

  /// Used when [ComicReadingPageLogic.readingMethod] is [ReadingMethod.topToBottomContinuously].
  ///
  /// Select a image form screen, to share or download
  Future<int?> selectImage() async {
    var logic = StateController.find<ComicReadingPageLogic>();
    var items = logic.itemScrollListener.itemPositions.value
        .where((item) => item.index < logic.urls.length)
        .toList();
    if (items.isEmpty) {
      return null;
    }
    if (items.length == 1) {
      return items[0].index;
    }
    int? res;
    await showDialog(
        context: App.globalContext!,
        builder: (context) {
          return SimpleDialog(
            title: Text("选择屏幕上的图片".tl),
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 400,
                ),
                child: Column(
                  children: [
                    for (var item in items)
                      ListTile(
                        title: Text((item.index + 1).toString()),
                        onTap: () {
                          res = item.index;
                          App.globalBack();
                        },
                        trailing: const Icon(Icons.arrow_right),
                      )
                  ],
                ),
              )
            ],
          );
        });
    return res;
  }

  String getImageKey(int index) {
    var logic = StateController.find<ComicReadingPageLogic>();
    if (type == ComicType.ehentai) {
      return "${readingData.id}${index + 1}";
    }
    return type == ReadingType.hitomi
        ? (readingData as HitomiReadingData).images[index].hash
        : logic.urls[index];
  }

  Future<File> _getFileFromStream(Stream<DownloadProgress> stream) async {
    await for (var event in stream) {
      if (event.finished) {
        return event.getFile();
      }
    }
    throw "failed";
  }

  void share() async {
    var logic = StateController.find<ComicReadingPageLogic>();
    int? index = logic.index - 1;
    if (logic.readingMethod == ReadingMethod.topToBottomContinuously) {
      index = await selectImage();
    }
    if (index == null) {
      return;
    }

    var file = await _getFileFromStream(
        readingData.loadImage(logic.order, index, logic.urls[index]));

    shareImage(file);
  }

  Future<String?> _persistentCurrentImage() async {
    var logic = StateController.find<ComicReadingPageLogic>();
    int? index = logic.index - 1;
    if (logic.readingMethod == ReadingMethod.topToBottomContinuously) {
      index = await selectImage();
    }
    if (index == null) {
      return null;
    }

    var file = await _getFileFromStream(
        readingData.loadImage(logic.order, index, logic.urls[index]));

    return persistentCurrentImage(file);
  }

  void saveCurrentImage() async {
    var logic = StateController.find<ComicReadingPageLogic>();
    int? index = logic.index - 1;
    if (logic.readingMethod == ReadingMethod.topToBottomContinuously) {
      index = await selectImage();
    }
    if (index == null) {
      return;
    }

    var file = await _getFileFromStream(
        readingData.loadImage(logic.order, index, logic.urls[index]));

    saveImage(file);
  }
}
