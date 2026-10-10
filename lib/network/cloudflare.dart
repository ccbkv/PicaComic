import 'dart:async';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/pages/webview.dart';
import 'package:pica_comic/utils/ext.dart';

import '../base.dart';
import '../components/components.dart';
import '../utils/translations.dart';
import 'cookie_jar.dart';

class CloudflareException implements DioException {
  final String url;

  CloudflareException(this.url);

  @override
  String toString() {
    return "CloudflareException: $url";
  }

  static CloudflareException? fromString(String message) {
    var match = RegExp(r"CloudflareException: (.+)").firstMatch(message);
    if (match == null) return null;
    return CloudflareException(match.group(1)!);
  }

  @override
  DioException copyWith(
      {RequestOptions? requestOptions,
      Response<dynamic>? response,
      DioExceptionType? type,
      Object? error,
      StackTrace? stackTrace,
      String? message}) {
    return this;
  }

  @override
  Object? get error => this;

  @override
  String? get message => toString();

  @override
  RequestOptions get requestOptions => RequestOptions();

  @override
  Response? get response => null;

  @override
  StackTrace get stackTrace => StackTrace.empty;

  @override
  DioExceptionType get type => DioExceptionType.badResponse;

  @override
  DioExceptionReadableStringBuilder? stringBuilder;
}

class CloudflareInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.headers['cookie'].toString().contains('cf_clearance')) {
      options.headers['user-agent'] = appdata.implicitData[3] ?? webUA;
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 403) {
      handler.next(_check(err.response!) ?? err);
    } else {
      handler.next(err);
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response.statusCode == 403) {
      var err = _check(response);
      if (err != null) {
        handler.reject(err);
        return;
      }
    }
    handler.next(response);
  }

  CloudflareException? _check(Response response) {
    if (response.headers['cf-mitigated']?.firstOrNull == "challenge") {
      return CloudflareException(response.requestOptions.uri.toString());
    }
    return null;
  }
}

void passCloudflare(CloudflareException e, void Function() onFinished) async {
  var url = e.url;
  var uri = Uri.parse(url);

  void saveCookies(Map<String, String> cookies) {
    var domain = uri.host;
    var splits = domain.split('.');
    if (splits.length > 1) {
      domain = ".${splits[splits.length - 2]}.${splits[splits.length - 1]}";
    }
    SingleInstanceCookieJar.instance!.saveFromResponse(
      uri,
      List<io.Cookie>.generate(cookies.length, (index) {
        var cookie = io.Cookie(
            cookies.keys.elementAt(index), cookies.values.elementAt(index));
        cookie.domain = domain;
        return cookie;
      }),
    );
  }

  // windows version of package `flutter_inappwebview` cannot get some cookies
  // Using DesktopWebview instead
  if (App.isLinux) {
    var webview = DesktopWebview(
      initialUrl: url,
      onTitleChange: (title, controller) async {
        var head =
            await controller.evaluateJavascript("document.head.innerHTML") ??
                "";
        var body =
            await controller.evaluateJavascript("document.body.innerHTML") ??
                "";
        Log.info("Cloudflare", "Checking head: $head");
        var isChallenging = head.contains('#challenge-success-text') ||
            head.contains("#challenge-error-text") ||
            head.contains("#challenge-form") ||
            body.contains("challenge-platform") ||
            body.contains("window._cf_chl_opt");
        if (!isChallenging) {
          Log.info(
            "Cloudflare",
            "Cloudflare is passed due to there is no challenge css",
          );
          var ua = controller.userAgent;
          if (ua != null) {
            appdata.implicitData[3] = ua;
            appdata.writeImplicitData();
          }
          var cookiesMap = await controller.getCookies(url);
          if (cookiesMap['cf_clearance'] == null) {
            return;
          }
          saveCookies(cookiesMap);
          controller.close();
          onFinished();
        }
      },
      onClose: onFinished,
    );
    webview.open();
  } else {
    bool success = false;
    bool closed = false;
    bool checking = false;
    Timer? timer;
    Future<void> check(InAppWebViewController controller) async {
      if (closed || success || checking) return;
      checking = true;
      try {
        final currentUrl = await controller.getUrl();
        if (currentUrl == null ||
            Uri.parse(currentUrl.toString()).origin != uri.origin) return;
        // Background challenge scripts can remain on the normal website.
        // Check active challenge UI, not script URLs in the page's HTML.
        final ready = await controller.evaluateJavascript(source: """
          document.readyState !== 'loading' &&
          !document.querySelector('#challenge-form, #challenge-running') &&
          !window._cf_chl_opt
        """);
        if (ready != true || closed) return;
        var cookies = await controller.getCookies(url) ?? [];
        if (!cookies.any((cookie) =>
            cookie.name == 'cf_clearance' && cookie.value.isNotEmpty)) return;
        final ua = await controller.getUA();
        if (closed || success) return;
        if (ua != null) {
          appdata.implicitData[3] = ua;
          appdata.writeImplicitData();
        }
        SingleInstanceCookieJar.instance?.saveFromResponse(uri, cookies);
        success = true;
        timer?.cancel();
        App.globalBack();
      } catch (error) {
        if (!closed) Log.error("Cloudflare", error.toString());
      } finally {
        checking = false;
      }
    }

    try {
      await App.globalTo(
        () => AppWebview(
          initialUrl: url,
          singlePage: true,
          onTitleChange: (title, controller) => unawaited(check(controller)),
          onLoadStop: (controller) => unawaited(check(controller)),
          onStarted: (controller) {
            timer = Timer.periodic(const Duration(milliseconds: 750),
                (_) => unawaited(check(controller)));
          },
        ),
      );
    } finally {
      closed = true;
      timer?.cancel();
      onFinished();
    }
  }
}
