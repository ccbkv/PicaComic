/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on PlatformViewRegistryImpl.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

import HashMap from '@ohos.util.HashMap';
import PlatformViewFactory from './PlatformViewFactory'
import PlatformViewRegistry from './PlatformViewRegistry'

export default class PlatformViewRegistryImpl implements PlatformViewRegistry {
  // Maps a platform view type id to its factory.
  private viewFactories: HashMap<String, PlatformViewFactory>;

  constructor() {
    this.viewFactories = new HashMap();
  }

  registerViewFactory(viewTypeId: string, factory: PlatformViewFactory): boolean {
    if (this.viewFactories.hasKey(viewTypeId)) {
      return false;
    }

    this.viewFactories.set(viewTypeId, factory);
    return true;
  }

  getFactory(viewTypeId: string): PlatformViewFactory {
    return this.viewFactories.get(viewTypeId);
  }
}
