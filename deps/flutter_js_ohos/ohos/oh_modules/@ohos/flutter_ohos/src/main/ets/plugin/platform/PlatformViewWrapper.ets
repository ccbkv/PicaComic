/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/

import OhosTouchProcessor from '../../embedding/ohos/OhosTouchProcessor';
import { DVModel, DVModelParameters } from '../../view/DynamicView/dynamicView';
import { createDVModelFromJson } from '../../view/DynamicView/dynamicViewJson';
import { RootDvModeManager } from './RootDvModelManager';
import matrix4 from '@ohos.matrix4'
import Log from '../../util/Log';
import Any from '../common/Any';

const TAG: string = "PlatformViewWrapper";

export class PlatformViewWrapper {
  private prevLeft: number = 0;
  private prevTop: number = 0;
  private left: number = 0;
  private top: number = 0;
  private bufferWidth: number = 0;
  private bufferHeight: number = 0;
  private touchProcessor: OhosTouchProcessor | null = null;
  private model: DVModel | undefined;

  public setTouchProcessor(newTouchProcessor: OhosTouchProcessor): void {
    this.touchProcessor = newTouchProcessor;
  }

  constructor() {
  }

  public getDvModel(): DVModel {
    return this.model!;
  }

  setParams: (params: DVModelParameters, key: string, element: Any) => void =
    (params: DVModelParameters, key: string, element: Any): void => {
      let params2 = params as Record<string, Any>;
      params2[key] = element;
    }
  getParams: (params: DVModelParameters, element: string) => string | Any =
    (params: DVModelParameters, element: string): string | Any => {
      let params2 = params as Record<string, Any>;
      return params2[element];
    }

  public setLayoutParams(parameters: DVModelParameters): void {
    if (!this.model) {
      return;
    }
    if (this.model.params == null) {
      this.model.params = new DVModelParameters();
    }
    this.setParams(this.model.params, "marginLeft", this.getParams(parameters, "marginLeft"));
    this.setParams(this.model.params, "marginTop", this.getParams(parameters, "marginTop"));
    this.left = this.getParams(parameters, "marginLeft");
    this.top = this.getParams(parameters, "marginTop");

    this.setParams(this.model.params, "width", this.getParams(parameters, "width"));
    this.setParams(this.model.params, "height", this.getParams(parameters, "height"));
  }

  public addDvModel(model: DVModel): void {
    this.model = model
  }
}

class DVModelParam {
  compType: string
  children: []

  constructor(compType: string, children: []) {
    this.compType = compType;
    this.children = children;
  }
}