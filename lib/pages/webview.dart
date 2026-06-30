import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:liquid_glass_widgets/widgets/overlays/glass_menu.dart';
import 'package:liquid_glass_widgets/widgets/overlays/glass_menu_item.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/ui_mode.dart';
import 'package:pica_comic/network/http_client.dart';
import 'package:pica_comic/utils/extensions.dart';
import 'package:pica_comic/utils/translations.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../base.dart';

export 'package:flutter_inappwebview/flutter_inappwebview.dart'
    show WebUri, URLRequest;

extension WebviewExtension on InAppWebViewController {
  Future<List<io.Cookie>?> getCookies(String url) async {
    if (url.contains("https://")) {
      url.replaceAll("https://", "");
    }
    if (url[url.length - 1] == '/') {
      url = url.substring(0, url.length - 1);
    }
    CookieManager cookieManager = CookieManager.instance(
      webViewEnvironment: AppWebview.webViewEnvironment,
    );
    final cookies = await cookieManager.getCookies(
      url: WebUri(url),
      webViewController: this,
    );
    var res = <io.Cookie>[];
    for (var cookie in cookies) {
      var c = io.Cookie(cookie.name, cookie.value);
      c.domain = cookie.domain;
      res.add(c);
    }
    return res;
  }

  Future<String?> getUA() async {
    var res = await evaluateJavascript(source: "navigator.userAgent");
    if (res is String) {
      if (res[0] == "'" || res[0] == "\"") {
        res = res.substring(1, res.length - 1);
      }
    }
    return res is String ? res : null;
  }
}

class AppWebview extends StatefulWidget {
  const AppWebview(
      {required this.initialUrl,
      this.onTitleChange,
      this.onNavigation,
      this.singlePage = false,
      this.onStarted,
      this.onLoadStop,
      this.userAgent,
      super.key});

  final String initialUrl;

  final void Function(String title, InAppWebViewController controller)?
      onTitleChange;

  final bool Function(String url, InAppWebViewController controller)?
      onNavigation;

  final void Function(InAppWebViewController controller)? onStarted;

  final void Function(InAppWebViewController controller)? onLoadStop;

  final bool singlePage;

  final String? userAgent;

  static WebViewEnvironment? webViewEnvironment;

  @override
  State<AppWebview> createState() => _AppWebviewState();
}

class _AppWebviewState extends State<AppWebview> {
  static const double _kLocalAppBarHeight = 58;

  InAppWebViewController? controller;

  String title = "Webview";

  double _progress = 0;

  late var future = _createWebviewEnvironment();

  Future<void> _openInBrowser() async {
    final url = (await controller?.getUrl())?.toString();
    if (url != null) {
      await launchUrlString(url);
    }
  }

  Future<void> _copyLink() async {
    final url = (await controller?.getUrl())?.toString();
    if (url != null) {
      await Clipboard.setData(ClipboardData(text: url));
    }
  }

  void _showMoreMenu() {
    showMenuX(
      context,
      Offset(context.width, context.padding.top),
      [
        MenuEntry(
          icon: Icons.open_in_browser,
          text: "在浏览器中打开".tl,
          onClick: _openInBrowser,
        ),
        MenuEntry(
          icon: Icons.copy,
          text: "复制链接".tl,
          onClick: _copyLink,
        ),
        MenuEntry(
          icon: Icons.refresh,
          text: "重新加载".tl,
          onClick: () => controller?.reload(),
        ),
      ],
    );
  }

  List<Widget> _buildGlassMenuItems() {
    return [
      GlassMenuItem(
        title: "在浏览器中打开".tl,
        icon: const Icon(Icons.open_in_browser),
        onTap: _openInBrowser,
      ),
      GlassMenuItem(
        title: "复制链接".tl,
        icon: const Icon(Icons.copy),
        onTap: _copyLink,
      ),
      GlassMenuItem(
        title: "重新加载".tl,
        icon: const Icon(Icons.refresh),
        onTap: () => controller?.reload(),
      ),
    ];
  }

  PreferredSizeWidget _buildAppBar(List<Widget> actions) {
    final topPadding = context.padding.top;
    final content = SizedBox(
      height: _kLocalAppBarHeight + topPadding,
      child: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Tooltip(
              message: "返回".tl,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DefaultTextStyle(
                style: DefaultTextStyle.of(context).style.copyWith(fontSize: 20),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            ...actions,
            const SizedBox(width: 8),
          ],
        ),
      ),
    );

