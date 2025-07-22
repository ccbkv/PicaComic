/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on PlatformViewRegistry.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

import PlatformViewFactory from './PlatformViewFactory'

/**
 * Registry for platform view factories.
 *
 * <p>Plugins can register factories for specific view types.
 */
export default interface PlatformViewRegistry {
  /**
   * Registers a factory for a platform view.
   *
   * @param viewTypeId unique identifier for the platform view's type.
   * @param factory factory for creating platform views of the specified type.
   * @return true if succeeded, false if a factory is already registered for viewTypeId.
   */
  registerViewFactory(viewTypeId: string, factory: PlatformViewFactory): boolean;
}