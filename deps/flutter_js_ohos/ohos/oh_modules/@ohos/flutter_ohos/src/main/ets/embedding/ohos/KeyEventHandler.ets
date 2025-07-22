/*
 * Copyright (c) 2021-2024 Huawei Device Co., Ltd. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE_HW file.
 */

import { HashMap } from '@kit.ArkTS';
import deviceInfo from '@ohos.deviceInfo';
import TextInputPlugin from '../../plugin/editing/TextInputPlugin';
import Log from '../../util/Log';
import { KeyCode } from '@kit.InputKit';

const TAG = "KeyEventHandler";

class KeyText {
  public normalCase: string;
  public shiftCase: string;

  constructor(normalCase: string, shiftCase: string) {
    this.normalCase = normalCase;
    this.shiftCase = shiftCase;
  }
};

/*
 * In the emulator/hdc tool input scenario, all keyevents will be passed to the onKeyEvent callback, so we need
 * insert the text to textInputPlugin ourselves. In the other scenarios like phone/pc/ets, the input method will be
 * responsible for inserting the text to textInputPlugin, consuming 'down' events and let 'up' events go which will
 * be captured by onKeyEvent.
 * There is no need to process the status of the capslock button. Because in the scenario of the emulator/hdc tool,
 * if capslock is pressed, os will send a 'shift' keyevent before the keyevent of the input key and we will insert
 * uppercase characters correctly.
 */
export class KeyEventHandler {
  // 组合键
  private static combinationKeys: Set<KeyCode> = new Set<KeyCode>([
    KeyCode.KEYCODE_CTRL_LEFT,
    KeyCode.KEYCODE_CTRL_RIGHT,
    KeyCode.KEYCODE_ALT_LEFT,
    KeyCode.KEYCODE_ALT_RIGHT,
  ]);
  private static shiftKeys: Set<KeyCode> = new Set<KeyCode>([
    KeyCode.KEYCODE_SHIFT_LEFT,
    KeyCode.KEYCODE_SHIFT_RIGHT,
  ]);
  private static keyTextMap: Map<KeyCode, KeyText> = new Map([
    [KeyCode.KEYCODE_0, new KeyText('0', ')')],
    [KeyCode.KEYCODE_1, new KeyText('1', '!')],
    [KeyCode.KEYCODE_2, new KeyText('2', '@')],
    [KeyCode.KEYCODE_3, new KeyText('3', '#')],
    [KeyCode.KEYCODE_4, new KeyText('4', '$')],
    [KeyCode.KEYCODE_5, new KeyText('5', '%')],
    [KeyCode.KEYCODE_6, new KeyText('6', '^')],
    [KeyCode.KEYCODE_7, new KeyText('7', '&')],
    [KeyCode.KEYCODE_8, new KeyText('8', '*')],
    [KeyCode.KEYCODE_9, new KeyText('9', '(')],

    [KeyCode.KEYCODE_A, new KeyText('a', 'A')],
    [KeyCode.KEYCODE_B, new KeyText('b', 'B')],
    [KeyCode.KEYCODE_C, new KeyText('c', 'C')],
    [KeyCode.KEYCODE_D, new KeyText('d', 'D')],
    [KeyCode.KEYCODE_E, new KeyText('e', 'E')],
    [KeyCode.KEYCODE_F, new KeyText('f', 'F')],
    [KeyCode.KEYCODE_G, new KeyText('g', 'G')],
    [KeyCode.KEYCODE_H, new KeyText('h', 'H')],
    [KeyCode.KEYCODE_I, new KeyText('i', 'I')],
    [KeyCode.KEYCODE_J, new KeyText('j', 'J')],
    [KeyCode.KEYCODE_K, new KeyText('k', 'K')],
    [KeyCode.KEYCODE_L, new KeyText('l', 'L')],
    [KeyCode.KEYCODE_M, new KeyText('m', 'M')],
    [KeyCode.KEYCODE_N, new KeyText('n', 'N')],
    [KeyCode.KEYCODE_O, new KeyText('o', 'O')],
    [KeyCode.KEYCODE_P, new KeyText('p', 'P')],
    [KeyCode.KEYCODE_Q, new KeyText('q', 'Q')],
    [KeyCode.KEYCODE_R, new KeyText('r', 'R')],
    [KeyCode.KEYCODE_S, new KeyText('s', 'S')],
    [KeyCode.KEYCODE_T, new KeyText('t', 'T')],
    [KeyCode.KEYCODE_U, new KeyText('u', 'U')],
    [KeyCode.KEYCODE_V, new KeyText('v', 'V')],
    [KeyCode.KEYCODE_W, new KeyText('w', 'W')],
    [KeyCode.KEYCODE_X, new KeyText('x', 'X')],
    [KeyCode.KEYCODE_Y, new KeyText('y', 'Y')],
    [KeyCode.KEYCODE_Z, new KeyText('z', 'Z')],

    [KeyCode.KEYCODE_GRAVE, new KeyText('`', '~')],
    [KeyCode.KEYCODE_MINUS, new KeyText('-', '_')],
    [KeyCode.KEYCODE_EQUALS, new KeyText('=', '+')],
    [KeyCode.KEYCODE_LEFT_BRACKET, new KeyText('[', '{')],
    [KeyCode.KEYCODE_RIGHT_BRACKET, new KeyText(']', '}')],
    [KeyCode.KEYCODE_BACKSLASH, new KeyText('\\', '|')],
    [KeyCode.KEYCODE_SEMICOLON, new KeyText(';', ':')],
    [KeyCode.KEYCODE_APOSTROPHE, new KeyText('\'', '"')],
    [KeyCode.KEYCODE_COMMA, new KeyText(',', '<')],
    [KeyCode.KEYCODE_PERIOD, new KeyText('.', '>')],
    [KeyCode.KEYCODE_SLASH, new KeyText('/', '?')],
    [KeyCode.KEYCODE_SPACE, new KeyText(' ', ' ')],

    [KeyCode.KEYCODE_NUMPAD_0, new KeyText('0', '')],
    [KeyCode.KEYCODE_NUMPAD_1, new KeyText('1', '')],
    [KeyCode.KEYCODE_NUMPAD_2, new KeyText('2', '')],
    [KeyCode.KEYCODE_NUMPAD_3, new KeyText('3', '')],
    [KeyCode.KEYCODE_NUMPAD_4, new KeyText('4', '')],
    [KeyCode.KEYCODE_NUMPAD_5, new KeyText('5', '')],
    [KeyCode.KEYCODE_NUMPAD_6, new KeyText('6', '')],
    [KeyCode.KEYCODE_NUMPAD_7, new KeyText('7', '')],
    [KeyCode.KEYCODE_NUMPAD_8, new KeyText('8', '')],
    [KeyCode.KEYCODE_NUMPAD_9, new KeyText('9', '')],
  ]);

