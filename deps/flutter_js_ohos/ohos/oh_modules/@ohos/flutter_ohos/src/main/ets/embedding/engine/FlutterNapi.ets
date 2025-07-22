/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/

import flutter from 'libflutter.so';
import common from '@ohos.app.ability.common';
import Log from '../../util/Log';
import resourceManager from '@ohos.resourceManager';
import { PlatformMessageHandler } from './dart/PlatformMessageHandler';
import { FlutterCallbackInformation } from '../../view/FlutterCallbackInformation';
import image from '@ohos.multimedia.image';
import { EngineLifecycleListener } from './FlutterEngine';
import { ByteBuffer } from '../../util/ByteBuffer';
import LocalizationPlugin from '../../plugin/localization/LocalizationPlugin';
import i18n from '@ohos.i18n';
import Any from '../../plugin/common/Any';
import FlutterManager from '../ohos/FlutterManager';
import deviceInfo from '@ohos.deviceInfo';
import TouchEventProcessor from '../ohos/TouchEventProcessor';
import { EmbeddingNodeController } from '../ohos/EmbeddingNodeController';
import BuildProfile from '../../../../../BuildProfile';
import { Action } from '../engine/systemchannels/AccessibilityChannel';

const TAG = "FlutterNapi";

enum ContextType {
  APP_LIFECYCLE = 0,
  JS_PAGE_LIFECYCLE,
}

interface PendingMessage {
  channel: string;
  message: ArrayBuffer;
  replyId: number;
  messageData: number;
}

/**
 * 提供arkTs的flutterNAPI接口
 */
export default class FlutterNapi {
  private static hasInit: boolean = false;
  //是否已实现
  hasImplemented: boolean = false;
  nativeShellHolderId: number | null = null;
  platformMessageHandler: PlatformMessageHandler | null = null;
  private engineLifecycleListeners = new Set<EngineLifecycleListener>();
  accessibilityDelegate: AccessibilityDelegate | null = null;
  localizationPlugin: LocalizationPlugin | null = null;
  isDisplayingFlutterUi: boolean = false;
  isPreloadedFlutterUi: boolean = false;
  isRunningDart: boolean = false;
  private nextSpawnNapi: FlutterNapi | null = null;
  private pendingMessages: PendingMessage[] = [];
  private readyForHandleMessage: boolean = true;
  private firstPreloading: boolean = true;

  /**
   * 更新刷新率
   * @param rate
   */
  updateRefreshRate(refreshRateFPS: number) {
    flutter.nativeUpdateRefreshRate(refreshRateFPS);
  }

  updateSize(width: number, height: number) {
    flutter.nativeUpdateSize(width, height);
  }

  updateDensity(densityPixels: number) {
    flutter.nativeUpdateDensity(densityPixels);
  }

  init(context: common.Context,
    args: Array<string>,
    bundlePath: string,
    appStoragePath: string,
    engineCachesPath: string,
    initTimeMillis: number) {
    if (FlutterNapi.hasInit) {
      Log.e(TAG, "the engine has init");
      return;
    }
    Log.d(TAG, "HAR_VERSION=" + BuildProfile.HAR_VERSION);
    Log.d(TAG, JSON.stringify({
      "name": "init, initTimeMillis=" + initTimeMillis,
      "bundlePath": bundlePath,
      "appStoragePath": appStoragePath,
      "engineCachesPath": engineCachesPath,
      "args": args,
    }));
    let code: number | null = flutter.nativeInit(context, args, bundlePath, appStoragePath,
      engineCachesPath, initTimeMillis, deviceInfo.productModel);
    FlutterNapi.hasInit = code == 0;
    Log.d(TAG, "init code=" + code + ", FlutterNapi.hasInit" + FlutterNapi.hasInit);
  }

  static prefetchDefaultFontManager(): void {
    flutter.nativePrefetchDefaultFontManager();
  }

  checkAndReloadFont(): void {
    flutter.nativeCheckAndReloadFont(this.nativeShellHolderId!);
  }

  attachToNative(): void {
    if (!FlutterNapi.hasInit) {
      Log.e(TAG, "attachToNative fail, FlutterNapi.hasInit=" + FlutterNapi.hasInit);
      return;
    }
    if (this.nativeShellHolderId == null) {
      this.nativeShellHolderId = flutter.nativeAttach(this);
    }
    Log.d(TAG, "nativeShellHolderId=" + this.nativeShellHolderId);
  }

