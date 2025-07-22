/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on FlutterEngineProvider.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

import FlutterEngine from '../engine/FlutterEngine';
import common from '@ohos.app.ability.common';

export default interface FlutterEngineProvider {
  provideFlutterEngine(context: common.Context): FlutterEngine | null;
}