/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on FlutterPlugin.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

import common from '@ohos.app.ability.common';
import { BinaryMessenger } from '../../../plugin/common/BinaryMessenger';
import PlatformViewFactory from '../../../plugin/platform/PlatformViewFactory';
import PlatformViewRegistry from '../../../plugin/platform/PlatformViewRegistry';
import { TextureRegistry } from '../../../view/TextureRegistry';
import FlutterEngine from '../FlutterEngine';

export interface FlutterPlugin {
  //获取唯一的类名 类似安卓的Class<? extends FlutterPlugin ts无法实现只能用户自定义
  getUniqueClassName(): string

  /**
   * This {@code FlutterPlugin} has been associated with a {@link
   * io.flutter.embedding.engine.FlutterEngine} instance.
   *
   * <p>Relevant resources that this {@code FlutterPlugin} may need are provided via the {@code
   * binding}. The {@code binding} may be cached and referenced until {@link
   * #onDetachedFromEngine(FlutterPluginBinding)} is invoked and returns.
   */
  onAttachedToEngine(binding: FlutterPluginBinding): void;

  /**
   * This {@code FlutterPlugin} has been removed from a {@link
   * io.flutter.embedding.engine.FlutterEngine} instance.
   *
   * <p>The {@code binding} passed to this method is the same instance that was passed in {@link
   * #onAttachedToEngine(FlutterPluginBinding)}. It is provided again in this method as a
   * convenience. The {@code binding} may be referenced during the execution of this method, but it
   * must not be cached or referenced after this method returns.
   *
   * <p>{@code FlutterPlugin}s should release all resources in this method.
   */
  onDetachedFromEngine(binding: FlutterPluginBinding): void;
}

export class FlutterPluginBinding {
  private applicationContext: common.Context;
  private flutterEngine: FlutterEngine;
  private binaryMessenger: BinaryMessenger;
  private flutterAssets: FlutterAssets;
  private textureRegistry: TextureRegistry;
  private platformViewRegistry: PlatformViewRegistry;

  constructor(applicationContext: common.Context, flutterEngine: FlutterEngine, binaryMessenger: BinaryMessenger,
    flutterAssets: FlutterAssets, textureRegistry: TextureRegistry, platformViewRegistry?: PlatformViewRegistry) {
    this.applicationContext = applicationContext;
    this.flutterEngine = flutterEngine;
    this.binaryMessenger = binaryMessenger;
    this.flutterAssets = flutterAssets;
    this.textureRegistry = textureRegistry;
    this.platformViewRegistry = platformViewRegistry ?? new EmptyPlatformViewRegistry();
  }

  getApplicationContext(): common.Context {
    return this.applicationContext;
  }

  getFlutterEngine(): FlutterEngine {
    return this.flutterEngine;
  }

  getBinaryMessenger(): BinaryMessenger {
    return this.binaryMessenger;
  }

  getFlutterAssets(): FlutterAssets {
    return this.flutterAssets;
  }

  getTextureRegistry(): TextureRegistry {
    return this.textureRegistry;
  }

  public getPlatformViewRegistry(): PlatformViewRegistry {
    return this.platformViewRegistry;
  }
}

/** Provides Flutter plugins with access to Flutter asset information. */
export interface FlutterAssets {
  /**
   * Returns the relative file path to the Flutter asset with the given name, including the file's
   * extension, e.g., {@code "myImage.jpg"}.
   *
   * <p>The returned file path is relative to the Ohos app's standard assets directory.
   * Therefore, the returned path is appropriate to pass to Ohos's {@code ResourceManage}, but
   * the path is not appropriate to load as an absolute path.
   */
  getAssetFilePathByName(assetFileName: string): string;

  /**
   * Same as {@link #getAssetFilePathByName(String)} but with added support for an explicit
   * Ohos {@code bundleName}.
   */
  getAssetFilePathByName(assetFileName: string, bundleName: string): string;

  /**
   * Returns the relative file path to the Flutter asset with the given subpath, including the
   * file's extension, e.g., {@code "/dir1/dir2/myImage.jpg"}.
   *
   * <p>The returned file path is relative to the Ohos app's standard assets directory.
   * Therefore, the returned path is appropriate to pass to Ohos's {@code ResourceManage}, but
   * the path is not appropriate to load as an absolute path.
   */
  getAssetFilePathBySubpath(assetSubpath: string): string;

  /**
   * Same as {@link #getAssetFilePathBySubpath(String)} but with added support for an explicit
   * Ohos {@code bundleName}.
   */
  getAssetFilePathBySubpath(assetSubpath: string, bundleName: string): string;
}

class EmptyPlatformViewRegistry implements PlatformViewRegistry {
  registerViewFactory(viewTypeId: string, factory: PlatformViewFactory): boolean {
    return false;
  }
}