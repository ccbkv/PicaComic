/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/
import Log from '../../util/Log';
import MessageChannelUtils from '../../util/MessageChannelUtils';
import StringUtils from '../../util/StringUtils';
import { BinaryMessenger, BinaryReply, TaskQueue } from './BinaryMessenger';
import Any from './Any';
import MethodCall from './MethodCall';
import MethodCodec from './MethodCodec';
import { MethodResult } from './MethodChannel'
import SendableStandardMethodCodec from './SendableStandardMethodCodec';
import SendableMethodCallHandler from './SendableMethodCallHandler'
import SendableMethodCodec from './SendableMethodCodec'
import SendableBinaryMessageHandler from './SendableBinaryMessageHandler'

/**
 * A named channel for communicating with the Flutter application using asynchronous method calls.
 *
 * <p>Incoming method calls are decoded from binary on receipt, and Java results are encoded into
 * binary before being transmitted back to Flutter. The {@link MethodCodec} used must be compatible
 * with the one used by the Flutter application. This can be achieved by creating a <a
 * href="https://api.flutter.dev/flutter/services/MethodChannel-class.html">MethodChannel</a>
 * counterpart of this channel on the Dart side. The Java type of method call arguments and results
 * is {@code Object}, but only values supported by the specified {@link MethodCodec} can be used.
 *
 * <p>The logical identity of the channel is given by its name. Identically named channels will
 * interfere with each other's communication.
 */

export default class BackgroundMethodChannel {
  static TAG = "BackgroundMethodChannel#";
  private messenger: BinaryMessenger;
  private name: string;
  private codec: SendableMethodCodec;
  private taskQueue: TaskQueue;
  private args: Object[];

  constructor(messenger: BinaryMessenger,
    name: string,
    codec: SendableMethodCodec = SendableStandardMethodCodec.INSTANCE,
    taskQueue?: TaskQueue,
    ...args: Object[]) {
    this.messenger = messenger
    this.name = name
    this.codec = codec
    this.taskQueue = taskQueue ?? messenger.makeBackgroundTaskQueue()
    this.args = args
  }

  /**
   * Invokes a method on this channel, optionally expecting a result.
   *
   * <p>Any uncaught exception thrown by the result callback will be caught and logged.
   *
   * @param method the name String of the method.
   * @param arguments the arguments for the invocation, possibly null.
   * @param callback a {@link Result} callback for the invocation result, or null.
   */
  invokeMethod(method: string, args: Any, callback?: MethodResult): void {
    this.messenger.send(this.name,
      this.codec.encodeMethodCall(new MethodCall(method, args)),
      callback == null ? null : new IncomingSendableResultHandler(callback, this.codec));
  }

  /**
   * Registers a method call handler on this channel.
   *
   * <p>Overrides any existing handler registration for (the name of) this channel.
   *
   * <p>If no handler has been registered, any incoming method call on this channel will be handled
   * silently by sending a null reply. This results in a <a
   * href="https://api.flutter.dev/flutter/services/MissingPluginException-class.html">MissingPluginException</a>
   * on the Dart side, unless an <a
   * href="https://api.flutter.dev/flutter/services/OptionalMethodChannel-class.html">OptionalMethodChannel</a>
   * is used.
   *
   * @param handler a {@link MethodCallHandler}, or null to deregister.
   */
  setMethodCallHandler(handler: SendableMethodCallHandler | null): void {
    this.messenger.setMessageHandler(this.name,
      handler == null ? null : new IncomingSendableMethodCallHandler(handler, this.codec),
      this.taskQueue, ...this.args);
  }

  /**
   * Adjusts the number of messages that will get buffered when sending messages to channels that
   * aren't fully set up yet. For example, the engine isn't running yet or the channel's message
   * handler isn't set up on the Dart side yet.
   */
  resizeChannelBuffer(newSize: number): void {
    MessageChannelUtils.resizeChannelBuffer(this.messenger, this.name, newSize);
  }
}

export class IncomingSendableResultHandler implements BinaryReply {
  private callback: MethodResult;
  private codec: SendableMethodCodec;

  constructor(callback: MethodResult, codec: SendableMethodCodec) {
    this.callback = callback;
    this.codec = codec
  }

  reply(reply: ArrayBuffer | null): void {
    try {
      if (reply == null) {
        this.callback.notImplemented();
      } else {
        try {
          this.callback.success(this.codec.decodeEnvelope(reply));
        } catch (e) {
          this.callback.error(e.code, e.getMessage(), e.details);
        }
      }
    } catch (e) {
      Log.e(BackgroundMethodChannel.TAG, "Failed to handle method call result", e);
    }
  }
}

@Sendable
export class IncomingSendableMethodCallHandler implements SendableBinaryMessageHandler {
  private handler: SendableMethodCallHandler;
  private codec: SendableMethodCodec;

  constructor(handler: SendableMethodCallHandler, codec: SendableMethodCodec) {
    this.handler = handler;
    this.codec = codec;
  }

  onMessage(message: ArrayBuffer, reply: BinaryReply, ...args: Object[]): void {
    try {
      this.handler.onMethodCall(
        this.codec.decodeMethodCall(message),
        {
          success: (result: Any): void => {
            reply.reply(this.codec.encodeSuccessEnvelope(result));
          },
          error: (errorCode: string, errorMessage: string, errorDetails: Any): void => {
            reply.reply(this.codec.encodeErrorEnvelope(errorCode, errorMessage, errorDetails));
          },
          notImplemented: (): void => {
            reply.reply(StringUtils.stringToArrayBuffer(""));
          }
        }, ...args);
    } catch (e) {
      reply.reply(this.codec.encodeErrorEnvelopeWithStacktrace("error", e.getMessage(), null, e));
    }
  }
}