  runBundleAndSnapshotFromLibrary(
    bundlePath: string,
    entrypointFunctionName: string | undefined,
    pathToEntrypointFunction: string | undefined,
    assetManager: resourceManager.ResourceManager,
    entrypointArgs: Array<string>) {
    if (!FlutterNapi.hasInit) {
      Log.e(TAG, "runBundleAndSnapshotFromLibrary fail, FlutterNapi.hasInit=" + FlutterNapi.hasInit);
      return;
    }
    Log.d(TAG, "init: bundlePath=" + bundlePath + "  entrypointFunctionName=" + entrypointFunctionName +
      "  pathToEntrypointFunction=" + pathToEntrypointFunction + "  entrypointArgs=" + JSON.stringify(entrypointArgs))
    if (!this.nativeShellHolderId) {
      Log.e(TAG, "runBundleAndSnapshotFromLibrary this.nativeShellHolderId = " + this.nativeShellHolderId)
      return;
    }
    flutter.nativeRunBundleAndSnapshotFromLibrary(this.nativeShellHolderId!, bundlePath, entrypointFunctionName,
      pathToEntrypointFunction, assetManager, entrypointArgs);
    this.isRunningDart = true;
    this.isDisplayingFlutterUi = false;
    this.isPreloadedFlutterUi = false;
  };

  /**
   * 当前so方法是否都实现
   * @returns
   */
  checkImplemented(methodName: string = ""): boolean {
    if (!this.hasImplemented) {
      Log.e(TAG, "this method has not implemented -> " + methodName)
    }
    return this.hasImplemented;
  }

  setPlatformMessageHandler(platformMessageHandler: PlatformMessageHandler | null): void {
    this.ensureRunningOnMainThread();
    this.platformMessageHandler = platformMessageHandler;
  }

  private nativeNotifyLowMemoryWarning(nativeShellHolderId: number): void {

  }

  static nativeLookupCallbackInformation(handle: number): FlutterCallbackInformation | null {
    let callbackInformation = new FlutterCallbackInformation();
    let ret: number = flutter.nativeLookupCallbackInformation(callbackInformation, handle);
    if (ret == 0) {
      return callbackInformation;
    }
    return null;
  }

  notifyLowMemoryWarning(): void {
    this.ensureRunningOnMainThread();
    if (!this.nativeShellHolderId) {
      Log.e(TAG, "notifyLowMemoryWarning this.nativeShellHolderId = " + this.nativeShellHolderId)
      return;
    }
    this.nativeNotifyLowMemoryWarning(this.nativeShellHolderId!);
  }

  isAttached(): boolean {
    return this.nativeShellHolderId != null;
  }

  private ensureRunningOnMainThread(): void {

  }

  dispatchEmptyPlatformMessage(channel: String, responseId: number): void {
    this.ensureRunningOnMainThread();
    if (this.isAttached()) {
      if (!this.nativeShellHolderId) {
        Log.e(TAG, "dispatchEmptyPlatformMessage this.nativeShellHolderId = " + this.nativeShellHolderId)
        return;
      }
      flutter.nativeDispatchEmptyPlatformMessage(this.nativeShellHolderId!, channel, responseId);
    } else {
      Log.w(
        TAG,
        "Tried to send a platform message to Flutter, but FlutterNapi was detached from native C++. Could not send. Channel: "
          + channel
          + ". Response ID: "
          + responseId);
    }
  }

  /** Sends a reply {@code message} from HarmonyOS to Flutter over the given {@code channel}. */
  dispatchPlatformMessage(channel: String, message: ArrayBuffer, position: number, responseId: number): void {
    this.ensureRunningOnMainThread();
    if (this.isAttached()) {
      if (!this.nativeShellHolderId) {
        Log.e(TAG, "dispatchPlatformMessage this.nativeShellHolderId = " + this.nativeShellHolderId)
        return;
      }
      flutter.nativeDispatchPlatformMessage(this.nativeShellHolderId!, channel, message, position, responseId);
    } else {
      Log.w(
        TAG,
        "Tried to send a platform message to Flutter, but FlutterNapi was detached from native C++. Could not send. Channel: "
          + channel
          + ". Response ID: "
          + responseId);
    }
  }

