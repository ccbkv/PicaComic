/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/

import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import { FlutterAbilityAndEntryDelegate, Host } from './FlutterAbilityAndEntryDelegate';
import Log from '../../util/Log';
import FlutterEngine from '../engine/FlutterEngine';
import PlatformPlugin from '../../plugin/PlatformPlugin';
import FlutterShellArgs from '../engine/FlutterShellArgs';
import FlutterAbilityLaunchConfigs from './FlutterAbilityLaunchConfigs';
import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import { FlutterPlugin } from '../engine/plugins/FlutterPlugin';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import I18n from '@ohos.i18n'
import { PlatformBrightness } from '../engine/systemchannels/SettingsChannel';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';
import { Configuration } from '@ohos.app.ability.Configuration';
import { deviceInfo } from '@kit.BasicServicesKit';
import ExclusiveAppComponent from './ExclusiveAppComponent';
import errorManager from '@ohos.app.ability.errorManager';
import appRecovery from '@ohos.app.ability.appRecovery';
import FlutterManager from './FlutterManager';
import { FlutterView } from '../../view/FlutterView';
import ApplicationInfoLoader from '../engine/loader/ApplicationInfoLoader';
import { accessibility } from '@kit.AccessibilityKit';

const TAG = "FlutterAbility";

/**
 * flutter ohos基础ability，请在让主ability继承自该类。
 * 该类主要职责：
 * 1、持有FlutterAbilityDelegate并初始化；
 * 2、生命周期传递；
 */
export class FlutterAbility extends UIAbility implements Host {
  private delegate?: FlutterAbilityAndEntryDelegate | null;
  private flutterView: FlutterView | null = null;
  private mainWindow?: window.Window | null;
  private errorManagerId: number = 0;

  getFlutterView(): FlutterView | null {
    return this.flutterView;
  }

  pagePath(): string {
    return "pages/Index"
  }

  /**
   * 可重写该方法，自定义FlutterAbility是否全屏；
   * 默认值，根据设备类型，判断是否需要全屏
   */
  isDefaultFullScreen(): boolean {
    return deviceInfo.deviceType != '2in1';
  }

  /**
   * onCreate
   * 1、create and attach delegate
   * 2、config windows transparent noNeed?
   * 3、lifecycle.onCreate
   * 4. setContentView()  noNeed
   */
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
    // 冷启动通过上下文环境获取到系统当前文字大小，并进行键值存储
    AppStorage.setOrCreate('fontSizeScale', this.context.config.fontSizeScale);
    Log.i(TAG, "this.context.config.fontSizeScale = " + this.context.config.fontSizeScale);

    Log.i(TAG, "bundleCodeDir=" + this.context.bundleCodeDir);
    FlutterManager.getInstance().pushUIAbility(this)

    this.delegate = new FlutterAbilityAndEntryDelegate(this);
    this?.delegate?.onAttach(this.context);
    Log.i(TAG, 'onAttach end');
    this?.delegate?.platformPlugin?.setUIAbilityContext(this.context);
    this?.delegate?.onRestoreInstanceState(want);

    if (this.stillAttachedForEvent("onWindowStageCreate")) {
      this?.delegate?.onWindowStageCreate();
    }

    Log.i(TAG, 'MyAbility onCreate');

    let observer: errorManager.ErrorObserver = {
      onUnhandledException(errorMsg) {
        Log.e(TAG, "onUnhandledException, errorMsg:", errorMsg);
        appRecovery.saveAppState();
        appRecovery.restartApp();
      }
    }
    this.errorManagerId = errorManager.on('error', observer);

    let flutterApplicationInfo = ApplicationInfoLoader.load(this.context);

