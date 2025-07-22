/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on FlutterOverlaySurface.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

export class FlutterOverlaySurface {
  private id: number;

  constructor(id: number) {
    this.id = id
  }

  getId(): number {
    return this.id;
  }
}