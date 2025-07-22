/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on TextureRegistry.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/
import image from '@ohos.multimedia.image';

export interface TextureRegistry {

  createSurfaceTexture(): SurfaceTextureEntry;

  getTextureId(): number;

  registerTexture(textureId: number): SurfaceTextureEntry;

  registerSurfaceTexture(receiver: image.ImageReceiver): SurfaceTextureEntry;

  registerPixelMap(pixelMap: PixelMap): number;

  setTextureBackGroundPixelMap(textureId: number, pixelMap: PixelMap): void;

  /**
   * @deprecated since 3.7
   */
  setTextureBackGroundColor(textureId: number, color: number): void;

  setTextureBufferSize(textureId: number, width: number, height: number): void;

  notifyTextureResizing(textureId: number, width: number, height: number): void;

  /**
   * @deprecated since 3.22
   * @useinstead TextureRegistry#setExternalNativeImagePtr
   */
  setExternalNativeImage(textureId: number, native_image: number): boolean;

  setExternalNativeImagePtr(textureId: number, native_image: bigint): boolean;

  resetExternalTexture(textureId: number, need_surfaceId: boolean): number;

  unregisterTexture(textureId: number): void;

  onTrimMemory(level: number): void;
}

export interface SurfaceTextureEntry {
  getTextureId(): number;

  getSurfaceId(): number;

  /*
  * This return value is OHNativeWindow* in native code.
  * Once converted to OHNativeWindow*, it can be used to create an EGLSurface or VkSurface for rendering.
  * This OHNativeWindow* needn't be released when invoking unregisterTexture.
  */
  getNativeWindowId(): number;

  release(): void;
}

export interface OnFrameConsumedListener {
  onFrameConsumed(): void;
}

export interface OnTrimMemoryListener {
  onTrimMemory(level: number): void;
}