/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/

import common from '@ohos.app.ability.common';
import FlutterEngineConfigurator from './FlutterEngineConfigurator';
import FlutterEngineProvider from './FlutterEngineProvider';
import FlutterEngine from '../engine/FlutterEngine';
import PlatformPlugin, { PlatformPluginDelegate } from '../../plugin/PlatformPlugin';
import Want from '@ohos.app.ability.Want';
import FlutterShellArgs from '../engine/FlutterShellArgs';
import DartExecutor, { DartEntrypoint } from '../engine/dart/DartExecutor';
import FlutterAbilityLaunchConfigs from './FlutterAbilityLaunchConfigs';
import Log from '../../util/Log';
import FlutterInjector from '../../FlutterInjector';
import UIAbility from '@ohos.app.ability.UIAbility';
import ExclusiveAppComponent from './ExclusiveAppComponent';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import { FlutterPlugin } from '../engine/plugins/FlutterPlugin';
import FlutterEngineCache from '../engine/FlutterEngineCache';
import FlutterEngineGroupCache from '../engine/FlutterEngineGroupCache';
import FlutterEngineGroup, { Options } from '../engine/FlutterEngineGroup';
import FlutterNapi from '../engine/FlutterNapi';
import { FlutterView } from '../../view/FlutterView';
import FlutterManager from './FlutterManager';
import Any from '../../plugin/common/Any';
import inputMethod from '@ohos.inputMethod';
import window from '@ohos.window';

const TAG = "FlutterAbilityDelegate";
const PLUGINS_RESTORATION_BUNDLE_KEY = "plugins";
const FRAMEWORK_RESTORATION_BUNDLE_KEY = "framework";

/**
 * 主要职责：
 * 1、初始化engine
 * 2、处理ability生命周期回调
 */
class FlutterAbilityAndEntryDelegate implements ExclusiveAppComponent<UIAbility> {
  protected host?: Host | null;
  flutterEngine?: FlutterEngine | null;
  platformPlugin?: PlatformPlugin;
  protected context?: common.Context;
  protected isFlutterEngineFromHostOrCache: boolean = false;
  private engineGroup?: FlutterEngineGroup;
  private isHost: boolean = false;
  private flutterView?: FlutterView;
  private inputMethodController: inputMethod.InputMethodController = inputMethod.getController();

  constructor(host?: Host) {
    this.host = host;
    if (this.host) {
      this.isHost = true;
    }
  }

  /**
   * 是否还attach在ability上
   */
  isAttached = false;

  onAttach(context: common.Context) {
    this.context = context;
    this.ensureAlive();
    if (this.flutterEngine == null) {
      this.setupFlutterEngine();
    }

    if (this.host?.shouldAttachEngineToAbility()) {
      // Notify any plugins that are currently attached to our FlutterEngine that they
      // are now attached to an Ability.
      Log.d(TAG, "Attaching FlutterEngine to the Ability that owns this delegate.");
      this.flutterEngine?.getAbilityControlSurface()?.attachToAbility(this);
    }

    this.platformPlugin = this.host?.providePlatformPlugin(this.flutterEngine!)

    this.isAttached = true;
    if (this.flutterEngine) {
      this.flutterEngine.getSystemLanguages();
    }
    if (this.flutterEngine && this.flutterView && this.host?.attachToEngineAutomatically()) {
      this.flutterView.attachToFlutterEngine(this.flutterEngine!!);
    }
    this.host?.configureFlutterEngine(this.flutterEngine!!);
    if (this.flutterEngine) {
      this.flutterEngine.processPendingMessages();
    }
  }

