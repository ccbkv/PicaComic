// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'src/messages.g.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

class ImagePickerOhos extends ImagePickerPlatform {
  ImagePickerOhos({@visibleForTesting ImagePickerApi? api})
      : _hostApi = api ?? ImagePickerApi();

  final ImagePickerApi _hostApi;
  bool useOhosPhotoPicker = false;
  static void registerWith() {
    ImagePickerPlatform.instance = ImagePickerOhos();
  }

  @override
  Future<PickedFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) async {
    final String? path = await _getImagePath(
      source: source,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
      preferredCameraDevice: preferredCameraDevice,
    );
    return path != null ? PickedFile(path) : null;
  }

  @override
  Future<List<PickedFile>?> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    final List<dynamic> paths = await _getMultiImagePath(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
    if (paths.isEmpty) {
      return null;
    }

    return paths.map((dynamic path) => PickedFile(path as String)).toList();
  }

  Future<List<dynamic>> _getMultiImagePath({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
  }) {
    if (imageQuality != null && (imageQuality < 0 || imageQuality > 100)) {
      throw ArgumentError.value(
          imageQuality, 'imageQuality', 'must be between 0 and 100');
    }

    if (maxWidth != null && maxWidth < 0) {
      throw ArgumentError.value(maxWidth, 'maxWidth', 'cannot be negative');
    }

    if (maxHeight != null && maxHeight < 0) {
      throw ArgumentError.value(maxHeight, 'maxHeight', 'cannot be negative');
    }

    if (limit != null && limit < 2) {
      throw ArgumentError.value(limit, 'limit', 'cannot be lower than 2');
    }

    return _hostApi.pickImages(
      SourceSpecification(type: SourceType.gallery),
      ImageSelectionOptions(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          quality: imageQuality ?? 100),
      GeneralOptions(
        allowMultiple: true,
        usePhotoPicker: useOhosPhotoPicker,
        limit: limit,
      ),
    );
  }

  Future<String?> _getImagePath({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    if (imageQuality != null && (imageQuality < 0 || imageQuality > 100)) {
      throw ArgumentError.value(
          imageQuality, 'imageQuality', 'must be between 0 and 100');
    }

    if (maxWidth != null && maxWidth < 0) {
      throw ArgumentError.value(maxWidth, 'maxWidth', 'cannot be negative');
    }

    if (maxHeight != null && maxHeight < 0) {
      throw ArgumentError.value(maxHeight, 'maxHeight', 'cannot be negative');
    }

    final List<String?> paths = await _hostApi.pickImages(
      _buildSourceSpec(source, preferredCameraDevice),
      ImageSelectionOptions(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          quality: imageQuality ?? 100),
      GeneralOptions(
        allowMultiple: false,
        usePhotoPicker: useOhosPhotoPicker,
      ),
    );
    return paths.isEmpty ? null : paths.first;
  }

  @override
  Future<PickedFile?> pickVideo({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
  }) async {
    final String? path = await _getVideoPath(
      source: source,
      maxDuration: maxDuration,
      preferredCameraDevice: preferredCameraDevice,
    );
    return path != null ? PickedFile(path) : null;
  }

  Future<String?> _getVideoPath({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
  }) async {
    final List<String?> paths = await _hostApi.pickVideos(
      _buildSourceSpec(source, preferredCameraDevice),
      VideoSelectionOptions(maxDurationSeconds: maxDuration?.inSeconds),
      GeneralOptions(
        allowMultiple: false,
        usePhotoPicker: useOhosPhotoPicker,
      ),
    );
    return paths.isEmpty ? null : paths.first;
  }

  @override
  Future<XFile?> getImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) async {
    final String? path = await _getImagePath(
      source: source,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
      preferredCameraDevice: preferredCameraDevice,
    );
    return path != null ? XFile(path) : null;
  }

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    final String? path = await _getImagePath(
      source: source,
      maxHeight: options.maxHeight,
      maxWidth: options.maxWidth,
      imageQuality: options.imageQuality,
      preferredCameraDevice: options.preferredCameraDevice,
      requestFullMetadata: options.requestFullMetadata,
    );
    return path != null ? XFile(path) : null;
  }

  @override
  Future<List<XFile>?> getMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    final List<dynamic> paths = await _getMultiImagePath(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
    if (paths.isEmpty) {
      return null;
    }

    return paths.map((dynamic path) => XFile(path as String)).toList();
  }

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async {
    final List<dynamic> paths = await _getMultiImagePath(
      maxWidth: options.imageOptions.maxWidth,
      maxHeight: options.imageOptions.maxHeight,
      imageQuality: options.imageOptions.imageQuality,
      limit: options.limit,
    );

    if (paths.isEmpty) {
      return <XFile>[];
    }

    return paths.map((dynamic path) => XFile(path as String)).toList();
  }

  @override
  Future<List<XFile>> getMedia({
    required MediaOptions options,
  }) async {
    return (await _hostApi.pickMedia(
      _mediaOptionsToMediaSelectionOptions(options),
      _mediaOptionsToGeneralOptions(options),
    ))
        .map((String? path) => XFile(path!))
        .toList();
  }

  @override
  Future<XFile?> getVideo({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
  }) async {
    final String? path = await _getVideoPath(
      source: source,
      maxDuration: maxDuration,
      preferredCameraDevice: preferredCameraDevice,
    );
    return path != null ? XFile(path) : null;
  }

  MediaSelectionOptions _mediaOptionsToMediaSelectionOptions(
      MediaOptions mediaOptions) {
    final ImageSelectionOptions imageSelectionOptions =
        _imageOptionsToImageSelectionOptionsWithValidator(
            mediaOptions.imageOptions);
    return MediaSelectionOptions(
      imageSelectionOptions: imageSelectionOptions,
    );
  }

  ImageSelectionOptions _imageOptionsToImageSelectionOptionsWithValidator(
      ImageOptions? imageOptions) {
    final double? maxHeight = imageOptions?.maxHeight;
    final double? maxWidth = imageOptions?.maxWidth;
    final int? imageQuality = imageOptions?.imageQuality;

    if (imageQuality != null && (imageQuality < 0 || imageQuality > 100)) {
      throw ArgumentError.value(
          imageQuality, 'imageQuality', 'must be between 0 and 100');
    }

    if (maxWidth != null && maxWidth < 0) {
      throw ArgumentError.value(maxWidth, 'maxWidth', 'cannot be negative');
    }

    if (maxHeight != null && maxHeight < 0) {
      throw ArgumentError.value(maxHeight, 'maxHeight', 'cannot be negative');
    }
    return ImageSelectionOptions(
        quality: imageQuality ?? 100, maxHeight: maxHeight, maxWidth: maxWidth);
  }

  GeneralOptions _mediaOptionsToGeneralOptions(MediaOptions options) {
    final bool allowMultiple = options.allowMultiple;
    final int? limit = options.limit;

    if (!allowMultiple && limit != null) {
      throw ArgumentError.value(
        allowMultiple,
        'allowMultiple',
        'cannot be false, when limit is not null',
      );
    }

    if (limit != null && limit < 2) {
      throw ArgumentError.value(limit, 'limit', 'cannot be lower then 2');
    }

    return GeneralOptions(
      allowMultiple: allowMultiple,
      usePhotoPicker: useOhosPhotoPicker,
      limit: limit,
    );
  }

  @override
  Future<LostData> retrieveLostData() async {
    final LostDataResponse result = await getLostData();

    if (result.isEmpty) {
      return LostData.empty();
    }

    return LostData(
      file: result.file != null ? PickedFile(result.file!.path) : null,
      exception: result.exception,
      type: result.type,
    );
  }

  @override
  Future<LostDataResponse> getLostData() async {
    final CacheRetrievalResult? result = await _hostApi.retrieveLostResults();

    if (result == null) {
      return LostDataResponse.empty();
    }

    assert(result.paths.isEmpty != (result.error == null));

    final CacheRetrievalError? error = result.error;
    final PlatformException? exception = error == null
        ? null
        : PlatformException(code: error.code, message: error.message);
    final List<XFile> pickedFileList =
        result.paths.map((String? path) => XFile(path!)).toList();

    return LostDataResponse(
      file: pickedFileList.isEmpty ? null : pickedFileList.last,
      exception: exception,
      type: _retrieveTypeForCacheType(result.type),
      files: pickedFileList,
    );
  }

  SourceSpecification _buildSourceSpec(
      ImageSource source, CameraDevice device) {
    return SourceSpecification(
        type: _sourceSpecTypeForSource(source),
        camera: _sourceSpecCameraForDevice(device));
  }

  SourceType _sourceSpecTypeForSource(ImageSource source) {
    switch (source) {
      case ImageSource.camera:
        return SourceType.camera;
      case ImageSource.gallery:
        return SourceType.gallery;
    }
  }

  SourceCamera _sourceSpecCameraForDevice(CameraDevice device) {
    switch (device) {
      case CameraDevice.front:
        return SourceCamera.front;
      case CameraDevice.rear:
        return SourceCamera.rear;
    }
  }

  RetrieveType _retrieveTypeForCacheType(CacheRetrievalType type) {
    switch (type) {
      case CacheRetrievalType.image:
        return RetrieveType.image;
      case CacheRetrievalType.video:
        return RetrieveType.video;
    }
  }
}