  invokePlatformMessageEmptyResponseCallback(responseId: number): void {
    if (this.isAttached()) {
      if (!this.nativeShellHolderId) {
        Log.e(TAG, "invokePlatformMessageEmptyResponseCallback this.nativeShellHolderId = " + this.nativeShellHolderId)
        return;
      }
      flutter.nativeInvokePlatformMessageEmptyResponseCallback(this.nativeShellHolderId!, responseId);
    } else {
      Log.w(
        TAG,
        "Tried to send a platform message response, but FlutterNapi was detached from native C++. Could not send. Response ID: "
          + responseId);
    }
  }

  invokePlatformMessageResponseCallback(responseId: number, message: ArrayBuffer, position: number) {
    if (this.isAttached()) {
      if (!this.nativeShellHolderId) {
        Log.e(TAG, "this.nativeShellHolderId = " + this.nativeShellHolderId)
        return;
      }
      flutter.nativeInvokePlatformMessageResponseCallback(
        this.nativeShellHolderId!, responseId, message, position);
    } else {
      Log.w(
        TAG,
        "Tried to send a platform message response, but FlutterNapi was detached from native C++. Could not send. Response ID: "
          + responseId);
    }
  }

  setViewportMetrics(devicePixelRatio: number, physicalWidth: number
    , physicalHeight: number, physicalPaddingTop: number, physicalPaddingRight: number
    , physicalPaddingBottom: number, physicalPaddingLeft: number, physicalViewInsetTop: number
    , physicalViewInsetRight: number, physicalViewInsetBottom: number, physicalViewInsetLeft: number
    , systemGestureInsetTop: number, systemGestureInsetRight: number, systemGestureInsetBottom: number
    , systemGestureInsetLeft: number, physicalTouchSlop: number, displayFeaturesBounds: Array<number>
    , displayFeaturesType: Array<number>, displayFeaturesState: Array<number>): void {
    if (this.isAttached()) {
      if (!this.nativeShellHolderId) {
        Log.e(TAG, "setViewportMetrics this.nativeShellHolderId = " + this.nativeShellHolderId)
        return;
      }
      flutter.nativeSetViewportMetrics(this.nativeShellHolderId!, devicePixelRatio,
        physicalWidth,
        physicalHeight,
        physicalPaddingTop,
        physicalPaddingRight,
        physicalPaddingBottom,
        physicalPaddingLeft,
        physicalViewInsetTop,
        physicalViewInsetRight,
        physicalViewInsetBottom,
        physicalViewInsetLeft,
        systemGestureInsetTop,
        systemGestureInsetRight,
        systemGestureInsetBottom,
        systemGestureInsetLeft,
        physicalTouchSlop,
        displayFeaturesBounds,
        displayFeaturesType,
        displayFeaturesState);
    }
  }

  spawn(entrypointFunctionName: string, pathToEntrypointFunction: string, initialRoute: string,
    entrypointArgs: Array<string>): FlutterNapi {
    if (this.nextSpawnNapi) {
      let ret = this.nextSpawnNapi;
      this.nextSpawnNapi = null;
      return ret;
    }
    let flutterNapi = new FlutterNapi();
    let shellHolderId: number =
      flutter.nativeSpawn(this.nativeShellHolderId, entrypointFunctionName, pathToEntrypointFunction, initialRoute,
        entrypointArgs, flutterNapi);
    flutterNapi.nativeShellHolderId = shellHolderId;
    flutterNapi.isRunningDart = this.isRunningDart;
    flutterNapi.isDisplayingFlutterUi = false;
    flutterNapi.isPreloadedFlutterUi = false;
    return flutterNapi;
  }

  preSpawn(entrypointFunctionName: string, pathToEntrypointFunction: string, initialRoute: string,
    entrypointArgs: Array<string>): FlutterNapi {
    if (this.nextSpawnNapi) {
      this.nextSpawnNapi.detachFromNativeAndReleaseResources();
    }
    let flutterNapi = new FlutterNapi();
    let shellHolderId: number =
      flutter.nativeSpawn(this.nativeShellHolderId, entrypointFunctionName, pathToEntrypointFunction, initialRoute,
        entrypointArgs, flutterNapi);
    flutterNapi.nativeShellHolderId = shellHolderId;
    flutterNapi.isRunningDart = this.isRunningDart;
    flutterNapi.isDisplayingFlutterUi = false;
    flutterNapi.isPreloadedFlutterUi = false;
    this.nextSpawnNapi = flutterNapi;
    return flutterNapi;
  }

