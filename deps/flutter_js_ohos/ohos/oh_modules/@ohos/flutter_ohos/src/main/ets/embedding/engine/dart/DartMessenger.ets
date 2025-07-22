/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on DartMessenger.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/
import { ErrorEvent, Queue, taskpool, worker, MessageEvents, JSON } from '@kit.ArkTS';

import Log from '../../../util/Log';
import {
  BinaryMessageHandler,
  BinaryMessenger,
  BinaryReply,
  TaskPriority,
  TaskQueue,
  TaskQueueOptions
} from '../../../plugin/common/BinaryMessenger';
import FlutterNapi from '../FlutterNapi';
import { PlatformMessageHandler } from './PlatformMessageHandler';
import { TraceSection } from '../../../util/TraceSection';
import SendableBinaryMessageHandler from '../../../plugin/common/SendableBinaryMessageHandler'

/**
 * Message conduit for 2-way communication between HarmonyOS and Dart.
 *
 * <p>See {@link BinaryMessenger}, which sends messages from HarmonyOS to Dart
 *
 * <p>See {@link PlatformMessageHandler}, which handles messages to HarmonyOS from Dart
 */

const TAG = "DartMessenger";

export class DartMessenger implements BinaryMessenger, PlatformMessageHandler {
  flutterNapi: FlutterNapi;
  /**
   * Maps a channel name to an object that contains the task queue and the handler associated with
   * the channel.
   */
  messageHandlers: Map<String, HandlerInfo> = new Map();
  pendingReplies: Map<number, BinaryReply> = new Map();
  nextReplyId: number = 1;
  taskQueueFactory: TaskQueueFactory;
  createdTaskQueues: Map<TaskQueue, DartMessengerTaskQueue> = new Map();

  constructor(flutterNapi: FlutterNapi) {
    this.flutterNapi = flutterNapi;
    this.taskQueueFactory = new DefaultTaskQueueFactory();
  }

  makeBackgroundTaskQueue(options?: TaskQueueOptions): TaskQueue {
    let taskQueue: DartMessengerTaskQueue =
      this.taskQueueFactory.makeBackgroundTaskQueue(options ?? new TaskQueueOptions());
    let token: TaskQueueToken = new TaskQueueToken();
    this.createdTaskQueues.set(token, taskQueue);
    return token;
  }

  setMessageHandler(channel: String, handler: BinaryMessageHandler | SendableBinaryMessageHandler | null,
    taskQueue?: TaskQueue, ...args: Object[]): void {
    if (handler == null) {
      Log.d(TAG, "Removing handler for channel '" + channel + "'");
      this.messageHandlers.delete(channel);
      return;
    }
    let dartMessengerTaskQueue: DartMessengerTaskQueue | null = null;
    if (taskQueue !== null && taskQueue !== undefined) {
      dartMessengerTaskQueue = this.createdTaskQueues.get(taskQueue) ?? null;
      if (dartMessengerTaskQueue == null) {
        throw new Error(
          "Unrecognized TaskQueue, use BinaryMessenger to create your TaskQueue (ex makeBackgroundTaskQueue)."
        );
      }
    }
    Log.d(TAG, "Setting handler for channel '" + channel + "'");

    this.messageHandlers.set(channel, new HandlerInfo(handler, dartMessengerTaskQueue, ...args));
  }

  send(channel: String, message: ArrayBuffer, callback?: BinaryReply): void {
    Log.d(TAG, "Sending message over channel '" + channel + "'");
    let traceId: number = TraceSection.begin("DartMessenger#send on " + channel);
    try {
      Log.d(TAG, "Sending message with callback over channel '" + channel + "'");
      let replyId: number = this.nextReplyId++;
      if (callback != null) {
        this.pendingReplies.set(replyId, callback);
      }
      if (message == null) {
        this.flutterNapi.dispatchEmptyPlatformMessage(channel, replyId);
      } else {
        this.flutterNapi.dispatchPlatformMessage(channel, message, message.byteLength, replyId);
      }
    } finally {
      TraceSection.endWithId("DartMessenger#send on " + channel, traceId);
    }
    this.IsFlutterNavigationExecuted(channel);
  }

  dispatchMessageToQueue(handlerInfo: HandlerInfo, message: ArrayBuffer, replyId: number): void {
    let taskState: TaskState = new TaskState(handlerInfo.handler as ESObject, message, ...handlerInfo.args);
    handlerInfo.taskQueue?.dispatch(taskState, new Reply(this.flutterNapi, replyId));
  }

