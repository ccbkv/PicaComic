import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pica_comic/base.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/app_page_route.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/foundation/ui_mode.dart';
import 'package:pica_comic/network/cloudflare.dart';
import 'package:pica_comic/network/nhentai_network/nhentai_main_network.dart';
import 'package:pica_comic/pages/webview.dart';
import 'package:pica_comic/utils/translations.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// NHentai API v2 登录响应
class NhentaiLoginResponse {
  final String accessToken;
  final String? refreshToken;
  final int? expiresIn;
  final String? tokenType;
  final Map<String, dynamic>? user;

  NhentaiLoginResponse({
    required this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.tokenType,
    this.user,
  });

  factory NhentaiLoginResponse.fromJson(Map<String, dynamic> json) {
    return NhentaiLoginResponse(
      accessToken: json['access_token']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString(),
      expiresIn: int.tryParse(json['expires_in']?.toString() ?? ''),
      tokenType: json['token_type']?.toString(),
      user: json['user'] as Map<String, dynamic>?,
    );
  }
}

/// PoW (Proof of Work) 挑战响应
class NhentaiPowChallenge {
  final String challenge;
  final int difficulty;

  NhentaiPowChallenge({
    required this.challenge,
    required this.difficulty,
  });

  factory NhentaiPowChallenge.fromJson(Map<String, dynamic> json) {
    return NhentaiPowChallenge(
      challenge: json['challenge']?.toString() ?? '',
      difficulty: int.tryParse(json['difficulty']?.toString() ?? '0') ?? 0,
    );
  }
}

/// CAPTCHA 配置响应
class NhentaiCaptchaConfig {
  final String provider;
  final String siteKey;

  NhentaiCaptchaConfig({
    required this.provider,
    required this.siteKey,
  });

  factory NhentaiCaptchaConfig.fromJson(Map<String, dynamic> json) {
    return NhentaiCaptchaConfig(
      provider: json['provider']?.toString() ?? '',
      siteKey: json['site_key']?.toString() ?? '',
    );
  }
}

/// 解决 PoW nonce
Future<String> solvePowNonce({
  required String challenge,
  required int difficulty,
  int maxIterations = 3000000,
}) async {
  return await Isolate.run<String>(() => _solvePowNonceJob(
    challenge: challenge,
    difficulty: difficulty,
    maxIterations: maxIterations,
  ));
}

Future<String> _solvePowNonceJob({
  required String challenge,
  required int difficulty,
  required int maxIterations,
}) async {
  for (var nonce = 0; nonce < maxIterations; nonce++) {
    final nonceText = nonce.toString();
    final input = '$challenge$nonceText';
    final digest = sha256.convert(utf8.encode(input)).bytes;
    if (_hasLeadingZeroBits(digest, difficulty)) {
      return nonceText;
    }
  }
  throw StateError('PoW nonce not found within $maxIterations iterations');
}

bool _hasLeadingZeroBits(List<int> bytes, int bits) {
  if (bits <= 0) return true;

  var remaining = bits;
  for (final byte in bytes) {
    if (remaining <= 0) return true;

    if (remaining >= 8) {
      if (byte != 0) return false;
      remaining -= 8;
      continue;
    }

    final mask = 0xFF << (8 - remaining) & 0xFF;
    return (byte & mask) == 0;
  }

  return remaining <= 0;
}

/// 获取 PoW 挑战
Future<NhentaiPowChallenge> getPowChallenge() async {
  final response = await NhentaiNetwork().dio.get<dynamic>(
    '${NhentaiNetwork().apiUrl}/pow',
    queryParameters: {'action': 'login'},
  );
  return NhentaiPowChallenge.fromJson(response.data as Map<String, dynamic>);
}

/// 获取 CAPTCHA 配置
Future<NhentaiCaptchaConfig> getCaptchaConfig() async {
  final response = await NhentaiNetwork().dio.get<dynamic>('${NhentaiNetwork().apiUrl}/captcha');
  return NhentaiCaptchaConfig.fromJson(response.data as Map<String, dynamic>);
}

