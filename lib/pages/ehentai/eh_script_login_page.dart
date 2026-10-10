import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/network/cloudflare.dart';
import 'package:pica_comic/network/cookie_jar.dart';
import 'package:pica_comic/pages/webview.dart';
import 'package:pica_comic/utils/translations.dart';

/// EH's Prime login protocol; the script owns cookie validation and success.
class EhScriptLoginPage extends StatefulWidget {
  const EhScriptLoginPage({
    super.key,
    required this.fields,
    required this.validateCookies,
    this.loginUrl,
    this.checkStatus,
    this.onLoginSuccess,
  });

  final List<String> fields;
  final Future<bool> Function(List<String>) validateCookies;
  final String? loginUrl;
  final Future<bool> Function(String, String)? checkStatus;
  final Future<void> Function()? onLoginSuccess;

  @override
  State<EhScriptLoginPage> createState() => _EhScriptLoginPageState();
}

class _EhScriptLoginPageState extends State<EhScriptLoginPage> {
  late final _controllers =
      widget.fields.map((_) => TextEditingController()).toList();
  bool _busy = false;
  String? _error;
  DesktopWebview? _desktop;

  @override
  void dispose() {
    _desktop?.close();
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final values = _controllers.map((c) => c.text).toList();
      bool success;
      try {
        success = await widget.validateCookies(values);
      } catch (e) {
        final challenge = CloudflareException.fromString(e.toString());
        if (challenge == null || !mounted) rethrow;
        final verified = Completer<void>();
        passCloudflare(challenge, () {
          if (!verified.isCompleted) verified.complete();
        });
        await verified.future;
        if (!mounted) return;
        final cookies = SingleInstanceCookieJar.instance!
            .loadForRequest(Uri.parse(challenge.url));
        if (!cookies.any(
            (cookie) => cookie.name == 'cf_clearance' && cookie.value.isNotEmpty)) {
          setState(() => _error = 'Cloudflare 验证未完成'.tl);
          return;
        }
        // Retry once; a challenge must never count as a successful login.
        success = await widget.validateCookies(values);
      }
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = '登录失败'.tl);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _webLogin() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    var url = widget.loginUrl!;
    var title = '';
    var checking = false;
    var closed = false;
    var succeeded = false;

    Future<bool> validate(Future<List<Cookie>> Function() getCookies) async {
      if (checking || closed || succeeded || !mounted) return false;
      checking = true;
      try {
        final currentUrl = url;
        if (!await widget.checkStatus!(currentUrl, title)) return false;
        final cookies = await getCookies();
        if (closed || !mounted) return false;
        SingleInstanceCookieJar.instance!
            .saveFromResponse(Uri.parse(currentUrl), cookies);
        await widget.onLoginSuccess?.call();
        if (closed || !mounted) return false;
        succeeded = true;
        return true;
      } catch (e) {
        if (mounted) setState(() => _error = e.toString());
        return false;
      } finally {
        checking = false;
      }
    }

    try {
      if (App.isLinux) {
        if (!await DesktopWebview.isAvailable()) {
          throw StateError('Webview is not available');
        }
        if (!mounted) return;
        final done = Completer<void>();
        Future<void> check(DesktopWebview webview) async {
          if (await validate(() async {
            final values = await webview.getCookies(url);
            // Preserve EH's shared login domain when the desktop API only
            // supplies cookie names and values.
            return values.entries.map((entry) {
              final cookie = Cookie(entry.key, entry.value);
              if (Uri.parse(url).host.endsWith('.e-hentai.org')) {
                cookie.domain = '.e-hentai.org';
              }
              return cookie;
            }).toList();
          })) {
            webview.close();
          }
        }

        _desktop = DesktopWebview(
          initialUrl: url,
          onNavigation: (value, webview) {
            url = value;
            unawaited(check(webview));
          },
          onTitleChange: (value, webview) {
            title = value;
            unawaited(check(webview));
          },
          onClose: () {
            closed = true;
            if (!done.isCompleted) done.complete();
          },
        );
        _desktop!.open();
        await done.future;
        _desktop = null;
      } else {
        final navigator = Navigator.of(context);
        late final MaterialPageRoute<void> route;
        route = MaterialPageRoute<void>(
          builder: (_) => AppWebview(
            initialUrl: widget.loginUrl!,
            singlePage: true,
            onTitleChange: (value, controller) async {
              title = value;
              url = (await controller.getUrl())?.toString() ?? url;
              if (!route.isCurrent) return;
              if (await validate(
                  () async => await controller.getCookies(url) ?? <Cookie>[])) {
                if (route.isCurrent) navigator.pop();
              }
            },
            onLoadStop: (controller) async {
              url = (await controller.getUrl())?.toString() ?? url;
              title = await controller.getTitle() ?? '';
              if (!route.isCurrent) return;
              if (await validate(
                  () async => await controller.getCookies(url) ?? <Cookie>[])) {
                if (route.isCurrent) navigator.pop();
              }
            },
          ),
        );
        await navigator.push(route);
        closed = true;
      }
      if (mounted && succeeded) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      closed = true;
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('登录'.tl)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            width: 400,
            child: Column(
              children: [
                for (var i = 0; i < widget.fields.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextField(
                      controller: _controllers[i],
                      enabled: !_busy,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: widget.fields[i],
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                if (_error != null)
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                if (_busy)
                  const CircularProgressIndicator()
                else
                  FilledButton(onPressed: _login, child: Text('登录'.tl)),
                if (widget.loginUrl != null && widget.checkStatus != null)
                  TextButton(
                    onPressed: _busy ? null : _webLogin,
                    child: Text('在Webview中登录'.tl),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