  /**
   * 加载app.so资源或者snapshot
   */
  private doInitialFlutterViewRun(): void {
    let initialRoute = this.host?.getInitialRoute();
    if (initialRoute == null && this.host != null) {
      initialRoute = this.maybeGetInitialRouteFromIntent(this.host.getWant());

    }
    if (initialRoute == null) {
      initialRoute = FlutterAbilityLaunchConfigs.DEFAULT_INITIAL_ROUTE;
    }
    const libraryUri = this.host?.getDartEntrypointLibraryUri();
    Log.d(TAG,
      "Executing Dart entrypoint: " + this.host?.getDartEntrypointFunctionName() + ", library uri: " + libraryUri ==
        null ? "\"\"" : libraryUri + ", and sending initial route: " + initialRoute);

    // The engine needs to receive the Flutter app's initial route before executing any
    // Dart code to ensure that the initial route arrives in time to be applied.
    this.flutterEngine?.getNavigationChannel()?.setInitialRoute(initialRoute ?? '');

    let appBundlePathOverride = this.host?.getAppBundlePath();
    if (appBundlePathOverride == null || appBundlePathOverride == '') {
      appBundlePathOverride = FlutterInjector.getInstance().getFlutterLoader().findAppBundlePath();
    }

    const dartEntrypoint: DartEntrypoint = new DartEntrypoint(
      appBundlePathOverride,
      this.host?.getDartEntrypointLibraryUri() ?? '',
      this.host?.getDartEntrypointFunctionName() ?? ''
    );
    this.flutterEngine?.dartExecutor.executeDartEntrypoint(dartEntrypoint, this.host?.getDartEntrypointArgs());
  }

  private maybeGetInitialRouteFromIntent(want: Want): string {
    return '';
  }

  /**
   * 通过参数，配置flutterEngine
   * @param want
   */
  onRestoreInstanceState(want: Want) {
    let frameworkState: Uint8Array = this.getRestorationData(want.parameters as Record<string, Object>);
    if (this.host?.shouldRestoreAndSaveState()) {
      this.flutterEngine?.getRestorationChannel()?.setRestorationData(frameworkState);
    }
  }

  private getRestorationData(wantParam: Record<string, Object>): Uint8Array {
    let result: Uint8Array = new Uint8Array(1).fill(0);
    if (wantParam == null) {
      return result;
    }
    if (wantParam[FRAMEWORK_RESTORATION_BUNDLE_KEY] == undefined) {
      return result
    }
    if (typeof wantParam[FRAMEWORK_RESTORATION_BUNDLE_KEY] == 'object') {
      let data: Record<string, Any> = wantParam[FRAMEWORK_RESTORATION_BUNDLE_KEY] as Record<string,
      Any>;
      let byteArray: Array<number> = new Array;
      Object.keys(data).forEach(
        key => {
          byteArray.push(data[key]);
        }
      );
      result = Uint8Array.from(byteArray);
    }
    return result;
  }

  /**
   * 初始化flutterEngine
   */
  setupFlutterEngine() {
    // First, check if the host wants to use a cached FlutterEngine.
    const cachedEngineId = this.host?.getCachedEngineId();
    Log.d(TAG, "cachedEngineId=" + cachedEngineId);
    if (cachedEngineId && cachedEngineId.length > 0) {
      this.flutterEngine = FlutterEngineCache.getInstance().get(cachedEngineId);
      this.isFlutterEngineFromHostOrCache = true;
      if (this.flutterEngine == null) {
        throw new Error(
          "The requested cached FlutterEngine did not exist in the FlutterEngineCache: '"
            + cachedEngineId
            + "'");
      }
      return;
    }

    // Second, defer to subclasses for a custom FlutterEngine.
    if (this.host && this.context) {
      this.flutterEngine = this.host.provideFlutterEngine(this.context);
    }
    if (this.flutterEngine != null) {
      this.isFlutterEngineFromHostOrCache = true;
      return;
    }

    // Third, check if the host wants to use a cached FlutterEngineGroup
    // and create new FlutterEngine using FlutterEngineGroup#createAndRunEngine
    const cachedEngineGroupId = this.host?.getCachedEngineGroupId();
    Log.d(TAG, "cachedEngineGroupId=" + cachedEngineGroupId);
    if (cachedEngineGroupId != null) {
      const flutterEngineGroup = FlutterEngineGroupCache.instance.get(cachedEngineGroupId);
      if (flutterEngineGroup == null) {
        throw new Error(
          "The requested cached FlutterEngineGroup did not exist in the FlutterEngineGroupCache: '"
            + cachedEngineGroupId
            + "'");
      }

      if (this.context != null) {
        this.flutterEngine = flutterEngineGroup.createAndRunEngineByOptions(
          this.addEntrypointOptions(new Options(this.context)));
      }
      this.isFlutterEngineFromHostOrCache = false;
      return;
    }

    // Our host did not provide a custom FlutterEngine. Create a FlutterEngine to back our
    // FlutterView.
    Log.d(
      TAG,
      "No preferred FlutterEngine was provided. Creating a new FlutterEngine for this FlutterAbility.");

    let group = this.engineGroup;
    if (group == null && this.context != null) {
      group = new FlutterEngineGroup();
      const flutterShellArgs = this.host ? this.host.getFlutterShellArgs() : new FlutterShellArgs();
      group.checkLoader(this.context, flutterShellArgs.toArray() ?? []);
      this.engineGroup = group;
    }
    if (this.context) {
      this.flutterEngine = group?.createAndRunEngineByOptions(this.addEntrypointOptions(new Options(this.context)
        .setWaitForRestorationData(this.host?.shouldRestoreAndSaveState() || false)));
    }
    this.isFlutterEngineFromHostOrCache = false;
  }

