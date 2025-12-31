import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pica_comic/base.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/foundation/app_page_route.dart';
import 'package:pica_comic/network/webdav.dart';
import 'package:pica_comic/tools/app_links.dart';
import 'package:pica_comic/tools/background_service.dart';
import 'package:pica_comic/tools/translations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'category_page.dart';
import 'explore_page.dart';
import 'favorites/main_favorites_page.dart';
import 'pre_search_page.dart';
import 'settings/settings_page.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/network/update.dart';
import 'me_page.dart';
import 'package:pica_comic/network/picacg_network/methods.dart';
import 'package:pica_comic/tools/android_first_use_manager.dart';

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
  const MainPage({Key? key}) : super(key: key);

  static MainPageState of(BuildContext context) {
    return context.findAncestorStateOfType<MainPageState>()!;
  }

  @override
  State<MainPage> createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  GlobalKey<NavigatorState>? _navigatorKey;

  late final NaviObserver _observer;
  int _currentIndex = 0;

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
    App.to(_navigatorKey!.currentContext!, widget);
  }

  // Venera-style navigation method
  void back() {
    _navigatorKey!.currentContext!.pop();
  }

  List<Widget> get _pages => [
        const MePage(),
        FavoritesPage(),
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
          if (App.isMobile) {
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
    var lastCheck = await appdata.readLastCheckUpdate();
    if (lastCheck != null) {
      if (DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastCheck)).inDays < 1) {
        return;
      }
    }
    if (appdata.settings[2] != "1") {
      return;
    }
    var res = await checkUpdate();
    appdata.writeLastCheckUpdate(DateTime.now().millisecondsSinceEpoch);
    if (res != true) return;
    var info = await getUpdatesInfo();
    if (info == null) return;
    showDialog(
        context: App.globalContext!,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text("有可用更新".tl),
            content: Text(info),
            actions: [
              TextButton(
                  onPressed: () {
                    dialogContext.pop();
                    appdata.settings[2] = "0";
                    appdata.writeData();
                  },
                  child: const Text("关闭更新检查")),
              TextButton(onPressed: dialogContext.pop, child: Text("取消".tl)),
              TextButton(
                  onPressed: () {
                    getDownloadUrl().then((s) {
                      launchUrlString(s, mode: LaunchMode.externalApplication);
                    });
                  },
                  child: Text("下载".tl))
            ],
          );
        });

    // if (appdata.settings[80] == "1") {
    //   ComicSourceSettings.checkCustomComicSourceUpdate();
    // }
  }

  void _checkDownload() {
    if (downloadManager.downloading.isNotEmpty) {
      Future.delayed(const Duration(microseconds: 500), () {
        if (mounted) {
          showDialog(
            context: context,
            builder: (dialogContext) {
              return AlertDialog(
                title: Text("下载管理器".tl),
                content: Text("继续未完成的下载?".tl),
                actions: [
                  TextButton(onPressed: dialogContext.pop, child: Text("否".tl)),
                  TextButton(
                      onPressed: () {
                        downloadManager.start();
                        dialogContext.pop();
                      },
                      child: Text("是".tl))
                ],
              );
            },
          );
        }
      });
    }
  }

  @override
  void initState() {
    _navigatorKey = GlobalKey();
    App.mainNavigatorKey = _navigatorKey;
    _observer = NaviObserver();
    
    // Initialize with the initial page setting, not the current page state
    _currentIndex = int.parse(appdata.settings[23]);
    
    // Keep all original functionality
    _login();
    notifications.requestPermission();
    notifications.cancelAll();
    _checkUpdates();
    _checkDownload();

    if (appdata.firstUse[3] == "0") {
      appdata.firstUse[3] = "1";
      appdata.writeData();
      
      // 在Android平台上同时更新AndroidFirstUseManager
      if (App.isAndroid) {
        AndroidFirstUseManager.instance.setFirstUse3("1");
      }
    }

    Future.delayed(const Duration(milliseconds: 300), () => Webdav.syncData())
        .then((v) => checkClipboard());
    
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return NaviPane(
      initialPage: int.parse(appdata.settings[23]),
      observer: _observer,
      navigatorKey: _navigatorKey!,
      paneItems: [
        PaneItemEntry(
            label: '主页'.tl,
            icon: Icons.home_outlined,
            activeIcon: Icons.home),
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
        if(_currentIndex != 0)
          PaneActionEntry(
            icon: Icons.search,
            label: "搜索".tl,
            onTap: () => to(() => PreSearchPage(), preventDuplicate: true),
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
          // Save current page state to settings[24], keep initial page setting at settings[23]
          appdata.settings[24] = index.toString();
          appdata.writeData();
        });
        HapticFeedback.selectionClick();
      },
    );
  }
}
