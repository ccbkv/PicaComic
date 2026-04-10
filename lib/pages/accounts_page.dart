import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pica_comic/foundation/comic_source/comic_source.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/ui_mode.dart';
import 'package:pica_comic/utils/translations.dart';
import 'package:pica_comic/pages/webview.dart';
import 'package:pica_comic/foundation/js_engine.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' show CookieManager, WebUri;
import 'package:url_launcher/url_launcher_string.dart';

class AccountsPageLogic extends StateController {
  final _reLogin = <String, bool>{};
}

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  AccountsPageLogic get logic => StateController.find<AccountsPageLogic>();

  @override
  Widget build(BuildContext context) {
    var body = StateBuilder<AccountsPageLogic>(
      init: AccountsPageLogic(),
      builder: (logic) {
        Widget body = CustomScrollView(
          slivers: [
            SliverList(
              delegate: SliverChildListDelegate(
                buildContent(context).toList(),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.only(bottom: context.padding.bottom),
            )
          ],
        );
        if (App.isFluent) {
          return Material(
            type: MaterialType.transparency,
            child: body,
          );
        }
        return body;
      },
    );

    if (PopupIndicatorWidget.maybeOf(context) != null) {
      return PopUpWidgetScaffold(title: "账号管理".tl, body: body);
    } else {
      return Scaffold(
        appBar: AppBar(
          title: Text("账号管理".tl),
        ),
        body: body,
      );
    }
  }

  Iterable<Widget> buildContent(BuildContext context) sync* {
    var sources =
        ComicSource.sources.where((element) => element.account != null);
    if (sources.isEmpty) return;

    for (var element in sources) {
      final bool logged = element.isLogin;
      yield Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(
          element.name.tl,
          style: const TextStyle(fontSize: 20),
        ),
      );
      if (!logged) {
        yield ListTile(
          title: Text("登录".tl),
          onTap: () async {
            if (element.account!.onLogin != null) {
              await element.account!.onLogin!(context);
            }
            if (element.account!.login != null && context.mounted) {
              await context.to(
                () => _LoginPage(
                  login: element.account!.login!,
                  loginWebsite: element.account!.loginWebsite,
                  registerWebsite: element.account!.registerWebsite,
                  source: element,
                ),
              );
              element.saveData();
            }
            logic.update();
            StateController.findOrNull(tag: "me_page_accounts")?.update();
          },
        );
      }
      if (logged) {
        for (var item in element.account!.infoItems) {
          if (item.builder != null) {
            yield item.builder!(context);
          } else {
            yield ListTile(
              title: Text(item.title.tl),
              subtitle: item.data == null ? null : Text(item.data!()),
              onTap: item.onTap,
            );
          }
        }
        if (element.account!.allowReLogin) {
          bool loading = logic._reLogin[element.key] == true;
          yield ListTile(
            title: Text("重新登录".tl),
            subtitle: Text("如果登录失效点击此处".tl),
          onTap: () async {
            if (element.data["account"] == null) {
              showToast(message: "无数据".tl);
              return;
            }
            logic._reLogin[element.key] = true;
            logic.update();
            final List account = element.data["account"];
            var res = await element.account!.login!(account[0], account[1]);
            if (res.error) {
              showToast(message: res.errorMessage!);
            } else {
              showToast(message: "重新登录成功".tl);
            }
            logic._reLogin[element.key] = false;
            logic.update();
            StateController.findOrNull(tag: "me_page_accounts")?.update();
          },
            trailing: loading
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh),
          );
        }
        yield ListTile(
          title: Text("退出登录".tl),
          onTap: () async {
            element.data["account"] = null;
            element.account?.logout();
            element.saveData();
            // 清除 WebView 的所有 cookies，防止网页登录时自动使用旧凭证
            try {
              var cookieManager = CookieManager.instance(
                webViewEnvironment: AppWebview.webViewEnvironment,
              );
              await cookieManager.deleteAllCookies();
            } catch (_) {}
            logic.update();
            StateController.findOrNull(tag: "me_page_accounts")?.update();
          },
          trailing: const Icon(Icons.logout),
        );
      }
      yield const Divider();
    }
  }

  void setClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    showToast(message: "已复制".tl, icon: const Icon(Icons.check));
  }
}

class _LoginPage extends StatefulWidget {
  const _LoginPage({required this.login, this.loginWebsite, this.registerWebsite, this.source});

  final LoginFunction login;

  final String? loginWebsite;

  final String? registerWebsite;

  final ComicSource? source;

