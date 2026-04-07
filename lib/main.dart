import 'dart:async';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pica_comic/base.dart';
import 'package:pica_comic/components/window_frame.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/app_page_route.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/init.dart';
import 'package:pica_comic/network/http_client.dart';
import 'package:pica_comic/pages/auth_page.dart';
import 'package:pica_comic/pages/main_page.dart';
import 'package:pica_comic/pages/welcome_page.dart';
import 'package:pica_comic/utils/block_screenshot.dart';
import 'package:pica_comic/utils/mouse_listener.dart';
import 'package:pica_comic/utils/android_first_use_manager.dart';
import 'package:pica_comic/utils/tags_translation.dart';
import 'package:window_manager/window_manager.dart';

import 'components/components.dart';
import 'network/webdav.dart';

void main(List<String> args) {
  if (runWebViewTitleBarWidget(args)) {
    return;
  }
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await init();
    FlutterError.onError = (details) {
      LogManager.addLog(LogLevel.error, "Unhandled Exception",
          "${details.exception}\n${details.stack}");
    };

    setNetworkProxy();
    runApp(const MyApp());
    if (App.isDesktop) {
      await windowManager.ensureInitialized();
      windowManager.waitUntilReadyToShow().then((_) async {
        await windowManager.setTitleBarStyle(
          TitleBarStyle.hidden,
          windowButtonVisibility: App.isMacOS,
        );
        if (App.isLinux) {
          await windowManager.setBackgroundColor(Colors.transparent);
        }
        await windowManager.setMinimumSize(const Size(500, 600));
        if (!App.isLinux) {
          // https://github.com/leanflutter/window_manager/issues/460
          var placement = await WindowPlacement.loadFromFile();
          await placement.applyToWindow();
          await windowManager.show();
          WindowPlacement.loop();
        }
      });
    }
  }, (error, stack) {
    LogManager.addLog(LogLevel.error, "Unhandled Exception", "$error\n$stack");
  });
}

class _CustomScrollBehavior extends MaterialScrollBehavior {
  const _CustomScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static void Function()? updater;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  DateTime time = DateTime.fromMillisecondsSinceEpoch(0);

  bool forceRebuild = false;

  OverlayEntry? hideContentOverlay;

