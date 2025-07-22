/*
 * Copyright (c) 2024 Shenzhen Kaihong Digital Industry Development Co., Ltd.
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

import 'dart:convert';
import 'dart:typed_data';

import 'enums.dart';

abstract class OhosPixelMap<T> {
  T get data;

  OhosBitmapSource get source;
}

class DrawableResourceOhosPixelMap implements OhosPixelMap<String> {
  const DrawableResourceOhosPixelMap(this._pixelmap);

  final String _pixelmap;

  @override
  String get data => _pixelmap;

  @override
  OhosBitmapSource get source => OhosBitmapSource.drawable;
}

class FilePathOhosPixelMap implements OhosPixelMap<String> {
  const FilePathOhosPixelMap(this._pixelmap);

  final String _pixelmap;

  @override
  String get data => _pixelmap;

  @override
  OhosBitmapSource get source => OhosBitmapSource.filePath;
}

class ByteArrayOhosPixelMap implements OhosPixelMap<Uint8List> {
  const ByteArrayOhosPixelMap(this._pixelmap);

  factory ByteArrayOhosPixelMap.fromBase64String(String base64Image) =>
      ByteArrayOhosPixelMap(base64Decode(base64Image));

  final Uint8List _pixelmap;

  @override
  Uint8List get data => _pixelmap;

  @override
  OhosBitmapSource get source => OhosBitmapSource.byteArray;
}
