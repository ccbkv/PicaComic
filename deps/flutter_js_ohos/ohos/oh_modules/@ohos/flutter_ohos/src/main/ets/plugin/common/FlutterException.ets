/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on FlutterException.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/
import Any from './Any';

export default class FlutterException implements Error {
  stack?: string;
  message: string;
  name: string = "";
  code: string;
  details: Any

  constructor(code: string, message: string, details: Any) {
    this.message = message;
    this.code = code;
    this.details = details;
  }
}