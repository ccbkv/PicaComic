/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/
import { lang } from '@kit.ArkTS';

import MethodCall from './MethodCall';
import { MethodResult } from './MethodChannel';

/** A handler of incoming method calls. */
type ISendable = lang.ISendable;

export default interface SendableMethodCallHandler extends ISendable {
  /**
   * Handles the specified method call received from Flutter.
   *
   * <p>Handler implementations must submit a result for all incoming calls, by making a single
   * call on the given {@link Result} callback. Failure to do so will result in lingering Flutter
   * result handlers. The result may be submitted asynchronously and on any thread. Calls to
   * unknown or unimplemented methods should be handled using {@link Result#notImplemented()}.
   *
   * <p>Any uncaught exception thrown by this method will be caught by the channel implementation
   * and logged, and an error result will be sent back to Flutter.
   *
   * <p>The handler is called on the platform thread (HarmonyOS main thread) by default, or
   * otherwise on the thread specified by the {@link BinaryMessenger.TaskQueue} provided to the
   * associated {@link MethodChannel} when it was created. See also <a
   * href="https://github.com/flutter/flutter/wiki/The-Engine-architecture#threading">Threading in
   * the Flutter Engine</a>.
   *
   * @param call A {@link MethodCall}.
   * @param result A {@link Result} used for submitting the result of the call.
   */
  onMethodCall(call: MethodCall, result: MethodResult, ...args: Object[]): void;
}