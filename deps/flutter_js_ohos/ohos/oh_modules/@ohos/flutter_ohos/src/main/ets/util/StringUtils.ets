/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/

import flutter from 'libflutter.so'

/**
 * 默认字符串工具
 */
export default class StringUtils {

  static stringToArrayBuffer(str: string): ArrayBuffer {
    if (str.length == 0) {
      return new ArrayBuffer(0);
    }
    return flutter.nativeEncodeUtf8(str).buffer;
  }

  static arrayBufferToString(buffer: ArrayBuffer): string {
    if (buffer.byteLength <= 0) {
      return "";
    }
    return flutter.nativeDecodeUtf8(new Uint8Array(buffer));
  }

  static uint8ArrayToString(buffer: Uint8Array): string {
    if (buffer.length <= 0) {
      return "";
    }
    return flutter.nativeDecodeUtf8(buffer);
  }

  static isNotEmpty(str: string): boolean {
    return str != null && str.length > 0;
  }

  static isEmpty(str: string): boolean {
    return (!str) || str.length == 0;
  }
}