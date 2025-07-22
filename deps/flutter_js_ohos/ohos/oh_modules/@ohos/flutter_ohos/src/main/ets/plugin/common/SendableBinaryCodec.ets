/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on BinaryCodec.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

import SendableMessageCodec from './SendableMessageCodec';

/**
 * A {@link MessageCodec} using unencoded binary messages, represented as {@link ByteBuffer}s.
 *
 * <p>This codec is guaranteed to be compatible with the corresponding <a
 * href="https://api.flutter.dev/flutter/services/BinaryCodec-class.html">BinaryCodec</a> on the
 * Dart side. These parts of the Flutter SDK are evolved synchronously.
 *
 * <p>On the Dart side, messages are represented using {@code ByteData}.
 */

@Sendable
export default class SendableBinaryCodec implements SendableMessageCodec<ArrayBuffer> {
  private returnsDirectByteBufferFromDecoding: boolean = false;
  static readonly INSTANCE_DIRECT: SendableBinaryCodec = new SendableBinaryCodec(true);

  constructor(returnsDirectByteBufferFromDecoding: boolean) {
    this.returnsDirectByteBufferFromDecoding = returnsDirectByteBufferFromDecoding;
  }

  encodeMessage(message: ArrayBuffer): ArrayBuffer {
    return message
  }

  decodeMessage(message: ArrayBuffer | null): ArrayBuffer {
    if (message == null) {
      return new ArrayBuffer(0);
    } else if (this.returnsDirectByteBufferFromDecoding) {
      return message;
    } else {
      return message.slice(0, message.byteLength);
    }
  }
}
