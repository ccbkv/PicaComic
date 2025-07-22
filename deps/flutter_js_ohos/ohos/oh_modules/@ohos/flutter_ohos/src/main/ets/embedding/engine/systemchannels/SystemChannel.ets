/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on SystemChannel.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

import BasicMessageChannel from '../../../plugin/common/BasicMessageChannel';
import Any from '../../../plugin/common/Any';
import JSONMessageCodec from '../../../plugin/common/JSONMessageCodec';
import Log from '../../../util/Log';
import DartExecutor from '../dart/DartExecutor';

const TAG: string = "SystemChannel";

/**
 * fill in javadoc for SystemChannel.
 */
export default class SystemChannel {
  public channel: BasicMessageChannel<object>;

  constructor(dartExecutor: DartExecutor) {
    this.channel = new BasicMessageChannel<Any>(dartExecutor, "flutter/system", JSONMessageCodec.INSTANCE);
  }

  public sendMemoryPressureWarning(): void {
    Log.i(TAG, "Sending memory pressure warning to Flutter");
    let message: Map<string, string> = new Map().set("type", "memoryPressure");
    this.channel.send(message);
  }
}