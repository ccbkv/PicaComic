import 'dart:io';

import 'package:mobx/mobx.dart';
import 'package:pica_comic/pages/search/image_search_module.dart';
import 'package:pica_comic/request/apis/trace_api.dart';

part 'search_controller.g.dart';

class SearchPageController = SearchPageControllerBase
    with _$SearchPageController;

abstract class SearchPageControllerBase with Store {
  @observable
  bool isImageSearching = false;

  @observable
  String imageSearchError = '';

  @observable
  ObservableList<ResultItem> imageSearchResults = ObservableList.of([]);

  @action
  void clearImageSearchState() {
    isImageSearching = false;
    imageSearchError = '';
    imageSearchResults.clear();
  }

  @action
  Future<void> searchImageByFile(
    File imageFile, {
    String apiKey = '',
    List<int> databases = const [],
  }) async {
    isImageSearching = true;
    imageSearchError = '';
    imageSearchResults.clear();
    try {
      final result = await TraceApi.searchAnimeByImageFile(
        imageFile,
        apiKey: apiKey,
        databases: databases,
      );
      imageSearchResults.addAll(result.result ?? []);
      if (result.error != null && result.error!.isNotEmpty) {
        imageSearchError = result.error!;
      } else if (imageSearchResults.isEmpty) {
        imageSearchError = '未找到匹配结果';
      }
    } catch (_) {
      imageSearchError = '图片搜索失败，请稍后重试';
    } finally {
      isImageSearching = false;
    }
  }

  @action
  Future<void> searchImageByUrl(
    String imageUrl, {
    String apiKey = '',
    List<int> databases = const [],
  }) async {
    isImageSearching = true;
    imageSearchError = '';
    imageSearchResults.clear();
    try {
      final result = await TraceApi.searchAnimeByImageUrl(
        imageUrl,
        apiKey: apiKey,
        databases: databases,
      );
      imageSearchResults.addAll(result.result ?? []);
      if (result.error != null && result.error!.isNotEmpty) {
        imageSearchError = result.error!;
      } else if (imageSearchResults.isEmpty) {
        imageSearchError = '未找到匹配结果';
      }
    } catch (_) {
      imageSearchError = '图片搜索失败，请检查图片地址或稍后重试';
    } finally {
      isImageSearching = false;
    }
  }
}
