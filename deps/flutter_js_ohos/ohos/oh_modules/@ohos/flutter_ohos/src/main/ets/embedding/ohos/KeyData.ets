/*
 * Copyright (c) 2021-2025 Huawei Device Co., Ltd. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE_HW file.
 */

import util from '@ohos.util'

export default class KeyData {
  private static TAG = "KeyData";
  public static CHANNEL = "flutter/keydata";
  // If this value changes, update the code in the following files:
  //
  //  * key_data.h (kKeyDataFieldCount)
  //  * platform_dispatcher.dart (_kKeyDataFieldCount)
  private static FIELD_COUNT: number = 6;
  private static BYTES_PER_FIELD: number = 8;
  public timestamp: number = 0;
  public type: Type = Type.KDOWN;
  public physicalKey: number = 0;
  public logicalKey: number = 0;
  public isSynthesized: boolean = false;
  public deviceType: DeviceType = DeviceType.KKEYBOARD;
  public character: string | null = null;

  constructor(buffer?: ArrayBuffer) {
    if (buffer !== undefined) {
      const view = new DataView(buffer);
      let offset = 0;

      const decoder = new util.TextDecoder("utf-8");
      const charSize = Number(view.getBigInt64(offset, true));
      offset += 8;

      this.timestamp = Number(view.getBigInt64(offset, true));
      offset += 8;

      this.type = Number(view.getBigInt64(offset, true)) as Type;
      offset += 8;

      this.physicalKey = Number(view.getBigInt64(offset, true));
      offset += 8;

      this.logicalKey = Number(view.getBigInt64(offset, true));
      offset += 8;

      this.isSynthesized = view.getBigInt64(offset, true) === BigInt(1);
      offset += 8;

      this.deviceType = Number(view.getBigInt64(offset, true)) as DeviceType;
      offset += 8;

      if (offset + charSize !== buffer.byteLength) {
        throw new Error("KeyData corruption: String length does not match remaining bytes in buffer");
      }

      if (charSize != 0) {
        const strBytes = new Uint8Array(buffer, offset, charSize);
        this.character = decoder.decode(strBytes);
      }
    }
  }

  public toBytes(): ArrayBuffer {
    const encoder = new util.TextEncoder("utf-8");
    const encodedCharBytes = this.character == null ? null : encoder.encode(this.character);
    const charSize = this.character == null ? 0 : this.character.length;

    const totalBytes = (KeyData.FIELD_COUNT + 1) * KeyData.BYTES_PER_FIELD + charSize;
    const buffer = new ArrayBuffer(totalBytes);
    const view = new DataView(buffer);
    let offset = 0;

    view.setBigInt64(offset, BigInt(charSize), true);
    offset += 8;

    view.setBigInt64(offset, BigInt(this.timestamp), true);
    offset += 8;

    view.setBigInt64(offset, BigInt(this.type), true);
    offset += 8;

    view.setBigInt64(offset, BigInt(this.physicalKey), true);
    offset += 8;

    view.setBigInt64(offset, BigInt(this.logicalKey), true);
    offset += 8;

    view.setBigInt64(offset, this.isSynthesized ? BigInt(1) : BigInt(0), true);
    offset += 8;

    view.setBigInt64(offset, BigInt(this.deviceType), true);
    offset += 8;

    if (encodedCharBytes != null) {
      new Uint8Array(buffer, offset, charSize).set(encodedCharBytes);
    }

    return buffer;
  }
}

export enum Type {
  KDOWN = 0,
  KUP,
  KREPEAT
}

export enum DeviceType {
  KKEYBOARD = 0,
  KDIRECTIONALPAD,
  KGAMEPAD,
  KJOYSTICK,
  KHDMI
}