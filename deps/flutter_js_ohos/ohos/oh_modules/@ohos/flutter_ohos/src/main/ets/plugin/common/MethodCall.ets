/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on MethodCall.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

import ToolUtils from '../../util/ToolUtils';
import TreeMap from '@ohos.util.TreeMap';
import HashMap from '@ohos.util.HashMap';
import LightWeightMap from '@ohos.util.LightWeightMap';
import Any from './Any';

/** Command object representing a method call on a {@link MethodChannel}. */
export default class MethodCall {
  /** The name of the called method. */
  method: string;
  /**
   * Arguments for the call.
   *
   * <p>Consider using {@link #arguments()} for cases where a particular run-time type is expected.
   * Consider using {@link #argument(String)} when that run-time type is {@link Map} or {@link
   * JSONObject}.
   */
  args: Any;

  constructor(method: string, args: Any) {
    this.method = method;
    this.args = args;
  }

  argument(key: string): Any {
    if (this.args == null) {
      return null;
    } else if (this.args instanceof Map) {
      return (this.args as Map<Any, Any>).get(key);
    } else if (ToolUtils.isObj(this.args)) {
      return this.args[key];
    } else {
      throw new Error("ClassCastException");
    }
  }

  hasArgument(key: string): boolean {
    if (this.args == null) {
      return false;
    } else if (this.args instanceof Map) {
      return (this.args as Map<Any, Any>).has(key);
    } else if (ToolUtils.isObj(this.args)) {
      return this.args.hasOwnProperty(key);
    } else {
      throw new Error("ClassCastException");
    }
  }
}