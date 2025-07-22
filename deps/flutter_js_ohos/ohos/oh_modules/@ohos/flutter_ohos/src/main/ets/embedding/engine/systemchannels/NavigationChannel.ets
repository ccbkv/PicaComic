/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on NavigationChannel.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

import JSONMethodCodec from '../../../plugin/common/JSONMethodCodec';
import MethodCall from '../../../plugin/common/MethodCall';
import MethodChannel, { MethodCallHandler, MethodResult } from '../../../plugin/common/MethodChannel';
import Log from '../../../util/Log';
import DartExecutor from '../dart/DartExecutor';

export default class NavigationChannel {
  private static TAG = "NavigationChannel";
  private channel: MethodChannel;

  constructor(dartExecutor: DartExecutor) {
    this.channel = new MethodChannel(dartExecutor, "flutter/navigation", JSONMethodCodec.INSTANCE);
    // Provide a default handler that returns an empty response to any messages
    // on this channel.
    this.channel.setMethodCallHandler(new NavigationCallback());
  }

  setInitialRoute(initialRoute: string): void {
    Log.i(NavigationChannel.TAG, "Sending message to set initial route to '" + initialRoute + "'");
    this.channel.invokeMethod("setInitialRoute", initialRoute);
  }

  pushRoute(route: string): void {
    Log.i(NavigationChannel.TAG, "Sending message to push route '" + route + "'");
    this.channel.invokeMethod("pushRoute", route);
  }

  pushRouteInformation(route: string): void {
    Log.i(NavigationChannel.TAG, "Sending message to push route information '" + route + "'");
    this.channel.invokeMethod("pushRouteInformation", new Map().set("location", route));
  }

  popRoute(): void {
    Log.i(NavigationChannel.TAG, "Sending message to pop route.");
    this.channel.invokeMethod("popRoute", null);
  }

  setMethodCallHandler(handler: MethodCallHandler) {
    this.channel.setMethodCallHandler(handler);
  }
}

class NavigationCallback implements MethodCallHandler {
  onMethodCall(call: MethodCall, result: MethodResult) {
    result.success(null);
  }
}