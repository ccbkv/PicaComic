/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on BasicMessageChannel.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/
import MessageChannelUtils from '../../util/MessageChannelUtils';
import { BinaryMessageHandler } from './BinaryMessenger';
import Log from '../../util/Log';
import { BinaryReply } from './BinaryMessenger';
import { TaskQueue } from './BinaryMessenger';
import MessageCodec from './MessageCodec';
import { BinaryMessenger } from './BinaryMessenger';
import StringUtils from '../../util/StringUtils';

/**
 * A named channel for communicating with the Flutter application using basic, asynchronous message
 * passing.
 *
 * <p>Messages are encoded into binary before being sent, and binary messages received are decoded
 * into Java objects. The {@link MessageCodec} used must be compatible with the one used by the
 * Flutter application. This can be achieved by creating a <a
 * href="https://api.flutter.dev/flutter/services/BasicMessageChannel-class.html">BasicMessageChannel</a>
 * counterpart of this channel on the Dart side. The static Java type of messages sent and received
 * is {@code Object}, but only values supported by the specified {@link MessageCodec} can be used.
 *
 * <p>The logical identity of the channel is given by its name. Identically named channels will
 * interfere with each other's communication.
 */
export default class BasicMessageChannel<T> {
  public static TAG = "BasicMessageChannel#";
  public static CHANNEL_BUFFERS_CHANNEL = "dev.flutter/channel-buffers";
  private messenger: BinaryMessenger;
  private name: string;
  private codec: MessageCodec<T>;

  constructor(messenger: BinaryMessenger, name: string, codec: MessageCodec<T>) {
    this.messenger = messenger
    this.name = name
    this.codec = codec
  }

  /**
   * Sends the specified message to the Flutter application, optionally expecting a reply.
   *
   * <p>Any uncaught exception thrown by the reply callback will be caught and logged.
   *
   * @param message the message, possibly null.
   * @param callback a {@link Reply} callback, possibly null.
   */
  send(message: T, callback?: (reply: T) => void): void {
    this.messenger.send(this.name, this.codec.encodeMessage(message),
      callback == null ? null : new IncomingReplyHandler(callback, this.codec));
  }

  /**
   * Registers a message handler on this channel for receiving messages sent from the Flutter
   * application.
   *
   * <p>Overrides any existing handler registration for (the name of) this channel.
   *
   * <p>If no handler has been registered, any incoming message on this channel will be handled
   * silently by sending a null reply.
   *
   * @param handler a {@link MessageHandler}, or null to deregister.
   */
  setMessageHandler(handler: MessageHandler<T> | null): void {
    this.messenger.setMessageHandler(this.name,
      handler == null ? null : new IncomingMessageHandler(handler, this.codec));
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


export interface Reply<T> {
  /**
   * Handles the specified message reply.
   *
   * @param reply the reply, possibly null.
   */
  reply: (reply: T) => void;
}

export interface MessageHandler<T> {

  /**
   * Handles the specified message received from Flutter.
   *
   * <p>Handler implementations must reply to all incoming messages, by submitting a single reply
   * message to the given {@link Reply}. Failure to do so will result in lingering Flutter reply
   * handlers. The reply may be submitted asynchronously and invoked on any thread.
   *
   * <p>Any uncaught exception thrown by this method, or the preceding message decoding, will be
   * caught by the channel implementation and logged, and a null reply message will be sent back
   * to Flutter.
   *
   * <p>Any uncaught exception thrown during encoding a reply message submitted to the {@link
   * Reply} is treated similarly: the exception is logged, and a null reply is sent to Flutter.
   *
   * @param message the message, possibly null.
   * @param reply a {@link Reply} for sending a single message reply back to Flutter.
   */
  onMessage(message: T, reply: Reply<T>): void;
}

class IncomingReplyHandler<T> implements BinaryReply {
  private callback: (reply: T) => void;
  private codec: MessageCodec<T>

  constructor(callback: (reply: T) => void, codec: MessageCodec<T>) {
    this.callback = callback
    this.codec = codec
  }

  reply(reply: ArrayBuffer | null) {
    try {
      this.callback(this.codec.decodeMessage(reply));
    } catch (e) {
      Log.e(BasicMessageChannel.TAG, "Failed to handle message reply", e);
    }
  }
}

class IncomingMessageHandler<T> implements BinaryMessageHandler {
  private handler: MessageHandler<T>
  private codec: MessageCodec<T>

  constructor(handler: MessageHandler<T>, codec: MessageCodec<T>) {
    this.handler = handler;
    this.codec = codec
  }

  onMessage(message: ArrayBuffer, callback: BinaryReply) {
    try {
      this.handler.onMessage(
        this.codec.decodeMessage(message),
        {
          reply: (reply: T): void => {
            callback.reply(this.codec.encodeMessage(reply));
          }
        });
    } catch (e) {
      Log.e(BasicMessageChannel.TAG, "Failed to handle message", e);
      callback.reply(StringUtils.stringToArrayBuffer(""));
    }
  }
}
