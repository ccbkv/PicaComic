/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on ListenableEditingState.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

import { TextEditState } from '../../embedding/engine/systemchannels/TextInputChannel';
import Log from '../../util/Log';
import inputMethod from '@ohos.inputMethod';
import ArrayList from '@ohos.util.ArrayList';
import { TextEditingDelta } from './TextEditingDelta';
import TextInputChannel from '../../embedding/engine/systemchannels/TextInputChannel';
import { FlutterTextUtils } from './TextUtils';
import { KeyCode } from '@kit.InputKit';

const TAG = "ListenableEditingState";

enum DeleteStates {
  START,
  MOVING,
  END
}

export class ListenableEditingState {
  private TextInputChannel: TextInputChannel | null = null;
  private client: number = 0
  private leftDeleteState: DeleteStates = DeleteStates.END
  private rightDeleteState: DeleteStates = DeleteStates.END
  //Cache used to storage software keyboard input action
  private mStringCache: string;
  private mSelectionStartCache: number = 0;
  private mSelectionEndCache: number = 0;
  private mComposingStartCache: number = 0;
  private mComposingEndCache: number = 0;
  //used to compare with Cache

  private mListeners: ArrayList<EditingStateWatcher> = new ArrayList<EditingStateWatcher>();
  private mPendingListeners: ArrayList<EditingStateWatcher> = new ArrayList<EditingStateWatcher>();
  private mBatchTextEditingDeltas: ArrayList<TextEditingDelta> = new ArrayList<TextEditingDelta>();
  private mChangeNotificationDepth: number = 0;
  private mBatchEditNestDepth: number = 0;
  private mTextWhenBeginBatchEdit: string;
  private mSelectionStartWhenBeginBatchEdit: number = 0;
  private mSelectionEndWhenBeginBatchEdit: number = 0;
  private mComposingStartWhenBeginBatchEdit: number = 0;
  private mComposingEndWhenBeginBatchEdit: number = 0;

  constructor(TextInputChannel: TextInputChannel | null, client: number) {
    this.TextInputChannel = TextInputChannel;
    this.client = client
    this.mStringCache = "";
    this.mTextWhenBeginBatchEdit = "";
    this.mSelectionStartCache = 0;
    this.mSelectionEndCache = 0;
    this.mComposingStartCache = -1;
    this.mComposingEndCache = -1;
  }

  extractBatchTextEditingDeltas(): ArrayList<TextEditingDelta> {
    let currentBatchDeltas = new ArrayList<TextEditingDelta>();
    this.mBatchTextEditingDeltas.forEach((data) => {
      currentBatchDeltas.add(data);
    })
    this.mBatchTextEditingDeltas.clear();
    return currentBatchDeltas;
  }

  clearBatchDeltas(): void {
    this.mBatchTextEditingDeltas.clear();
  }

  replace(start: number, end: number, tb: String, tbStart: number, tbEnd: number): void {
    const placeIndex =
      this.mSelectionStartCache < this.mSelectionEndCache ? this.mSelectionStartCache : this.mSelectionEndCache;

    this.mBatchTextEditingDeltas.add(
      new TextEditingDelta(
        this.mStringCache.toString(),
        placeIndex + tbEnd,
        placeIndex + tbEnd,
        this.getComposingStart(),
        this.getComposingEnd(),
        start,
        end + tbStart,
        tb.toString()
      ));
  }

  getSelectionStart(): number {
    return this.mSelectionStartCache;
  }

  getSelectionEnd(): number {
    return this.mSelectionEndCache;
  }

  getComposingStart(): number {
    return this.mComposingStartCache;
  }

  getComposingEnd(): number {
    return this.mComposingEndCache;
  }

  getStringCache(): string {
    return this.mStringCache;
  }

  getSelectionString(): string {
    if (this.mSelectionStartCache < 0 || this.mSelectionEndCache > this.mStringCache.length) {
      return "";
    }
    return this.mStringCache.substring(this.mSelectionStartCache, this.mSelectionEndCache);
  }

  setSelectionStart(newSelectionStart: number): void {
    this.mSelectionStartCache = newSelectionStart;
  }

