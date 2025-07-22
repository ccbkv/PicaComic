/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on LifecycleChannel.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

import Log from '../../../util/Log';
import StringCodec from '../../../plugin/common/StringCodec';
import DartExecutor from '../dart/DartExecutor';
import BasicMessageChannel from '../../../plugin/common/BasicMessageChannel';

/**
 * 生命周期channel
 */
export default class LifecycleChannel {
  private static TAG = "LifecycleChannel";
  private static CHANNEL_NAME = "flutter/lifecycle";
  // These should stay in sync with the AppLifecycleState enum in the framework.
  private static RESUMED = "AppLifecycleState.resumed";
  private static INACTIVE = "AppLifecycleState.inactive";
  private static PAUSED = "AppLifecycleState.paused";
  private static DETACHED = "AppLifecycleState.detached";
  private lastOhosState = "";
  private lastFlutterState = "";
  private lastFocus = true;
  private channel: BasicMessageChannel<string>;

  constructor(dartExecutor: DartExecutor) {
    this.channel = new BasicMessageChannel<string>(dartExecutor, LifecycleChannel.CHANNEL_NAME, StringCodec.INSTANCE)
  }

  // Called if at least one window in the app has focus.
  aWindowIsFocused(): void {
    this.sendState(this.lastOhosState, true);
  }

  // Called if no windows in the app have focus.
  noWindowsAreFocused(): void {
    this.sendState(this.lastOhosState, false);
  }

  appIsResumed(): void {
    this.sendState(LifecycleChannel.RESUMED, this.lastFocus);
  }

  appIsInactive(): void {
    this.sendState(LifecycleChannel.INACTIVE, this.lastFocus);
  }

  appIsPaused(): void {
    this.sendState(LifecycleChannel.PAUSED, this.lastFocus);
  }

  appIsDetached(): void {
    this.sendState(LifecycleChannel.DETACHED, this.lastFocus);
  }

  // Here's the state table this implements:
  //
  // | UIAbility State | Window focused | Flutter state |
  // |-----------------|----------------|---------------|
  // | onCreate        |     true       |    resumed    |
  // | onCreate        |     false      |    inactive   |
  // | onForeground    |     true       |    resumed    |
  // | onForeground    |     false      |    inactive   |
  // | onBackground    |     true       |    paused     |
  // | onBackground    |     false      |    paused     |
  // | onDestroy       |     true       |    detached   |
  // | onDestroy       |     false      |    detached   |

  private sendState(state: string, hasFocus: boolean): void {
    if (this.lastOhosState == state && hasFocus == this.lastFocus) {
      // No inputs changed, so Flutter state could not have changed.
      return;
    }
    let newState: string;
    if (state == LifecycleChannel.RESUMED) {
      newState = hasFocus ? LifecycleChannel.RESUMED : LifecycleChannel.INACTIVE;
    } else {
      newState = state;
    }
    // Keep the last reported values for future updates.
    this.lastOhosState = state;
    this.lastFocus = hasFocus;
    if (newState == this.lastFlutterState) {
      // No change in the resulting Flutter state, so don't report anything.
      return;
    }
    Log.i(LifecycleChannel.TAG, "Sending " + newState + " message.");
    this.channel.send(newState);
    this.lastFlutterState = newState;
  }
}