/*
 * Copyright (c) 2021-2025 Huawei Device Co., Ltd. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE_HW file.
 */

import { BinaryMessenger, BinaryReply } from '../../plugin/common/BinaryMessenger';
import KeyData, { Type, DeviceType } from './KeyData';
import { Responder } from './KeyboardManager';
import KeyboardMap, { KeyPair, ModifierGoal } from './KeyboardMap';
import Log from '../../util/Log';

class EventTaskRunner {
  private tasks: Array<() => void> = [];

  constructor() {
  }

  public addTask(task: () => void): void {
    this.tasks.push(task);
  }

  public runTasks(): void {
    this.tasks.forEach(task => task());
  }
}

export default class KeyEmbedderResponder implements Responder {
  private static TAG = "KeyEmbedderResponder";
  private messenger: BinaryMessenger;
  private pressingRecords: Map<number, number> = new Map<number, number>();

  constructor(binaryMessenger: BinaryMessenger) {
    this.messenger = binaryMessenger;
  }

  private keyOfPlane(key: number, plane: number): number {
    return plane | (key & KeyboardMap.kValueMask);
  }

  private getEventType(event: KeyEvent): Type {
    let physicalKey: number = this.getPhysicalKey(event);
    let isPressed: boolean = this.pressingRecords.has(physicalKey);
    switch (event.type) {
      case KeyType.Down:
        return isPressed ? Type.KREPEAT : Type.KDOWN;
        break;
      case KeyType.Up:
        return Type.KUP;
        break;
      default:
        throw new Error("getEventType: Unexpected event type");
    }
  }

  private getLogicalKey(event: KeyEvent): number {
    let keyCode: number = event.keyCode;
    let logicalKey: number | undefined = KeyboardMap.toLogicalKey.get(keyCode);
    if (logicalKey !== undefined) {
      return logicalKey;
    }
    return this.keyOfPlane(keyCode, KeyboardMap.kOhosPlane);
  }

  /** Should use ScanCode here, but cannot access it from KeyEvent yet.
   * Use KeyCode instead and need correct it in the future.
   */
  private getPhysicalKey(event: KeyEvent): number {
    let keyCode: number = event.keyCode;
    let physicalKey: number | undefined = KeyboardMap.toPhysicalKey.get(keyCode);
    if (physicalKey !== undefined) {
      return physicalKey;
    }
    return this.keyOfPlane(keyCode, KeyboardMap.kOhosPlane);
  }

  updatePressingKeys(physicalKey: number, logicalKey: number | null): void {
    if (logicalKey != null) { // press
      if (this.pressingRecords.has(physicalKey)) {
        Log.e(KeyEmbedderResponder.TAG, "updatePressingKeys adding nonempty key");
      }
      this.pressingRecords.set(physicalKey, logicalKey);
    } else { // release
      if (!this.pressingRecords.has(physicalKey)) {
        Log.e(KeyEmbedderResponder.TAG, "updatePressingKeys deleting empty key");
      }
      this.pressingRecords.delete(physicalKey);
    }
  }

  synchronizeModifierKey(goal: ModifierGoal,
    truePressed: boolean,
    logicalKey: number,
    physicalKey: number,
    event: KeyEvent,
    postSyncEvents: EventTaskRunner) {
    let nowStates: boolean[] = new Array(goal.keys.length);
    let expectedPreStates: boolean[] = new Array(goal.keys.length);
    let postAnyPressed: boolean = false;

    for (let keyIdx = 0; keyIdx < goal.keys.length; keyIdx += 1) {
      let key: KeyPair = goal.keys[keyIdx];
      nowStates[keyIdx] = this.pressingRecords.has(key.physicalKey);
      if (key.logicalKey == logicalKey) {
        switch (this.getEventType(event)) {
          case Type.KDOWN:
            expectedPreStates[keyIdx] = false;
            postAnyPressed = true;
            if (!truePressed) {
              postSyncEvents.addTask(() => {
                this.synthesizeEvent(false, event.timestamp, logicalKey, physicalKey);
              });
            }
            break;
          case Type.KUP:
            expectedPreStates[keyIdx] = nowStates[keyIdx];
            break;
          case Type.KREPEAT:
            expectedPreStates[keyIdx] = nowStates[keyIdx];
            postAnyPressed = true;
            if (!truePressed) {
              postSyncEvents.addTask(() => {
                this.synthesizeEvent(false, event.timestamp, logicalKey, physicalKey);
              });
            }
            break;
        }
      } else {
        postAnyPressed = postAnyPressed || nowStates[keyIdx];
      }
    }

    if (truePressed) {
      for (let keyIdx = 0; keyIdx < goal.keys.length; keyIdx += 1) {
        if (expectedPreStates[keyIdx] !== undefined) {
          continue;
        }
        if (postAnyPressed) {
          expectedPreStates[keyIdx] = nowStates[keyIdx];
        } else {
          expectedPreStates[keyIdx] = true;
          postAnyPressed = true;
        }
      }
      if (!postAnyPressed) {
        expectedPreStates[0] = true;
      }
    } else {
      for (let keyIdx = 0; keyIdx < goal.keys.length; keyIdx += 1) {
        if (expectedPreStates[keyIdx] !== undefined) {
          continue;
        }
        expectedPreStates[keyIdx] = false;
      }
    }

    for (let keyIdx = 0; keyIdx < goal.keys.length; keyIdx += 1) {
      if (expectedPreStates[keyIdx] != nowStates[keyIdx]) {
        let key: KeyPair = goal.keys[keyIdx];
        this.synthesizeEvent(expectedPreStates[keyIdx], event.timestamp,
          key.logicalKey, key.physicalKey);
      }
    }
  }

