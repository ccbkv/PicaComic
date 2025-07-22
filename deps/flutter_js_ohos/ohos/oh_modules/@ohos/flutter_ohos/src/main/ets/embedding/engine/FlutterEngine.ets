/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on FlutterEngine.java originally written by
* Copyright (C) Copyright 2013 The Flutter Authors.
*
*/

import LifecycleChannel from './systemchannels/LifecycleChannel';
import DartExecutor, { DartEntrypoint } from './dart/DartExecutor';
import FlutterShellArgs from './FlutterShellArgs';
import FlutterInjector from '../../FlutterInjector';
import FlutterLoader from './loader/FlutterLoader';
import common from '@ohos.app.ability.common';
import resourceManager from '@ohos.resourceManager';
import FlutterNapi from './FlutterNapi';
import NavigationChannel from './systemchannels/NavigationChannel';
import Log from '../../util/Log';
import TestChannel from './systemchannels/TestChannel'
import FlutterEngineConnectionRegistry from './FlutterEngineConnectionRegistry';
import PluginRegistry from './plugins/PluginRegistry';
import AbilityControlSurface from './plugins/ability/AbilityControlSurface';
import TextInputChannel from './systemchannels/TextInputChannel';
import TextInputPlugin from '../../plugin/editing/TextInputPlugin';
import PlatformChannel from './systemchannels/PlatformChannel';
import SystemChannel from './systemchannels/SystemChannel';
import MouseCursorChannel from './systemchannels/MouseCursorChannel';
import RestorationChannel from './systemchannels/RestorationChannel';
import LocalizationChannel from './systemchannels/LocalizationChannel';
import AccessibilityChannel from './systemchannels/AccessibilityChannel';
import LocalizationPlugin from '../../plugin/localization/LocalizationPlugin'
import SettingsChannel from './systemchannels/SettingsChannel';
import PlatformViewsController from '../../plugin/platform/PlatformViewsController';
import { FlutterRenderer } from './renderer/FlutterRenderer';
import NativeVsyncChannel from './systemchannels/NativeVsyncChannel';

const TAG = "FlutterEngine";

/**
 * 操作FlutterEngin相关
 */
export default class FlutterEngine implements EngineLifecycleListener {
  private engineLifecycleListeners = new Set<EngineLifecycleListener>();
  dartExecutor: DartExecutor;
  private flutterLoader: FlutterLoader;
  private assetManager: resourceManager.ResourceManager;
  //channel定义
  private lifecycleChannel: LifecycleChannel | null = null;
  private navigationChannel: NavigationChannel | null = null;
  private textInputChannel: TextInputChannel | null = null;
  private testChannel: TestChannel | null = null;
  private platformChannel: PlatformChannel | null = null;
  private systemChannel: SystemChannel | null = null;
  private mouseCursorChannel: MouseCursorChannel | null = null;
  private restorationChannel: RestorationChannel | null = null;
  private accessibilityChannel: AccessibilityChannel | null = null;
  private localeChannel: LocalizationChannel | null = null;
  private flutterNapi: FlutterNapi;
  private renderer: FlutterRenderer;
  private pluginRegistry: FlutterEngineConnectionRegistry | null = null;
  private textInputPlugin: TextInputPlugin | null = null;
  private localizationPlugin: LocalizationPlugin | null = null;
  private settingsChannel: SettingsChannel | null = null;
  private platformViewsController: PlatformViewsController;
  private nativeVsyncChannel: NativeVsyncChannel | null = null;

  /**
   * 需要初始化的工作：
   * 1、初始化DartExecutor
   * 2、初始化所有channel
   * 3、初始化plugin
   * 4、初始化flutterLoader
   * 5、初始化flutterNapi
   * 6、engineLifecycleListeners
   */
  constructor(context: common.Context, flutterLoader: FlutterLoader | null, flutterNapi: FlutterNapi | null,
    platformViewsController: PlatformViewsController | null) {
    const injector: FlutterInjector = FlutterInjector.getInstance();
    if (flutterNapi == null) {
      flutterNapi = FlutterInjector.getInstance().getFlutterNapi();
    }
    this.flutterNapi = flutterNapi;
    this.assetManager = context.resourceManager;

    this.dartExecutor = new DartExecutor(this.flutterNapi, this.assetManager);
    this.dartExecutor.onAttachedToNAPI();

    if (flutterLoader == null) {
      flutterLoader = injector.getFlutterLoader();
    }
    this.flutterLoader = flutterLoader;

    this.renderer = new FlutterRenderer(this.flutterNapi);

    if (platformViewsController == null) {
      platformViewsController = new PlatformViewsController();
    }
    this.platformViewsController = platformViewsController;
    this.platformViewsController.attach(context, this.renderer, this.dartExecutor);
  }

