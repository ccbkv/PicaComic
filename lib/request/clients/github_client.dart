import 'package:dio/dio.dart';
import 'package:pica_comic/base.dart';
import 'package:pica_comic/network/res.dart';
import 'package:pica_comic/request/config/api_endpoints.dart';
import 'package:pica_comic/request/core/dio_factory.dart';
import 'package:pica_comic/utils/extensions.dart';

import '../../utils/translations.dart';

class GithubClient {
  GithubClient._();

  static final GithubClient instance = GithubClient._();

  Future<Res<Map<String, dynamic>>> latestRelease() async {
    final res = await getJson(ApiEndpoints.latestApp);
    if (res.error) return Res.fromErrorRes(res);
    return Res(Map<String, dynamic>.from(res.data));
  }

  Future<Res<String>> latestVersion() async {
    final res = await latestRelease();
    if (res.error) return Res.fromErrorRes(res);
    return Res(res.data['tag_name']?.toString() ?? appVersion);
  }

  Future<Res<dynamic>> getJson(
    String url, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await DioFactory.githubDio.get(
        url,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      );
      return Res(response.data);
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

  Future<Res<String>> getText(String url, {CancelToken? cancelToken}) async {
    try {
      final response = await DioFactory.githubDio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
        cancelToken: cancelToken,
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
}
