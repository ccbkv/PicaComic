/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/
import Any from '../plugin/common/Any';

export default class ToolUtils {
  static isObj(object: Object): boolean {
    return object && typeof (object) == 'object';
  }

  static implementsInterface(obj: Any, method: string): boolean {
    return Reflect.has(obj, method) && typeof obj[method] === 'function'
  }
}