/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
*/
import { FlutterView } from '../view/FlutterView';
import common from '@ohos.app.ability.common';
import PlatformViewController from '../plugin/platform/PlatformViewsController'

export default class FlutterPluginRegistry {
  private mPlatformViewsController: PlatformViewController;
  private mFlutterView: FlutterView | null = null;
  private mContext: common.Context | null = null;

  constructor() {
    this.mPlatformViewsController = new PlatformViewController();
    this.mFlutterView = null;
    this.mContext = null;
  }

  attach(flutterView: FlutterView, context: common.Context): void {
    this.mFlutterView = flutterView;
    this.mContext = context;
  }

  detach(): void {
    this.mPlatformViewsController.detach();
    this.mPlatformViewsController.onDetachedFromNapi();
    this.mFlutterView = null;
    this.mContext = null;
  }

  destroy(): void {
    this.mPlatformViewsController.onDetachedFromNapi();
  }

  onPreEngineRestart(): void {
    this.mPlatformViewsController.onPreEngineRestart();
  }
}