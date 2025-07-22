/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
*/

export class RawPointerCoords {
  private orientation: number = 0;
  private pressure: number = 0;
  private size: number = 0;
  private toolMajor: number = 0;
  private toolMinor: number = 0;
  private touchMajor: number = 0;
  private touchMinor: number = 0;
  private x: number = 0;
  private y: number = 0;

  constructor(orientation: number, pressure: number, size: number, toolMajor: number, toolMinor: number,
    touchMajor: number, touchMinor: number, x: number, y: number) {
    this.orientation = orientation;
    this.pressure = pressure;
    this.size = size;
    this.toolMajor = toolMajor;
    this.toolMinor = toolMinor;
    this.touchMajor = touchMajor;
    this.touchMinor = touchMinor;
    this.x = x;
    this.y = y;
  }

  getX(): number {
    return this.x;
  }

  getY(): number {
    return this.y;
  }
}