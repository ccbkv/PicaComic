/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on EventChannel.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/


/**
 * A named channel for communicating with the Flutter application using asynchronous event streams.
 *
 * <p>Incoming requests for event stream setup are decoded from binary on receipt, and Java
 * responses and events are encoded into binary before being transmitted back to Flutter. The {@link
 * MethodCodec} used must be compatible with the one used by the Flutter application. This can be
 * achieved by creating an <a
 * href="https://api.flutter.dev/flutter/services/EventChannel-class.html">EventChannel</a>
 * counterpart of this channel on the Dart side. The Java type of stream configuration arguments,
 * events, and error details is {@code Object}, but only values supported by the specified {@link
 * MethodCodec} can be used.
 *
 * <p>The logical identity of the channel is given by its name. Identically named channels will
 * interfere with each other's communication.
 */
import Log from '../../util/Log';
import { BinaryMessageHandler, BinaryMessenger, BinaryReply, TaskQueue } from './BinaryMessenger';
import Any from './Any';
import MethodCodec from './MethodCodec';
import StandardMethodCodec from './StandardMethodCodec';

const TAG = "EventChannel#";

export default class EventChannel {
  private messenger: BinaryMessenger;
  private name: string;
  private codec: MethodCodec;
  private taskQueue: TaskQueue | null;

  constructor(messenger: BinaryMessenger, name: string, codec?: MethodCodec, taskQueue?: TaskQueue) {
    this.messenger = messenger
    this.name = name
    this.codec = codec ? codec : StandardMethodCodec.INSTANCE
    // TODO:(0xZOne): 实现后台处理
    // this.taskQueue = taskQueue ?? null
    this.taskQueue = null
  }


  /**
   * Registers a stream handler on this channel.
   *
   * <p>Overrides any existing handler registration for (the name of) this channel.
   *
   * <p>If no handler has been registered, any incoming stream setup requests will be handled
   * silently by providing an empty stream.
   *
   * @param handler a {@link StreamHandler}, or null to deregister.
   */
  setStreamHandler(handler: StreamHandler): void {
    // We call the 2 parameter variant specifically to avoid breaking changes in
    // mock verify calls.
    // See https://github.com/flutter/flutter/issues/92582.
    if (this.taskQueue != null) {
      this.messenger.setMessageHandler(
        this.name,
        handler == null ? null : new IncomingStreamRequestHandler(handler, this.name, this.codec, this.messenger),
        this.taskQueue);
    } else {
      this.messenger.setMessageHandler(
        this.name,
        handler == null ? null : new IncomingStreamRequestHandler(handler, this.name, this.codec, this.messenger));
    }
  }
}

/**
 * Handler of stream setup and teardown requests.
 *
 * <p>Implementations must be prepared to accept sequences of alternating calls to {@link
 * #onListen(Object, EventChannel.EventSink)} and {@link #onCancel(Object)}. Implementations
 * should ideally consume no resources when the last such call is not {@code onListen}. In typical
 * situations, this means that the implementation should register itself with platform-specific
 * event sources {@code onListen} and deregister again {@code onCancel}.
 */
export interface StreamHandler {
  /**
   * Handles a request to set up an event stream.
   *
   * <p>Any uncaught exception thrown by this method will be caught by the channel implementation
   * and logged. An error result message will be sent back to Flutter.
   *
   * @param arguments stream configuration arguments, possibly null.
   * @param events an {@link EventSink} for emitting events to the Flutter receiver.
   */
  onListen(args: Any, events: EventSink): void;

  /**
   * Handles a request to tear down the most recently created event stream.
   *
   * <p>Any uncaught exception thrown by this method will be caught by the channel implementation
   * and logged. An error result message will be sent back to Flutter.
   *
   * <p>The channel implementation may call this method with null arguments to separate a pair of
   * two consecutive set up requests. Such request pairs may occur during Flutter hot restart. Any
   * uncaught exception thrown in this situation will be logged without notifying Flutter.
   *
   * @param arguments stream configuration arguments, possibly null.
   */
  onCancel(args: Any): void;
}

/**
 * Event callback. Supports dual use: Producers of events to be sent to Flutter act as clients of
 * this interface for sending events. Consumers of events sent from Flutter implement this
 * interface for handling received events (the latter facility has not been implemented yet).
 */