  invokeHandler(handler: BinaryMessageHandler | null, message: ArrayBuffer, replyId: number): void {
    if (handler != null) {
      try {
        Log.d(TAG, "Deferring to registered handler to process message.");
        handler.onMessage(message, new Reply(this.flutterNapi, replyId));
      } catch (ex) {
        Log.e(TAG, "Uncaught exception in binary message listener", ex);
        this.flutterNapi.invokePlatformMessageEmptyResponseCallback(replyId);
      }
    } else {
      Log.d(TAG, "No registered handler for message. Responding to Dart with empty reply message.");
      this.flutterNapi.invokePlatformMessageEmptyResponseCallback(replyId);
    }
  }

  handleMessageFromDart(channel: String, message: ArrayBuffer, replyId: number, messageData: number): void {
    Log.d(TAG, "Received message from Dart over channel '" + channel + "'");
    let handlerInfo: HandlerInfo | null = this.messageHandlers.get(channel) ?? null;
    if (handlerInfo?.taskQueue != null) {
      this.dispatchMessageToQueue(handlerInfo, message, replyId);
    } else {
      this.invokeHandler(handlerInfo?.handler as BinaryMessageHandler, message, replyId);
    }
    this.IsFlutterNavigationExecuted(channel);
  }

  handlePlatformMessageResponse(replyId: number, reply: ArrayBuffer): void {
    Log.d(TAG, "Received message reply from Dart.");
    let callback: BinaryReply | null = this.pendingReplies.get(replyId) ?? null;
    this.pendingReplies.delete(replyId);
    if (callback != null) {
      try {
        Log.d(TAG, "Invoking registered callback for reply from Dart.");
        callback.reply(reply);
      } catch (e) {
        Log.e(TAG, "Uncaught exception in binary message reply handler", e);
      }
    }
  }

  /**
   * Returns the number of pending channel callback replies.
   *
   * <p>When sending messages to the Flutter application using {@link BinaryMessenger#send(String,
   * ByteBuffer, io.flutter.plugin.common.BinaryMessenger.BinaryReply)}, developers can optionally
   * specify a reply callback if they expect a reply from the Flutter application.
   *
   * <p>This method tracks all the pending callbacks that are waiting for response, and is supposed
   * to be called from the main thread (as other methods). Calling from a different thread could
   * possibly capture an indeterministic internal state, so don't do it.
   */
  getPendingChannelResponseCount(): number {
    return this.pendingReplies.size;
  }

  //获取当前flutter页面是否路由跳转，并传递到native侧
  IsFlutterNavigationExecuted(channel: String): void {
    if (channel == "flutter/navigation") {
      this.flutterNapi.setFlutterNavigationAction(this.flutterNapi.nativeShellHolderId!, true);
      Log.d(TAG, "setFlutterNavigationAction -> '" + channel + "'");
    }
  }
}

/**
 * Holds information about a platform handler, such as the task queue that processes messages from
 * Dart.
 */
class HandlerInfo {
  handler: BinaryMessageHandler | SendableBinaryMessageHandler;
  taskQueue: DartMessengerTaskQueue | null;
  args: Object[];

  constructor(handler: BinaryMessageHandler | SendableBinaryMessageHandler,
    taskQueue: DartMessengerTaskQueue | null,
    ...args: Object[]) {
    this.handler = handler;
    this.taskQueue = taskQueue;
    this.args = args;
  }
}

class Reply implements BinaryReply {
  flutterNapi: FlutterNapi;
  replyId: number;
  done: boolean = false;

  constructor(flutterNapi: FlutterNapi, replyId: number) {
    this.flutterNapi = flutterNapi;
    this.replyId = replyId;
  }

  reply(reply: ArrayBuffer | null) {
    if (this.done) {
      throw new Error("Reply already submitted");
    }

    if (reply == null) {
      this.flutterNapi.invokePlatformMessageEmptyResponseCallback(this.replyId);
    } else {
      this.flutterNapi.invokePlatformMessageResponseCallback(this.replyId, reply, reply.byteLength);
    }
  }
}

export class TaskState {
  handler: SendableBinaryMessageHandler;
  message: ArrayBuffer;
  args: Object[];

  constructor(handler: SendableBinaryMessageHandler, message: ArrayBuffer, ...args: Object[]) {
    this.handler = handler;
    this.message = message;
    this.args = args;
  }
}

