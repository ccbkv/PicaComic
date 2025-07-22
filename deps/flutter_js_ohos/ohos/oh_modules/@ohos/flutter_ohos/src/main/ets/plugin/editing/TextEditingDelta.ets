/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on TextEditingDelta.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

import Log from '../../util/Log';

export class TextEditingDelta {
  private static TAG = "TextEditingDelta";
  private oldText: string = "";
  private deltaText: string = "";
  private deltaStart: number = 0;
  private deltaEnd: number = 0;
  private newSelectionStart: number;
  private newSelectionEnd: number;
  private newComposingStart: number;
  private newComposingEnd: number;

  constructor(oldEditable: string,
    selectionStart: number,
    selectionEnd: number,
    composingStart: number,
    composingEnd: number,
    replacementDestinationStart?: number,
    replacementDestinationEnd?: number,
    replacementSource?: string) {
    this.newSelectionStart = selectionStart;
    this.newSelectionEnd = selectionEnd;
    this.newComposingStart = composingStart;
    this.newComposingEnd = composingEnd;
    if (replacementDestinationStart === undefined ||
      replacementDestinationEnd === undefined ||
      replacementSource === undefined) {
      this.setDeltas(oldEditable, "", -1, -1);
    } else {
      this.setDeltas(
        oldEditable,
        replacementSource,
        replacementDestinationStart,
        replacementDestinationEnd);
    }
  }

  setDeltas(oldText: string, newText: string, newStart: number, newExtent: number): void {
    this.oldText = oldText;
    this.deltaText = newText;
    this.deltaStart = newStart;
    this.deltaEnd = newExtent;
  }

  toJSON(): TextEditingDeltaJson {
    let state: TextEditingDeltaJson = {
      oldText: this.oldText.toString(),
      deltaText: this.deltaText.toString(),
      deltaStart: this.deltaStart,
      deltaEnd: this.deltaEnd,
      selectionBase: this.newSelectionStart,
      selectionExtent: this.newSelectionEnd,
      composingBase: this.newComposingStart,
      composingExtent: this.newComposingEnd,
    };
    return state;
  }
}

export interface TextEditingDeltaJson {
  oldText: string;
  deltaText: string;
  deltaStart: number;
  deltaEnd: number;
  selectionBase: number;
  selectionExtent: number;
  composingBase: number;
  composingExtent: number;
}