  addEntrypointOptions(options: Options): Options {
    let appBundlePathOverride = this.host?.getAppBundlePath();
    if (appBundlePathOverride == null || appBundlePathOverride.length == 0) {
      appBundlePathOverride = FlutterInjector.getInstance().getFlutterLoader().findAppBundlePath();
    }

    const dartEntrypoint = new DartEntrypoint(appBundlePathOverride ?? '',
      '',
      this.host?.getDartEntrypointFunctionName() ?? '');
    let initialRoute = this.host?.getInitialRoute();
    if (initialRoute == null && this.host != null) {
      initialRoute = this.maybeGetInitialRouteFromIntent(this.host.getWant());
    }
    if (initialRoute == null) {
      initialRoute = FlutterAbilityLaunchConfigs.DEFAULT_INITIAL_ROUTE;
    }
    return options
      .setDartEntrypoint(dartEntrypoint)
      .setInitialRoute(initialRoute)
      .setDartEntrypointArgs(this.host?.getDartEntrypointArgs() ?? []);
  }

  createView(context: Context): FlutterView {
    this.flutterView = FlutterManager.getInstance().createFlutterView(context)
    if (this.flutterEngine && this.host?.attachToEngineAutomatically()) {
      this.flutterView.attachToFlutterEngine(this.flutterEngine!!);
    }
    return this.flutterView
  }

  /**
   * 释放所有持有对象
   */
  release() {
    this.host = null;
    this.flutterEngine = null;
    this.platformPlugin = undefined;
  }

  onDetach() {
    if (this.host?.shouldAttachEngineToAbility()) {
      // Notify plugins that they are no longer attached to an Ability.
      Log.d(TAG, "Detaching FlutterEngine from the Ability");
      this.flutterEngine?.getAbilityControlSurface()?.detachFromAbility();
    }
    this.flutterView?.detachFromFlutterEngine();
    this.host?.cleanUpFlutterEngine(this.flutterEngine!!);

    if (this.host?.shouldDispatchAppLifecycleState() && this.flutterEngine != null) {
      this.flutterEngine?.getLifecycleChannel()?.appIsDetached();
    }

    if (this.platformPlugin) {
      this.platformPlugin.destroy();
    }

    // Destroy our FlutterEngine if we're not set to retain it.
    if (this.host?.shouldDestroyEngineWithHost()) {
      this.flutterEngine?.destroy();
      if (this.host.getCachedEngineId() != null && this.host.getCachedEngineId().length > 0) {
        FlutterEngineCache.getInstance().remove(this.host.getCachedEngineId());
      }
      this.flutterEngine = null;
    }

    this.isAttached = false;
  }

  onLowMemory(): void {
    this.getFlutterNapi()?.notifyLowMemoryWarning();
    this.flutterEngine?.getSystemChannel()?.sendMemoryPressureWarning();
  }

  /**
   * 生命周期回调
   */

  onWindowStageCreate() {
    this.ensureAlive();
    this.doInitialFlutterViewRun();
  }

  onWindowStageDestroy() {

  }