  synthesizeEvent(isDown: boolean, timestamp: number,
    logicalKey: number, physicalKey: number) {
    const data: KeyData = new KeyData();
    data.timestamp = timestamp;
    data.type = isDown ? Type.KDOWN : Type.KUP;
    data.logicalKey = logicalKey;
    data.physicalKey = physicalKey;
    data.character = null;
    data.isSynthesized = true;
    data.deviceType = DeviceType.KKEYBOARD;
    if (physicalKey != 0 && logicalKey != 0) {
      this.updatePressingKeys(physicalKey, isDown ? logicalKey : null);
    }

    this.sendKeyEvent(data);
  }

  sendKeyEvent(data: KeyData) {
    this.messenger.send(KeyData.CHANNEL, data.toBytes());
  }

  handleKeyEvent(event: KeyEvent): boolean {
    if (event.keyCode == 0) {
      return false;
    }

    let physicalKey: number = this.getPhysicalKey(event);
    let logicalKey: number = this.getLogicalKey(event);

    let postSyncEvents: EventTaskRunner = new EventTaskRunner();

    for (let goalIdx = 0; goalIdx < KeyboardMap.modifierGoals.length; goalIdx += 1) {
      let goal: ModifierGoal = KeyboardMap.modifierGoals[goalIdx];
      if (event.getModifierKeyState != undefined) {
        this.synchronizeModifierKey(
          goal,
          event.getModifierKeyState([goal.name]),
          logicalKey,
          physicalKey,
          event,
          postSyncEvents
        );
      }
    }

    let isDownEvent: boolean;
    switch (event.type) {
      case KeyType.Down:
        isDownEvent = true;
        break;
      case KeyType.Up:
        isDownEvent = false;
        break;
      default:
        isDownEvent = false;
    }

    let type: Type;
    let lastLogicalKey: number | undefined = this.pressingRecords.get(physicalKey);
    if (isDownEvent) {
      if (lastLogicalKey === undefined) {
        type = Type.KDOWN;
      } else {
        /* Nothing about repeat found in KeyEvent, so if isDownEvent and the key is
          * currently pressed, take this event as a KREPEAT one.
        */
        type = Type.KREPEAT;
      }
    } else {
      if (lastLogicalKey === undefined) {
        /* Ignore abrupt up events */
        return false;
      } else {
        type = Type.KUP;
      }
    }

    if (type != Type.KREPEAT) {
      this.updatePressingKeys(physicalKey, isDownEvent ? logicalKey : null);
    }

    const data: KeyData = new KeyData();
    data.timestamp = event.timestamp;
    data.type = type;
    data.physicalKey = physicalKey;
    data.logicalKey = logicalKey;
    data.character = null;
    data.isSynthesized = false;
    // no deviceType found in KeyEvent
    data.deviceType = DeviceType.KKEYBOARD;
    this.sendKeyEvent(data);

    postSyncEvents.runTasks();
    return true;
  }

  public getPressedKeys(): Map<number, number> {
    return new Map<number, number>(this.pressingRecords);
  }
}