  addEngineLifecycleListener(engineLifecycleListener: EngineLifecycleListener): void {
    this.engineLifecycleListeners.add(engineLifecycleListener);
  }

  removeEngineLifecycleListener(engineLifecycleListener: EngineLifecycleListener) {
    this.engineLifecycleListeners.delete(engineLifecycleListener);
  }

  //Called by native to respond to a platform message that we sent.
  handlePlatformMessageResponse(replyId: number, reply: ArrayBuffer): void {
    Log.d(TAG, "called handlePlatformMessageResponse Response ID: " + replyId);
    if (this.platformMessageHandler != null) {
      this.platformMessageHandler.handlePlatformMessageResponse(replyId, reply);
    }
  }

  // Called by native on any thread.
  handlePlatformMessage(channel: string, message: ArrayBuffer, replyId: number, messageData: number): void {
    Log.d(TAG, "called handlePlatformMessage Channel: " + channel + ". Response ID: " + replyId);
    if (this.platformMessageHandler != null && this.readyForHandleMessage) {
      this.platformMessageHandler.handleMessageFromDart(channel, message, replyId, messageData);
    } else {
      const pendingMessage: PendingMessage = {
        channel,
        message,
        replyId,
        messageData
      };
      this.pendingMessages.push(pendingMessage);
    }
  }

  setPreloading(): void {
    if (this.firstPreloading) {
      this.readyForHandleMessage = false;
      this.firstPreloading = false;
    }
  }

  processPendingMessages(): void {
    Log.d(TAG, "processPendingMessages len:" + this.pendingMessages.length);
    this.readyForHandleMessage = true;
    while (this.pendingMessages.length > 0 && this.platformMessageHandler) {
      const pendingMessage = this.pendingMessages.shift();
      if (pendingMessage) {
        this.platformMessageHandler.handleMessageFromDart(
          pendingMessage.channel,
          pendingMessage.message,
          pendingMessage.replyId,
          pendingMessage.messageData
        );
      }
    }
  }

  // Called by native to notify first Flutter frame rendered.
  onFirstFrame(isPreload: number): void {
    Log.d(TAG, "called onFirstFrame isPreload:" + isPreload);
    if (isPreload) {
      this.isPreloadedFlutterUi = true;
    } else {
      this.processPendingMessages();
      if (this.isDisplayingFlutterUi) {
        return;
      }
      this.isDisplayingFlutterUi = true;
    }
    FlutterManager.getInstance().getFlutterViewList().forEach((value) => {
      if (this.nativeShellHolderId != null && value.isSameEngineShellHolderId(this.nativeShellHolderId)) {
        value.onFirstFrame(isPreload);
      }
    });
  }

  // Called by native.
  onPreEngineRestart(): void {
    Log.d(TAG, "called onPreEngineRestart")
    this.engineLifecycleListeners.forEach(listener => listener.onPreEngineRestart());
  }

  //  /** Invoked by native to obtain the results of OHOS's locale resolution algorithm. */
  computePlatformResolvedLocale(strings: Array<string>): Array<string> {
    Log.d(TAG, "called computePlatformResolvedLocale " + JSON.stringify(strings))
    return []
  }

  setSemanticsEnabledWithRespId(enabled: boolean, responseId: number): void {
    this.ensureRunningOnMainThread();
    if (this.isAttached()) {
      flutter.nativeSetSemanticsEnabled(this.nativeShellHolderId!, enabled);
    } else {
      Log.w(
        TAG,
        "Tried to send a platform message response, but FlutterNapi was detached from native C++. Could not send. Response ID: "
          + responseId);
    }
  }

  setSemanticsEnabled(enabled: boolean): void {
    this.ensureRunningOnMainThread();
    if (this.isAttached()) {
      flutter.nativeSetSemanticsEnabled(this.nativeShellHolderId!, enabled);
    } else {
      Log.e(
        TAG,
        "Tried to send a platform message response, but FlutterNapi was detached from native C++. Could not send.");
    }
  }

  setAccessibilityFeatures(accessibilityFeatureFlags: number, responseId: number): void {
    if (this.isAttached()) {
      flutter.nativeSetAccessibilityFeatures(accessibilityFeatureFlags, responseId);
    } else {
      Log.w(
        TAG,
        "Tried to send a platform message response, but FlutterNapi was detached from native C++. Could not send. Response ID: "
          + responseId);
    }
  }