  onWindowStageChanged(stageEventType: window.WindowStageEventType) {
    switch (stageEventType) {
      case window.WindowStageEventType.SHOWN:
        Log.i(TAG, 'windowStage shown.');
        break;
      case window.WindowStageEventType.ACTIVE: // 获焦状态
        Log.i(TAG, 'windowStage active.');
        this.getFlutterEngine()?.getTextInputChannel()?.textInputMethodHandler?.handleChangeFocus(true);
        this.onWindowFocusChanged(true);
        break;
      case window.WindowStageEventType.INACTIVE: // 失焦状态
        Log.i(TAG, 'windowStage inactive.');
        this.onWindowFocusChanged(false);
        break;
      case window.WindowStageEventType.PAUSED:
        Log.i(TAG, 'windowStage paused.');
        this.onPaused();
        break;
      case window.WindowStageEventType.RESUMED:
        Log.i(TAG, 'windowStage resumed.');
        this.onResumed();
        break;
      case window.WindowStageEventType.HIDDEN:
        Log.i(TAG, 'windowStage hidden.');
        break;
    }
  }

  onWindowFocusChanged(hasFocus: boolean): void {
    if (this.shouldDispatchAppLifecycleState()) {
      this.flutterEngine?.getAbilityControlSurface()?.onWindowFocusChanged(hasFocus);
      if (hasFocus) {
        this.flutterEngine?.getLifecycleChannel()?.aWindowIsFocused();
      } else {
        this.flutterEngine?.getLifecycleChannel()?.noWindowsAreFocused();
      }
    }
  }

  onShow() {
    this.ensureAlive();
    if (this.shouldDispatchAppLifecycleState()) {
      this.flutterEngine?.getLifecycleChannel()?.appIsResumed();
    }
  }

  onPaused() {
    if (this.shouldDispatchAppLifecycleState()) {
      this.flutterEngine?.getLifecycleChannel()?.appIsInactive();
    }
  }

  onResumed() {
    if (this.shouldDispatchAppLifecycleState()) {
      this.flutterEngine?.getLifecycleChannel()?.appIsResumed();
    }
  }

  onHide() {
    if (this.shouldDispatchAppLifecycleState()) {
      this.flutterEngine?.getLifecycleChannel()?.appIsPaused();
    }
  }

  onCheckAndReloadFont() {
    this.getFlutterNapi()?.checkAndReloadFont();
  }

  /**
   * 生命周期回调结束
   */

  shouldDispatchAppLifecycleState(): boolean {
    if (!this.isHost) {
      return this.isAttached;
    }
    if (this.host == null) {
      return false;
    }
    return this.host.shouldDispatchAppLifecycleState() && this.isAttached;
  }

  ensureAlive() {
    if (this.isHost && this.host == null) {
      throw new Error("Cannot execute method on a destroyed FlutterAbilityDelegate.");
    }
  }

  getFlutterNapi(): FlutterNapi | null {
    return this.flutterEngine?.getFlutterNapi() ?? null
  }

  getFlutterEngine(): FlutterEngine | null {
    return this.flutterEngine ?? null;
  }

  detachFromFlutterEngine() {
    if (this.host?.shouldDestroyEngineWithHost()) {
      // The host owns the engine and should never have its engine taken by another exclusive
      // ability.
      throw new Error(
        "The internal FlutterEngine created by "
          + this.host
          + " has been attached to by another Ability. To persist a FlutterEngine beyond the "
          + "ownership of this ability, explicitly create a FlutterEngine");
    }

    // Default, but customizable, behavior is for the host to call {@link #onDetach}
    // deterministically as to not mix more events during the lifecycle of the next exclusive
    // ability.
    this.host?.detachFromFlutterEngine();
  }

  getAppComponent(): UIAbility {
    const ability = this.host?.getAbility();
    if (ability == null) {
      throw new Error(
        "FlutterAbilityAndFragmentDelegate's getAppComponent should only "
          + "be queried after onAttach, when the host's ability should always be non-null");
    }
    return ability;
  }

  onNewWant(want: Want, launchParams: AbilityConstant.LaunchParam): void {
    this.ensureAlive()
    if (this.flutterEngine != null) {
      Log.i(TAG, "Forwarding onNewWant() to FlutterEngine and sending pushRouteInformation message.");
      this.flutterEngine?.getAbilityControlSurface()?.onNewWant(want, launchParams);
      const initialRoute = this.maybeGetInitialRouteFromIntent(want);
      if (initialRoute && initialRoute.length > 0) {
        this.flutterEngine?.getNavigationChannel()?.pushRouteInformation(initialRoute);
      }
    } else {
      Log.w(TAG, "onNewIntent() invoked before FlutterFragment was attached to an Ability.");
    }
  }

