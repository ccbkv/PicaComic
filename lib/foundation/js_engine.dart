import 'dart:convert';
import 'dart:math' as math;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:pica_comic/base.dart';
import 'package:pica_comic/foundation/comic_source/comic_source.dart';
import 'package:pica_comic/foundation/def.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/network/app_dio.dart';
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;
import 'package:pica_comic/network/cloudflare.dart';
import 'package:pica_comic/network/cookie_jar.dart';
import 'package:pica_comic/utils/extensions.dart';
import 'package:flutter_qjs/flutter_qjs.dart';
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
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart';
import 'package:pointycastle/paddings/pkcs7.dart';


class JavaScriptRuntimeException implements Exception {
  final String message;

  JavaScriptRuntimeException(this.message);

  @override
  String toString() {
    return "JSException: $message";
  }
}

class JsEngine with _JSEngineApi{
  factory JsEngine() => _cache ?? (_cache = JsEngine._create());

  static JsEngine? _cache;

  JsEngine._create();

  FlutterQjs? _engine;

  bool _closed = true;

  Dio? _dio;

  static void reset(){
    _cache = null;
    _cache?.dispose();
    JsEngine().init();
  }

  Future<void> init() async{
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
      _engine = FlutterQjs();
      _engine!.dispatch();
      var setGlobalFunc = _engine!.evaluate(
          "(key, value) => { this[key] = value; }");
      (setGlobalFunc as JSInvokable)(["sendMessage", _messageReceiver]);
      // Set appVersion for venera-style comic sources compatibility
      setGlobalFunc(["appVersion", appVersion]);
      setGlobalFunc.free();
      var jsInit = await rootBundle.load("assets/init.js");
      _engine!.evaluate(utf8.decode(jsInit.buffer.asUint8List()), name: "<init>");
    }
    catch(e, s){
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
          case 'load_setting':
            {
              String key = message["key"];
              String settingKey = message["setting_key"];
              var source = ComicSource.sources
                  .firstWhereOrNull((element) => element.key == key);
              if (source == null) {
                throw "Source not found: $key";
              }
              // First try to get from saved data
              var savedValue = source.data["settings"]?[settingKey];
              if (savedValue != null) {
                return savedValue;
              }
              // Then try to get default value from veneraSettings
              var veneraSetting = source.veneraSettings[settingKey];
              if (veneraSetting is Map) {
                var defaultValue = veneraSetting["default"];
                if (defaultValue != null) {
                  return defaultValue;
                }
                // For select type, return the first option's value
                var options = veneraSetting["options"];
                if (options is List && options.isNotEmpty) {
                  var firstOption = options.first;
                  if (firstOption is Map) {
                    return firstOption["value"];
                  }
                }
              }
              throw "Setting not found: $settingKey";
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
          case "uuid":
            {
              return _generateUuid();
            }
          case "cookie":
            {
              return handleCookieCallback(Map.from(message));
            }
        }
      }
    }
    catch(e, s){
      log("Failed to handle message: $message\n$e\n$s", "JsEngine", LogLevel.error);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _http(Map<String, dynamic> req) async{
    Response? response;
    String? error;

    try {
      var headers = Map<String, dynamic>.from(req["headers"] ?? {});
      if(headers["user-agent"] == null && headers["User-Agent"] == null){
        headers["User-Agent"] = webUA;
      }
      // Always use bytes responseType to avoid Content-Type parsing issues
      response = await _dio!.request(req["url"], data: req["data"], options: Options(
        method: req['http_method'],
        responseType: ResponseType.bytes,
        headers: headers
      ));
    } catch (e) {
      error = e.toString();
    }

    Map<String, String> headers = {};

    response?.headers.forEach((name, values) => headers[name] = values.join(','));

    dynamic body = response?.data;
    if (body is List<int>) {
      // Convert bytes to UTF-8 string for JS compatibility
      body = utf8.decode(body, allowMalformed: true);
    }

    return {
      "status": response?.statusCode,
      "headers": headers,
      "body": body,
      "error": error,
    };
  }

  dynamic runCode(String js, [String? name]) {
    return _engine!.evaluate(js, name: name);
  }

  void dispose() {
    _cache = null;
    _closed = true;
    _engine?.close();
    _engine?.port.close();
  }
}