  nativeSetAccessibilityFeatures(accessibilityFeatureFlags: number, responseId: number): void {
  }

  dispatchSemanticsAction(virtualViewId: number, action: Action, responseId: number): void {
    if (this.isAttached()) {
      this.nativeDispatchSemanticsAction(virtualViewId, action, responseId);
    } else {
      Log.w(
        TAG,
        "Tried to send a platform message response, but FlutterNapi was detached from native C++. Could not send. Response ID: "
          + responseId);
    }
  }

  nativeDispatchSemanticsAction(virtualViewId: number, action: Action, responseId: number): void {
  }

  setAccessibilityDelegate(delegate: AccessibilityDelegate, responseId: number): void {
    if (this.isAttached()) {
      this.accessibilityDelegate = delegate;
    } else {
      Log.w(
        TAG,
        "Tried to send a platform message response, but FlutterNapi was detached from native C++. Could not send. Response ID: "
          + responseId);
    }
  }

  accessibilityStateChange(state: Boolean): void {
    this.ensureRunningOnMainThread();
    if (this.accessibilityDelegate != null) {
      this.accessibilityDelegate.accessibilityStateChange(state);
    }
    Log.d(TAG, "accessibilityStateChange is called");
    flutter.nativeAccessibilityStateChange(this.nativeShellHolderId!, state);
  }

  setLocalizationPlugin(localizationPlugin: LocalizationPlugin | null): void {
    this.localizationPlugin = localizationPlugin;
  }

  /**
   * 获取系统语言列表
   * @param rate
   */
  getSystemLanguages() {
    Log.d(TAG, "called getSystemLanguages ")
    let index: number;
    let systemLanguages = i18n.System.getPreferredLanguageList();
    for (index = 0; index < systemLanguages.length; index++) {
      Log.d(TAG, "systemlanguages " + index + ":" + systemLanguages[index]);
    }
    if (!this.nativeShellHolderId) {
      Log.e(TAG, "getSystemLanguages this.nativeShellHolderId = " + this.nativeShellHolderId)
      return;
    }
    flutter.nativeGetSystemLanguages(this.nativeShellHolderId!, systemLanguages);
  }

  /**
   * xcomponet绑定flutterEngine
   * @param xcomponentId
   */
  xComponentAttachFlutterEngine(xcomponentId: string) {
    flutter.nativeXComponentAttachFlutterEngine(xcomponentId, this.nativeShellHolderId!);
  }

  /**
   * xcomponet预渲染
   * @param xcomponentId
   */
  xComponentPreDraw(xcomponentId: string, width: number, height: number) {
    flutter.nativeXComponentPreDraw(xcomponentId, this.nativeShellHolderId!, width, height);
  }

  /**
   * xcomponet解除绑定flutterEngine
   * @param xcomponentId
   */
  xComponentDetachFlutterEngine(xcomponentId: string) {
    flutter.nativeXComponentDetachFlutterEngine(xcomponentId, this.nativeShellHolderId!);
  }

  /**
   * xcomponent send mouseWheel event to flutterEngine
   * @param xcomponentId
   * @param eventType
   * @param event
   */
  xComponentDisPatchMouseWheel(xcomponentId: string, eventType: string, event: PanGestureEvent) {
    // only mouse
    if (event.source !== SourceType.Mouse) {
      return;
    }
    const vaildFinger = event.fingerList?.find(item => item.globalX && item.globalY);
    if (!vaildFinger) {
      return;
    }
    flutter.nativeXComponentDispatchMouseWheel(
      this.nativeShellHolderId!!,
      xcomponentId,
      eventType,
      vaildFinger?.id,
      vaildFinger?.localX,
      vaildFinger?.localY,
      event.offsetY,
      event.timestamp
    );
  }

  detachFromNativeAndReleaseResources() {
    if (!this.nativeShellHolderId) {
      Log.e(TAG, "detachFromNativeAndReleaseResources this.nativeShellHolderId = " + this.nativeShellHolderId)
      return;
    }
    flutter.nativeDestroy(this.nativeShellHolderId!!);
    this.nativeShellHolderId = null;
    this.isRunningDart = false;
    this.isDisplayingFlutterUi = false;
    this.isPreloadedFlutterUi = false;
    this.readyForHandleMessage = false;
  }

