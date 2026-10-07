import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pica_comic/base.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/foundation/app_page_route.dart';
import 'package:pica_comic/network/webdav.dart';
import 'package:pica_comic/pages/settings/app_updater.dart';
import 'package:pica_comic/utils/app_links.dart';
import 'package:pica_comic/utils/background_service.dart';
import 'package:pica_comic/utils/history_reader_launcher.dart';
import 'package:pica_comic/utils/android_widget.dart';
import 'package:pica_comic/utils/ohos_continuation.dart';
import 'package:pica_comic/utils/ohos_widget.dart';
import 'package:pica_comic/utils/translations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pica_comic/pages/tools.dart';

import 'category_page.dart';
import 'explore_page.dart';
import 'favorites/favorites_page.dart';
import 'history_page.dart';
import 'pre_search_page.dart';
import 'settings/settings_page.dart';
import 'package:pica_comic/foundation/app.dart';
import 'me_page.dart';
import 'package:pica_comic/network/picacg_network/methods.dart';
import 'package:pica_comic/utils/android_first_use_manager.dart';
import 'package:pica_comic/foundation/platform_utils.dart';
import 'reader/comic_reading_page.dart';

bool _haveClipboardDialog = false;

void checkClipboard() async {
  if (appdata.settings[61] == "0") {
    return;
  }
  var data = await Clipboard.getData(Clipboard.kTextPlain);
  if (data?.text != null && canHandle(data!.text!)) {
    await Future.delayed(const Duration(milliseconds: 200));
    if (_haveClipboardDialog) {
      return;
    }
    _haveClipboardDialog = true;
    await showDialog(
      context: App.globalContext!,
      builder: (context) => ContentDialog(
        title: "发现剪切板中的链接".tl,
        content: Text(data.text!),
        actions: [
          TextButton(
            onPressed: () {
              App.globalContext!.pop();
              handleAppLinks(Uri.parse(data.text!));
            },
            child: Text("打开".tl),
          ),
        ],
      ),
    );
    _haveClipboardDialog = false;
  }
}

class MainPage extends StatefulWidget {
  const MainPage({Key? key, this.initialWidgetAction}) : super(key: key);

  final String? initialWidgetAction;

  static MainPageState of(BuildContext context) {
    return context.findAncestorStateOfType<MainPageState>()!;
  }

  @override
  State<MainPage> createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  GlobalKey<NavigatorState>? _navigatorKey;

  late final NaviObserver _observer;
  Widget Function()? _initialNaviRouteBuilder;
  String? _initialNaviRouteName;
  int _currentIndex = 0;
  bool _handlingContinuation = false;
  bool _handlingWidgetAction = false;
  bool _startupTasksStarted = false;

