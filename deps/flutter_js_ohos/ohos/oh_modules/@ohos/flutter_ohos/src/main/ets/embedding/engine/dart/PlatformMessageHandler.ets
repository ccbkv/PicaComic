/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on PlatformMessageHandler.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

export interface PlatformMessageHandler {

  handleMessageFromDart(channel: String, message: ArrayBuffer, replyId: number, messageData: number): void;

  handlePlatformMessageResponse(replyId: number, reply: ArrayBuffer): void;

}