  unregisterTexture(textureId: number): void {
    Log.d(TAG, "called unregisterTexture ");
    if (!this.nativeShellHolderId) {
      Log.e(TAG, "unregisterTexture this.nativeShellHolderId = " + this.nativeShellHolderId)
      return;
    }
    flutter.nativeUnregisterTexture(this.nativeShellHolderId!, textureId);
  }

  registerPixelMap(textureId: number, pixelMap: PixelMap): void {
    Log.d(TAG, "called registerPixelMap ");
    if (!this.nativeShellHolderId) {
      Log.e(TAG, "registerPixelMap this.nativeShellHolderId = " + this.nativeShellHolderId)
      return;
    }
    flutter.nativeRegisterPixelMap(this.nativeShellHolderId!, textureId, pixelMap);
  }

  setTextureBackGroundPixelMap(textureId: number, pixelMap: PixelMap): void {
    if (this.isAttached()) {
      if (!this.nativeShellHolderId) {
        Log.e(TAG, "this.nativeShellHolderId = " + this.nativeShellHolderId)
        return;
      }
      flutter.nativeSetTextureBackGroundPixelMap(this.nativeShellHolderId!, textureId, pixelMap);
    } else {
      return;
    }
  }

  setTextureBackGroundColor(textureId: number, color: number): void {
    Log.d(TAG, "called setTextureBackGroundColor");
    if (!this.isAttached()) {
      Log.e(TAG, "setTextureBackGroundColor when napi is not attached");
      return;
    }
    flutter.nativeSetTextureBackGroundColor(this.nativeShellHolderId!, textureId, color);
  }

  registerTexture(textureId: number): number {
    Log.d(TAG, "called registerTexture ");
    if (!this.nativeShellHolderId) {
      Log.e(TAG, "registerTexture this.nativeShellHolderId = " + this.nativeShellHolderId)
      return 0;
    }
    return flutter.nativeRegisterTexture(this.nativeShellHolderId!, textureId);
  }

  /**
   * @deprecated since 3.22
   * @useinstead FlutterNapi#getTextureNativeWindowPtr
   */
  getTextureNativeWindowId(textureId: number): number {
    Log.d(TAG, "called getTextureNativeWindowId ");
    if (this.isAttached()) {
      if (!this.nativeShellHolderId) {
        Log.e(TAG, "this.nativeShellHolderId = " + this.nativeShellHolderId)
        return 0;
      }
      return flutter.nativeGetTextureWindowId(this.nativeShellHolderId!, textureId);
    } else {
      return 0;
    }
  }

  getTextureNativeWindowPtr(textureId: number): bigint {
    Log.d(TAG, "called getTextureNativeWindowPtr");
    if (this.isAttached()) {
      if (!this.nativeShellHolderId) {
        Log.e(TAG, "this.nativeShellHolderId = " + this.nativeShellHolderId)
        return BigInt("0");
      }
      return flutter.nativeGetTextureWindowPtr(this.nativeShellHolderId!, textureId);
    } else {
      return BigInt("0");
    }
  }

  /**
   * @deprecated since 3.22
   * @useinstead FlutterNapi#setExternalNativeImagePtr
   */
  setExternalNativeImage(textureId: number, native_image: number): boolean {
    Log.d(TAG, "called setExternalNativeImage ");
    if (this.isAttached()) {
      if (!this.nativeShellHolderId) {
        Log.e(TAG, "this.nativeShellHolderId = " + this.nativeShellHolderId)
        return false;
      }
      return Boolean(flutter.nativeSetExternalNativeImage(this.nativeShellHolderId!, textureId, native_image));
    } else {
      return false;
    }
  }

  setExternalNativeImagePtr(textureId: number, native_image_ptr: bigint): boolean {
    Log.d(TAG, "called setExternalNativeImagePtr");
    if (this.isAttached()) {
      if (!this.nativeShellHolderId) {
        Log.e(TAG, "this.nativeShellHolderId = " + this.nativeShellHolderId)
        return false;
      }
      return Boolean(flutter.nativeSetExternalNativeImagePtr(this.nativeShellHolderId!, textureId, native_image_ptr));
    } else {
      return false;
    }
  }