  onSaveState(reason: AbilityConstant.StateType, wantParam: Record<string, Object>): AbilityConstant.OnSaveResult {
    Log.i(TAG, "onSaveInstanceState. Giving framework and plugins an opportunity to save state.");
    this.ensureAlive();
    if (this.host?.shouldRestoreAndSaveState()) {
      wantParam[FRAMEWORK_RESTORATION_BUNDLE_KEY] = this.flutterEngine!.getRestorationChannel()!.getRestorationData();
    }
    if (this.host?.shouldAttachEngineToAbility()) {
      const plugins: Record<string, Object> = {}
      const result = this.flutterEngine?.getAbilityControlSurface()?.onSaveState(reason, plugins);
      wantParam[PLUGINS_RESTORATION_BUNDLE_KEY] = plugins;
      return result ?? AbilityConstant.OnSaveResult.ALL_REJECT
    }
    return AbilityConstant.OnSaveResult.ALL_REJECT
  }

  addPlugin(plugin: FlutterPlugin): void {
    this.flutterEngine?.getPlugins()?.add(plugin)
  }

  removePlugin(plugin: FlutterPlugin): void {
    this.flutterEngine?.getPlugins()?.remove(plugin.getUniqueClassName())
  }

  isFlutterEngineFromHost(): boolean {
    return this.isFlutterEngineFromHostOrCache;
  }

  initWindow() {
    if (this.flutterEngine && this.isAttached) {
      this.platformPlugin?.initWindow()
    }
  }
}

/**
 * FlutterAbility句柄
 */
interface Host extends FlutterEngineProvider, FlutterEngineConfigurator, PlatformPluginDelegate {

  getAbility(): UIAbility;

  shouldDispatchAppLifecycleState(): boolean;

  detachFromFlutterEngine(): void;

  shouldAttachEngineToAbility(): boolean;

  getCachedEngineId(): string;

  getCachedEngineGroupId(): string | null;

  /**
   * Returns true if the {@link io.flutter.embedding.engine.FlutterEngine} used in this delegate
   * should be destroyed when the host/delegate are destroyed.
   */
  shouldDestroyEngineWithHost(): boolean;

  /** Returns the {@link FlutterShellArgs} that should be used when initializing Flutter. */
  getFlutterShellArgs(): FlutterShellArgs;

  /** Returns arguments that passed as a list of string to Dart's entrypoint function. */
  getDartEntrypointArgs(): Array<string>;

  /**
   * Returns the URI of the Dart library which contains the entrypoint method (example
   * "package:foo_package/main.dart"). If null, this will default to the same library as the
   * `main()` function in the Dart program.
   */
  getDartEntrypointLibraryUri(): string;

  /** Returns the path to the app bundle where the Dart code exists. */
  getAppBundlePath(): string;

  /**
   * Returns the Dart entrypoint that should run when a new {@link
   * io.flutter.embedding.engine.FlutterEngine} is created.
   */
  getDartEntrypointFunctionName(): string;

  /** Returns the initial route that Flutter renders. */
  getInitialRoute(): string;

  getWant(): Want;

  shouldRestoreAndSaveState(): boolean;

  getExclusiveAppComponent(): ExclusiveAppComponent<UIAbility> | null

  providePlatformPlugin(flutterEngine: FlutterEngine): PlatformPlugin | undefined

  /**
   * Whether to automatically attach the {@link FlutterView} to the engine.
   *
   * <p>In the add-to-app scenario where multiple {@link FlutterView} share the same {@link
   * FlutterEngine}, the host application desires to determine the timing of attaching the {@link
   * FlutterView} to the engine, for example, during the {@code onResume} instead of the {@code
   * onCreateView}.
   *
   * <p>Defaults to {@code true}.
   */
  attachToEngineAutomatically(): boolean;
}

export { Host, FlutterAbilityAndEntryDelegate }