interface DartMessengerTaskQueue {
  dispatch(taskState: TaskState, callback: Reply): void;
}

interface SerialTaskQueue extends DartMessengerTaskQueue {
}

interface TaskQueueFactory {
  makeBackgroundTaskQueue(options: TaskQueueOptions): DartMessengerTaskQueue;
}

class ConcurrentTaskQueue implements DartMessengerTaskQueue {
  private priority: TaskPriority;

  constructor(priority: TaskPriority) {
    this.priority = priority;
  }

  dispatch(taskState: TaskState, callback: Reply): void {
    let task: taskpool.Task = new taskpool.Task(handleMessageInBackground,
                                                taskState.handler,
                                                taskState.message,
                                                ...taskState.args);
    taskpool.execute(task, this.priority as number).then((result: Object) => {
      callback.reply(result as ArrayBuffer);
    }).catch((err: string) => {
      callback.reply(null);
      Log.e(TAG, "Oops! Failed to execute task: ", err);
    });
  }
}

const scriptURL: string = '../workers/PlatformChannelWorker.ets';
class SerialTaskQueueWithWorker implements SerialTaskQueue {
  private static workerInstance: worker.ThreadWorker | null = null;

  constructor () {
    if (!SerialTaskQueueWithWorker.workerInstance) {
      SerialTaskQueueWithWorker.workerInstance =
        new worker.ThreadWorker(scriptURL, {name: 'PlatformChannelWorker'});
    }
  }

  dispatch(taskState: TaskState, callback: Reply): void {
    SerialTaskQueueWithWorker.workerInstance!.onmessage = (e: MessageEvents): void => {
      callback.reply(e.data as ArrayBuffer);
    }

    SerialTaskQueueWithWorker.workerInstance!.onerror = (err: ErrorEvent) => {
      callback.reply(null);
      Log.e(TAG, "Oops! Failed to execute task in worker thread: ", err.message);
    }

    SerialTaskQueueWithWorker.workerInstance!.postMessageWithSharedSendable(taskState, [taskState.message]);
  }
}

type Runnable = () => Promise<void>;
class SerialTaskQueueWithTaskPool implements SerialTaskQueue {
  private priority: TaskPriority;
  private queue: Queue<Runnable> = new Queue();
  private isRunning: boolean = false;

  constructor(priority: TaskPriority) {
    this.priority = priority;
  }

  dispatch(taskState: TaskState, callback: Reply): void {
    let task: taskpool.Task = new taskpool.Task(handleMessageInBackground,
                                                taskState.handler,
                                                taskState.message,
                                                ...taskState.args);
    const runnable: Runnable = async () => {
      try {
        const result = await taskpool.execute(task, this.priority as number);
        callback.reply(result as ArrayBuffer);
      } catch (err) {
        callback.reply(null);
        Log.e(TAG, "Oops! Failed to execute task: ", err);
      }
    };

    this.queue.add(runnable);

    if (!this.isRunning) {
      this.runNext();
    }
  }

  private async runNext(): Promise<void> {
    if (this.queue.length > 0) {
      this.isRunning = true;
      const task = this.queue.pop();
      try {
        await task();
      } finally {
        this.isRunning = false;
        this.runNext(); // 执行下一个任务
      }
    }
  }
}

class DefaultTaskQueueFactory implements TaskQueueFactory {
  makeBackgroundTaskQueue(options: TaskQueueOptions): DartMessengerTaskQueue {
    if (options.isSingleThreadMode()) {
      return new SerialTaskQueueWithWorker();
    } else {
      if (options.getIsSerial()) {
        return new SerialTaskQueueWithTaskPool(options.getPriority());
      }
      return new ConcurrentTaskQueue(options.getPriority());
    }
  }
}

class TaskQueueToken implements TaskQueue {
}

@Concurrent
async function handleMessageInBackground(handler: SendableBinaryMessageHandler,
  message: ArrayBuffer,
  ...args: Object[]): Promise<ArrayBuffer | null> {
  const result = await new Promise<ArrayBuffer | null>((resolve, reject) => {
    try {
      handler.onMessage(message, {
        reply: (reply: ArrayBuffer | null): void => {
          resolve(reply);
        }
      }, ...args);
    } catch (e) {
      reject(null);
      Log.e('WARNING', "Oops! Failed to handle message in the background: ", e);
    }
  });
  return result;
}