  resetExternalTexture(textureId: number, need_surfaceId: boolean): number {
    Log.d(TAG, "called resetExternalTexture ");
    if (this.isAttached()) {
      if (!this.nativeShellHolderId) {
        Log.e(TAG, "this.nativeShellHolderId = " + this.nativeShellHolderId)
        return 0;
      }
      return flutter.nativeResetExternalTexture(this.nativeShellHolderId!, textureId, need_surfaceId);
    } else {
      return 0;
    }
  }

  setTextureBufferSize(textureId: number, width: number, height: number): void {
    Log.d(TAG, "called setTextureBufferSize ");
    if (!this.isAttached()) {
      Log.e(TAG, "setTextureBufferSize this.nativeShellHolderId:" + this.nativeShellHolderId)
      return;
    }
    flutter.nativeSetTextureBufferSize(this.nativeShellHolderId!, textureId, width, height);
  }

  notifyTextureResizing(textureId: number, width: number, height: number): void {
    Log.d(TAG, "called notifyTextureResizing ");
    if (!this.isAttached()) {
      Log.e(TAG, "notifyTextureResizing this.nativeShellHolderId:" + this.nativeShellHolderId)
      return;
    }
    flutter.nativeNotifyTextureResizing(this.nativeShellHolderId!, textureId, width, height);
  }

  enableFrameCache(enable: boolean): void {
    if (!this.nativeShellHolderId) {
      return;
    }
    flutter.nativeEnableFrameCache(this.nativeShellHolderId!, enable);
  }

  /** Dispatch Touch Event */
  onTouchEvent(strings: Array<string>): void {
    if (this.isAttached()) {
      TouchEventProcessor.getInstance().postTouchEvent(strings);
    }
  }

  static unicodeIsEmoji(code: number): boolean {
    return Boolean(flutter.nativeUnicodeIsEmoji(code));
  }

  static unicodeIsEmojiModifier(code: number): boolean {
    return Boolean(flutter.nativeUnicodeIsEmojiModifier(code));
  }

  static unicodeIsEmojiModifierBase(code: number): boolean {
    return Boolean(flutter.nativeUnicodeIsEmojiModifierBase(code));
  }

  static unicodeIsVariationSelector(code: number): boolean {
    return Boolean(flutter.nativeUnicodeIsVariationSelector(code));
  }

  static unicodeIsRegionalIndicatorSymbol(code: number): boolean {
    return Boolean(flutter.nativeUnicodeIsRegionalIndicatorSymbol(code));
  }

  setFontWeightScale(fontWeightScale: number): void {
    this.ensureRunningOnMainThread();
    if (this.isAttached()) {
      Log.i(TAG, "setFontWeightScale: " + fontWeightScale);
      flutter.nativeSetFontWeightScale(this.nativeShellHolderId!, fontWeightScale);
    } else {
      Log.w(TAG, "setFontWeightScale is detached !");
    }
  }

  setFlutterNavigationAction(shellHolderId: number, isNavigate: boolean): void {
    this.ensureRunningOnMainThread();
    if (this.isAttached()) {
      Log.i(TAG, "setFlutterNavigationAction: " + isNavigate);
      flutter.nativeSetFlutterNavigationAction(shellHolderId, isNavigate);
    } else {
      Log.w(TAG, "setFlutterNavigationAction is detached !");
    }
  }

  SetDVsyncSwitch(isEnable: boolean): void {
    flutter.nativeSetDVsyncSwitch(this.nativeShellHolderId!, isEnable);
  }

  /*
  * 发送屏幕滑动速度
  * @param velocity: 当前屏幕滑动速度
  */
  static animationVoting(type: number, velocity: number): void {
    flutter.nativeAnimationVoting(type, velocity);
  }

  /*
  * 发送视频帧数
  * @param seconds: 秒数
  * @param frameCount: 一定时间内的帧数
  */
  static videoVoting(seconds: number, frameCount: number): void {
    flutter.nativeVideoVoting(seconds, frameCount);
  }

  /*
  * 预加载帧率配置文件
  */
  static prefetchFramesCfg(): void {
    flutter.nativePrefetchFramesCfg();
  }

  /*
  * 查询ltpo功能开启状态
  */
  static checkLTPOSwitchState(): number {
    return flutter.nativeCheckLTPOSwitchState();
  }
}

export interface AccessibilityDelegate {
  accessibilityStateChange(state: Boolean): void;
}