    if (flutterApplicationInfo.isDebugMode) {
      this.delegate?.initWindow();
    }
  }

  onDestroy() {
    FlutterManager.getInstance().popUIAbility(this);

    errorManager.off('error', this.errorManagerId);

    if (this.flutterView != null) {
      this.flutterView.onDestroy()
      this.flutterView = null;
    }

    if (this.stillAttachedForEvent("onDestroy")) {
      this?.delegate?.onDetach();
    }

    this.release()
  }

  onSaveState(reason: AbilityConstant.StateType, wantParam: Record<string, Object>): AbilityConstant.OnSaveResult {
    return this?.delegate?.onSaveState(reason, wantParam) ?? AbilityConstant.OnSaveResult.ALL_REJECT;
  }

  protected windowStageEventCallback = (data: window.WindowStageEventType) => {
    this.delegate?.onWindowStageChanged(data)
  }

  /**
   * window状态改变回调
   * @param windowStage
   */
  onWindowStageCreate(windowStage: window.WindowStage) {
    FlutterManager.getInstance().pushWindowStage(this, windowStage);
    this.delegate?.initWindow();
    this.mainWindow = windowStage.getMainWindowSync();
    try {
      windowStage.on('windowStageEvent', this.windowStageEventCallback);
      this.flutterView = this.delegate!!.createView(this.context)
      Log.i(TAG, 'onWindowStageCreate:' + this.flutterView!!.getId());
      let storage: LocalStorage = new LocalStorage();
      storage.setOrCreate("viewId", this.flutterView!!.getId())
      windowStage.loadContent(this.pagePath(), storage, (err, data) => {
        if (err.code) {
          Log.e(TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
          return;
        }
        this.flutterView?.onWindowCreated();

        Log.i(TAG, 'Succeeded in loading the content. Data: %{public}s', JSON.stringify(data) ?? '');
      });
      if (this.isDefaultFullScreen()) {
        FlutterManager.getInstance().setUseFullScreen(true, this.context);
      }
    } catch (exception) {
      Log.e(TAG, 'Failed to enable the listener for window stage event changes. Cause:' + JSON.stringify(exception));
    }
  }

  onNewWant(want: Want, launchParams: AbilityConstant.LaunchParam): void {
    this?.delegate?.onNewWant(want, launchParams)
  }

  onWindowStageDestroy() {
    FlutterManager.getInstance().popWindowStage(this);
    if (this.stillAttachedForEvent("onWindowStageDestroy")) {
      this?.delegate?.onWindowStageDestroy();
    }
  }

  onForeground() {
    if (this.stillAttachedForEvent("onForeground")) {
      this?.delegate?.onShow();
    }
  }

  onBackground() {
    if (this.stillAttachedForEvent("onBackground")) {
      this?.delegate?.onHide();
    }
  }

  onWindowStageWillDestroy(windowStage: window.WindowStage) {
    try {
      windowStage.off('windowStageEvent', this.windowStageEventCallback);
    } catch (err) {
      Log.e(TAG, "windowStage off failed");
    }
  }

  release() {
    if (this?.delegate != null) {
      this?.delegate?.release();
      this.delegate = null;
    }
  }

  /**
   * host所有实现方法开始======start
   */

  getAbility(): UIAbility {
    return this;
  }

  getFlutterAbilityAndEntryDelegate(): FlutterAbilityAndEntryDelegate | null {
    return this.delegate ?? null;
  }

  shouldDispatchAppLifecycleState(): boolean {
    return true;
  }

  provideFlutterEngine(context: common.Context): FlutterEngine | null {
    return null;
  }

  providePlatformPlugin(flutterEngine: FlutterEngine): PlatformPlugin | undefined {
    return new PlatformPlugin(flutterEngine.getPlatformChannel()!, this.context, this);
  }

  configureFlutterEngine(flutterEngine: FlutterEngine) {

  }

  cleanUpFlutterEngine(flutterEngine: FlutterEngine) {

  }

  getFlutterShellArgs(): FlutterShellArgs {
    return FlutterShellArgs.fromWant(this.getWant());
  }

  getDartEntrypointArgs(): Array<string> {
    if (this.launchWant.parameters![FlutterAbilityLaunchConfigs.EXTRA_DART_ENTRYPOINT_ARGS]) {
      return this.launchWant.parameters![FlutterAbilityLaunchConfigs.EXTRA_DART_ENTRYPOINT_ARGS] as Array<string>;
    }
    return new Array<string>()
  }

  detachFromFlutterEngine() {
    if (this?.delegate != null) {
      this?.delegate?.onDetach();
    }
  }

  popSystemNavigator(): boolean {
    return false;
  }

  shouldAttachEngineToAbility(): boolean {
    return true;
  }

  getDartEntrypointLibraryUri(): string {
    return "";
  }

  getAppBundlePath(): string {
    return "";
  }

  getDartEntrypointFunctionName(): string {
    if (this.launchWant.parameters![FlutterAbilityLaunchConfigs.EXTRA_DART_ENTRYPOINT]) {
      return this.launchWant.parameters![FlutterAbilityLaunchConfigs.EXTRA_DART_ENTRYPOINT] as string;
    }
    return FlutterAbilityLaunchConfigs.DEFAULT_DART_ENTRYPOINT
  }

  getInitialRoute(): string {
    if (this.launchWant.parameters![FlutterAbilityLaunchConfigs.EXTRA_INITIAL_ROUTE]) {
      return this.launchWant.parameters![FlutterAbilityLaunchConfigs.EXTRA_INITIAL_ROUTE] as string;
    }
    return ""
  }

  getWant(): Want {
    return this.launchWant;
  }

  shouldDestroyEngineWithHost(): boolean {
    if ((this.getCachedEngineId() != null && this.getCachedEngineId().length > 0) ||
    this.delegate!!.isFlutterEngineFromHost()) {
      // Only destroy a cached engine if explicitly requested by app developer.
      return false;
    }
    return true;
  }

  attachToEngineAutomatically(): boolean {
    return true;
  }

  shouldRestoreAndSaveState(): boolean {
    if (this.launchWant.parameters![FlutterAbilityLaunchConfigs.EXTRA_CACHED_ENGINE_ID] != undefined) {
      return this.launchWant.parameters![FlutterAbilityLaunchConfigs.EXTRA_CACHED_ENGINE_ID] as boolean;
    }
    if (this.getCachedEngineId() != null && this.getCachedEngineId().length > 0) {
      // Prevent overwriting the existing state in a cached engine with restoration state.
      return false;
    }
    return true;
  }

  getExclusiveAppComponent(): ExclusiveAppComponent<UIAbility> | null {
    return this.delegate ? this.delegate : null
  }

  getCachedEngineId(): string {
    return this.launchWant.parameters![FlutterAbilityLaunchConfigs.EXTRA_CACHED_ENGINE_ID] as string
  }

  getCachedEngineGroupId(): string | null {
    return this.launchWant.parameters![FlutterAbilityLaunchConfigs.EXTRA_CACHED_ENGINE_GROUP_ID] as string
  }

  /**
   * host所有实现方法结束======end
   */
  private stillAttachedForEvent(event: string) {
    Log.i(TAG, 'Ability ' + event);
    if (this?.delegate == null) {
      Log.w(TAG, "FlutterAbility " + event + " call after release.");
      return false;
    }
    if (!this?.delegate?.isAttached) {
      Log.w(TAG, "FlutterAbility " + event + " call after detach.");
      return false;
    }
    return true;
  }

  addPlugin(plugin: FlutterPlugin): void {
    if (this?.delegate != null) {
      this?.delegate?.addPlugin(plugin)
    }
  }

  removePlugin(plugin: FlutterPlugin): void {
    if (this?.delegate != null) {
      this?.delegate?.removePlugin(plugin)
    }
  }

  onMemoryLevel(level: AbilityConstant.MemoryLevel): void {
    Log.i(TAG, 'onMemoryLevel: ' + level);
    if (level === AbilityConstant.MemoryLevel.MEMORY_LEVEL_CRITICAL) {
      this?.delegate?.onLowMemory();
    }
  }

  onConfigurationUpdate(config: Configuration) {
    Log.i(TAG, 'onConfigurationUpdate config:' + JSON.stringify(config));
    this?.delegate?.flutterEngine?.getSettingsChannel()?.startMessage()
      .setNativeSpellCheckServiceDefined(false)
      .setBrieflyShowPassword(false)
      .setAlwaysUse24HourFormat(I18n.System.is24HourClock())
      .setPlatformBrightness(config.colorMode != ConfigurationConstant.ColorMode.COLOR_MODE_DARK
        ? PlatformBrightness.LIGHT : PlatformBrightness.DARK)
      .setTextScaleFactor(config.fontSizeScale == undefined ? 1.0 : config.fontSizeScale)
      .send(); //热启动生命周期内，实时监听系统设置环境改变并实时发送相应信息

    //实时获取系统字体加粗系数
    this.delegate?.getFlutterNapi()?.setFontWeightScale(config.fontWeightScale == undefined ? 0 :
    config.fontWeightScale);
    Log.i(TAG, 'fontWeightScale: ' + JSON.stringify(config.fontWeightScale));

    if (config.language != '') {
      this.getFlutterEngine()?.getLocalizationPlugin()?.sendLocaleToFlutter();
    }
    this?.delegate?.onCheckAndReloadFont();

  }

  getFlutterEngine(): FlutterEngine | null {
    return this.delegate?.flutterEngine || null;
  }
}