  @override
  State<_LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<_LoginPage> {
  String username = "";
  String password = "";
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        title: Text("登录".tl),
      ),
      body: Column(children: [
        const Spacer(),
        TextField(
          decoration: InputDecoration(
            labelText: "用户名".tl,
            border: const OutlineInputBorder(),
          ),
          onChanged: (s) {
            username = s;
          },
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: InputDecoration(
            labelText: "密码".tl,
            border: const OutlineInputBorder(),
          ),
          obscureText: true,
          onChanged: (s) {
            password = s;
          },
          onSubmitted: (s) => login(),
        ),
        const SizedBox(height: 32),
        Button.filled(
          isLoading: loading,
          onPressed: login,
          child: Text("继续".tl),
        ),
        const SizedBox(height: 16),
        if (widget.loginWebsite != null || widget.source != null)
          TextButton(
            onPressed: loginWithWebview,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("通过网页登录".tl),
                const SizedBox(width: 4),
                const Icon(
                  Icons.open_in_browser,
                  size: 16,
                ),
              ],
            ),
          ),
        const Spacer(),
        if (widget.registerWebsite != null)
          TextButton(
            onPressed: () => launchUrlString(widget.registerWebsite!),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("注册".tl),
                const SizedBox(width: 4),
                const Icon(
                  Icons.open_in_new,
                  size: 16,
                ),
              ],
            ),
          ),
        if (UiMode.m1(context))
          SizedBox(
            height: MediaQuery.of(context).padding.bottom,
          ),
      ]).paddingLeft(32).paddingRight(32).paddingBottom(16),
    );
  }

  void login() {
    if (username.isEmpty || password.isEmpty) {
      showToast(message: "不能为空".tl, icon: const Icon(Icons.error_outline));
      return;
    }
    setState(() {
      loading = true;
    });
    widget.login(username, password).then((value) {
      if (value.error) {
        showToast(message: value.errorMessage!);
        setState(() {
          loading = false;
        });
      } else {
        showToast(message: "登录成功".tl, icon: const Icon(Icons.check));
        StateController.findOrNull(tag: "me_page_accounts")?.update();
        if(mounted) {
          context.pop();
        }
      }
    });
  }

  void loginWithWebview() async {
    String? loginUrl = widget.loginWebsite;
    if (loginUrl == null && widget.source != null) {
      try {
        var apiUrl = JsEngine().runCode(
          "ComicSource.sources.${widget.source!.key}.apiUrl",
        );
        if (apiUrl is String && apiUrl.isNotEmpty) {
          loginUrl = "$apiUrl/web/login";
        }
      } catch (_) {}
    }
    if (loginUrl == null) return;
    var url = loginUrl;
    bool success = false;
    bool _cookiesCleared = false;

    void checkLogin(controller) async {
      if (success) return;
      try {
        var cookieManager = CookieManager.instance(
          webViewEnvironment: AppWebview.webViewEnvironment,
        );
        var cookies = await cookieManager.getCookies(url: WebUri(url));
        for (var cookie in cookies) {
          if (cookie.name == 'token' && cookie.value.isNotEmpty) {
            success = true;
            if (widget.source != null) {
              try {
                JsEngine().runCode(
                  "ComicSource.sources.${widget.source!.key}.saveData('token', ${jsonEncode(cookie.value)})",
                );
              } catch (_) {}
              widget.source!.data['account'] = 'ok';
              widget.source!.saveData();
            }
            showToast(message: "登录成功".tl, icon: const Icon(Icons.check));
            StateController.findOrNull(tag: "me_page_accounts")?.update();
            if (mounted) {
              Navigator.of(context).pop();
            }
            break;
          }
        }
      } catch (_) {}
    }

    if (App.isLinux) {
      if (!await DesktopWebview.isAvailable()) {
        showToast(message: "不支持".tl);
        return;
      }
      var webview = DesktopWebview(
        initialUrl: url,
        onTitleChange: (currentUrl, wv) async {
          if (success) return;
          var cookies = await wv.getCookies(url);
          if (cookies != null && cookies.containsKey('token')) {
            success = true;
            if (widget.source != null) {
              try {
                JsEngine().runCode(
                  "ComicSource.sources.${widget.source!.key}.saveData('token', ${jsonEncode(cookies['token'])})",
                );
              } catch (_) {}
              widget.source!.data['account'] = 'ok';
              widget.source!.saveData();
            }
            wv.close();
            showToast(message: "登录成功".tl, icon: const Icon(Icons.check));
            StateController.findOrNull(tag: "me_page_accounts")?.update();
            if (mounted) {
              Navigator.of(context).pop();
            }
          }
        },
      );
      webview.open();
    } else {
      // 使用桌面版 User-Agent，防止移动端跳转到 H5 页面
      const desktopUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      await context.to(() => AppWebview(
        initialUrl: url,
        userAgent: desktopUserAgent,
        onTitleChange: (title, controller) {
          checkLogin(controller);
        },
        onLoadStop: (controller) async {
          // 首次加载页面时清除 cookies，确保登录页面是干净的状态
          if (!_cookiesCleared) {
            _cookiesCleared = true;
            try {
              await controller.evaluateJavascript(source: '''
                (function() {
                  var cookies = document.cookie.split(";");
                  for (var i = 0; i < cookies.length; i++) {
                    var cookie = cookies[i].trim();
                    if (!cookie) continue;
                    var eqPos = cookie.indexOf("=");
                    var name = eqPos > -1 ? cookie.substr(0, eqPos) : cookie;
                    // 尝试多种方式删除 cookie
                    document.cookie = name + "=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/";
                    document.cookie = name + "=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/;domain=" + location.hostname;
                    var domainParts = location.hostname.split('.');
                    if (domainParts.length > 1) {
                      var rootDomain = domainParts.slice(-2).join('.');
                      document.cookie = name + "=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/;domain=." + rootDomain;
                    }
                  }
                  return document.cookie === "" ? "cleared" : "has_cookies";
                })();
              ''');
              // 清除 cookies 后刷新页面，确保服务器看到干净的请求
              await controller.reload();
              return;
            } catch (_) {}
          }
          checkLogin(controller);
        },
      ));
    }
  }
}