  init(context: common.Context, dartVmArgs: Array<string> | null, waitForRestorationData: boolean) {
    if (!this.flutterNapi.isAttached()) {
      this.flutterLoader.startInitialization(context)
      this.flutterLoader.ensureInitializationComplete(dartVmArgs);
    }
    //channel初始化
    this.lifecycleChannel = new LifecycleChannel(this.dartExecutor);
    this.navigationChannel = new NavigationChannel(this.dartExecutor);
    this.textInputChannel = new TextInputChannel(this.dartExecutor);
    this.testChannel = new TestChannel(this.dartExecutor);
    this.platformChannel = new PlatformChannel(this.dartExecutor);
    this.systemChannel = new SystemChannel(this.dartExecutor);
    this.mouseCursorChannel = new MouseCursorChannel(this.dartExecutor);
    this.restorationChannel = new RestorationChannel(this.dartExecutor, waitForRestorationData);
    this.settingsChannel = new SettingsChannel(this.dartExecutor);
    this.localeChannel = new LocalizationChannel(this.dartExecutor);
    this.accessibilityChannel = new AccessibilityChannel(this.dartExecutor, this.flutterNapi);
    this.flutterNapi.addEngineLifecycleListener(this);
    this.localizationPlugin = new LocalizationPlugin(context, this.localeChannel);
    this.nativeVsyncChannel = new NativeVsyncChannel(this.dartExecutor, this.flutterNapi);

    // It should typically be a fresh, unattached NAPI. But on a spawned engine, the NAPI instance
    // is already attached to a native shell. In that case, the Java FlutterEngine is created around
    // an existing shell.
    if (!this.flutterNapi.isAttached()) {
      this.attachToNapi();
    }
    this.flutterNapi.setLocalizationPlugin(this.localizationPlugin);

    this.pluginRegistry =
      new FlutterEngineConnectionRegistry(context.getApplicationContext(), this, this.flutterLoader);
    this.localizationPlugin.sendLocaleToFlutter();
    Log.d(TAG, "Call init finished.")
  }

  private attachToNapi(): void {
    Log.d(TAG, "Attaching to NAPI.");
    this.flutterNapi.attachToNative();
    if (!this.isAttachedToNapi()) {
      throw new Error("FlutterEngine failed to attach to its native Object reference.");
    }
  }

  spawn(context: common.Context,
    dartEntrypoint: DartEntrypoint,
    initialRoute: string,
    dartEntrypointArgs: Array<string>,
    platformViewsController: PlatformViewsController,
    waitForRestorationData: boolean) {
    if (!this.isAttachedToNapi()) {
      throw new Error(
        "Spawn can only be called on a fully constructed FlutterEngine");
    }

    const newFlutterNapi =
      this.flutterNapi.spawn(
        dartEntrypoint.dartEntrypointFunctionName,
        dartEntrypoint.dartEntrypointLibrary,
        initialRoute,
        dartEntrypointArgs);
    const flutterEngine = new FlutterEngine(
      context,
      null,
      newFlutterNapi,
      platformViewsController
    );
    flutterEngine.init(context, null, waitForRestorationData)
    return flutterEngine
  }

  private isAttachedToNapi(): boolean {
    return this.flutterNapi.isAttached();
  }

  processPendingMessages() {
    if (this.flutterNapi.isAttached()) {
      this.flutterNapi.processPendingMessages();
    }
  }

  getLifecycleChannel(): LifecycleChannel | null {
    return this.lifecycleChannel;
  }

  getNavigationChannel(): NavigationChannel | null {
    return this.navigationChannel;
  }

  getTextInputChannel(): TextInputChannel | null {
    return this.textInputChannel;
  }

  getPlatformChannel(): PlatformChannel | null {
    return this.platformChannel;
  }

  getSystemChannel(): SystemChannel | null {
    return this.systemChannel;
  }

  getLocaleChannel(): LocalizationChannel | null {
    return this.localeChannel;
  }

  getMouseCursorChannel(): MouseCursorChannel | null {
    return this.mouseCursorChannel;
  }

  getFlutterNapi(): FlutterNapi {
    return this.flutterNapi;
  }

  getFlutterRenderer(): FlutterRenderer {
    return this.renderer;
  }

  getDartExecutor(): DartExecutor {
    return this.dartExecutor
  }

  getPlugins(): PluginRegistry | null {
    return this.pluginRegistry;
  }

  getAbilityControlSurface(): AbilityControlSurface | null {
    return this.pluginRegistry;
  }

  getSettingsChannel() {
    return this.settingsChannel;
  }

  getFlutterLoader() {
    return this.flutterLoader;
  }

  onPreEngineRestart(): void {
    this.engineLifecycleListeners.forEach(listener => listener.onPreEngineRestart())
  }

  onEngineWillDestroy(): void {

  }

  addEngineLifecycleListener(listener: EngineLifecycleListener): void {
    this.engineLifecycleListeners.add(listener);
  }

  removeEngineLifecycleListener(listener: EngineLifecycleListener): void {
    this.engineLifecycleListeners.delete(listener);
  }

  destroy(): void {
    Log.d(TAG, "Destroying.");
    this.engineLifecycleListeners.forEach(listener => listener.onEngineWillDestroy())
    this.flutterNapi.removeEngineLifecycleListener(this);
    this.pluginRegistry?.detachFromAbility();
    this.platformViewsController?.onDetachedFromNapi();
    this.pluginRegistry?.destroy();
    this.dartExecutor.onDetachedFromNAPI();
    this.flutterNapi.detachFromNativeAndReleaseResources();
  }

  getRestorationChannel(): RestorationChannel | null {
    return this.restorationChannel;
  }

  getAccessibilityChannel(): AccessibilityChannel | null {
    return this.accessibilityChannel;
  }

  getLocalizationPlugin(): LocalizationPlugin | null {
    return this.localizationPlugin;
  }

  getSystemLanguages(): void {
    return this.flutterNapi.getSystemLanguages();
  }

  getPlatformViewsController(): PlatformViewsController | null {
    return this.platformViewsController;
  }

  getNativeVsyncChannel(): NativeVsyncChannel | null {
    return this.nativeVsyncChannel;
  }

  async prefetchFramesCfg(): Promise<void> {
    FlutterNapi.prefetchFramesCfg();
  }
}

export interface EngineLifecycleListener {
  onPreEngineRestart(): void;

  onEngineWillDestroy(): void;
}