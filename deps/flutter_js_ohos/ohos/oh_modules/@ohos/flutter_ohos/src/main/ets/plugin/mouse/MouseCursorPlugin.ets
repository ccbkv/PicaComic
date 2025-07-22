/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on MouseCursorPlugin.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

import MouseCursorChannel, { MouseCursorMethodHandler } from '../../embedding/engine/systemchannels/MouseCursorChannel';
import pointer from '@ohos.multimodalInput.pointer';
import HashMap from '@ohos.util.HashMap';
import Log from '../../util/Log';
import Any from '../common/Any';

const TAG: string = "MouseCursorPlugin";

export default class MouseCursorPlugin implements MouseCursorMethodHandler {
  private mouseCursorChannel: MouseCursorChannel;
  private systemCursorConstants: HashMap<string, pointer.PointerStyle> | null = null;
  private windowId: number;

  constructor(windowId: number, mouseCursorChannel: MouseCursorChannel) {
    this.windowId = windowId;
    this.mouseCursorChannel = mouseCursorChannel;
    this.mouseCursorChannel.setMethodHandler(this);
  }

  activateSystemCursor(kind: string): void {
    if (this.windowId < 0) {
      Log.w(TAG, "set point style failed windowId is invalid");
      return;
    }
    let pointStyle: pointer.PointerStyle = this.resolveSystemCursor(kind);
    try {
      pointer.setPointerStyle(this.windowId, pointStyle, (err: Any) => {
        Log.i(TAG, "set point style success kind : " + kind);
      })
    } catch (e) {
      Log.e(TAG, "set point style failed : " + kind + " " + JSON.stringify(e));
    }
  }

