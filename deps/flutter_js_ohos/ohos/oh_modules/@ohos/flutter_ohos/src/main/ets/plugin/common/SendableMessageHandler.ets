/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/
import { lang } from '@kit.ArkTS';
import { Reply } from './BasicMessageChannel';

type ISendable = lang.ISendable;

export default interface SendableMessageHandler<T> extends ISendable {
  onMessage(message: T, reply: Reply<T>): void;
}