/// 执行 API 登录
Future<NhentaiLoginResponse> apiLogin({
  required String username,
  required String password,
  required String captchaResponse,
  required String powChallenge,
  required String powNonce,
}) async {
  final response = await NhentaiNetwork().dio.post<dynamic>(
    '${NhentaiNetwork().apiUrl}/auth/login',
    data: {
      'username': username.trim(),
      'password': password,
      'captcha_response': captchaResponse.replaceAll(RegExp(r'\s+'), ''),
      'pow_challenge': powChallenge,
      'pow_nonce': powNonce,
      'pow_action': 'login',
    },
  );

  final data = response.data as Map<String, dynamic>;
  final loginResponse = NhentaiLoginResponse.fromJson(data);

  if (loginResponse.accessToken.isEmpty) {
    throw StateError('Access token missing from login response');
  }

  return loginResponse;
}

/// 显示 API 登录页面
Future<void> showApiLoginDialog(
  BuildContext context, {
  required void Function() onSuccess,
}) async {
  final result = await showPopUpWidget<bool>(
    context,
    const NhentaiLoginPage(),
  );

  if (result == true) {
    onSuccess();
  }
}

/// NHentai 登录页面
class NhentaiLoginPage extends StatefulWidget {
  const NhentaiLoginPage({super.key});

  @override
  State<NhentaiLoginPage> createState() => _NhentaiLoginPageState();
}

