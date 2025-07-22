/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/
import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import Log from './Log';

/**
 * ohos路径获取工具
 */
const TAG: string = "PathUtils";

export default class PathUtils {
  static getFilesDir(context: common.Context): string {
    return context.filesDir;
  }

  static getCacheDirectory(context: common.Context): string {
    return context.cacheDir;
  }

  static getDataDirectory(context: common.Context): string | null {
    const name = "flutter";
    const flutterDir = context.filesDir + "/" + name;
    if (!fs.accessSync(flutterDir)) {
      try {
        fs.mkdirSync(flutterDir);
      } catch (err) {
        Log.e(TAG, "mkdirSync failed err:" + err);
        return null;
      }
    }
    return flutterDir;
  }
}