    final appBarChild = enableLiquidGlassUi
        ? GlassContainerLite(
            width: double.infinity,
            height: _kLocalAppBarHeight + topPadding,
            shape: LiquidRoundedSuperellipse(borderRadius: 28),
            child: content,
          )
        : Material(
            color: Theme.of(context).colorScheme.surface,
            child: content,
          );

    return PreferredSize(
      preferredSize: Size.fromHeight(_kLocalAppBarHeight + topPadding),
      child: appBarChild,
    );
  }

  Future<bool> _createWebviewEnvironment() async {
    // 获取代理设置 - 使用索引 [8]
    var proxy = appdata.settings[8].toString();
    // 只在 Android 平台处理代理设置，iOS 不支持 WebViewFeature API
    // 并且只处理非系统代理和非直连的情况
    if (App.isAndroid && proxy != "system" && proxy != "direct" && proxy != "0" && proxy.isNotEmpty) {
      var proxyAvailable = await WebViewFeature.isFeatureSupported(
        WebViewFeature.PROXY_OVERRIDE,
      );
      if (proxyAvailable) {
        ProxyController proxyController = ProxyController.instance();
        await proxyController.clearProxyOverride();
        if (!proxy.contains("://")) {
          proxy = "http://$proxy";
        }
        await proxyController.setProxyOverride(
          settings: ProxySettings(
            proxyRules: [ProxyRule(url: proxy)],
          ),
        );
      }
    }
    if (!App.isWindows) {
      return true;
    }
    AppWebview.webViewEnvironment = await WebViewEnvironment.create(
      settings: WebViewEnvironmentSettings(
        userDataFolder: "${App.dataPath}\\webview",
      ),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final actions = [
      if (enableLiquidGlassUi)
        Builder(builder: (context) {
          final view = View.of(context);
          final actualSize = Size(
            view.physicalSize.width / view.devicePixelRatio,
            view.physicalSize.height / view.devicePixelRatio,
          );
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(size: actualSize),
            child: GlassMenu(
              autoAdjustToScreen: true,
              menuWidth: 220,
              settings: LiquidGlassSettings(
                blur: 18,
                glassColor: isDark
                    ? scheme.surfaceContainerHighest.withValues(alpha: 0.24)
                    : Colors.white.withValues(alpha: 0.28),
                ambientStrength: isDark ? 0.34 : 0.48,
                saturation: 1.14,
                thickness: 18,
              ),
              items: _buildGlassMenuItems(),
              triggerBuilder: (ctx, toggle) => Tooltip(
                message: "更多",
                child: GlassIconActionButton(
                  icon: Icons.more_horiz,
                  tooltip: "更多".tl,
                  onTap: toggle,
                ),
              ),
            ),
          );
        })
      else
        Tooltip(
          message: "更多",
          child: IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: _showMoreMenu,
          ),
        )
    ];

    Widget body = FutureBuilder(
      future: future,
      builder: (context, e) {
        if (e.error != null) {
          return Center(child: Text("Error: ${e.error}"));
        }
        if (!e.hasData) {
          return const SizedBox();
        }
        return createWebviewWithEnvironment(
          AppWebview.webViewEnvironment,
        );
      },
    );

    body = Stack(
      children: [
        Positioned.fill(child: body),
        if (_progress < 1.0)
          const Positioned.fill(
              child: Center(child: CircularProgressIndicator()))
      ],
    );

    return Scaffold(
        appBar: _buildAppBar(actions),
        body: Builder(
          builder: (context) {
            final route = ModalRoute.of(context);
            if (route == null) return body;
            return AnimatedBuilder(
              animation: route.secondaryAnimation ?? const AlwaysStoppedAnimation(0),
              builder: (context, child) {
                return Offstage(
                  offstage: route.secondaryAnimation?.status != AnimationStatus.dismissed,
                  child: child,
                );
              },
              child: body,
            );
          },
        ));
  }

  Widget createWebviewWithEnvironment(WebViewEnvironment? e) {
    return InAppWebView(
      webViewEnvironment: e,
      initialSettings: InAppWebViewSettings(
        isInspectable: true,
        userAgent: widget.userAgent,
      ),
      initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
      onTitleChanged: (c, t) {
        if (mounted) {
          setState(() {
            title = t ?? "Webview";
          });
        }
        widget.onTitleChange?.call(title, controller!);
      },
      shouldOverrideUrlLoading: (c, r) async {
        var res =
            widget.onNavigation?.call(r.request.url?.toString() ?? "", c) ??
                false;
        if (res) {
          return NavigationActionPolicy.CANCEL;
        } else {
          return NavigationActionPolicy.ALLOW;
        }
      },
      onWebViewCreated: (c) {
        controller = c;
        widget.onStarted?.call(c);
      },
      onLoadStop: (c, r) {
        widget.onLoadStop?.call(c);
      },
      onProgressChanged: (c, p) {
        if (mounted) {
          setState(() {
            _progress = p / 100;
          });
        }
      },
    );
  }
}

