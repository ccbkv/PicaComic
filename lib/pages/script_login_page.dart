import 'dart:async';
import 'dart:convert';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/network/http_client.dart';
import 'package:pica_comic/utils/app_url_launcher.dart';
import 'package:pica_comic/utils/translations.dart';

import 'webview.dart';

typedef ScriptLoginCall = Future<dynamic> Function(
    String method, List<dynamic> arguments);

/// UI only. URLs, verification scripts and authentication decisions live in JS.
class ScriptLoginPage extends StatefulWidget {
  const ScriptLoginPage({super.key, required this.call});

  final ScriptLoginCall call;

  @override
  State<ScriptLoginPage> createState() => _ScriptLoginPageState();
}

class _ScriptLoginPageState extends State<ScriptLoginPage> {
  static int _nextSession = 0;
  late final String _session =
      '${DateTime.now().microsecondsSinceEpoch}-${_nextSession++}';
  final _username = TextEditingController();
  final _password = TextEditingController();
  Map<String, dynamic>? _config;
  String? _error;
  bool _busy = true;
  bool _verified = false;

  Future<Map<String, dynamic>> _call(String method,
      [List<dynamic> arguments = const []]) async {
    final value = await widget.call(method, [_session, ...arguments]);
    if (value is! Map) throw StateError('Invalid script login response');
    return Map<String, dynamic>.from(value);
  }

  @override
  void initState() {
    super.initState();
    _begin();
  }

  Future<void> _begin() async {
    try {
      final config = await _call('begin');
      if (mounted) setState(() => _config = config);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    // The script invalidates pending requests before they can save credentials.
    unawaited(
        widget.call('end', [_session]).then<void>((_) {}, onError: (_, __) {}));
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _applyResult(Map<String, dynamic> result) {
    if (!mounted) return;
    if (result['success'] == true) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      if (result['verified'] is bool) _verified = result['verified'];
      if (result['verificationRequired'] == true) _verified = false;
      _error = result['message']?.toString();
    });
  }

  Future<void> _openWebview(String mode) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final config = await _call('webview', [mode]);
      if (!mounted) return;
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (_) => _ScriptLoginWebview(
            config: config,
            onEvent: (event) => _call('onWebviewEvent', [mode, event]),
          ),
        ),
      );
      if (result != null) _applyResult(result);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = '请输入用户名和密码'.tl);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _applyResult(await _call('submit', [_username.text, _password.text]));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    return Scaffold(
      appBar: Appbar(title: Text((config?['title']?.toString() ?? '登录').tl)),
      body: config == null
          ? Center(
              child: _busy
                  ? const CircularProgressIndicator()
                  : Text(_error ?? 'Error'),
            )
          : LayoutBuilder(builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        (constraints.maxHeight - 64).clamp(0, double.infinity),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextField(
                        controller: _username,
                        enabled: !_busy,
                        decoration: InputDecoration(
                          labelText:
                              (config['usernameLabel']?.toString() ?? '用户名').tl,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _password,
                        enabled: !_busy,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText:
                              (config['passwordLabel']?.toString() ?? '密码').tl,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (config['verificationRequired'] == true) ...[
                        Text((_verified
                                ? config['verifiedLabel']?.toString() ?? '验证已完成'
                                : config['verificationPrompt']?.toString() ??
                                    '请先完成验证')
                            .tl),
                        TextButton(
                          onPressed:
                              _busy ? null : () => _openWebview('verify'),
                          child: Text(
                              (config['verifyLabel']?.toString() ?? '继续').tl),
                        ),
                      ],
                      if (_error != null)
                        Text(_error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            )),
                      const SizedBox(height: 16),
                      Button.filled(
                        isLoading: _busy,
                        disabled: _busy ||
                            (config['verificationRequired'] == true &&
                                !_verified),
                        onPressed: _submit,
                        child: Text(
                            (config['submitLabel']?.toString() ?? '登录').tl),
                      ),
                      if (config['webLoginLabel'] != null)
                        TextButton(
                          onPressed: _busy ? null : () => _openWebview('login'),
                          child: Text(config['webLoginLabel'].toString().tl),
                        ),
                      if (config['registerUrl'] != null)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => AppUrlLauncher.launchExternalUrl(
                                    config['registerUrl'].toString(),
                                  ),
                          child: Text(
                              (config['registerLabel']?.toString() ?? '创建账号')
                                  .tl),
                        ),
                    ],
                  ),
                ),
              );
            }),
    );
  }
}