  private textInputPlugin?: TextInputPlugin;
  private isShiftMode: boolean = false;
  private isCombinationMode: boolean = false;

  constructor(textInputPlugin?: TextInputPlugin) {
    this.textInputPlugin = textInputPlugin;
  }

  getKeyText(event: KeyEvent) : string {
    let keyText = KeyEventHandler.keyTextMap.get(event.keyCode);
    if (keyText != undefined) {
      return this.isShiftMode ? keyText.shiftCase : keyText.normalCase;
    }
    return '';
  }

  startDeleting(code: number) {
    this.textInputPlugin?.getEditingState().startDeleting(code);
  }

  endDeletion(code: number) {
    this.textInputPlugin?.getEditingState().endDeletion(code);
  }

  handleKeyEvent(event: KeyEvent) {
    Log.i(TAG, JSON.stringify({
      "name": "handleKeyEvent",
      "event": event
    }));
    if (event.type == KeyType.Down) {
      if (KeyEventHandler.combinationKeys.has(event.keyCode)) {
        this.isCombinationMode = true;
      } else if (KeyEventHandler.shiftKeys.has(event.keyCode)) {
        this.isShiftMode = true;
      } else {
        // Ctrl/Alt 键按下状态或数据为空时，不输入字符（字母/数字/符号）
        if (!this.isCombinationMode && this.getKeyText(event)) {
          this.textInputPlugin?.getEditingState().handleInsertTextEvent(this.getKeyText(event));
        }
      }
    } else if (event.type == KeyType.Up) {
      if (KeyEventHandler.combinationKeys.has(event.keyCode)) {
        this.isCombinationMode = false;
      } else if (KeyEventHandler.shiftKeys.has(event.keyCode)) {
        this.isShiftMode = false;
      }
    }
  }
}
