import 'dart:convert';
import 'dart:math' as math;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:pica_comic/base.dart';
import 'package:pica_comic/comic_source/comic_source.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/network/app_dio.dart';
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;
import 'package:pica_comic/network/cloudflare.dart';
import 'package:pica_comic/network/cookie_jar.dart';
import 'package:pica_comic/tools/extensions.dart';
//import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/asn1/asn1_parser.dart';
import 'package:pointycastle/asn1/primitives/asn1_integer.dart';
import 'package:pointycastle/asn1/primitives/asn1_sequence.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/pkcs1.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';
import 'package:pointycastle/block/modes/cfb.dart';
import 'package:pointycastle/block/modes/ecb.dart';
import 'package:pointycastle/block/modes/ofb.dart';

import 'package:flutter_js_ohos/extensions/fetch.dart';
import 'package:flutter_js_ohos/extensions/handle_promises.dart';
import 'package:flutter_js_ohos/extensions/xhr.dart';
import 'package:flutter_js_ohos/flutter_js.dart';
import 'package:flutter_js_ohos/javascript_runtime.dart';
import 'package:flutter_js_ohos/javascriptcore/binding/js_base.dart';
import 'package:flutter_js_ohos/javascriptcore/binding/js_context_ref.dart';
import 'package:flutter_js_ohos/javascriptcore/binding/js_object_ref.dart';
import 'package:flutter_js_ohos/javascriptcore/binding/js_string_ref.dart';
import 'package:flutter_js_ohos/javascriptcore/binding/js_typed_array.dart';
import 'package:flutter_js_ohos/javascriptcore/binding/js_value_ref.dart';
import 'package:flutter_js_ohos/javascriptcore/binding/jsc_ffi.dart';
import 'package:flutter_js_ohos/javascriptcore/flutter_jscore.dart';
import 'package:flutter_js_ohos/javascriptcore/jscore/js_class.dart';
import 'package:flutter_js_ohos/javascriptcore/jscore/js_context.dart';
import 'package:flutter_js_ohos/javascriptcore/jscore/js_context_group.dart';
import 'package:flutter_js_ohos/javascriptcore/jscore/js_object.dart';
import 'package:flutter_js_ohos/javascriptcore/jscore/js_property_name_accumulator.dart';
import 'package:flutter_js_ohos/javascriptcore/jscore/js_property_name_array.dart';
import 'package:flutter_js_ohos/javascriptcore/jscore/js_string.dart';
import 'package:flutter_js_ohos/javascriptcore/jscore/js_value.dart';
import 'package:flutter_js_ohos/javascriptcore/jscore_bindings.dart';
import 'package:flutter_js_ohos/javascriptcore/jscore_runtime.dart';
import 'package:flutter_js_ohos/js_eval_result.dart';
import 'package:flutter_js_ohos/quickjs-sync-server/quickjs_oasis_jsbridge.dart';
import 'package:flutter_js_ohos/quickjs/ffi.dart';
//import 'package:flutter_js_ohos/quickjs/isolate.dart';
//import 'package:flutter_js_ohos/quickjs/object.dart';
import 'package:flutter_js_ohos/quickjs/qjs_typedefs.dart';
import 'package:flutter_js_ohos/quickjs/quickjs_runtime.dart';
import 'package:flutter_js_ohos/quickjs/quickjs_runtime2.dart';
import 'package:flutter_js_ohos/quickjs/utf8_null_terminated.dart';
//import 'package:flutter_js_ohos/quickjs/wrapper.dart';

class JavaScriptRuntimeException implements Exception {
  final String message;

  JavaScriptRuntimeException(this.message);

  @override
  String toString() {
    return "JSException: $message";
  }
}

class JsEngine with _JSEngineApi {
  factory JsEngine() => _cache ?? (_cache = JsEngine._create());

  static JsEngine? _cache;

  JsEngine._create();

  JavascriptRuntime? _engine;

  bool _closed = true;

  Dio? _dio;

  static void reset() {
    _cache = null;
    _cache?.dispose();
    JsEngine().init();
  }

  Future<void> init() async {
    if (!_closed) {
      return;
    }
    try {
      _dio ??= logDio(BaseOptions(
          responseType: ResponseType.plain, validateStatus: (status) => true));
      _cookieJar ??= SingleInstanceCookieJar.instance!;
      _dio!.interceptors.add(CookieManagerSql(_cookieJar!));
      _dio!.interceptors.add(CloudflareInterceptor());
      _closed = false;
      _engine = getJavascriptRuntime();
      _engine!.onMessage('sendMessage', (args) => _messageReceiver(args));
      var jsInit = await rootBundle.load("assets/init.js");
      var res = await _engine!
          .evaluateAsync(utf8.decode(jsInit.buffer.asUint8List()));
      _engine!.executePendingJob();
      await _engine!.handlePromise(res);
    } catch (e, s) {
      log('JS Engine Init Error:\n$e\n$s', 'JS Engine', LogLevel.error);
    }
  }