  /**
   * Return mouse cursor point style
   *
   * <p>This method guarantees to return a non-null object.
   *
   * @param kind mouse cursor type
   * @returns point style
   */
  private resolveSystemCursor(kind: string): pointer.PointerStyle {
    if (this.systemCursorConstants == null) {
      this.systemCursorConstants = new HashMap();
      this.systemCursorConstants.set("alias", pointer.PointerStyle.DEFAULT);
      this.systemCursorConstants.set("allScroll", pointer.PointerStyle.MOVE);
      this.systemCursorConstants.set("basic", pointer.PointerStyle.DEFAULT);
      this.systemCursorConstants.set("cell", pointer.PointerStyle.DEFAULT);
      this.systemCursorConstants.set("click", pointer.PointerStyle.HAND_POINTING);
      this.systemCursorConstants.set("contextMenu", pointer.PointerStyle.DEFAULT);
      this.systemCursorConstants.set("copy", pointer.PointerStyle.CURSOR_COPY);
      this.systemCursorConstants.set("forbidden", pointer.PointerStyle.CURSOR_FORBID);
      this.systemCursorConstants.set("grab", pointer.PointerStyle.HAND_OPEN);
      this.systemCursorConstants.set("grabbing", pointer.PointerStyle.HAND_GRABBING);
      this.systemCursorConstants.set("help", pointer.PointerStyle.HELP);
      this.systemCursorConstants.set("move", pointer.PointerStyle.MOVE);
      this.systemCursorConstants.set("none", pointer.PointerStyle.DEFAULT);
      this.systemCursorConstants.set("noDrop", pointer.PointerStyle.DEFAULT);
      this.systemCursorConstants.set("precise", pointer.PointerStyle.CROSS);
      this.systemCursorConstants.set("text", pointer.PointerStyle.TEXT_CURSOR);
      this.systemCursorConstants.set("resizeColum", pointer.PointerStyle.NORTH_SOUTH);
      this.systemCursorConstants.set("resizeDown", pointer.PointerStyle.SOUTH);
      this.systemCursorConstants.set("resizeDownLeft", pointer.PointerStyle.SOUTH_WEST);
      this.systemCursorConstants.set("resizeDownRight", pointer.PointerStyle.SOUTH_EAST);
      this.systemCursorConstants.set("resizeLeft", pointer.PointerStyle.WEST);
      this.systemCursorConstants.set("resizeLeftRight", pointer.PointerStyle.RESIZE_LEFT_RIGHT);
      this.systemCursorConstants.set("resizeRight", pointer.PointerStyle.EAST);
      this.systemCursorConstants.set("resizeRow", pointer.PointerStyle.WEST_EAST);
      this.systemCursorConstants.set("resizeUp", pointer.PointerStyle.NORTH);
      this.systemCursorConstants.set("resizeUpDown", pointer.PointerStyle.RESIZE_UP_DOWN);
      this.systemCursorConstants.set("resizeUpLeft", pointer.PointerStyle.NORTH_WEST);
      this.systemCursorConstants.set("resizeUpRight", pointer.PointerStyle.NORTH_EAST);
      this.systemCursorConstants.set("resizeUpLeftDownRight", pointer.PointerStyle.NORTH_WEST_SOUTH_EAST);
      this.systemCursorConstants.set("resizeUpRightDownLeft", pointer.PointerStyle.NORTH_EAST_SOUTH_WEST);
      this.systemCursorConstants.set("verticalText", pointer.PointerStyle.TEXT_CURSOR);
      this.systemCursorConstants.set("wait", pointer.PointerStyle.DEFAULT);
      this.systemCursorConstants.set("zoomIn", pointer.PointerStyle.ZOOM_IN);
      this.systemCursorConstants.set("zoomOut", pointer.PointerStyle.ZOOM_OUT);
      this.systemCursorConstants.set("middleBtnEast", pointer.PointerStyle.MIDDLE_BTN_EAST);
      this.systemCursorConstants.set("middleBtnWest", pointer.PointerStyle.MIDDLE_BTN_WEST);
      this.systemCursorConstants.set("middleBtnSouth", pointer.PointerStyle.MIDDLE_BTN_SOUTH);
      this.systemCursorConstants.set("middleBtnNorth", pointer.PointerStyle.MIDDLE_BTN_NORTH);
      this.systemCursorConstants.set("middleBtnNorthSouth", pointer.PointerStyle.MIDDLE_BTN_NORTH_SOUTH);
      this.systemCursorConstants.set("middleBtnNorthEast", pointer.PointerStyle.MIDDLE_BTN_NORTH_EAST);
      this.systemCursorConstants.set("middleBtnNorthWest", pointer.PointerStyle.MIDDLE_BTN_NORTH_WEST);
      this.systemCursorConstants.set("middleBtnSouthEast", pointer.PointerStyle.MIDDLE_BTN_SOUTH_EAST);
      this.systemCursorConstants.set("middleBtnSouthWest", pointer.PointerStyle.MIDDLE_BTN_SOUTH_WEST);
      this.systemCursorConstants.set("middleBtnNorthSouthWestEast",
        pointer.PointerStyle.MIDDLE_BTN_NORTH_SOUTH_WEST_EAST);
      this.systemCursorConstants.set("horizontalTextCursor", pointer.PointerStyle.HORIZONTAL_TEXT_CURSOR);
      this.systemCursorConstants.set("cursorCross", pointer.PointerStyle.CURSOR_CROSS);
      this.systemCursorConstants.set("cursorCircle", pointer.PointerStyle.CURSOR_CIRCLE);
      this.systemCursorConstants.set("loading", pointer.PointerStyle.LOADING);
      this.systemCursorConstants.set("running", pointer.PointerStyle.RUNNING);
      this.systemCursorConstants.set("colorSucker", pointer.PointerStyle.COLOR_SUCKER);
      this.systemCursorConstants.set("screenshotChoose", pointer.PointerStyle.SCREENSHOT_CHOOSE);
      this.systemCursorConstants.set("screenshotCursor", pointer.PointerStyle.SCREENSHOT_CURSOR);
    }
    let pointStyle: pointer.PointerStyle = this.systemCursorConstants.get(kind);
    if (pointStyle === null) {
      return pointer.PointerStyle.DEFAULT;
    }
    return pointStyle;
  }

  /**
   * Detaches the text input plugin from the platform views controller;
   *
   * <p> The MouseCursorPlugin instance should not be used after call this.
   */
  destroy(): void {
    this.mouseCursorChannel.setMethodHandler(null);
  }
}

