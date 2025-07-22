/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on JSONMethodCodec.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/
import Log from '../../util/Log';

import ToolUtils from '../../util/ToolUtils';
import FlutterException from './FlutterException';
import Any from './Any';
import JSONMessageCodec from './JSONMessageCodec';
import MethodCall from './MethodCall';
import MethodCodec from './MethodCodec';

/**
 * A {@link MethodCodec} using UTF-8 encoded JSON method calls and result envelopes.
 *
 * <p>This codec is guaranteed to be compatible with the corresponding <a
 * href="https://api.flutter.dev/flutter/services/JSONMethodCodec-class.html">JSONMethodCodec</a> on
 * the Dart side. These parts of the Flutter SDK are evolved synchronously.
 *
 * <p>Values supported as methods arguments and result payloads are those supported by {@link
 * JSONMessageCodec}.
 */
export default class JSONMethodCodec implements MethodCodec {
  static INSTANCE = new JSONMethodCodec();

  encodeMethodCall(methodCall: MethodCall): ArrayBuffer {
    try {
      const map: Record<string, Any> = {
        "method": methodCall.method, "args": methodCall.args
      }

      return JSONMessageCodec.INSTANCE.encodeMessage(map);
    } catch (e) {
      throw new Error("Invalid JSON");
    }
  }

  decodeMethodCall(message: ArrayBuffer): MethodCall {
    try {
      const json: Any = JSONMessageCodec.INSTANCE.decodeMessage(message);
      if (ToolUtils.isObj(json)) {
        const method: string = json["method"];
        const args: Any = json["args"];
        if (typeof method == 'string') {
          return new MethodCall(method, args);
        }
      }
      throw new Error("Invalid method call: " + json);
    } catch (e) {
      throw new Error("Invalid JSON:" + JSON.stringify(e));
    }
  }

  encodeSuccessEnvelope(result: Any): ArrayBuffer {
    return JSONMessageCodec.INSTANCE.encodeMessage([result]);
  }

  encodeErrorEnvelope(errorCode: Any, errorMessage: string, errorDetails: Any): ArrayBuffer {
    return JSONMessageCodec.INSTANCE.encodeMessage([errorCode, errorMessage, errorDetails]);
  }

  encodeErrorEnvelopeWithStacktrace(errorCode: string, errorMessage: string, errorDetails: Any,
    errorStacktrace: string): ArrayBuffer {
    return JSONMessageCodec.INSTANCE.encodeMessage([errorCode, errorMessage, errorDetails, errorStacktrace])
  }

  decodeEnvelope(envelope: ArrayBuffer): Any {
    try {
      const json: Any = JSONMessageCodec.INSTANCE.decodeMessage(envelope);
      if (json instanceof Array) {
        if (json.length == 1) {
          return json[0];
        }
        if (json.length == 3) {
          const code: string = json[0];
          const message: string = json[1];
          const details: Any = json[2];
          if (typeof code == 'string' && (message == null || typeof message == 'string')) {
            throw new FlutterException(code, message, details);
          }
        }
      }
      throw new Error("Invalid envelope: " + json);
    } catch (e) {
      throw new Error("Invalid JSON");
    }
  }
}