  setSelectionEnd(newSelectionEnd: number): void {
    this.mSelectionEndCache = newSelectionEnd;
  }

  setComposingStart(newComposingStart: number): void {
    this.mComposingStartCache = newComposingStart;
  }

  setComposingEnd(newComposingEnd: number): void {
    this.mComposingEndCache = newComposingEnd;
  }

  setStringCache(newStringCache: string): void {
    this.mStringCache = newStringCache;
  }

  notifyListener(listener: EditingStateWatcher,
    textChanged: boolean,
    selectionChanged: boolean,
    composingChanged: boolean): void {
    this.mChangeNotificationDepth++;
    listener.didChangeEditingState(textChanged, selectionChanged, composingChanged);
    this.mChangeNotificationDepth--;
  }

  notifyListenersIfNeeded(textChanged: boolean, selectionChanged: boolean, composingChanged: boolean) {
    if (textChanged || selectionChanged || composingChanged) {
      for (const listener of this.mListeners) {
        this.notifyListener(listener, textChanged, selectionChanged, composingChanged);
      }
    }
  }

  handleInsertTextEvent(text: string): void {
    let start =
      this.mSelectionStartCache < this.mSelectionEndCache ? this.mSelectionStartCache : this.mSelectionEndCache;
    let end = this.mSelectionStartCache > this.mSelectionEndCache ? this.mSelectionStartCache : this.mSelectionEndCache;
    const length = text.length;
    this.replace(start, end, text, 0, length);

    if (this.mStringCache.length == this.mSelectionStartCache) {
      //Insert text one by one
      let tempStr: string = this.mStringCache.substring(0, start) + text + this.mStringCache.substring(end);
      this.mStringCache = tempStr;
      this.setSelectionStart(this.mStringCache.length);
      this.setSelectionEnd(this.mStringCache.length);
    } else if (this.mStringCache.length > this.mSelectionStartCache) {
      //Insert text in the middle of string
      let tempStr: string = this.mStringCache.substring(0, start) + text + this.mStringCache.substring(end);
      this.mStringCache = tempStr;
      this.mSelectionStartCache = start + text.length;
      this.mSelectionEndCache = this.mSelectionStartCache;
    }
    if (this.mListeners == null) {
      Log.e(TAG, "mListeners is null");
      return;
    }
    this.notifyListenersIfNeeded(true, true, false);
  }

  updateTextInputState(state: TextEditState): void {
    if (this.leftDeleteState === DeleteStates.START) {
      this.leftDeleteState = DeleteStates.MOVING;
    }
    if (this.rightDeleteState === DeleteStates.START) {
      this.rightDeleteState = DeleteStates.MOVING;
    }
    this.beginBatchEdit();
    this.setStringCache(state.text);
    if (state.hasSelection()) {
      this.setSelectionStart(state.selectionStart);
      this.setSelectionEnd(state.selectionEnd);
    } else {
      this.setSelectionStart(0);
      this.setSelectionEnd(0);
    }
    this.endBatchEdit();
  }

  beginBatchEdit(): void {
    this.mBatchEditNestDepth++;
    if (this.mChangeNotificationDepth > 0) {
      Log.e(TAG, "editing state should not be changed in a listener callback");
    }
    if (this.mBatchEditNestDepth == 1 && !this.mListeners.isEmpty()) {
      this.mTextWhenBeginBatchEdit = this.getStringCache();
      this.mSelectionStartWhenBeginBatchEdit = this.getSelectionStart();
      this.mSelectionEndWhenBeginBatchEdit = this.getSelectionEnd();
      this.mComposingStartWhenBeginBatchEdit = this.getComposingStart();
      this.mComposingEndWhenBeginBatchEdit = this.getComposingEnd();
    }
  }

