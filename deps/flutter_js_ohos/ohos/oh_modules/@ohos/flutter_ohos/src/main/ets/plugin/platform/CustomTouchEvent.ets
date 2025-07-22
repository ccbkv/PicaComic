/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
*/

export class CustomTouchEvent implements TouchEvent {
  type: TouchType = 0;
  touches: CustomTouchObject[];
  changedTouches: CustomTouchObject[];
  stopPropagation: () => void = () => {
  };
  timestamp: number;
  source: SourceType;
  pressure: number;
  tiltX: number;
  tiltY: number;
  sourceTool: SourceTool;

  constructor(type: TouchType, touches: CustomTouchObject[], changedTouches: CustomTouchObject[], timestamp: number,
    source: SourceType, pressure: number, tiltX: number, tiltY: number, sourceTool: SourceTool) {
    this.type = type;
    this.touches = touches;
    this.changedTouches = changedTouches;
    this.timestamp = timestamp;
    this.source = source;
    this.pressure = pressure;
    this.tiltX = tiltX;
    this.tiltY = tiltY;
    this.sourceTool = sourceTool;
  }

  preventDefault: () => void = () => {
  };

  getModifierKeyState(keys: string[]): boolean {
    throw new Error('Method not implemented.');
  }

  target: EventTarget = new CustomEventTarget(new CustomArea(0, 0, { x: 0, y: 0 }, { x: 0, y: 0 }));

  getHistoricalPoints(): HistoricalPoint[] {
    throw new Error('Method not implemented.');
  }
}

class CustomEventTarget implements EventTarget {
  area: Area = new CustomArea(0, 0, { x: 0, y: 0 }, { x: 0, y: 0 });

  constructor(area: Area) {
    this.area = area;
  }
}

class CustomArea implements Area {
  width: Length = 0;
  height: Length = 0;
  position: Position = { x: 0, y: 0 };
  globalPosition: Position = { x: 0, y: 0 };

  constructor(width: Length, height: Length, position: Position, globalPosition: Position) {
    this.width = width;
    this.height = height;
    this.position = position;
    this.globalPosition = globalPosition;
  }
}

export class CustomTouchObject implements TouchObject {
  type: TouchType;
  id: number;
  displayX: number;
  displayY: number;
  windowX: number;
  windowY: number;
  screenX: number;
  screenY: number;
  x: number;
  y: number;

  constructor(type: TouchType, id: number, displayX: number, displayY: number, windowX: number, windowY: number,
    screenX: number, screenY: number, x: number, y: number) {
    this.type = type;
    this.id = id;
    this.displayX = displayX;
    this.displayY = displayY;
    this.windowX = windowX;
    this.windowY = windowY;
    this.screenX = screenX;
    this.screenY = screenY;
    this.x = x;
    this.y = y;
  }
}