class _NhentaiLoginPageState extends State<NhentaiLoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // 验证状态
  bool _needCloudflare = false;
  bool _isVerifying = false;
  bool _cloudflarePassed = false;
  bool _loading = false;

  // PoW 相关
  NhentaiPowChallenge? _powChallenge;
  NhentaiCaptchaConfig? _captchaConfig;

  // CAPTCHA token
  String? _captchaToken;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 使用 passCloudflare 进行验证
  Future<void> _passCloudflareVerification() async {
    final url = '${NhentaiNetwork().baseUrl}/login/?next=/';

    passCloudflare(
      CloudflareException(url),
      () {
        setState(() {
          _cloudflarePassed = true;
          _needCloudflare = false;
        });
        _getCookiesAfterCloudflare();
      },
    );
  }

  /// Cloudflare 验证后获取 cookies
  Future<void> _getCookiesAfterCloudflare() async {
    try {
      // 尝试获取 PoW 和 CAPTCHA 配置
      await _initializeChallenge();
    } catch (e) {
      Log.error('NHentaiLogin', 'Error after cloudflare: $e');
    }
  }

  Future<void> _initializeChallenge() async {
    try {
      _powChallenge = await getPowChallenge();
      _captchaConfig = await getCaptchaConfig();
    } catch (e) {
      Log.error('NHentaiLogin', 'Failed to get challenge: $e');
    }
  }

  Future<void> _doLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
    });

    try {
      // 确保有 PoW 挑战
      if (_powChallenge == null) {
        await _initializeChallenge();
      }

      if (_powChallenge == null) {
        setState(() {
          _loading = false;
        });
        showToast(message: '无法获取验证信息，请重试'.tl);
        return;
      }

      // 解决 PoW
      final powNonce = await solvePowNonce(
        challenge: _powChallenge!.challenge,
        difficulty: _powChallenge!.difficulty,
      );

      // 检查是否有 CAPTCHA token
      if (_captchaToken == null || _captchaToken!.isEmpty) {
        setState(() {
          _loading = false;
          _needCloudflare = true;
        });
        showToast(message: '请先完成验证'.tl);
        return;
      }

      // 尝试登录
      try {
        final loginResponse = await apiLogin(
          username: _usernameController.text,
          password: _passwordController.text,
          captchaResponse: _captchaToken!,
          powChallenge: _powChallenge!.challenge,
          powNonce: powNonce,
        );

        // 登录成功
        await _saveLoginState(loginResponse);
        setState(() {
          _loading = false;
        });
        if (mounted) {
          Navigator.of(context).pop(true);
        }
        showToast(message: '登录成功'.tl);
        return;
      } on DioException catch (e) {
        // 检查是否需要 Cloudflare 验证
        if (e is CloudflareException || e.response?.statusCode == 403) {
          setState(() {
            _loading = false;
            _needCloudflare = true;
          });
          showToast(message: '需要先进行Cloudflare验证'.tl);
          return;
        }
        // 其他错误，可能是需要 CAPTCHA
        if (e.response?.data != null) {
          final errorData = e.response!.data;
          if (errorData.toString().contains('captcha')) {
            setState(() {
              _loading = false;
              _needCloudflare = true;
            });
            showToast(message: '需要先进行Cloudflare验证'.tl);
            return;
          }
        }
        rethrow;
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
      String errorMsg = e.toString();
      if (errorMsg.contains('Login failed')) {
        errorMsg = '登录失败：用户名或密码错误'.tl;
      } else if (errorMsg.contains('captcha') || errorMsg.contains('CAPTCHA')) {
        errorMsg = '需要先进行Cloudflare验证'.tl;
        setState(() {
          _needCloudflare = true;
        });
      } else {
        errorMsg = '登录失败: $errorMsg'.tl;
      }
      showToast(message: errorMsg);
      Log.error('NHentaiLogin', 'Login error: $e');
    }
  }

  /// 保存登录状态
  Future<void> _saveLoginState(NhentaiLoginResponse loginResponse) async {
    final cookieJar = NhentaiNetwork().cookieJar!;
    final uri = Uri.parse(NhentaiNetwork().baseUrl);

    final accessTokenCookie = io.Cookie('access_token', loginResponse.accessToken);
    accessTokenCookie.domain = '.nhentai.net';
    cookieJar.saveFromResponse(uri, [accessTokenCookie]);

    if (loginResponse.refreshToken != null && loginResponse.refreshToken!.isNotEmpty) {
      final refreshTokenCookie = io.Cookie('refresh_token', loginResponse.refreshToken!);
      refreshTokenCookie.domain = '.nhentai.net';
      cookieJar.saveFromResponse(uri, [refreshTokenCookie]);
    }

    NhentaiNetwork().logged = true;
  }

  @override
  Widget build(BuildContext context) {
    var body = Column(
        children: [
          const Spacer(),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: '用户名'.tl,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入用户名'.tl;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: '密码'.tl,
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入密码'.tl;
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _doLogin(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // CAPTCHA 验证区域
          if (_captchaToken == null || _captchaToken!.isEmpty)
            _buildCaptchaPrompt()
          else
            _buildCaptchaVerifiedIndicator(),
          const SizedBox(height: 32),
          Button.filled(
            isLoading: _loading,
            disabled: _captchaToken == null || _captchaToken!.isEmpty,
            onPressed: _doLogin,
            child: Text('登录'.tl),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              if (App.isLinux) {
                _loginWithWebViewDesktop();
              } else {
                _loginWithWebView();
              }
            },
            child: Text('通过网页登录'.tl),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => launchUrlString('https://nhentai.net/register'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link),
                const SizedBox(width: 8),
                Text('创建账号'.tl),
              ],
            ),
          ),
          if (UiMode.m1(context))
            SizedBox(
              height: MediaQuery.of(context).padding.bottom,
            ),
        ],
      ).paddingLeft(32).paddingRight(32).paddingBottom(16);

    return Scaffold(
      appBar: Appbar(
        title: Text('登录'.tl),
      ),
      body: body,
    );
  }

  /// CAPTCHA 验证提示
  Widget _buildCaptchaPrompt() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '需要先进行Cloudflare验证'.tl,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Button.filled(
            onPressed: _openCaptchaWebView,
            child: Text('继续'.tl),
          ),
        ],
      ),
    );
  }

  /// CAPTCHA 验证完成的指示器
  Widget _buildCaptchaVerifiedIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 8),
          Text(
            '验证已完成'.tl,
            style: const TextStyle(color: Colors.green),
          ),
        ],
      ),
    );
  }

  /// 打开 CAPTCHA WebView
  Future<void> _openCaptchaWebView() async {
    if (_captchaConfig == null) {
      showToast(message: '正在获取验证配置...'.tl);
      try {
        _captchaConfig = await getCaptchaConfig();
      } catch (e) {
        showToast(message: '获取验证配置失败'.tl);
        return;
      }
    }

    final token = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => NhentaiCaptchaPage(
          siteKey: _captchaConfig!.siteKey,
        ),
      ),
    );

    if (token != null && token.isNotEmpty) {
      setState(() {
        _captchaToken = token;
      });
      showToast(message: '验证成功'.tl);
    }
  }

  /// 使用 WebView 登录（移动端）
  Future<void> _loginWithWebView() async {
    bool loginSuccess = false;
    bool hasSeenLoginPage = false;
    
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (outerContext) => AppWebview(
          initialUrl: "${NhentaiNetwork().baseUrl}/login/?next=/",
          singlePage: true,
          onTitleChange: (title, controller) async {
            Log.info('NHentaiLogin', 'WebView title changed: $title');
            
            // 检测是否看到了登录页面
            if (title.contains("Login")) {
              hasSeenLoginPage = true;
              Log.info('NHentaiLogin', 'Detected login page, waiting for user to login...');
              return;
            }
            
            // 只有在看到过登录页面，且当前不在登录/注册页面时，才认为登录成功
            if (hasSeenLoginPage &&
                !title.contains("Login") &&
                !title.contains("Register") &&
                title.contains("nhentai")) {
              var ua = await controller.getUA();
              if (ua != null) {
                appdata.implicitData[3] = ua;
                appdata.writeImplicitData();
              }
              var cookiesList = await controller.getCookies("${NhentaiNetwork().baseUrl}/");
              Log.info('NHentaiLogin', 'Cookies received: ${cookiesList?.length ?? 0}');
              if (cookiesList != null) {
                bool hasSession = false;
                for (var cookie in cookiesList) {
                  Log.info('NHentaiLogin', 'Cookie: ${cookie.name}');
                  // NHentai 使用 access_token 或 sessionid 表示登录状态
                  if (cookie.name == "access_token" ||
                      cookie.name == "sessionid" ||
                      cookie.name == "XSRF-TOKEN") {
                    hasSession = true;
                  }
                  cookie.domain = ".nhentai.net";
                }
                NhentaiNetwork().cookieJar!.saveFromResponse(
                    Uri.parse(NhentaiNetwork().baseUrl), cookiesList);
                if (hasSession) {
                  NhentaiNetwork().logged = true;
                  loginSuccess = true;
                  Log.info('NHentaiLogin', 'Login successful, closing WebView');
                  // 关闭 WebView 页面
                  if (Navigator.canPop(outerContext)) {
                    Navigator.of(outerContext).pop();
                  }
                }
              }
            }
          },
          onLoadStop: (controller) async {
            // 页面加载完成时也检查一次 cookies
            Log.info('NHentaiLogin', 'Page loaded, checking cookies...');
            var cookiesList = await controller.getCookies("${NhentaiNetwork().baseUrl}/");
            if (cookiesList != null) {
              for (var cookie in cookiesList) {
                if (cookie.name == "access_token" ||
                    cookie.name == "sessionid" ||
                    cookie.name == "XSRF-TOKEN") {
                  Log.info('NHentaiLogin', 'Found session cookie on load: ${cookie.name}');
                }
              }
            }
          },
        ),
      ),
    );
    
    // 如果 WebView 登录成功，关闭登录页面并返回 true
    Log.info('NHentaiLogin', 'WebView closed, loginSuccess=$loginSuccess');
    if (loginSuccess && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  /// 使用 WebView 登录（桌面端）
  void _loginWithWebViewDesktop() {
    bool loginSuccess = false;
    var webview = DesktopWebview(
      initialUrl: "${NhentaiNetwork().baseUrl}/login/?next=/",
      onTitleChange: (title, controller) async {
        Log.info('NHentaiLogin', 'Desktop WebView title changed: $title');
        if (title == "nhentai.net") return;
        if (!title.contains("Login") && !title.contains("Register") && title.contains("nhentai")) {
          var ua = controller.userAgent;
          if (ua != null) {
            appdata.implicitData[3] = ua;
            appdata.writeImplicitData();
          }
          var cookies = await controller.getCookies("${NhentaiNetwork().baseUrl}/");
          Log.info('NHentaiLogin', 'Desktop cookies received: ${cookies?.length ?? 0}');
          List<io.Cookie> cookiesList = [];
          bool hasSession = false;
          if (cookies != null) {
            cookies.forEach((key, value) {
              Log.info('NHentaiLogin', 'Desktop cookie: $key');
              // NHentai 使用 access_token 或 sessionid 表示登录状态
              if (key == "access_token" ||
                  key == "sessionid" ||
                  key == "XSRF-TOKEN") {
                hasSession = true;
              }
              var cookie = io.Cookie(key, value);
              cookie.domain = ".nhentai.net";
              if (key != "cf_clearance") {
                cookiesList.add(cookie);
              }
            });
          }
          NhentaiNetwork().cookieJar!.saveFromResponse(
              Uri.parse(NhentaiNetwork().baseUrl), cookiesList);
          if (hasSession) {
            NhentaiNetwork().logged = true;
            loginSuccess = true;
            Log.info('NHentaiLogin', 'Desktop login successful');
            controller.close();
            if (mounted) {
              // 关闭登录页面并返回 true
              Navigator.of(context).pop(true);
            }
          }
        }
      },
    );
    webview.open();
  }
}

