/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/

import FlutterApplicationInfo from './FlutterApplicationInfo';
import common from '@ohos.app.ability.common';

export default class ApplicationInfoLoader {
  static load(context: common.Context) {
    let applicationInfo =
      new FlutterApplicationInfo(null, null, null, null, null, context.bundleCodeDir + '/libs/arm64', true);
    return applicationInfo
  }
}