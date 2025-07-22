/*
 * Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'messages.g.dart' as messages;

messages.StorageDirectory _convertStorageDirectory(
    StorageDirectory? directory) {
  switch (directory) {
    case null:
      return messages.StorageDirectory.root;
    case StorageDirectory.music:
      return messages.StorageDirectory.music;
    case StorageDirectory.podcasts:
      return messages.StorageDirectory.podcasts;
    case StorageDirectory.ringtones:
      return messages.StorageDirectory.ringtones;
    case StorageDirectory.alarms:
      return messages.StorageDirectory.alarms;
    case StorageDirectory.notifications:
      return messages.StorageDirectory.notifications;
    case StorageDirectory.pictures:
      return messages.StorageDirectory.pictures;
    case StorageDirectory.movies:
      return messages.StorageDirectory.movies;
    case StorageDirectory.downloads:
      return messages.StorageDirectory.downloads;
    case StorageDirectory.dcim:
      return messages.StorageDirectory.dcim;
    case StorageDirectory.documents:
      return messages.StorageDirectory.documents;
  }
}

/// The OHOS implementation of [PathProviderPlatform].
class PathProviderOhos extends PathProviderPlatform {
  final messages.PathProviderApi _api = messages.PathProviderApi();

  /// Registers this class as the default instance of [PathProviderPlatform].
  static void registerWith() {
    PathProviderPlatform.instance = PathProviderOhos();
  }

  @override
  Future<String?> getTemporaryPath() {
    return _api.getTemporaryPath();
  }

  @override
  Future<String?> getApplicationSupportPath() {
    return _api.getApplicationSupportPath();
  }

  @override
  Future<String?> getLibraryPath() {
    throw UnsupportedError('getLibraryPath is not supported on OHOS');
  }

  @override
  Future<String?> getApplicationDocumentsPath() {
    return _api.getApplicationDocumentsPath();
  }

  @override
  Future<String?> getApplicationCachePath() {
    return _api.getApplicationCachePath();
  }

  @override
  Future<String?> getExternalStoragePath() {
    return _api.getExternalStoragePath();
  }

  @override
  Future<List<String>?> getExternalCachePaths() async {
    return (await _api.getExternalCachePaths()).cast<String>();
  }

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async {
    return _getExternalStoragePaths(type: type);
  }

  @override
  Future<String?> getDownloadsPath() async {
    final List<String> paths =
    await _getExternalStoragePaths(type: StorageDirectory.downloads);
    return paths.isEmpty ? null : paths.first;
  }

  Future<List<String>> _getExternalStoragePaths({
    StorageDirectory? type,
  }) async {
    return (await _api.getExternalStoragePaths(_convertStorageDirectory(type)))
        .cast<String>();
  }
}
