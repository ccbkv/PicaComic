/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/

import BasicMessageChannel from '../plugin/common/BasicMessageChannel';
import { BinaryMessenger } from '../plugin/common/BinaryMessenger';
import StringUtils from './StringUtils';

export default class MessageChannelUtils {
  static resizeChannelBuffer(messenger: BinaryMessenger, channel: string, newSize: number) {
    const dataStr = `resize\r${channel}\r${newSize}`
    messenger.send(BasicMessageChannel.CHANNEL_BUFFERS_CHANNEL, StringUtils.stringToArrayBuffer(dataStr));
  }
}