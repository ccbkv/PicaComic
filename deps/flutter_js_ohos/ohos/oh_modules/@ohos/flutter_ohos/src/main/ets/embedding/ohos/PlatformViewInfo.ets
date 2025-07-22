/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/


import PlatformView from '../../plugin/platform/PlatformView';

export class PlatformViewInfo {
  public platformView: PlatformView;
  public surfaceId: string;
  public width: number;
  public height: number;
  public top: number;
  public left: number;
  public direction: Direction;

  constructor(platformView: PlatformView, surfaceId: string, width: number, height: number, top: number, left: number,
    direction: Direction) {
    this.platformView = platformView;
    this.surfaceId = surfaceId;
    this.width = width;
    this.height = height;
    this.top = top;
    this.left = left;
    this.direction = direction;
  }
}