  dynamic _messageReceiver(dynamic message) {
    try {
      if (message is Map<dynamic, dynamic>) {
        String method = message["method"] as String;
        switch (method) {
          case "log":
            {
              String level = message["level"];
              LogManager.addLog(
                  switch (level) {
                    "error" => LogLevel.error,
                    "warning" => LogLevel.warning,
                    "info" => LogLevel.info,
                    _ => LogLevel.warning
                  },
                  message["title"],
                  message["content"].toString());
            }
          case 'load_data':
            {
              String key = message["key"];
              String dataKey = message["data_key"];
              return ComicSource.sources
                  .firstWhereOrNull((element) => element.key == key)
                  ?.data[dataKey];
            }
          case 'save_data':
            {
              String key = message["key"];
              String dataKey = message["data_key"];
              var data = message["data"];
              var source = ComicSource.sources
                  .firstWhere((element) => element.key == key);
              source.data[dataKey] = data;
              source.saveData();
            }
          case 'delete_data':
            {
              String key = message["key"];
              String dataKey = message["data_key"];
              var source = ComicSource.sources
                  .firstWhereOrNull((element) => element.key == key);
              source?.data.remove(dataKey);
              source?.saveData();
            }
          case 'http':
            {
              return _http(Map.from(message));
            }
          case 'html':
            {
              return handleHtmlCallback(Map.from(message));
            }
          case 'convert':
            {
              return _convert(Map.from(message));
            }
          case "random":
            {
              return _randomInt(message["min"], message["max"]);
            }
          case "cookie":
            {
              return handleCookieCallback(Map.from(message));
            }
        }
      }
    } catch (e, s) {
      log("Failed to handle message: $message\n$e\n$s", "JsEngine",
          LogLevel.error);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _http(Map<String, dynamic> req) async {
    Response? response;
    String? error;

    try {
      var headers = Map<String, dynamic>.from(req["headers"] ?? {});
      if (headers["user-agent"] == null && headers["User-Agent"] == null) {
        headers["User-Agent"] = webUA;
      }
      response = await _dio!.request(req["url"],
          data: req["data"],
          options: Options(
              method: req['http_method'],
              responseType: req["bytes"] == true
                  ? ResponseType.bytes
                  : ResponseType.plain,
              headers: headers));
    } catch (e) {
      error = e.toString();
    }

    Map<String, String> headers = {};

    response?.headers
        .forEach((name, values) => headers[name] = values.join(','));

    dynamic body = response?.data;
    if (body is! Uint8List && body is List<int>) {
      body = Uint8List.fromList(body);
    }

    return {
      "status": response?.statusCode,
      "headers": headers,
      "body": body,
      "error": error,
    };
  }

  Future<JsEvalResult> runCode(String js, [String? name]) async {
    var res = await _engine!.evaluateAsync(js);
    _engine!.executePendingJob();
    return await _engine!.handlePromise(res);
  }

  void dispose() {
    _cache = null;
    _closed = true;
    _engine?.dispose();
  }
}

mixin class _JSEngineApi {
  final Map<int, dom.Document> _documents = {};
  final Map<int, dom.Element> _elements = {};
  CookieJarSql? _cookieJar;

  dynamic handleHtmlCallback(Map<String, dynamic> data) {
    switch (data["function"]) {
      case "parse":
        _documents[data["key"]] = html.parse(data["data"]);
        return null;
      case "querySelector":
        var res = _documents[data["key"]]!.querySelector(data["query"]);
        if (res == null) return null;
        _elements[_elements.length] = res;
        return _elements.length - 1;
      case "querySelectorAll":
        var res = _documents[data["key"]]!.querySelectorAll(data["query"]);
        var keys = <int>[];
        for (var element in res) {
          _elements[_elements.length] = element;
          keys.add(_elements.length - 1);
        }
        return keys;
      case "getText":
        return _elements[data["key"]]!.text;
      case "getAttributes":
        return _elements[data["key"]]!.attributes;
      case "dom_querySelector":
        var res = _elements[data["key"]]!.querySelector(data["query"]);
        if (res == null) return null;
        _elements[_elements.length] = res;
        return _elements.length - 1;
      case "dom_querySelectorAll":
        var res = _elements[data["key"]]!.querySelectorAll(data["query"]);
        var keys = <int>[];
        for (var element in res) {
          _elements[_elements.length] = element;
          keys.add(_elements.length - 1);
        }
        return keys;
      case "getChildren":
        var res = _elements[data["key"]]!.children;
        var keys = <int>[];
        for (var element in res) {
          _elements[_elements.length] = element;
          keys.add(_elements.length - 1);
        }
        return keys;
    }
  }

  dynamic handleCookieCallback(Map<String, dynamic> data) {
    switch (data["function"]) {
      case "set":
        _cookieJar!.saveFromResponse(
            Uri.parse(data["url"]),
            (data["cookies"] as List).map((e) {
              var c = Cookie(e["name"], e["value"]);
              if (e['domain'] != null) {
                c.domain = e['domain'];
              }
              return c;
            }).toList());
        return null;
      case "get":
        var cookies = _cookieJar!.loadForRequest(Uri.parse(data["url"]));
        return cookies
            .map((e) => {
          "name": e.name,
          "value": e.value,
          "domain": e.domain,
          "path": e.path,
          "expires": e.expires,
          "max-age": e.maxAge,
          "secure": e.secure,
          "httpOnly": e.httpOnly,
          "session": e.expires == null,
        })
            .toList();
      case "delete":
        clearCookies([data["url"]]);
        return null;
    }
  }

  void clear() {
    _documents.clear();
    _elements.clear();
  }

  void clearCookies(List<String> domains) async {
    for (var domain in domains) {
      var uri = Uri.tryParse(domain);
      if (uri == null) continue;
      _cookieJar!.deleteUri(uri);
    }
  }

  dynamic _convert(Map<String, dynamic> data) {
    String type = data["type"];
    var value = data["value"];
    bool isEncode = data["isEncode"];
    try {
      switch (type) {
        case "base64":
          if (value is String) {
            value = utf8.encode(value);
          }
          return isEncode ? base64Encode(value) : base64Decode(value);
        case "md5":
          return Uint8List.fromList(md5.convert(value).bytes);
        case "sha1":
          return Uint8List.fromList(sha1.convert(value).bytes);
        case "sha256":
          return Uint8List.fromList(sha256.convert(value).bytes);
        case "sha512":
          return Uint8List.fromList(sha512.convert(value).bytes);
        case "aes-ecb":
          if (!isEncode) {
            var key = data["key"];
            var cipher = ECBBlockCipher(AESEngine());
            cipher.init(false, KeyParameter(key));
            return cipher.process(value);
          }
          return null;
        case "aes-cbc":
          if (!isEncode) {
            var key = data["key"];
            var iv = data["iv"];
            var cipher = CBCBlockCipher(AESEngine());
            cipher.init(false, ParametersWithIV(KeyParameter(key), iv));
            return cipher.process(value);
          }
          return null;
        case "aes-cfb":
          if (!isEncode) {
            var key = data["key"];
            var blockSize = data["blockSize"];
            var cipher = CFBBlockCipher(AESEngine(), blockSize);
            cipher.init(false, KeyParameter(key));
            return cipher.process(value);
          }
          return null;
        case "aes-ofb":
          if (!isEncode) {
            var key = data["key"];
            var blockSize = data["blockSize"];
            var cipher = OFBBlockCipher(AESEngine(), blockSize);
            cipher.init(false, KeyParameter(key));
            return cipher.process(value);
          }
          return null;
        case "rsa":
          if (!isEncode) {
            var key = data["key"];
            final cipher = PKCS1Encoding(RSAEngine());
            cipher.init(false,
                PrivateKeyParameter<RSAPrivateKey>(_parsePrivateKey(key)));
            return _processInBlocks(cipher, value);
          }
          return null;
        default:
          return value;
      }
    } catch (e) {
      Log.error("JS Engine", "Failed to convert $type: $e");
      return null;
    }
  }

  RSAPrivateKey _parsePrivateKey(String privateKeyString) {
    List<int> privateKeyDER = base64Decode(privateKeyString);
    var asn1Parser = ASN1Parser(privateKeyDER as Uint8List);
    final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;
    final privateKey = topLevelSeq.elements![2];

    asn1Parser = ASN1Parser(privateKey.valueBytes!);
    final pkSeq = asn1Parser.nextObject() as ASN1Sequence;

    final modulus = pkSeq.elements![1] as ASN1Integer;
    final privateExponent = pkSeq.elements![3] as ASN1Integer;
    final p = pkSeq.elements![4] as ASN1Integer;
    final q = pkSeq.elements![5] as ASN1Integer;

    return RSAPrivateKey(
        modulus.integer!, privateExponent.integer!, p.integer!, q.integer!);
  }

  Uint8List _processInBlocks(AsymmetricBlockCipher engine, Uint8List input) {
    final numBlocks = input.length ~/ engine.inputBlockSize +
        ((input.length % engine.inputBlockSize != 0) ? 1 : 0);

    final output = Uint8List(numBlocks * engine.outputBlockSize);

    var inputOffset = 0;
    var outputOffset = 0;
    while (inputOffset < input.length) {
      final chunkSize = (inputOffset + engine.inputBlockSize <= input.length)
          ? engine.inputBlockSize
          : input.length - inputOffset;

      outputOffset += engine.processBlock(
          input, inputOffset, chunkSize, output, outputOffset);

      inputOffset += chunkSize;
    }

    return (output.length == outputOffset)
        ? output
        : output.sublist(0, outputOffset);
  }

  int _randomInt(int min, int max) {
    return (min + (max - min) * math.Random().nextDouble()).toInt();
  }
}