export interface EventSink {
  /**
   * Consumes a successful event.
   *
   * @param event the event, possibly null.
   */
  success(event: Any): void;

  /**
   * Consumes an error event.
   *
   * @param errorCode an error code String.
   * @param errorMessage a human-readable error message String, possibly null.
   * @param errorDetails error details, possibly null
   */
  error(errorCode: string, errorMessage: string, errorDetails: Any): void;

  /**
   * Consumes end of stream. Ensuing calls to {@link #success(Object)} or {@link #error(String,
   * String, Object)}, if any, are ignored.
   */
  endOfStream(): void;
}

class IncomingStreamRequestHandler implements BinaryMessageHandler {
  private handler: StreamHandler;
  private activeSink = new AtomicReference<EventSink>(null);
  private codec: MethodCodec;
  private name: string;
  private messenger: BinaryMessenger;

  constructor(handler: StreamHandler, name: string, codec: MethodCodec, messenger: BinaryMessenger) {
    this.handler = handler;
    this.codec = codec;
    this.name = name;
    this.messenger = messenger;
  }

  onMessage(message: ArrayBuffer, reply: BinaryReply): void {
    const call = this.codec.decodeMethodCall(message);
    if (call.method == "listen") {
      this.onListen(call.args, reply);
    } else if (call.method == "cancel") {
      this.onCancel(call.args, reply);
    } else {
      reply.reply(null);
    }
  }

  onListen(args: Any, callback: BinaryReply): void {
    const eventSink = new EventSinkImplementation(this.activeSink, this.name, this.codec, this.messenger);
    const oldSink = this.activeSink.getAndSet(eventSink);
    if (oldSink != null) {
      // Repeated calls to onListen may happen during hot restart.
      // We separate them with a call to onCancel.
      try {
        this.handler.onCancel(null);
      } catch (e) {
        Log.e(TAG + this.name, "Failed to close existing event stream", e);
      }
    }
    try {
      this.handler.onListen(args, eventSink);
      callback.reply(this.codec.encodeSuccessEnvelope(null));
    } catch (e) {
      this.activeSink.set(null);
      Log.e(TAG + this.name, "Failed to open event stream", e);
      callback.reply(this.codec.encodeErrorEnvelope("error", e.getMessage(), null));
    }
  }

  onCancel(args: Any, callback: BinaryReply): void {
    const oldSink = this.activeSink.getAndSet(null);
    if (oldSink != null) {
      try {
        this.handler.onCancel(args);
        callback.reply(this.codec.encodeSuccessEnvelope(null));
      } catch (e) {
        Log.e(TAG + this.name, "Failed to close event stream", e);
        callback.reply(this.codec.encodeErrorEnvelope("error", e.getMessage(), null));
      }
    } else {
      callback.reply(this.codec.encodeErrorEnvelope("error", "No active stream to cancel", null));
    }
  }
}

class EventSinkImplementation implements EventSink {
  private hasEnded = false;
  private activeSink: AtomicReference<EventSink>;
  private messenger: BinaryMessenger;
  private codec: MethodCodec;
  private name: string;

  constructor(activeSink: AtomicReference<EventSink>, name: string, codec: MethodCodec, messenger: BinaryMessenger) {
    this.activeSink = activeSink;
    this.codec = codec;
    this.name = name;
    this.messenger = messenger;
  }

  success(event: Any): void {
    if (this.hasEnded || this.activeSink.get() != this) {
      return;
    }
    this.messenger.send(this.name, this.codec.encodeSuccessEnvelope(event));
  }

  error(errorCode: string, errorMessage: string, errorDetails: Any) {
    if (this.hasEnded || this.activeSink.get() != this) {
      return;
    }
    this.messenger.send(
      this.name, this.codec.encodeErrorEnvelope(errorCode, errorMessage, errorDetails));
  }

  endOfStream(): void {
    if (this.hasEnded || this.activeSink.get() != this) {
      return;
    }
    this.hasEnded = true;
    this.messenger.send(this.name, new ArrayBuffer(0));
  }
}

class AtomicReference<T> {
  private value: T | null;

  constructor(value: T | null) {
    this.value = value
  }

  get(): T | null {
    return this.value;
  }

  set(newValue: T | null): void {
    this.value = newValue;
  }

  getAndSet(newValue: T | null) {
    const oldValue = this.value;
    this.value = newValue;
    return oldValue;
  }
}