/// 旧的 WebView 登录方式（保留作为备用）
void nhLoginWebView(void Function() onFinished) async {
  if (App.isLinux) {
    var webview = DesktopWebview(
      initialUrl: "${NhentaiNetwork().baseUrl}/login/?next=/",
      onTitleChange: (title, controller) async {
        print(title);
        if (title == "nhentai.net") return;
        if (!title.contains("Login") && !title.contains("Register") && title.contains("nhentai")) {
          var ua = controller.userAgent;
          if (ua != null) {
            appdata.implicitData[3] = ua;
            appdata.writeImplicitData();
          }
          var cookies = await controller.getCookies("${NhentaiNetwork().baseUrl}/");
          List<io.Cookie> cookiesList = [];
          if (cookies != null) {
            cookies.forEach((key, value) {
              var cookie = io.Cookie(key, value);
              if (key == "sessionid" || key == "XSRF-TOKEN") {
                NhentaiNetwork().logged = true;
              }
              cookie.domain = ".nhentai.net";
              if (key != "cf_clearance") {
                cookiesList.add(cookie);
              }
            });
          }
          NhentaiNetwork().cookieJar!.saveFromResponse(
              Uri.parse(NhentaiNetwork().baseUrl), cookiesList);
          if (NhentaiNetwork().logged) {
            onFinished();
            controller.close();
          }
        }
      },
    );
    webview.open();
  } else {
    await App.globalTo(() => AppWebview(
          initialUrl: "${NhentaiNetwork().baseUrl}/login/?next=/",
          singlePage: true,
          onTitleChange: (title, controller) async {
            if (!title.contains("Login") &&
                !title.contains("Register") &&
                title.contains("nhentai")) {
              var ua = await controller.getUA();
              if (ua != null) {
                appdata.implicitData[3] = ua;
                appdata.writeImplicitData();
              }
              var cookiesList = await controller.getCookies("${NhentaiNetwork().baseUrl}/");
              if (cookiesList != null) {
                for (var cookie in cookiesList) {
                  if (cookie.name == "sessionid" || cookie.name == "XSRF-TOKEN") {
                    NhentaiNetwork().logged = true;
                  }
                  cookie.domain = ".nhentai.net";
                }
                NhentaiNetwork().cookieJar!.saveFromResponse(
                    Uri.parse(NhentaiNetwork().baseUrl), cookiesList);
              }
              if (NhentaiNetwork().logged) {
                onFinished();
                App.globalBack();
              }
            }
          },
        ));
  }
}

