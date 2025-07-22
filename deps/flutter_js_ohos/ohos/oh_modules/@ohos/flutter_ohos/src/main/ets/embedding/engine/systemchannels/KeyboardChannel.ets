/*
 * Copyright (c) 2021-2025 Huawei Device Co., Ltd. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE_HW file.
 */


import DartExecutor from '../dart/DartExecutor';
import MethodChannel, { MethodCallHandler, MethodResult } from '../../../plugin/common/MethodChannel';
import MethodCall from '../../../plugin/common/MethodCall';
import StandardMethodCodec from '../../../plugin/common/StandardMethodCodec';
import Log from '../../../util/Log';

export default class KeyboardChannel implements MethodCallHandler {
  private static TAG = "KeyboardChannel";
  private static CHANNEL_NAME = "flutter/keyboard";
  private channel: MethodChannel;
  private handler: KeyboardMethodHandler | null = null;

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (this.handler == null) {
      Log.i(KeyboardChannel.TAG, "KeyboardMethodHandler is null");
      return;
    }

    let method: string = call.method;
    switch (method) {
      case "getKeyboardState": {
        Log.i(KeyboardChannel.TAG, "getKeyboardState enter");
        result.success(this.handler?.getKeyboardState());
        break;
      }
      default: {
        result.notImplemented();
        break;
      }
    }
  }

  constructor(dartExecutor: DartExecutor) {
    this.channel = new MethodChannel(dartExecutor, KeyboardChannel.CHANNEL_NAME, StandardMethodCodec.INSTANCE);
    this.channel.setMethodCallHandler(this);
  }

  public setKeyboardMethodHandler(keyboardMessageHandler: KeyboardMethodHandler | null): void {
    this.handler = keyboardMessageHandler;
  }
}

export interface KeyboardMethodHandler {
  getKeyboardState(): Map<number, number>;
}