  endBatchEdit(): void {
    if (this.mBatchEditNestDepth == 0) {
      Log.e(TAG, "endBatchEdit called without a matching beginBatchEdit");
      return;
    }
    if (this.mBatchEditNestDepth == 1) {
      Log.d(TAG, "mBatchEditNestDepth == 1");
      for (const listener of this.mPendingListeners) {
        this.notifyListener(listener, true, true, true);
      }

      if (!this.mListeners.isEmpty()) {
        Log.d(TAG, "didFinishBatchEdit with " + this.mListeners.length + " listener(s)");
        const textChanged = !(this.mStringCache == this.mTextWhenBeginBatchEdit);
        const selectionChanged = this.mSelectionStartWhenBeginBatchEdit != this.getSelectionStart()
          || this.mSelectionEndWhenBeginBatchEdit != this.getSelectionEnd();
        const composingRegionChanged = this.mComposingStartWhenBeginBatchEdit != this.getComposingStart()
          || this.mComposingEndWhenBeginBatchEdit != this.getComposingEnd();
        Log.d(TAG, "textChanged: " + textChanged + " selectionChanged: " + selectionChanged +
          " composingRegionChanged: " + composingRegionChanged);
        this.notifyListenersIfNeeded(textChanged, selectionChanged, composingRegionChanged);
      }
    }
    for (const listener of this.mPendingListeners) {
      this.mListeners.add(listener);
    }
    this.mPendingListeners.clear();
    this.mBatchEditNestDepth--;
  }

  addEditingStateListener(listener: EditingStateWatcher): void {
    if (this.mChangeNotificationDepth > 0) {
      Log.e(TAG, "adding a listener " + JSON.stringify(listener) + " in a listener callback");
    }
    if (this.mBatchEditNestDepth > 0) {
      Log.d(TAG, "a listener was added to EditingState while a batch edit was in progress");
      this.mPendingListeners.add(listener);
    } else {
      this.mListeners.add(listener);
    }
  }

  removeEditingStateListener(listener: EditingStateWatcher): void {
    if (this.mChangeNotificationDepth > 0) {
      Log.e(TAG, "removing a listener " + JSON.stringify(listener) + " in a listener callback");
    }
    this.mListeners.remove(listener);
    if (this.mBatchEditNestDepth > 0) {
      this.mPendingListeners.remove(listener);
    }
  }

  startDeleting(code: number) {
    if (code === KeyCode.KEYCODE_FORWARD_DEL) {
      this.rightDeleteState = DeleteStates.START
    } else {
      this.leftDeleteState = DeleteStates.START
    }
  }

  endDeletion(code: number) {
    if (code === KeyCode.KEYCODE_FORWARD_DEL) {
      this.rightDeleteState = DeleteStates.END
    } else {
      this.leftDeleteState = DeleteStates.END
    }
  }

  handleDeleteEvent(leftOrRight: boolean, length: number): void {
    if (length === 0) {
      return;
    }

    let start =
      this.mSelectionStartCache < this.mSelectionEndCache ? this.mSelectionStartCache : this.mSelectionEndCache;
    let end = this.mSelectionStartCache > this.mSelectionEndCache ? this.mSelectionStartCache : this.mSelectionEndCache;

    if (leftOrRight == false && this.leftDeleteState !== DeleteStates.MOVING) {
      //delete left
      if (start == 0 && end == 0) {
        return;
      }

      let unicodeStart = start;
      if (start == end) {
        for (let i = 0; i < length; i++) {
          unicodeStart = FlutterTextUtils.getOffsetBefore(this.mStringCache, unicodeStart);
          if (unicodeStart === 0) {
            break;
          }
        }
      }
      this.replace(unicodeStart, end, "", 0, 0);
      this.mSelectionStartCache = unicodeStart;
      let tempStr: string = this.mStringCache.slice(0, unicodeStart) + this.mStringCache.slice(end);
      this.mStringCache = tempStr;
      this.mSelectionEndCache = this.mSelectionStartCache;
    } else if (leftOrRight == true && this.rightDeleteState !== DeleteStates.MOVING) {
      //delete right
      if (start == this.mStringCache.length) {
        return;
      }
      let unicodeEnd = end;
      if (start == end) {
        for (let i = 0; i < length; i++) {
          unicodeEnd = FlutterTextUtils.getOffsetAfter(this.mStringCache, unicodeEnd);
          if (unicodeEnd === this.mStringCache.length) {
            break;
          }
        }
      }
      this.replace(start, unicodeEnd, "", 0, 0);
      this.mSelectionEndCache = start;
      let tempStr: string = this.mStringCache.slice(0, start) +
        (unicodeEnd >= this.mStringCache.length ? "" : this.mStringCache.slice(unicodeEnd));
      this.mStringCache = tempStr;
      this.mSelectionStartCache = this.mSelectionEndCache;
    }
    this.notifyListenersIfNeeded(true, true, false);
  }