class DesktopWebview {
  static Future<bool> isAvailable() => WebviewWindow.isWebviewAvailable();

  final String initialUrl;

  final void Function(String title, DesktopWebview controller)? onTitleChange;

  final void Function(String url, DesktopWebview webview)? onNavigation;

  final void Function(DesktopWebview controller)? onStarted;

  final void Function()? onClose;

  DesktopWebview(
      {required this.initialUrl,
      this.onTitleChange,
      this.onNavigation,
      this.onStarted,
      this.onClose});

  Webview? _webview;

  String? _ua;

  String? title;

  void onMessage(String message) {
    var json = jsonDecode(message);
    if (json is Map) {
      if (json["id"] == "document_created") {
        title = json["data"]["title"];
        _ua = json["data"]["ua"];
        onTitleChange?.call(title!, this);
      }
    }
  }

  String? get userAgent => _ua;

  Timer? timer;

  void _runTimer() {
    timer ??= Timer.periodic(const Duration(seconds: 2), (t) async {
      const js = '''
        function collect() {
          if(document.readyState === 'loading') {
            return '';
          }
          let data = {
            id: "document_created",
            data: {
              title: document.title,
              url: location.href,
              ua: navigator.userAgent
            }
          };
          return data;
        }
        collect();
      ''';
      if (_webview != null) {
        onMessage(await evaluateJavascript(js) ?? '');
      }
    });
  }

  void open() async {
    _webview = await WebviewWindow.create(
        configuration: CreateConfiguration(
      useWindowPositionAndSize: true,
      userDataFolderWindows: "${App.dataPath}\\webview",
      title: "webview",
      proxy: await getProxy(),
    ));
    _webview!.addOnWebMessageReceivedCallback(onMessage);
    _webview!.setOnNavigation((s) {
      s = s.substring(1, s.length - 1);
      return onNavigation?.call(s, this);
    });
    _webview!.launch(initialUrl, triggerOnUrlRequestEvent: false);
    _runTimer();
    _webview!.onClose.then((value) {
      _webview = null;
      timer?.cancel();
      timer = null;
      onClose?.call();
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      onStarted?.call(this);
    });
  }

  Future<String?> evaluateJavascript(String source) {
    return _webview!.evaluateJavaScript(source);
  }

  Future<Map<String, String>> getCookies(String url) async {
    var allCookies = await _webview!.getAllCookies();
    var res = <String, String>{};
    for (var c in allCookies) {
      if (_cookieMatch(url, c.domain)) {
        res[_removeCode0(c.name)] = _removeCode0(c.value);
      }
    }
    return res;
  }

  String _removeCode0(String s) {
    var codeUints = List<int>.from(s.codeUnits);
    codeUints.removeWhere((e) => e == 0);
    return String.fromCharCodes(codeUints);
  }

  bool _cookieMatch(String url, String domain) {
    domain = _removeCode0(domain);
    var host = Uri.parse(url).host;
    var acceptedHost = _getAcceptedDomains(host);
    return acceptedHost.contains(domain.removeAllBlank);
  }

  List<String> _getAcceptedDomains(String host) {
    var acceptedDomains = <String>[host];
    var hostParts = host.split(".");
    for (var i = 0; i < hostParts.length - 1; i++) {
      acceptedDomains.add(".${hostParts.sublist(i).join(".")}");
    }
    return acceptedDomains;
  }

  void close() {
    _webview?.close();
    _webview = null;
  }
}
