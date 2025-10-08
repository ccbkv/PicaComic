import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:pica_comic/base.dart';

String get ua {
  return "Mozilla/5.0 (Linux; Android 10; K; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/138.0.0.0 Mobile Safari/537.36";
}

String get jmImgUA {
  return "Dalvik/2.1.0 (Linux; Android 10; K)";
}

String get jmAppVersion {
  return appdata.settings[89];
}

const _jmPkgName = "com.example.app";

const _jmAuthKey = "18comicAPPContent";

Map<String, String> getBaseHeaders() {
  return {
    "Accept": "*/*",
    "Accept-Encoding": "gzip, deflate, br, zstd",
    "Accept-Language": "zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7",
    "Connection": "keep-alive",
    "Origin": "https://localhost",
    "Referer": "https://localhost/",
    "Sec-Fetch-Dest": "empty",
    "Sec-Fetch-Mode": "cors",
    "Sec-Fetch-Site": "cross-site",
    "X-Requested-With": _jmPkgName,
  };
}

Map<String, String> getImgHeaders(){
  return {
    "Accept": "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
    "Accept-Encoding": "gzip, deflate, br, zstd",
    "Accept-Language": "zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7",
    "Connection": "keep-alive",
    "Referer": "https://localhost/",
    "Sec-Fetch-Dest": "image",
    "Sec-Fetch-Mode": "no-cors",
    "Sec-Fetch-Site": "cross-site",
    "Sec-Fetch-Storage-Access": "active",
    "User-Agent": ua,
    "X-Requested-With": _jmPkgName,
  };
}

BaseOptions getApiOptions(int time,
    {bool post = false, bool byte = true}) {

  var token = md5.convert(const Utf8Encoder().convert("$time$_jmAuthKey"));

  return BaseOptions(
      receiveDataWhenStatusError: true,
      connectTimeout: const Duration(seconds: 8),
      responseType: byte ? ResponseType.bytes : null,
      headers: {
        ...getBaseHeaders(),
        "Authorization": "Bearer",
        "Sec-Fetch-Storage-Access": "active",
        "token": token.toString(),
        "tokenparam": "$time,$jmAppVersion",
        "user-agent": ua,
        if (post) "Content-Type": "application/x-www-form-urlencoded"
      });
}