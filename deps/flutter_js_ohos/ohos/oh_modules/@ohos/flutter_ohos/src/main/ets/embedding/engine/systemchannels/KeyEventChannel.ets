/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on KeyEventChannel.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

import BasicMessageChannel from '../../../plugin/common/BasicMessageChannel';
import { BinaryMessenger } from '../../../plugin/common/BinaryMessenger';
import Log from '../../../util/Log';
import JSONMessageCodec from '../../../plugin/common/JSONMessageCodec';

export default class KeyEventChannel {
  private static TAG = "KeyEventChannel";
  private static CHANNEL_NAME = "flutter/keyevent";
  private channel: BasicMessageChannel<Map<String, Object>>;

  constructor(binaryMessenger: BinaryMessenger) {
    this.channel = new BasicMessageChannel<Map<String, Object>>(binaryMessenger, KeyEventChannel.CHANNEL_NAME,
      JSONMessageCodec.INSTANCE);
  }

  sendFlutterKeyEvent(keyEvent: FlutterKeyEvent,
    isKeyUp: boolean,
    responseHandler: EventResponseHandler): void {
    this.channel.send(this.encodeKeyEvent(keyEvent, isKeyUp),
      (message: Map<String, Object>) => {
        let isEventHandled = false;
        try {
          if (message != null) {
            isEventHandled = message.get("handled") as boolean;
          }
        } catch (e) {
          Log.e(KeyEventChannel.TAG, "Unable to unpack JSON message: " + e);
        }
        responseHandler.onFrameworkResponse(isEventHandled);
      }
    );
  }

  private encodeKeyEvent(keyEvent: FlutterKeyEvent, isKeyUp: boolean): Map<String, Object> {
    let message: Map<String, Object> = new Map();
    message.set("type", isKeyUp ? "keyup" : "keydown");
    message.set("keymap", "ohos");
    message.set("keyCode", keyEvent.event.keyCode);
    message.set("deviceId", keyEvent.event.deviceId);
    message.set("flags", keyEvent.event.keyText);
    message.set("metaState", keyEvent.event.metaKey);
    message.set("source", keyEvent.event.keySource);
    message.set("intentionCode", keyEvent.event.intentionCode)
    return message;
  }
}

export interface EventResponseHandler {
  onFrameworkResponse: (isEventHandled: boolean) => void;
}

export class FlutterKeyEvent {
  event: KeyEvent;

  constructor(ohosKeyEvent: KeyEvent) {
    this.event = ohosKeyEvent;
  }
}