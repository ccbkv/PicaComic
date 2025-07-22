// Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE_ODID file.
// Based on ImagePickerPlugin.java originally written by
// Copyright 2013 The Flutter Authors.

import AbilityLifecycleCallback from '@ohos.app.ability.AbilityLifecycleCallback';

import AbilityAware from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityAware';

import {
  AbilityPluginBinding
} from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityPluginBinding';
import {
  FlutterPlugin,
  FlutterPluginBinding
} from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import common from '@ohos.app.ability.common';
import Ability from '@ohos.app.ability.Ability';
import { BinaryMessenger } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BinaryMessenger';
import ImagePickerDelegate, { CameraDevice } from './ImagePickerDelegate';
import {
  GeneralOptions,
  ImagePickerApi,
  ImageSelectionOptions,
  SourceSpecification,
  Result,
  SourceType,
  MediaSelectionOptions,
  CacheRetrievalResult,
  VideoSelectionOptions,
  SourceCamera,
  FlutterError
} from './Messages';
import ImagePickerCache from './ImagePickerCache';
import ExifDataCopier from './ExifDataCopier';
import ImageResizer from './ImageResizer';
import UIAbility from '@ohos.app.ability.UIAbility';
import ArrayList from '@ohos.util.ArrayList';
import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';

const TAG: string = "ImagePickerPlugin";

//export default class ImagePickerPlugin implements FlutterPlugin, AbilityAware, ImagePickerApi {
export default class ImagePickerPlugin implements FlutterPlugin, AbilityAware {
  private static TAG = "ImagePickerPlugin";
  private pluginBinding: FlutterPluginBinding | null = null;
  private state: AbilityState | null = null;

  getUniqueClassName(): string {
    return ImagePickerPlugin.TAG;
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.pluginBinding = binding;
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.pluginBinding = null;
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    Log.i(TAG, "onAttachedToAbility");
    if (!this.pluginBinding) {
      return
    }
    this.setup(this.pluginBinding.getBinaryMessenger(), this.pluginBinding.getApplicationContext(),
      binding.getAbility(), binding);
  }

  onDetachedFromAbility(): void {
    if (this.state != null) {
      this.state.release();
      this.state = null;
    }
  }

  setup(messenger: BinaryMessenger, context: common.Context, ability: UIAbility, binding: AbilityPluginBinding): void {
    this.state = new AbilityState(ability, null, messenger, this as ESObject, binding, context);
  }

  constructor(delegate?: ImagePickerDelegate, ability?: UIAbility) {
    if (delegate != null && ability != null) {
      this.state = new AbilityState(ability, delegate);
    }
  }

  pickImages(source: SourceSpecification, options: ImageSelectionOptions, generalOptions: GeneralOptions, result: Result<ArrayList<string>>) {
    let delegate: ImagePickerDelegate | null = this.getImagePickerDelegate();
    if (delegate === null) {
      result.error(new FlutterError("no_ability", "image_picker plugin requires a foreground ability", null));
      return;
    }

    this.setCameraDevice(delegate, source);
    if (generalOptions.getAllowMultiple()) {
      delegate.chooseMultiImagesFromGallery(options, generalOptions, result);
    } else {
      switch (source.getType()) {
        case SourceType.GALLERY: {
          delegate.chooseImageFromGallery(options, generalOptions.getUsePhotoPicker(), result);
          break;
        }
        case SourceType.CAMERA: {
          delegate.takeImageWithCamera(options, result);
        }
      }
    }
  }

  pickVideos(source: SourceSpecification, options: VideoSelectionOptions, generalOptions: GeneralOptions, result: Result<ArrayList<string>>): void {
    let delegate: ImagePickerDelegate | null = this.getImagePickerDelegate();
    if (delegate === null) {
      result.error(new FlutterError("no_ability", "image_pickerplugin requires a foreground ability", null));
      return;
    }

    this.setCameraDevice(delegate, source);
    if (generalOptions.getAllowMultiple()) {
      result.error(new FlutterError("no_ability", "image_pickerplugin requires a foreground ability", null));
    } else {
      switch (source.getType()) {
        case SourceType.GALLERY: {
          delegate.chooseVideoFromGallery(options, generalOptions.getUsePhotoPicker(), result);
          break;
        }
        case SourceType.CAMERA: {
          delegate.takeVideoWithCamera(options, result);
        }
      }
    }
  }

