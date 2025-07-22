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

// ignore_for_file: public_member_api_docs

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/cupertino.dart';

import 'file_selector_api.g.dart';

/// An implementation of [FileSelectorPlatform] for Android.
class FileSelectorOhos extends FileSelectorPlatform {
  FileSelectorOhos({@visibleForTesting FileSelectorApi? api})
      : _api = api ?? FileSelectorApi();

  final FileSelectorApi _api;

  /// Registers this class as the implementation of the file_selector platform interface.
  static void registerWith() {
    FileSelectorPlatform.instance = FileSelectorOhos();
  }

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    final FileResponse? file = await _api.openFile(
      initialDirectory,
      _fileTypesFromTypeGroups(acceptedTypeGroups),
    );
    return file == null ? null : _xFileFromFileResponse(file);
  }

  @override
  Future<List<XFile>> openFiles({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    final List<FileResponse?> files = await _api.openFiles(
      initialDirectory,
      _fileTypesFromTypeGroups(acceptedTypeGroups),
    );
    return files
        .cast<FileResponse>()
        .map<XFile>(_xFileFromFileResponse)
        .toList();
  }

  @override
  Future<String?> getDirectoryPath({
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    return _api.getDirectoryPath(initialDirectory);
  }

  XFile _xFileFromFileResponse(FileResponse file) {
    return XFile.fromData(
      file.bytes,
      // Note: The name parameter is not used by XFile. The XFile.name returns
      // the extracted file name from XFile.path.
      name: file.name,
      length: file.size,
      mimeType: file.mimeType,
      path: file.path,
    );
  }

  FileTypes _fileTypesFromTypeGroups(List<XTypeGroup>? typeGroups) {
    if (typeGroups == null) {
      return FileTypes(extensions: <String>[], mimeTypes: <String>[]);
    }

    final Set<String> mimeTypes = <String>{};
    final Set<String> extensions = <String>{};

    for (final XTypeGroup group in typeGroups) {
      if (!group.allowsAny &&
          group.mimeTypes == null &&
          group.extensions == null) {
        throw ArgumentError(
          'Provided type group $group does not allow all files, but does not '
          'set any of the Android supported filter categories. At least one of '
          '"extensions" or "mimeTypes" must be non-empty for Android.',
        );
      }

      mimeTypes.addAll(group.mimeTypes ?? <String>{});
      extensions.addAll(group.extensions ?? <String>{});
    }

    return FileTypes(
      mimeTypes: mimeTypes.toList(),
      extensions: extensions.toList(),
    );
  }
}
