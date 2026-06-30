import 'package:dio/dio.dart';
import 'package:pica_comic/request/core/dio_factory.dart';
import 'package:pica_comic/utils/extensions.dart';

import '../../utils/translations.dart';

class TraceClient {
  TraceClient._();

  static final TraceClient instance = TraceClient._();

  Future<dynamic> post(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic> headers = const {},
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await DioFactory.downloadDio.post(
        url,
        data: data,
        queryParameters: queryParameters,
        options: Options(headers: headers),
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (e) {
      if (e.type != DioExceptionType.unknown) {
        throw e.message ?? '未知'.tl;
      }
      throw e.toString().split('\n').elementAtOrNull(1) ?? 'Network Error';
    }
  }
}