mixin class _JSEngineApi{
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
        if(res == null) return null;
        _elements[_elements.length] = res;
        return _elements.length - 1;
      case "querySelectorAll":
        var res = _documents[data["key"]]!.querySelectorAll(data["query"]);
        var keys = <int>[];
        for(var element in res){
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
        if(res == null) return null;
        _elements[_elements.length] = res;
        return _elements.length - 1;
      case "dom_querySelectorAll":
        var res = _elements[data["key"]]!.querySelectorAll(data["query"]);
        var keys = <int>[];
        for(var element in res){
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
      case "getElementById":
        var res = _documents[data["key"]]!.getElementById(data["id"]);
        if(res == null) return null;
        _elements[_elements.length] = res;
        return _elements.length - 1;
      case "getInnerHTML":
        return _elements[data["key"]]!.innerHtml;
    }
  }

  dynamic handleCookieCallback(Map<String, dynamic> data) {
    switch (data["function"]) {
      case "set":
        _cookieJar!.saveFromResponse(
            Uri.parse(data["url"]),
            (data["cookies"] as List).map((e) {
              var c = Cookie(e["name"], e["value"]);
              if(e['domain'] != null){
                c.domain = e['domain'];
              }
              return c;
            }).toList());
        return null;
      case "get":
        var cookies = _cookieJar!.loadForRequest(Uri.parse(data["url"]));
        return cookies.map((e) => {
          "name": e.name,
          "value": e.value,
          "domain": e.domain,
          "path": e.path,
          "expires": e.expires,
          "max-age": e.maxAge,
          "secure": e.secure,
          "httpOnly": e.httpOnly,
          "session": e.expires == null,
        }).toList();
      case "delete":
        clearCookies([data["url"]]);
        return null;
    }
  }

  void clear(){
    _documents.clear();
    _elements.clear();
  }

  void clearCookies(List<String> domains) async{
    for(var domain in domains){
      var uri = Uri.tryParse(domain);
      if(uri == null) continue;
      _cookieJar!.deleteUri(uri);
    }
  }

  Uint8List _toUint8List(dynamic value) {
    if (value is Uint8List) {
      return value;
    } else if (value is String) {
      return Uint8List.fromList(utf8.encode(value));
    } else if (value is List) {
      return Uint8List.fromList(value.cast<int>());
    }
    throw "Cannot convert ${value.runtimeType} to Uint8List";
  }

  dynamic _convert(Map<String, dynamic> data) {
    String type = data["type"];
    var value = data["value"];
    bool isEncode = data["isEncode"];
    try {
      switch (type) {
        case "base64":
          if(value is String && isEncode){
            value = utf8.encode(value);
          }
          if (isEncode) {
            return base64Encode(value);
          } else {
            // Convert Uint8List to regular List<int> for JS compatibility
            // Ensure value is String for base64Decode
            var valueStr = value is String ? value : utf8.decode(value);
            var decoded = base64Decode(valueStr);
            return decoded.toList();
          }
        case "utf8":
          if (isEncode) {
            // String to bytes
            if (value is String) {
              return utf8.encode(value).toList();
            }
            throw "UTF8 encode requires a string";
          } else {
            // Bytes to string
            var bytes = _toUint8List(value);
            return utf8.decode(bytes, allowMalformed: true);
          }
        case "md5":
          if (value is String) {
            value = utf8.encode(value);
          } else if (value is List) {
            value = value.cast<int>().toList();
          }
          return md5.convert(value).bytes.toList();
        case "sha1":
          if (value is String) {
            value = utf8.encode(value);
          } else if (value is List) {
            value = value.cast<int>().toList();
          }
          return sha1.convert(value).bytes.toList();
        case "sha256":
          if (value is String) {
            value = utf8.encode(value);
          } else if (value is List) {
            value = value.cast<int>().toList();
          }
          return sha256.convert(value).bytes.toList();
        case "sha512":
          if (value is String) {
            value = utf8.encode(value);
          } else if (value is List) {
            value = value.cast<int>().toList();
          }
          return sha512.convert(value).bytes.toList();
        case "hmac":
          var key = data["key"];
          var hash = data["hash"];
          // Convert key to List<int> if needed
          if (key is String) {
            key = utf8.encode(key);
          } else if (key is List) {
            key = key.cast<int>().toList();
          }
          // Convert value to List<int> if needed
          if (value is String) {
            value = utf8.encode(value);
          } else if (value is List) {
            value = value.cast<int>().toList();
          }
          var hmac = Hmac(
              switch (hash) {
                "md5" => md5,
                "sha1" => sha1,
                "sha256" => sha256,
                "sha512" => sha512,
                _ => throw "Unsupported hash: $hash"
              },
              key);
          if (data['isString'] == true) {
            return hmac.convert(value).toString();
          } else {
            return hmac.convert(value).bytes.toList();
          }
        case "aes-ecb":
          if(!isEncode){
            var key = _toUint8List(data["key"]);
            var valueBytes = _toUint8List(value);
            Log.info("JS Engine", "AES-ECB decrypt: key length=${key.length}, value length=${valueBytes.length}");
            // Use PaddedBlockCipher for proper ECB mode with PKCS7 padding
            var cipher = PaddedBlockCipherImpl(PKCS7Padding(), ECBBlockCipher(AESEngine()));
            cipher.init(false, PaddedBlockCipherParameters(KeyParameter(key), null));
            var decrypted = cipher.process(valueBytes);
            Log.info("JS Engine", "AES-ECB decrypted length: ${decrypted.length}");
            return decrypted.toList();
          }
          return null;
        case "aes-cbc":
          if(!isEncode){
            var key = _toUint8List(data["key"]);
            var iv = _toUint8List(data["iv"]);
            var valueBytes = _toUint8List(value);
            // Use PaddedBlockCipher for proper CBC mode with PKCS7 padding
            var cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()));
            cipher.init(false, PaddedBlockCipherParameters(ParametersWithIV(KeyParameter(key), iv), null));
            var decrypted = cipher.process(valueBytes);
            return decrypted.toList();
          }
          return null;
        case "aes-cfb":
          if(!isEncode){
            var key = _toUint8List(data["key"]);
            var blockSize = data["blockSize"];
            var valueBytes = _toUint8List(value);
            var cipher = CFBBlockCipher(AESEngine(), blockSize);
            cipher.init(false, KeyParameter(key));
            return cipher.process(valueBytes).toList();
          }
          return null;
        case "aes-ofb":
          if(!isEncode){
            var key = _toUint8List(data["key"]);
            var blockSize = data["blockSize"];
            var valueBytes = _toUint8List(value);
            var cipher = OFBBlockCipher(AESEngine(), blockSize);
            cipher.init(false, KeyParameter(key));
            return cipher.process(valueBytes).toList();
          }
          return null;
        case "rsa":
          if(!isEncode){
            var key = data["key"];
            var valueBytes = _toUint8List(value);
            final cipher = PKCS1Encoding(RSAEngine());
            cipher.init(
                false, PrivateKeyParameter<RSAPrivateKey>(_parsePrivateKey(key)));
            return _processInBlocks(cipher, valueBytes).toList();
          }
          return null;
        default:
          return value;
      }
    }
    catch(e) {
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

    return RSAPrivateKey(modulus.integer!, privateExponent.integer!, p.integer!, q.integer!);
  }

  Uint8List _processInBlocks(
      AsymmetricBlockCipher engine, Uint8List input) {
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

  String _generateUuid() {
    final random = math.Random();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    // Set version (4) and variant bits
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    // Format as UUID string
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
}
