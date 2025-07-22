/*
* Copyright (c) 2025 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/
import Any from '../plugin/common/Any';
import ApplicationInfoLoader from '../embedding/engine/loader/ApplicationInfoLoader';

import { BuilderParams, DVModelParameters } from '../view/DynamicView/dynamicView';

@Component
struct XComponentStruct {
  private context: Any;
  private applicationInfo = ApplicationInfoLoader.load(getContext());
  dvModelParams: DVModelParameters = new DVModelParameters();

  build() {
    // todo OS解决默认背景色后可以移除冗余重复代码,仅保留差异的backgroundColor属性条件配置
    if (this.applicationInfo.isDebugMode) {
      XComponent({
        id: (this.dvModelParams as Record<string, Any>)["xComponentId"],
        type: XComponentType.TEXTURE,
        libraryname: 'flutter'
      })
        .onLoad((context) => {
          this.context = context;
        })
        .onDestroy(() => {
        })
        .backgroundColor(Color.White)
    } else {
      XComponent({
        id: (this.dvModelParams as Record<string, Any>)["xComponentId"],
        type: XComponentType.TEXTURE,
        libraryname: 'flutter'
      })
        .onLoad((context) => {
          this.context = context;
        })
        .onDestroy(() => {
        })
    }
  }
}

@Builder
export function BuildXComponentStruct(buildParams: BuilderParams) {
  XComponentStruct({ dvModelParams: buildParams.params });
}