  pickMedia(mediaSelectionOptions: MediaSelectionOptions, generalOptions: GeneralOptions, result: Result<ArrayList<string>>): void {
    let delegate: ImagePickerDelegate | null = this.getImagePickerDelegate();
    if (delegate === null) {
      result.error(new FlutterError("no_ability", "image_pickerplugin requires a foreground ability", null));
      return;
    }
    delegate.chooseMediaFromGallery(mediaSelectionOptions, generalOptions, result);
  }

  async retrieveLostResults(): Promise<CacheRetrievalResult | null> {
    let delegate = this.getImagePickerDelegate();
    if (delegate == null) {
      throw new FlutterError("no_ability", "image_picker plugin requires a foreground ability", null);
    }
    return await delegate.retrieveLostImage().then((result) => {
      return result;
    });
  }

  getAbilityState(): AbilityState | null {
    return this.state;
  }

  static constructorDelegate(setupAbility: UIAbility): ImagePickerDelegate {
    let cache: ImagePickerCache = new ImagePickerCache(setupAbility.context);
    let exifDataCopier: ExifDataCopier = new ExifDataCopier();
    let imageResizer: ImageResizer = new ImageResizer(setupAbility.context, exifDataCopier);
    return new ImagePickerDelegate(setupAbility, imageResizer, cache);
  }

  getImagePickerDelegate(): ImagePickerDelegate | null {
    if (this.state == null || this.state.getAbility() == null) {
      return null;
    }
    return this.state.getDelegate();
  }

  setCameraDevice(delegate: ImagePickerDelegate, source: SourceSpecification) {
    let camera: SourceCamera = source.getCamera();
    if (camera != null) {
      let device: CameraDevice;
      switch (camera) {
        case SourceCamera.FRONT: {
          device = CameraDevice.FRONT;
          break;
        }
        case SourceCamera.REAR: {
          device = CameraDevice.REAR;
          break;
        }
      }
      delegate.setCameraDevice(device);
    }
  }
}

class AbilityState {
  private ability: UIAbility | null;
  private context: common.Context | null = null;
  private abilityBinding: AbilityPluginBinding | null = null;
  private messenger: BinaryMessenger | null = null;
  private delegate: ImagePickerDelegate | null = null;
  private abilityLifecycleCallback: AbilityLifecycleCallback;

  constructor(ability: UIAbility, delegate?: ImagePickerDelegate | null, messenger?: BinaryMessenger, handler?: ImagePickerApi, abilityBinding?: AbilityPluginBinding, context?: common.Context) {
    this.ability = ability;
    if (context) {
      this.context = context;
    }
    if (abilityBinding) {
      this.abilityBinding = abilityBinding;
    }
    if (messenger) {
      this.messenger = messenger;
    }
    if (delegate) {
      this.delegate = delegate;
    }

    this.abilityLifecycleCallback = {
      onAbilityCreate(ability) {
        console.log('AbilityLifecycleCallback onAbilityCreate.');
      },
      onWindowStageCreate(ability, windowStage) {
        console.log('AbilityLifecycleCallback onWindowStageCreate.');
      },
      onWindowStageActive(ability, windowStage) {
        console.log('AbilityLifecycleCallback onWindowStageActive.');
      },
      onWindowStageInactive(ability, windowStage) {
        console.log('AbilityLifecycleCallback onWindowStageInactive.');
      },
      onWindowStageDestroy(ability, windowStage) {
        console.log('AbilityLifecycleCallback onWindowStageDestroy.');
      },
      onAbilityDestroy(ability) {
        console.log('AbilityLifecycleCallback onAbilityDestroy.');
      },
      onAbilityForeground(ability) {
        console.log('AbilityLifecycleCallback onAbilityForeground.');
      },
      onAbilityBackground(ability) {
        console.log('AbilityLifecycleCallback onAbilityBackground.');
      },
      onAbilityContinue(ability) {
        console.log('AbilityLifecycleCallback onAbilityContinue.');
      }
    };

    this.delegate = ImagePickerPlugin.constructorDelegate(this.ability);
    ImagePickerApi.setup(messenger as BinaryMessenger, handler);
  }

  release(): void {
    if (this.abilityBinding != null) {
      this.abilityBinding = null;
    }

    ImagePickerApi.setup(null, null);

    this.ability = null;
    this.delegate = null;
  }

  getAbility(): Ability | null {
    return this.ability;
  }

  getDelegate(): ImagePickerDelegate | null {
    return this.delegate;
  }
}
