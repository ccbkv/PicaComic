/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/

import BasicMessageChannel, { MessageHandler, Reply } from '../../../plugin/common/BasicMessageChannel';
import JSONMessageCodec from '../../../plugin/common/JSONMessageCodec';
import DartExecutor from '../dart/DartExecutor';
import Log from '../../../util/Log';

const TAG = "TestChannel"

export default class TestChannel {
  private channel: BasicMessageChannel<String>;

  constructor(dartExecutor: DartExecutor) {
    this.channel = new BasicMessageChannel<String>(dartExecutor, "flutter/test", JSONMessageCodec.INSTANCE);
    let callback = new MessageCallback();
    this.channel.setMessageHandler(callback);
  }
}

class MessageCallback implements MessageHandler<string> {
  onMessage(message: string, reply: Reply<string>) {
    Log.d(TAG, "receive msg = " + message);
    reply.reply("收到消息啦：" + message);
  }
}