class _ScriptLoginWebview extends StatefulWidget {
  const _ScriptLoginWebview({required this.config, required this.onEvent});

  final Map<String, dynamic> config;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) onEvent;

  @override
  State<_ScriptLoginWebview> createState() => _ScriptLoginWebviewState();
}

class _ScriptLoginWebviewState extends State<_ScriptLoginWebview> {
  InAppWebViewController? _mobile;
  Webview? _desktop;
  Timer? _timer;
  bool _polling = false;
  bool _closed = false;
  String? _error;

  String get _url => widget.config['url'] as String;
  String get _cookieUrl => widget.config['cookieUrl'] as String? ?? _url;

  @override
  void initState() {
    super.initState();
    final interval = (widget.config['pollIntervalMs'] as num? ?? 750)
        .toInt()
        .clamp(250, 5000);
    _timer = Timer.periodic(Duration(milliseconds: interval), (_) => _poll());
    if (App.isLinux) _openDesktop();
  }

  Future<void> _openDesktop() async {
    try {
      final window = await WebviewWindow.create(
          configuration: CreateConfiguration(
        userDataFolderWindows: '${App.dataPath}\\webview',
        title: widget.config['title']?.toString() ?? 'Login',
        proxy: await getProxy(),
      ));
      if (!mounted || _closed) {
        window.close();
        return;
      }
      _desktop = window;
      window.onClose.then((_) {
        _desktop = null;
        if (mounted && !_closed) {
          _closed = true;
          Navigator.of(context).pop();
        }
      });
      window.launch(_url, triggerOnUrlRequestEvent: false);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _poll() async {
    if (_polling || _closed || (_mobile == null && _desktop == null)) return;
    _polling = true;
    try {
      final script = widget.config['pollScript'] as String;
      dynamic event = _desktop != null
          ? await _desktop!.evaluateJavaScript(script)
          : await _mobile!.evaluateJavascript(source: script);
      if (event == null || event == '') return;
      // Desktop backends may return a JSON-encoded string instead of an object.
      for (var i = 0; event is String && i < 2; i++) {
        event = jsonDecode(event);
      }
      if (event is! Map || !mounted || _closed) return;
      final data = Map<String, dynamic>.from(event);
      final cookies = <Map<String, dynamic>>[];
      if (_desktop != null) {
        final uri = Uri.parse(_cookieUrl);
        for (final cookie in await _desktop!.getAllCookies()) {
          final domain = cookie.domain.replaceFirst(RegExp(r'^\.'), '');
          if ((uri.host == domain || uri.host.endsWith('.$domain')) &&
              uri.path.startsWith(cookie.path) &&
              (!cookie.secure || uri.scheme == 'https')) {
            cookies.add(cookie.toJson());
          }
        }
      } else {
        for (final cookie in await _mobile!.getCookies(_cookieUrl) ?? []) {
          cookies.add({
            'name': cookie.name,
            'value': cookie.value,
            'domain': cookie.domain,
            'path': cookie.path,
          });
        }
      }
      if (!mounted || _closed) return;
      data['cookies'] = cookies;
      data['desktop'] = _desktop != null;
      final result = await widget.onEvent(data);
      if (!mounted || _closed) return;
      if (result['close'] == true) {
        _closed = true;
        Navigator.of(context).pop(result);
      } else if (result['message'] != null) {
        setState(() => _error = result['message'].toString());
      }
    } catch (e) {
      if (mounted && !_closed) setState(() => _error = e.toString());
    } finally {
      _polling = false;
    }
  }

  @override
  void dispose() {
    _closed = true;
    _timer?.cancel();
    _desktop?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          Appbar(title: Text((widget.config['title']?.toString() ?? '登录').tl)),
      body: Column(
        children: [
          if (_error != null)
            Text(_error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                )),
          Expanded(
            child: App.isLinux
                ? const Center(child: CircularProgressIndicator())
                : AppWebview(
                    initialUrl: _url,
                    userAgent: widget.config['userAgent'] as String?,
                    singlePage: true,
                    onStarted: (controller) => _mobile = controller,
                    onLoadStop: (controller) {
                      _mobile = controller;
                      _poll();
                    },
                    onTitleChange: (_, controller) {
                      _mobile = controller;
                      _poll();
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