  Future<void> _handleContinuationPayload(Map<String, dynamic> payload) async {
    if (_handlingContinuation || !mounted) {
      return;
    }
    final page = buildReaderContinuationPage(payload);
    if (page == null) {
      return;
    }
    _handlingContinuation = true;
    try {
      for (int i = 0; i < 30; i++) {
        final navigator = App.navigatorKey.currentState;
        if (navigator != null && App.globalContext != null && mounted) {
          await Future.delayed(const Duration(milliseconds: 200));
          if (!mounted) {
            return;
          }
          await navigator.push(
            AppPageRoute(
              builder: (_) => page,
              settings: const RouteSettings(name: '/ComicReadingPage'),
            ),
          );
          return;
        }
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } finally {
      _handlingContinuation = false;
    }
  }

  Future<void> _handleWidgetAction(String payload) async {
    final action = readOhosWidgetActionName(payload);
    if (_handlingWidgetAction ||
        !mounted ||
        (action != 'open_history' && action != 'open_reader')) {
      return;
    }
    _handlingWidgetAction = true;
    try {
      for (int i = 0; i < 30; i++) {
        final navigator = _navigatorKey?.currentState;
        if (navigator != null && mounted) {
          if (action == 'open_reader') {
            final params = readOhosWidgetReaderParams(payload);
            if (params == null) {
              return;
            }
            navigator.pushAndRemoveUntil(
              AppPageRoute(
                builder: (_) => HistoryReaderLaunchPage(
                  type: params.type,
                  target: params.target,
                  ep: params.ep,
                  page: params.page,
                ),
                settings: const RouteSettings(name: '/HistoryReaderLaunchPage'),
              ),
              (route) => route.isFirst,
            );
            return;
          }
          if (_observer.routes.isNotEmpty &&
              _observer.routes.last.settings.name == '/HistoryPage') {
            return;
          }
          navigator.push(
            AppPageRoute(
              builder: (_) => const HistoryPage(),
              settings: const RouteSettings(name: '/HistoryPage'),
            ),
          );
          if (mounted) {
            setState(() {});
          }
          return;
        }
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } finally {
      _handlingWidgetAction = false;
    }
  }

  // Venera-style state management
  void updateCurrentIndex(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  // Venera-style navigation method
  void to(Widget Function() widget, {bool preventDuplicate = false}) async {
    if (preventDuplicate) {
      var page = widget();
      if ("/${page.runtimeType}" == _observer.routes.last.toString()) return;
    }
    await App.to(_navigatorKey!.currentContext!, widget);
    setState(() {});
  }

  // Venera-style navigation method
  void back() {
    _navigatorKey!.currentContext!.pop();
  }

  List<Widget> get _pages => [
        const MePage(),
        const FavoritesPage(),
        ExplorePage(
          key: Key(appdata.appSettings.explorePages.length.toString()),
        ),
        const AllCategoryPage(),
      ];

  void _login() {
    network.updateProfile().then((res) {
      if (res.error) {
        showToast(message: res.errorMessageWithoutNull);
      } else {
        //检查是否打卡
        if (network.user?.isPunched == false && appdata.settings[6] == "1") {
          if (supportsWorkmanager) {
            runBackgroundService();
          } else {
            network.user?.isPunched = true;
            network.punchIn().then((b) {
              if (b) {
                showToast(message: "打卡成功".tl);
                network.user?.exp += 10;
              }
            });
          }
        }
      }
    });
  }

  void _checkUpdates() async {
    AutoUpdater().autoCheckForUpdates();
  }

  void _checkDownload() {
    if (downloadManager.downloading.isNotEmpty) {
      Future.delayed(const Duration(microseconds: 500), () {
        if (mounted) {
          showDialog(
            context: context,
            builder: (dialogContext) {
              return ContentDialog(
                title: "下载管理器".tl,
                content: Text("继续未完成的下载?".tl)
                    .paddingHorizontal(16)
                    .paddingVertical(8),
                actions: [
                  Button.text(
                      onPressed: () {
                        downloadManager.start();
                        dialogContext.pop();
                      },
                      child: Text("是".tl)),
                ],
              );
            },
          );
        }
      });
    }
  }

  void _runStartupSideEffects({required bool suppressDialogs}) {
    if (_startupTasksStarted) {
      return;
    }
    _startupTasksStarted = true;

    _login();
    notifications.requestPermission();
    notifications.cancelAll();

    if (!suppressDialogs) {
      _checkUpdates();
      _checkDownload();
    }

    if (appdata.firstUse[3] == "0") {
      appdata.firstUse[3] = "1";
      appdata.writeData();
      
      // 在Android平台上同时更新AndroidFirstUseManager
      if (App.isAndroid) {
        AndroidFirstUseManager.instance.setFirstUse3("1");
      }
    }

    Future.delayed(const Duration(milliseconds: 300), () => Webdav.syncData())
        .then((v) {
      if (!suppressDialogs) {
        checkClipboard();
      }
    });
  }

  Future<void> _bootstrapOhosIntegrations() async {
    if (kEnableOhosContinuation) {
      await OhosContinuationService.instance.initialize();
    }
    await OhosWidgetService.instance.initialize();
    if (!mounted) {
      return;
    }
    _runStartupSideEffects(
      suppressDialogs:
          OhosContinuationService.instance.launchedFromContinuation ||
              OhosWidgetService.instance.launchedFromWidget,
    );
    if (kEnableOhosContinuation &&
        OhosContinuationService.instance.hasPendingPayload) {
      await OhosContinuationService.instance.dispatchPendingPayload();
    }
    if (OhosWidgetService.instance.hasPendingAction) {
      await OhosWidgetService.instance.dispatchPendingAction();
    }
  }

  Future<void> _bootstrapAndroidWidget() async {
    await AndroidWidgetService.instance.initialize();
    if (!mounted) {
      return;
    }
    _runStartupSideEffects(
      suppressDialogs: AndroidWidgetService.instance.launchedFromWidget,
    );
    if (AndroidWidgetService.instance.hasPendingAction) {
      await AndroidWidgetService.instance.dispatchPendingAction();
    }
  }

  @override
  void initState() {
    _navigatorKey = GlobalKey();
    App.mainNavigatorKey = _navigatorKey;
    _observer = NaviObserver();
    _configureInitialWidgetRoute(widget.initialWidgetAction);
    if (PlatformUtils.isOhos) {
      if (kEnableOhosContinuation) {
        OhosContinuationService.instance.setHandler(_handleContinuationPayload);
      }
      OhosWidgetService.instance.setHandler(_handleWidgetAction);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_bootstrapOhosIntegrations());
      });
    } else if (App.isAndroid) {
      AndroidWidgetService.instance.setHandler(_handleWidgetAction);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_bootstrapAndroidWidget());
      });
    } else {
      _runStartupSideEffects(suppressDialogs: false);
    }

    // Initialize with the initial page setting, not the current page state
    _currentIndex = int.parse(appdata.settings[23]);

    super.initState();
  }

  void _configureInitialWidgetRoute(String? payload) {
    if (payload == null || payload.isEmpty) {
      return;
    }
    final action = readOhosWidgetActionName(payload);
    if (action == 'open_history') {
      _initialNaviRouteBuilder = () => const HistoryPage();
      _initialNaviRouteName = '/HistoryPage';
      return;
    }
    if (action == 'open_reader') {
      final params = readOhosWidgetReaderParams(payload);
      if (params == null) {
        return;
      }
      _initialNaviRouteBuilder = () => HistoryReaderLaunchPage(
            type: params.type,
            target: params.target,
            ep: params.ep,
            page: params.page,
          );
      _initialNaviRouteName = '/HistoryReaderLaunchPage';
    }
  }

  @override
  Widget build(BuildContext context) {
    return NaviPane(
      initialPage: int.parse(appdata.settings[23]),
      initialRouteBuilder: _initialNaviRouteBuilder,
      initialRouteName: _initialNaviRouteName,
      observer: _observer,
      navigatorKey: _navigatorKey!,
      paneItems: [
        PaneItemEntry(
            label: '主页'.tl, icon: Icons.home_outlined, activeIcon: Icons.home),
        PaneItemEntry(
            label: '收藏夹'.tl,
            icon: Icons.local_activity_outlined,
            activeIcon: Icons.local_activity),
        PaneItemEntry(
            label: '发现'.tl,
            icon: Icons.explore_outlined,
            activeIcon: Icons.explore),
        PaneItemEntry(
            label: '分类'.tl,
            icon: Icons.category_outlined,
            activeIcon: Icons.category),
      ],
      paneActions: [
        if (_currentIndex != 0)
          PaneActionEntry(
            icon: Icons.search,
            label: "搜索".tl,
            onTap: () => to(() => PreSearchPage(), preventDuplicate: true),
          ),
        PaneActionEntry(
          icon: Icons.handyman_outlined,
          label: "工具".tl,
          onTap: () => openTool(context),
        ),
        PaneActionEntry(
          icon: Icons.settings,
          label: "设置".tl,
          onTap: () {
            to(() => const SettingsPage(), preventDuplicate: true);
          },
        )
      ],
      pageBuilder: (index) {
        return _pages[index];
      },
      onPageChanged: (index) {
        setState(() {
          _currentIndex = index;
          // Clear appbar actions when switching main pages
          if (App.isFluent) {
            App.mainAppbarActions.value = null;
          }
          // Save current page state to settings[24], keep initial page setting at settings[23]
          appdata.settings[24] = index.toString();
          appdata.writeData();
        });
      },
    );
  }
}
