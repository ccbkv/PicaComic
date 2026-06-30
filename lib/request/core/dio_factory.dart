import 'package:dio/dio.dart';
import 'package:pica_comic/network/app_dio.dart';

class DioFactory {
  DioFactory._();

  static Dio? _githubDio;
  static Dio? _downloadDio;

  static Dio get githubDio =>
      _githubDio ??= logDio(BaseOptions(
        headers: {
          'accept': 'application/vnd.github+json',
        },
      ));

  static Dio get downloadDio =>
      _downloadDio ??= logDio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ));

  static void reset() {
    _githubDio = null;
    _downloadDio = null;
  }
}
