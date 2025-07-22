/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on LocalizationChannel.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

import DartExecutor from '../dart/DartExecutor';
import MethodChannel, { MethodCallHandler, MethodResult } from '../../../plugin/common/MethodChannel';
import MethodCall from '../../../plugin/common/MethodCall';
import List from '@ohos.util.List';
import JSONMethodCodec from '../../../plugin/common/JSONMethodCodec';
import intl from '@ohos.intl';
import Log from '../../../util/Log';

const TAG = "LocalizationChannel";

export default class LocalizationChannel implements MethodCallHandler {
  private static TAG = "LocalizationChannel";
  private static CHANNEL_NAME = "flutter/localization";
  private channel: MethodChannel;
  private localizationMessageHandler: LocalizationMessageHandler | null = null;

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (this.localizationMessageHandler == null) {
      Log.e(TAG, "localizationMessageHandler is null");
      return;
    }
    let method: string = call.method;
    switch (method) {
      case "Localization.getStringResource": {
        Log.i(TAG, "Localization.getStringResource enter");
        let key: string = call.argument("key");
        let localeString: string = "";
        if (call.hasArgument("locale")) {
          localeString = call.argument("locale");
        }
        result.success(this.localizationMessageHandler?.getStringResource(key, localeString));
        break;
      }
      default: {
        result.notImplemented();
        break;
      }
    }
  }

  constructor(dartExecutor: DartExecutor) {
    this.channel = new MethodChannel(dartExecutor, LocalizationChannel.CHANNEL_NAME, JSONMethodCodec.INSTANCE);
    this.channel.setMethodCallHandler(this);
  }

  setLocalizationMessageHandler(localizationMessageHandler: LocalizationMessageHandler): void {
    this.localizationMessageHandler = localizationMessageHandler;
  }

  sendLocales(locales: string[]): void {
    let data: string[] = [];
    for (let i = 0; i < locales.length; i++) {
      let locale = new intl.Locale(locales[i]);
      data.push(locale.language);
      data.push(locale.region);
      data.push(locale.script);
      data.push(''); // locale.getVariant locale的一种变体
    }
    this.channel.invokeMethod("setLocale", data);
  }
}

export interface LocalizationMessageHandler {
  getStringResource(key: string, local: string): void;
}