/// 主登录入口 - 使用新的 API 登录方式
void nhLogin(void Function() onFinished) async {
  final context = App.globalContext;
  if (context == null) {
    // 如果无法获取 context，回退到旧方式
    nhLoginWebView(onFinished);
    return;
  }

  await showApiLoginDialog(context, onSuccess: onFinished);
}

/// NHentai CAPTCHA 验证页面
/// 用于获取 Turnstile CAPTCHA token
class NhentaiCaptchaPage extends StatefulWidget {
  final String siteKey;

  const NhentaiCaptchaPage({
    super.key,
    required this.siteKey,
  });

  @override
  State<NhentaiCaptchaPage> createState() => _NhentaiCaptchaPageState();
}

class _NhentaiCaptchaPageState extends State<NhentaiCaptchaPage> {
  bool _isLoading = true;
  String? _error;
  bool _popped = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('继续'.tl),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          Expanded(
            child: AppWebview(
              initialUrl: '${NhentaiNetwork().baseUrl}/login/?next=/',
              singlePage: true,
              onLoadStop: (controller) async {
                setState(() {
                  _isLoading = false;
                });

                // 注入 JavaScript 来监听 CAPTCHA token
                await _injectCaptchaListener(controller);
              },
              onTitleChange: (title, controller) async {
                // 尝试从页面获取 CAPTCHA token
                await _tryGetCaptchaToken(controller);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 注入 JavaScript 监听 CAPTCHA token
  Future<void> _injectCaptchaListener(InAppWebViewController controller) async {
    // 注入脚本监听 turnstile token
    await controller.evaluateJavascript(source: '''
      // 监听 turnstile 回调
      if (typeof turnstile !== 'undefined') {
        const originalRender = turnstile.render;
        turnstile.render = function(container, params) {
          const originalCallback = params.callback;
          params.callback = function(token) {
            // 将 token 发送到 Flutter
            window.flutter_inappwebview.callHandler('captchaToken', token);
            if (originalCallback) originalCallback(token);
          };
          return originalRender(container, params);
        };
      }

      // 也监听已经存在的 widget
      setInterval(function() {
        const token = document.querySelector('input[name="cf-turnstile-response"]')?.value;
        if (token) {
          window.flutter_inappwebview.callHandler('captchaToken', token);
        }
      }, 1000);
    ''');

    // 添加 JavaScript 处理器
    controller.addJavaScriptHandler(
      handlerName: 'captchaToken',
      callback: (args) {
        final token = args.isNotEmpty ? args[0]?.toString() : null;
        if (token != null && token.isNotEmpty && !_popped) {
          _popped = true;
          Navigator.of(context).pop(token);
        }
      },
    );
  }

  /// 尝试从页面获取 CAPTCHA token
  Future<void> _tryGetCaptchaToken(InAppWebViewController controller) async {
    try {
      // 尝试从输入框获取 token
      final token = await controller.evaluateJavascript(source: '''
        document.querySelector('input[name="cf-turnstile-response"]')?.value ||
        document.querySelector('[name="captcha_response"]')?.value ||
        '';
      ''');

      if (token != null && token.toString().isNotEmpty && !_popped) {
        _popped = true;
        Navigator.of(context).pop(token.toString());
      }
    } catch (e) {
      Log.error('NHentaiCaptcha', 'Error getting token: \$e');
    }
  }
}
