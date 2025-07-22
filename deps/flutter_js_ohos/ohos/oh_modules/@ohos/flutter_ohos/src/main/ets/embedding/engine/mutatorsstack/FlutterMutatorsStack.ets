/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on FlutterMutatorsStack.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

import matrix4 from '@ohos.matrix4'
import List from '@ohos.util.List';

export enum FlutterMutatorType {
  CLIP_RECT,
  CLIP_PATH,
  TRANSFORM,
  OPACITY
}

class Rect {
  width: number;
  height: number;
  radius: string | number | Array<string | number>;

  constructor(width: number, height: number, radius?: string | number | Array<string | number>) {
    this.width = width;
    this.height = height;
    this.radius = radius ?? 0;
  }
}

class Path {
  width: number | string;
  height: number | string;
  commands: string;

  constructor(width: number | string, height: number | string, commands?: string) {
    this.width = width;
    this.height = height;
    this.commands = commands ?? '';
  }
}

export class FlutterMutator {
  private matrix: matrix4.Matrix4Transit | null = null;
  private rect: Rect = new Rect(0, 0);
  private path: Path = new Path(0, 0);

  constructor(args: matrix4.Matrix4Transit | Rect | Path) {
    if (args instanceof Rect) {
      this.rect = args;
    } else if (args instanceof Path) {
      this.path = args;
    } else {
      this.matrix = args;
    }
  }

  public getMatrix(): matrix4.Matrix4Transit | null {
    return this.matrix;
  }

  public getRect() {
    return this.rect;
  }

  public getPath() {
    return this.path;
  }
}

export class FlutterMutatorsStack {
  private mutators: List<FlutterMutator>;
  private finalClippingPaths: List<Path>;
  private finalClippingRects: List<Rect>;
  private finalMatrix: matrix4.Matrix4Transit;

  constructor() {
    this.mutators = new List();
    this.finalClippingPaths = new List();
    this.finalClippingRects = new List();
    this.finalMatrix = matrix4.identity();
  }

  public pushTransform(values: Array<number>): void {
    if (values.length != 16) {
      return;
    }
    let index = 0;
    let matrix = matrix4.init(
      [values[index++], values[index++], values[index++], values[index++],
        values[index++], values[index++], values[index++], values[index++],
        values[index++], values[index++], values[index++], values[index++],
        values[index++], values[index++], values[index++], values[index++]]);
    let mutator = new FlutterMutator(matrix);
    this.mutators.add(mutator);
    this.finalMatrix.combine(matrix);
  }

  public pushClipRect(width: number, height: number, radius?: number) {
    let rect = new Rect(width, height, radius);
    let mutator = new FlutterMutator(rect);
    this.mutators.add(mutator);
    this.finalClippingRects.add(rect);
  }

  public pushClipPath(width: number, height: number, command?: string) {
    let path = new Path(width, height, command);
    let mutator = new FlutterMutator(path);
    this.mutators.add(mutator);
    this.finalClippingPaths.add(path);
  }

  public getMutators() {
    return this.mutators;
  }

  public getFinalClippingPaths() {
    return this.finalClippingPaths;
  }

  public getFinalClippingRects() {
    return this.finalClippingRects;
  }

  public getFinalMatrix() {
    return this.finalMatrix;
  }
}