  void hideContent() {
    if (hideContentOverlay != null) return;
    hideContentOverlay = OverlayEntry(
        builder: (context) => Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.width,
              color: Theme.of(context).colorScheme.surface,
            ));
    OverlayWidget.addOverlay(hideContentOverlay!);
  }

  void showContent() {
    hideContentOverlay = null;
    OverlayWidget.removeAll();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 安全检查settings数组
    bool enableAuth = false;
    try {
      enableAuth =
          appdata.settings.length > 13 ? appdata.settings[13] == "1" : false;
    } catch (e) {
      LogManager.addLog(LogLevel.error, "MyApp.didChangeAppLifecycleState",
          "Error checking auth settings: $e");
      enableAuth = false;
    }

    if (App.isAndroid) {
      try {
        bool highRefreshRate =
            appdata.settings.length > 38 ? appdata.settings[38] == "1" : false;
        if (highRefreshRate) {
          FlutterDisplayMode.setHighRefreshRate();
        }
      } catch (e) {
        LogManager.addLog(LogLevel.error, "MyApp.didChangeAppLifecycleState",
            "Error checking refresh rate settings: $e");
      }
    }

    setNetworkProxy();
    scheduleMicrotask(() {
      if (state == AppLifecycleState.hidden && enableAuth) {
        if (!AuthPage.lock && enableAuth) {
          AuthPage.initial = false;
          AuthPage.lock = true;
          App.to(App.globalContext!, () => const AuthPage());
        }
      }

      if (state == AppLifecycleState.inactive && enableAuth) {
        hideContent();
      } else if (state == AppLifecycleState.resumed) {
        showContent();
        Future.delayed(const Duration(milliseconds: 200), checkClipboard);
      }

      if (DateTime.now().millisecondsSinceEpoch - time.millisecondsSinceEpoch >
          7200000) {
        Webdav.syncData();
        time = DateTime.now();
      }
    });
  }

  @override
  void initState() {
    MyApp.updater = () => setState(() => forceRebuild = true);
    time = DateTime.now();
    TagsTranslation.readData();

    // 安全检查Android高刷新率设置
    if (App.isAndroid) {
      try {
        bool highRefreshRate =
            appdata.settings.length > 38 ? appdata.settings[38] == "1" : false;
        if (highRefreshRate) {
          FlutterDisplayMode.setHighRefreshRate();
        }
      } catch (e) {
        LogManager.addLog(LogLevel.error, "MyApp.initState",
            "Error setting high refresh rate: $e");
      }
    }

    listenMouseSideButtonToBack();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WidgetsBinding.instance.addObserver(this);
    notifications.init();

    // 安全检查截图阻止设置
    try {
      bool shouldBlockScreenshot =
          appdata.settings.length > 12 ? appdata.settings[12] == "1" : false;
      if (shouldBlockScreenshot) {
        blockScreenshot();
      }
    } catch (e) {
      LogManager.addLog(LogLevel.error, "MyApp.initState",
          "Error setting screenshot block: $e");
    }

    if (App.isIOS) {
      PaintingBinding.instance.imageCache.maximumSizeBytes = 200 * 1024 * 1024;
    } else {
      PaintingBinding.instance.imageCache.maximumSizeBytes = 200 * 1024 * 1024;
    }
    super.initState();
  }

  @override
  void didChangePlatformBrightness() {
    setState(() {});
  }

  (ColorScheme, ColorScheme) _generateColorSchemes(
      ColorScheme? light, ColorScheme? dark) {
    Color? color;

    // 安全检查主题设置
    try {
      int themeIndex =
          appdata.settings.length > 27 ? int.parse(appdata.settings[27]) : 0;
      if (themeIndex != 0) {
        color = colors[themeIndex - 1];
      } else {
        color = light?.primary ?? Colors.blueAccent;
      }
    } catch (e) {
      LogManager.addLog(LogLevel.error, "MyApp._generateColorSchemes",
          "Error getting theme color: $e");
      color = light?.primary ?? Colors.blueAccent;
    }

    // 使用与venera一致的flex_seed_scheme配色方案
    final lightScheme = SeedColorScheme.fromSeeds(
      primaryKey: color,
      brightness: Brightness.light,
      tones: FlexTones.vividBackground(Brightness.light),
    );
    final darkScheme = SeedColorScheme.fromSeeds(
      primaryKey: color,
      brightness: Brightness.dark,
      tones: FlexTones.vividBackground(Brightness.dark),
    );

    // 安全检查纯黑色模式设置
    try {
      bool pureBlackMode =
          appdata.settings.length > 84 ? appdata.settings[84] == "1" : false;
      if (pureBlackMode) {
        final modifiedDarkScheme =
            darkScheme.copyWith(surface: Colors.black).harmonized();
        return (lightScheme, modifiedDarkScheme);
      }
    } catch (e) {
      LogManager.addLog(LogLevel.error, "MyApp._generateColorSchemes",
          "Error checking pure black mode: $e");
    }

    return (lightScheme, darkScheme);
  }

  // 获取字体配置（与venera一致，支持自定义字体覆盖）
  (String?, List<String>?) _getFontConfig() {
    // 检查是否有自定义字体设置
    if (appdata.settings.length > 95 && appdata.settings[95].isNotEmpty) {
      return (appdata.settings[95], null);
    }
    
    String? font;
    List<String>? fallback;
    if (App.isLinux || App.isWindows) {
      font = 'Noto Sans CJK';
      fallback = [
        'Segoe UI',
        'Noto Sans SC',
        'Noto Sans TC',
        'Noto Sans JP',
        'Noto Sans KR',
        'DejaVu Sans',
        'Arial',
        'sans-serif',
      ];
    } else if (App.isMacOS) {
      font = 'PingFang SC';
      fallback = [
        'Heiti SC',
        'STHeiti',
        'Noto Sans SC',
        'Noto Sans TC',
        'Noto Sans JP',
        'Noto Sans KR',
        'Arial',
        'sans-serif',
      ];
    }
    return (font, fallback);
  }

  // 异步检查firstUse[3]的值
  Future<bool> _checkFirstUse() async {
    try {
      // 在Android平台上使用AndroidFirstUseManager
      if (App.isAndroid) {
        return await AndroidFirstUseManager.isFirstUse();
      }
      // 确保数据已经加载
      await appdata.readData();
      // 检查firstUse[3]的值
      return appdata.firstUse.length > 3 ? appdata.firstUse[3] != "1" : true;
    } catch (e) {
      LogManager.addLog(LogLevel.error, "MyApp._checkFirstUse",
          "Error checking firstUse: $e");
      return true; // 发生错误时，显示欢迎页面
    }
  }

  @override
  Widget build(BuildContext context) {
    if (forceRebuild) {
      forceRebuild = false;
      void rebuild(Element el) {
        el.markNeedsBuild();
        el.visitChildren(rebuild);
      }

      (context as Element).visitChildren(rebuild);
    }
    return DynamicColorBuilder(builder: (light, dark) {
      var (lightColor, darkColor) = _generateColorSchemes(light, dark);
      if (appdata.settings.length > 91 && appdata.settings[91] == "1") {
        return fluent.FluentApp(
          title: 'Pica Comic',
          debugShowCheckedModeBanner: false,
          navigatorKey: App.navigatorKey,
          theme: fluent.FluentThemeData(
             accentColor: fluent.AccentColor('normal', {
               'normal': lightColor.primary,
               'dark': lightColor.primary,
               'light': lightColor.primary,
               'darker': lightColor.primary,
               'lighter': lightColor.primary,
               'darkest': lightColor.primary,
               'lightest': lightColor.primary,
             }),
             brightness: fluent.Brightness.light,
             fontFamily: _getFontConfig().$1,
           ),
           darkTheme: fluent.FluentThemeData(
             accentColor: fluent.AccentColor('normal', {
               'normal': darkColor.primary,
               'dark': darkColor.primary,
               'light': darkColor.primary,
               'darker': darkColor.primary,
               'lighter': darkColor.primary,
               'darkest': darkColor.primary,
               'lightest': darkColor.primary,
             }),
             brightness: fluent.Brightness.dark,
             fontFamily: _getFontConfig().$1,
           ),
          themeMode: appdata.appSettings.darkMode == 2
              ? fluent.ThemeMode.dark
              : appdata.appSettings.darkMode == 1
                  ? fluent.ThemeMode.light
                  : fluent.ThemeMode.system,
          scrollBehavior: const _CustomScrollBehavior(),
          onGenerateRoute: (settings) => AppPageRoute(
            builder: (context) {
              // 使用FutureBuilder来异步检查firstUse[3]的值
              return FutureBuilder<bool>(
                future: _checkFirstUse(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    // 显示加载页面
                    return const Scaffold(
                      body: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    // 发生错误，显示欢迎页面
                    LogManager.addLog(LogLevel.error, "MyApp.onGenerateRoute",
                        "Error checking firstUse: ${snapshot.error}");
                    return const WelcomePage();
                  } else {
                    // 根据firstUse[3]的值决定显示哪个页面
                    bool isFirstUse = snapshot.data ?? true;
                    return isFirstUse
                        ? const WelcomePage()
                        : (appdata.settings[13] == "1"
                            ? const AuthPage()
                            : const MainPage());
                  }
                },
              );
            },
          ),
          localizationsDelegates: const [
            fluent.FluentLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('zh', 'CN'),
            Locale('zh', 'TW'),
            Locale('en', 'US')
          ],
          builder: (context, widget) {
            ErrorWidget.builder = (details) {
              LogManager.addLog(LogLevel.error, "Unhandled Exception",
                  "${details.exception}\n${details.stack}");
              return Material(
                child: Center(
                  child: Text(details.exception.toString()),
                ),
              );
            };
            if (widget != null) {
              widget = OverlayWidget(widget);
              if (App.isDesktop) {
                widget = Shortcuts(
                  shortcuts: {
                    LogicalKeySet(LogicalKeyboardKey.escape):
                        VoidCallbackIntent(
                      () {
                        final globalNavigator = App.navigatorKey.currentState;
                        if (globalNavigator != null &&
                            globalNavigator.canPop()) {
                          App.globalBack();
                        } else {
                          final mainNavigator =
                              App.mainNavigatorKey?.currentState;
                          if (mainNavigator != null && mainNavigator.canPop()) {
                            mainNavigator.pop();
                          }
                        }
                      },
                    ),
                  },
                  child: WindowFrame(widget),
                );
              }
              return Theme(
                  data: ThemeData(
                    colorScheme: fluent.FluentTheme.of(context).brightness ==
                            fluent.Brightness.light
                        ? lightColor
                        : darkColor,
                    useMaterial3: true,
                    fontFamily: _getFontConfig().$1,
                    fontFamilyFallback: _getFontConfig().$2,
                    brightness: fluent.FluentTheme.of(context).brightness ==
                            fluent.Brightness.light
                        ? Brightness.light
                        : Brightness.dark,
                  ),
                  child: _SystemUiProvider(widget));
            }
            throw ('widget is null');
          },
        );
      }
      return MaterialApp(
        title: 'Pica Comic',
        debugShowCheckedModeBanner: false,
        navigatorKey: App.navigatorKey,
        scrollBehavior: const _CustomScrollBehavior(),
        theme: ThemeData(
          colorScheme: lightColor,
          useMaterial3: true,
          fontFamily: _getFontConfig().$1,
          fontFamilyFallback: _getFontConfig().$2,
        ),
        darkTheme: ThemeData(
          colorScheme: darkColor,
          useMaterial3: true,
          fontFamily: _getFontConfig().$1,
          fontFamilyFallback: _getFontConfig().$2,
          brightness: Brightness.dark,
        ),
        themeMode: appdata.appSettings.darkMode == 2
            ? ThemeMode.dark
            : appdata.appSettings.darkMode == 1
                ? ThemeMode.light
                : ThemeMode.system,
        onGenerateRoute: (settings) => AppPageRoute(
          builder: (context) {
            // 使用FutureBuilder来异步检查firstUse[3]的值
            return FutureBuilder<bool>(
              future: _checkFirstUse(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  // 显示加载页面
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                } else if (snapshot.hasError) {
                  // 发生错误，显示欢迎页面
                  LogManager.addLog(LogLevel.error, "MyApp.onGenerateRoute",
                      "Error checking firstUse: ${snapshot.error}");
                  return const WelcomePage();
                } else {
                  // 根据firstUse[3]的值决定显示哪个页面
                  bool isFirstUse = snapshot.data ?? true;
                  return isFirstUse
                      ? const WelcomePage()
                      : (appdata.settings[13] == "1"
                          ? const AuthPage()
                          : const MainPage());
                }
              },
            );
          },
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('zh', 'CN'),
          Locale('zh', 'TW'),
          Locale('en', 'US')
        ],
        builder: (context, widget) {
          ErrorWidget.builder = (details) {
            LogManager.addLog(LogLevel.error, "Unhandled Exception",
                "${details.exception}\n${details.stack}");
            return Material(
              child: Center(
                child: Text(details.exception.toString()),
              ),
            );
          };
          if (widget != null) {
            widget = OverlayWidget(widget);
            if (App.isDesktop) {
              widget = Shortcuts(
                shortcuts: {
                  LogicalKeySet(LogicalKeyboardKey.escape): VoidCallbackIntent(
                    () {
                      final globalNavigator = App.navigatorKey.currentState;
                      if (globalNavigator != null && globalNavigator.canPop()) {
                        App.globalBack();
                      } else {
                        final mainNavigator = App.mainNavigatorKey?.currentState;
                        if (mainNavigator != null && mainNavigator.canPop()) {
                          mainNavigator.pop();
                        }
                      }
                    },
                  ),
                },
                child: WindowFrame(widget),
              );
            }
            return _SystemUiProvider(widget);
          }
          throw ('widget is null');
        },
      );
    });
  }
}

class _SystemUiProvider extends StatelessWidget {
  const _SystemUiProvider(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    var brightness = Theme.of(context).brightness;
    SystemUiOverlayStyle systemUiStyle;
    if (brightness == Brightness.light) {
      systemUiStyle = SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      );
    } else {
      systemUiStyle = SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiStyle,
      child: child,
    );
  }
}
