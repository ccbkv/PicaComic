/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/

import FlutterEngine from '../engine/FlutterEngine';
import PlatformPlugin from '../../plugin/PlatformPlugin';
import Want from '@ohos.app.ability.Want';
import FlutterShellArgs from '../engine/FlutterShellArgs';
import UIAbility from '@ohos.app.ability.UIAbility';
import ExclusiveAppComponent from './ExclusiveAppComponent';
import { FlutterAbilityAndEntryDelegate, Host } from './FlutterAbilityAndEntryDelegate';
import FlutterAbilityLaunchConfigs from './FlutterAbilityLaunchConfigs';
import Log from '../../util/Log';
import { FlutterView } from '../../view/FlutterView';
import FlutterManager from './FlutterManager';
import window from '@ohos.window';
import FlutterEngineConfigurator from './FlutterEngineConfigurator';
import { FlutterPlugin } from '../engine/plugins/FlutterPlugin';

const TAG = "FlutterEntry";

export default class FlutterEntry implements Host {
  private static ARG_SHOULD_ATTACH_ENGINE_TO_ABILITY: string = "should_attach_engine_to_ability";
  protected uiAbility: UIAbility | null = null
  protected delegate: FlutterAbilityAndEntryDelegate | null = null
  protected flutterView: FlutterView | null = null
  protected context: Context;
  protected windowStage: window.WindowStage | null = null
  private parameters: Record<string, Object> = {};
  protected engineConfigurator: FlutterEngineConfigurator | null = null
  protected hasInit: boolean = false;

  constructor(context: Context, params: Record<string, Object> = {}) {
    this.context = context;
    this.uiAbility = FlutterManager.getInstance().getUIAbility(context);
    this.parameters = params;
    this.windowStage = FlutterManager.getInstance().getWindowStage(this.uiAbility);
    this.hasInit = false;
  }

  protected windowStageEventCallback = (data: window.WindowStageEventType) => {
    this.delegate?.onWindowStageChanged(data)
  }

  aboutToAppear() {
    Log.i(TAG, 'aboutToAppear');
    if (this.hasInit == false) {
      this.delegate = new FlutterAbilityAndEntryDelegate(this);
      this.flutterView = this.delegate?.createView(this.context);
      this.flutterView?.onWindowCreated();
      this?.delegate?.onAttach(this.context);
      //this.flutterView?.preDraw();
      //Log.d(TAG, "XComponent aboutToAppear predraw");
      Log.i(TAG, 'onAttach end');
      this?.delegate?.platformPlugin?.setUIAbilityContext(this.uiAbility!!.context);
      this.delegate?.onWindowStageCreate()
      this.windowStage?.on('windowStageEvent', this.windowStageEventCallback);
      this.hasInit = true;
      this.delegate?.initWindow();
    }
  }

  setFlutterEngineConfigurator(configurator: FlutterEngineConfigurator) {
    this.engineConfigurator = configurator;
  }

  getFlutterView(): FlutterView {
    return this.flutterView!!
  }

  getFlutterEngine(): FlutterEngine | null {
    return this.delegate?.flutterEngine!
  }

  aboutToDisappear() {
    Log.d(TAG, "FlutterEntry aboutToDisappear");
    try {
      this.windowStage?.off('windowStageEvent', this.windowStageEventCallback);
    } catch (err) {
      Log.e(TAG, "windowStage off failed");
    }
    if (this.flutterView != null) {
      this.flutterView.onDestroy();
      this.flutterView = null;
    }
    if (this.delegate != null) {
      this.delegate?.onDetach();
      this.delegate?.release()
    }
  }

  onPageShow() { //生命周期
    Log.d(TAG, "FlutterEntry onPageShow");
    this?.delegate?.onShow();
  }

  onPageHide() { //生命周期
    Log.d(TAG, "FlutterEntry onPageHide");
    this?.delegate?.onHide();
  }

  onBackPress() {
    Log.d(TAG, "FlutterEntry onBackPress");
    this?.delegate?.flutterEngine?.getNavigationChannel()?.popRoute();
  }

  shouldDispatchAppLifecycleState(): boolean {
    return true;
  }

  detachFromFlutterEngine() {
    if (this?.delegate != null) {
      this?.delegate?.onDetach();
    }
  }

  getAbility(): UIAbility {
    return this.uiAbility!!
  }

  loadContent() {

  }

  shouldAttachEngineToAbility(): boolean {
    let param = this.parameters![FlutterEntry.ARG_SHOULD_ATTACH_ENGINE_TO_ABILITY];
    if (!param) {
      return true;
    }
    return param as boolean
  }

  getCachedEngineId(): string {
    let param = this.parameters![FlutterAbilityLaunchConfigs.EXTRA_CACHED_ENGINE_ID];
    if (!param) {
      return "";
    }
    return param as string
  }

  getCachedEngineGroupId(): string | null {
    let param = this.parameters![FlutterAbilityLaunchConfigs.EXTRA_CACHED_ENGINE_GROUP_ID];
    if (!param) {
      return null;
    }
    return param as string
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

  getFlutterShellArgs(): FlutterShellArgs {
    return new FlutterShellArgs();
  }

  getDartEntrypointArgs(): string[] {
    if (this.parameters![FlutterAbilityLaunchConfigs.EXTRA_DART_ENTRYPOINT_ARGS]) {
      return this.parameters![FlutterAbilityLaunchConfigs.EXTRA_DART_ENTRYPOINT_ARGS] as Array<string>;
    }
    return new Array<string>()
  }

  getDartEntrypointLibraryUri(): string {
    return "";
  }

  getAppBundlePath(): string {
    return "";
  }

  getDartEntrypointFunctionName(): string {
    if (this.parameters![FlutterAbilityLaunchConfigs.EXTRA_DART_ENTRYPOINT]) {
      return this.parameters![FlutterAbilityLaunchConfigs.EXTRA_DART_ENTRYPOINT] as string;
    }
    return FlutterAbilityLaunchConfigs.DEFAULT_DART_ENTRYPOINT
  }

  getInitialRoute(): string {
    if (this.parameters![FlutterAbilityLaunchConfigs.EXTRA_INITIAL_ROUTE]) {
      return this.parameters![FlutterAbilityLaunchConfigs.EXTRA_INITIAL_ROUTE] as string
    }
    return "";
  }

  getWant(): Want {
    return new Want();
  }

  shouldRestoreAndSaveState(): boolean {
    if (this.parameters![FlutterAbilityLaunchConfigs.EXTRA_CACHED_ENGINE_ID] != undefined) {
      return this.parameters![FlutterAbilityLaunchConfigs.EXTRA_CACHED_ENGINE_ID] as boolean;
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

  provideFlutterEngine(context: Context): FlutterEngine | null {
    return null;
  }

  providePlatformPlugin(flutterEngine: FlutterEngine): PlatformPlugin | undefined {
    return new PlatformPlugin(flutterEngine.getPlatformChannel()!, this.context, this);
  }

  configureFlutterEngine(flutterEngine: FlutterEngine) {
    if (this.engineConfigurator) {
      this.engineConfigurator.configureFlutterEngine(flutterEngine)
    }
  }

  cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
    if (this.engineConfigurator) {
      this.engineConfigurator.cleanUpFlutterEngine(flutterEngine)
    }
  }

  popSystemNavigator(): boolean {
    return false;
  }

  addPlugin(plugin: FlutterPlugin): void {
    this.delegate?.addPlugin(plugin)
  }

  removePlugin(plugin: FlutterPlugin): void {
    this.delegate?.removePlugin(plugin)
  }
}