  handleNewlineEvent(): void {
    // 获取光标所在位置;
    // 当光标移动前位置小于移动后的位置时，获取光标移动前位置;反之获取移动后位置
    let start =
      this.mSelectionStartCache < this.mSelectionEndCache ? this.mSelectionStartCache : this.mSelectionEndCache;
    // 当光标移动前位置大于移动后的位置时，获取光标移动前位置;反之获取移动后位置
    let end = this.mSelectionStartCache > this.mSelectionEndCache ? this.mSelectionStartCache : this.mSelectionEndCache;

    // 对光标位置和字符串长度进行对比，决定光标位置的计算方法
    if (this.mStringCache.length == this.mSelectionStartCache) {
      //Insert newline one by one
      let tempStr: string = this.mStringCache.substring(0, start) + '\n' + this.mStringCache.substring(end);
      this.mStringCache = tempStr;
      this.setSelectionStart(this.mStringCache.length);
      this.setSelectionEnd(this.mStringCache.length);
    } else if (this.mStringCache.length > this.mSelectionStartCache) {
      //Insert newline in the middle of string
      let tempStr: string = this.mStringCache.substring(0, start) + '\n' + this.mStringCache.substring(end);
      this.mStringCache = tempStr;
      this.mSelectionStartCache = start + 1;
      this.mSelectionEndCache = this.mSelectionStartCache;
    }
    if (this.mListeners == null) {
      Log.e(TAG, "mListeners is null");
      return;
    }
    this.notifyListenersIfNeeded(true, true, false);
  }

  handleFunctionKey(functionKey: inputMethod.FunctionKey): void {
    if (!this.TextInputChannel) {
      return
    }
    switch (functionKey.enterKeyType) {
      case inputMethod.EnterKeyType.PREVIOUS:
        this.TextInputChannel.previous(this.client);
        break;
      case inputMethod.EnterKeyType.UNSPECIFIED:
        this.TextInputChannel.unspecifiedAction(this.client);
        break;
      case inputMethod.EnterKeyType.NONE:
        this.TextInputChannel.newline(this.client);
        break;
      case inputMethod.EnterKeyType.GO:
        this.TextInputChannel.go(this.client);
        break;
      case inputMethod.EnterKeyType.SEARCH:
        this.TextInputChannel.search(this.client);
        break;
      case inputMethod.EnterKeyType.SEND:
        this.TextInputChannel.send(this.client);
        break;
      case inputMethod.EnterKeyType.NEXT:
        this.TextInputChannel.next(this.client);
        break;
      case inputMethod.EnterKeyType.DONE:
        this.TextInputChannel.done(this.client);
        break;
    }
  }

  handleSelectByRange(range: inputMethod.Range): void {
    Log.d(TAG, "handleSelectByRange start: " + range.start + " end: " + range.end);
  }

  // only for move cursor Left after insert text like "()" "[]" ...
  handleMoveCursor(direction: inputMethod.Direction): void {
    Log.d(TAG, "handleMoveCursor direction: " + direction);
    if (direction === inputMethod.Direction.CURSOR_LEFT) {
      let start = this.getSelectionStart();
      let end = this.getSelectionEnd();
      if (start === end && start > 0) {
        this.setSelectionStart(start - 1);
        this.setSelectionEnd(end - 1);
        this.notifyListenersIfNeeded(false, true, false);
      }
    }
  }
}

export interface EditingStateWatcher {
  // Changing the editing state in a didChangeEditingState callback may cause unexpected
  // behavior.
  didChangeEditingState(textChanged: boolean, selectionChanged: boolean, composingRegionChanged: boolean): void;
}