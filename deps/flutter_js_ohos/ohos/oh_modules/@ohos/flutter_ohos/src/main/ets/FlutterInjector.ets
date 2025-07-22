/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/

import FlutterNapi from './embedding/engine/FlutterNapi';
import FlutterLoader from './embedding/engine/loader/FlutterLoader';

/**
 * flutter相关主要类的单例持有，帮助实现自身和其他类的实例化管理
 */
export default class FlutterInjector {
  private static instance: FlutterInjector;
  private flutterLoader: FlutterLoader;
  private preloadFlutterNapi: FlutterNapi | null = null;

  static getInstance(): FlutterInjector {
    if (FlutterInjector.instance == null) {
      FlutterInjector.instance = new FlutterInjector();
    }
    return FlutterInjector.instance;
  }

  /**
   * 初始化
   */
  private constructor() {
    this.flutterLoader = new FlutterLoader(new FlutterNapi());
  }

  getFlutterLoader(): FlutterLoader {
    return this.flutterLoader;
  }

  getFlutterNapi(): FlutterNapi {
    if (this.preloadFlutterNapi) {
      let retFlutterNapi = this.preloadFlutterNapi;
      this.preloadFlutterNapi = null;
      return retFlutterNapi;
    }
    return new FlutterNapi();
  }

  getPreloadFlutterNapi(): FlutterNapi {
    this.preloadFlutterNapi = new FlutterNapi();
    return this.preloadFlutterNapi;
  }
}