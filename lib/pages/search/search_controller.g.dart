// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$SearchPageController on SearchPageControllerBase, Store {

  late final _$isImageSearchingAtom =
      Atom(name: 'SearchPageControllerBase.isImageSearching', context: context);

  @override
  bool get isImageSearching {
    _$isImageSearchingAtom.reportRead();
    return super.isImageSearching;
  }

  @override
  set isImageSearching(bool value) {
    _$isImageSearchingAtom.reportWrite(value, super.isImageSearching, () {
      super.isImageSearching = value;
    });
  }

  late final _$imageSearchErrorAtom =
      Atom(name: 'SearchPageControllerBase.imageSearchError', context: context);

  @override
  String get imageSearchError {
    _$imageSearchErrorAtom.reportRead();
    return super.imageSearchError;
  }

  @override
  set imageSearchError(String value) {
    _$imageSearchErrorAtom.reportWrite(value, super.imageSearchError, () {
      super.imageSearchError = value;
    });
  }

  late final _$imageSearchResultsAtom =
      Atom(name: 'SearchPageControllerBase.imageSearchResults', context: context);

  @override
  ObservableList<ResultItem> get imageSearchResults {
    _$imageSearchResultsAtom.reportRead();
    return super.imageSearchResults;
  }

  @override
  set imageSearchResults(ObservableList<ResultItem> value) {
    _$imageSearchResultsAtom.reportWrite(value, super.imageSearchResults, () {
      super.imageSearchResults = value;
    });
  }

  late final _$searchImageByFileAsyncAction =
      AsyncAction('SearchPageControllerBase.searchImageByFile', context: context);

  @override
  Future<void> searchImageByFile(
    File imageFile, {
    String apiKey = '',
    List<int> databases = const [],
  }) {
    return _$searchImageByFileAsyncAction.run(() => super.searchImageByFile(
          imageFile,
          apiKey: apiKey,
          databases: databases,
        ));
  }

  late final _$searchImageByUrlAsyncAction =
      AsyncAction('SearchPageControllerBase.searchImageByUrl', context: context);

  @override
  Future<void> searchImageByUrl(
    String imageUrl, {
    String apiKey = '',
    List<int> databases = const [],
  }) {
    return _$searchImageByUrlAsyncAction.run(() => super.searchImageByUrl(
          imageUrl,
          apiKey: apiKey,
          databases: databases,
        ));
  }

  late final _$_SearchPageControllerActionController =
      ActionController(name: 'SearchPageControllerBase', context: context);

  @override
  void clearImageSearchState() {
    final _$actionInfo = _$_SearchPageControllerActionController.startAction(
        name: 'SearchPageControllerBase.clearImageSearchState');
    try {
      return super.clearImageSearchState();
    } finally {
      _$_SearchPageControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
isImageSearching: ${isImageSearching},
imageSearchError: ${imageSearchError},
imageSearchResults: ${imageSearchResults}
    ''';
  }
}
