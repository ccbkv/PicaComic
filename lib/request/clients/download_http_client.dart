import 'package:dio/dio.dart';
import 'package:pica_comic/network/res.dart';
import 'package:pica_comic/request/core/dio_factory.dart';
import 'package:pica_comic/utils/extensions.dart';

import '../../utils/translations.dart';

class DownloadHttpClient {
  DownloadHttpClient._();

  static final DownloadHttpClient instance = DownloadHttpClient._();

  Future<Res<Response<ResponseBody>>> getStream(
    String url, {
    Map<String, dynamic> headers = const {},
    Duration? receiveTimeout,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await DioFactory.downloadDio.get<ResponseBody>(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
          receiveTimeout: receiveTimeout,
        ),
        cancelToken: cancelToken,
      );
      return Res(response);
    } on DioException catch (e) {
      String? message;
      if (e.type != DioExceptionType.unknown) {
        message = e.message ?? "未知".tl;
      } else {
        message = e.toString().split("\n").elementAtOrNull(1);
      }
      return Res(null, errorMessage: message ?? "Network Error");
    }
  }

  Future<Res<String>> getPlain(
    String url, {
    Map<String, dynamic> headers = const {},
    Duration? receiveTimeout,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await DioFactory.downloadDio.get<String>(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.plain,
          receiveTimeout: receiveTimeout,
        ),
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return Res(response.data ?? '');
    } on DioException catch (e) {
      String? message;
      if (e.type != DioExceptionType.unknown) {
        message = e.message ?? "未知".tl;
      } else {
        message = e.toString().split("\n").elementAtOrNull(1);
      }
      return Res(null, errorMessage: message ?? "Network Error");
    }
  }

  Future<Res<void>> download(
    String url,
    String savePath, {
    Map<String, dynamic> headers = const {},
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      await DioFactory.downloadDio.download(
        url,
        savePath,
        options: Options(headers: headers),
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return const Res(null);
    } on DioException catch (e) {
      String? message;
      if (e.type != DioExceptionType.unknown) {
        message = e.message ?? "未知".tl;
      } else {
        message = e.toString().split("\n").elementAtOrNull(1);
      }
      return Res(null, errorMessage: message ?? "Network Error");
    }
  }
}
