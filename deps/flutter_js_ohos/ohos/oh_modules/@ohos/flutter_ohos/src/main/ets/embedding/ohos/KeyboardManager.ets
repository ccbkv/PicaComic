/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on KeyboardManager.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/
import TextInputPlugin from '../../plugin/editing/TextInputPlugin';
import FlutterEngine from '../engine/FlutterEngine';
import KeyEventChannel, { FlutterKeyEvent } from '../engine/systemchannels/KeyEventChannel';
import KeyboardChannel from '../engine/systemchannels/KeyboardChannel';
import KeyEmbedderResponder from './KeyEmbedderResponder';
import { BinaryMessenger } from '../../plugin/common/BinaryMessenger';
import { KeyEventHandler } from './KeyEventHandler';
import HashSet from '@ohos.util.HashSet';
import { KeyCode } from '@kit.InputKit';

export default class KeyboardManager {
  private keyEventChannel: KeyEventChannel | null = null;
  private keyboardChannel: KeyboardChannel | null = null;
  protected keyEmbedderResponder: KeyEmbedderResponder;
  private keyEventHandler: KeyEventHandler;

  constructor(engine: FlutterEngine, textInputPlugin: TextInputPlugin) {
    this.keyEventChannel = new KeyEventChannel(engine.dartExecutor);
    this.keyboardChannel = new KeyboardChannel(engine.dartExecutor);
    this.keyboardChannel.setKeyboardMethodHandler(this);
    this.keyEmbedderResponder = new KeyEmbedderResponder(engine.dartExecutor);
    this.keyEventHandler = new KeyEventHandler(textInputPlugin);
  }

  onKeyPreIme(event: KeyEvent) : boolean {
    return false;
  }

  onKeyEvent(event: KeyEvent) : boolean {
    this.keyEmbedderResponder.handleKeyEvent(event);

    this.keyEventChannel?.sendFlutterKeyEvent(new FlutterKeyEvent(event), event.type == KeyType.Up, {
      onFrameworkResponse: (isEventHandled: boolean): void => {
      }
    })
    this.keyEventHandler.handleKeyEvent(event);
    return false;
  }

  public getKeyboardState(): Map<number, number> {
    return this.keyEmbedderResponder.getPressedKeys();
  }
}

export interface Responder {
  handleKeyEvent(keyEvent: KeyEvent): void;
}