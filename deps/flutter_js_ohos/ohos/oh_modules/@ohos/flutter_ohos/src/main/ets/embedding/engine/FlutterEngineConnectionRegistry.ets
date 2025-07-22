/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on FlutterEngineConnectionRegistry.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

import PluginRegistry from './plugins/PluginRegistry';
import { FlutterAssets, FlutterPlugin, FlutterPluginBinding } from './plugins/FlutterPlugin';
import FlutterEngine from './FlutterEngine';
import AbilityAware from './plugins/ability/AbilityAware';
import UIAbility from '@ohos.app.ability.UIAbility';
import {
  AbilityPluginBinding,
  WindowFocusChangedListener,
  OnSaveStateListener,
  NewWantListener
} from './plugins/ability/AbilityPluginBinding';
import HashSet from '@ohos.util.HashSet';
import Want from '@ohos.app.ability.Want';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import common from '@ohos.app.ability.common';
import FlutterLoader from './loader/FlutterLoader';
import Log from '../../util/Log';
import ToolUtils from '../../util/ToolUtils';
import AbilityControlSurface from './plugins/ability/AbilityControlSurface';
import ExclusiveAppComponent from '../ohos/ExclusiveAppComponent';
import FlutterEngineGroup from './FlutterEngineGroup';
import Any from '../../plugin/common/Any';

const TAG = "FlutterEngineCxnRegistry";

export default class FlutterEngineConnectionRegistry implements PluginRegistry, AbilityControlSurface {
  // PluginRegistry
  private plugins = new Map<string, FlutterPlugin>();
  private defaultPlugin: FlutterPlugin = new EmptyPlugin();
  // Standard FlutterPlugin
  private flutterEngine: FlutterEngine;
  private pluginBinding: FlutterPluginBinding;
  // AbilityAware
  private abilityAwarePlugins = new Map<string, AbilityAware>();
  private exclusiveAbility: ExclusiveAppComponent<UIAbility> | null = null;
  private abilityPluginBinding: FlutterEngineAbilityPluginBinding | null = null;

  constructor(appContext: common.Context, flutterEngine: FlutterEngine, flutterLoader: FlutterLoader) {
    this.flutterEngine = flutterEngine;
    this.pluginBinding = new FlutterPluginBinding(appContext, flutterEngine, flutterEngine.getDartExecutor(),
      new DefaultFlutterAssets(flutterLoader), flutterEngine.getFlutterRenderer(),
      flutterEngine.getPlatformViewsController()?.getRegistry());
  }

  add(plugin: FlutterPlugin): void {
    try {
      if (this.has(plugin.getUniqueClassName())) {
        Log.w(
          TAG,
          "Attempted to register plugin ("
            + plugin
            + ") but it was "
            + "already registered with this FlutterEngine ("
            + this.flutterEngine
            + ").");
        return;
      }

      Log.w(TAG, "Adding plugin: " + plugin.getUniqueClassName());
      // Add the plugin to our generic set of plugins and notify the plugin
      // that is has been attached to an engine.
      this.plugins.set(plugin.getUniqueClassName(), plugin);
      plugin.onAttachedToEngine(this.pluginBinding);

      // For AbilityAware plugins, add the plugin to our set of AbilityAware
      // plugins, and if this engine is currently attached to an Ability,
      // notify the AbilityAware plugin that it is now attached to an Ability.
      if (ToolUtils.implementsInterface(plugin, "onAttachedToAbility")) {
        const abilityAware: Any = plugin;
        this.abilityAwarePlugins.set(plugin.getUniqueClassName(), abilityAware);
        if (this.isAttachedToAbility()) {
          abilityAware.onAttachedToAbility(this.abilityPluginBinding);
        }
      }
    } finally {

    }
  }

  addList(plugins: Set<FlutterPlugin>): void {
    plugins.forEach(plugin => this.add(plugin))
  }

  has(pluginClassName: string): boolean {
    return this.plugins.has(pluginClassName);
  }

  get(pluginClassName: string): FlutterPlugin {
    return this.plugins.get(pluginClassName) ?? this.defaultPlugin;
  }

  remove(pluginClassName: string): void {
    const plugin = this.plugins.get(pluginClassName);
    if (plugin == null) {
      return;
    }
    if (ToolUtils.implementsInterface(plugin, "onAttachedToAbility")) {
      if (this.isAttachedToAbility()) {
        const abilityAware: Any = plugin;
        abilityAware.onDetachedFromAbility();
      }
      this.abilityAwarePlugins.delete(pluginClassName);
    }
    // Notify the plugin that is now detached from this engine. Then remove
    // it from our set of generic plugins.
    plugin.onDetachedFromEngine(this.pluginBinding);
    this.plugins.delete(pluginClassName)
  }

  removeList(pluginClassNames: Set<string>): void {
    pluginClassNames.forEach(plugin => this.remove(plugin))
  }

  removeAll(): void {
    this.removeList(new Set(this.plugins.keys()));
    this.plugins.clear();
  }

  private isAttachedToAbility(): boolean {
    return this.exclusiveAbility != null;
  }

  attachToAbility(exclusiveAbility: ExclusiveAppComponent<UIAbility>): void {
    if (this.exclusiveAbility != null) {
      this.exclusiveAbility.detachFromFlutterEngine();
    }
    // If we were already attached to an app component, detach from it.
    this.detachFromAppComponent();
    this.exclusiveAbility = exclusiveAbility;
    this.attachToAbilityInternal(exclusiveAbility.getAppComponent(),);
  }

  detachFromAbility(): void {
    if (this.isAttachedToAbility()) {
      try {
        this.abilityAwarePlugins.forEach(abilityAware => abilityAware.onDetachedFromAbility())
      } catch (e) {
        Log.e(TAG, "abilityAwarePlugins DetachedFromAbility failed, msg:" + e);
      }
      this.detachFromAbilityInternal();
    } else {
      Log.e(TAG, "Attempted to detach plugins from an Ability when no Ability was attached.");
    }
  }

  onNewWant(want: Want, launchParams: AbilityConstant.LaunchParam): void {
    this.abilityPluginBinding?.onNewWant(want, launchParams);
  }

  onWindowFocusChanged(hasFocus: boolean): void {
    this.abilityPluginBinding?.onWindowFocusChanged(hasFocus);
  }

  onSaveState(reason: AbilityConstant.StateType, wantParam: Record<string, Object>): AbilityConstant.OnSaveResult {
    return this.abilityPluginBinding?.onSaveState(reason, wantParam) ?? AbilityConstant.OnSaveResult.ALL_REJECT;
  }

  private detachFromAppComponent(): void {
    if (this.isAttachedToAbility()) {
      this.detachFromAbility();
    }
  }

  private attachToAbilityInternal(ability: UIAbility): void {
    this.abilityPluginBinding = new FlutterEngineAbilityPluginBinding(ability);
    // Notify all AbilityAware plugins that they are now attached to a new Ability.
    this.abilityAwarePlugins.forEach(abilityAware => abilityAware.onAttachedToAbility(this.abilityPluginBinding!));
  }

  private detachFromAbilityInternal(): void {
    this.exclusiveAbility = null;
    this.abilityPluginBinding = null;
  }

  destroy(): void {
    this.detachFromAppComponent();
    // Remove all registered plugins.
    this.removeAll();
  }
}

class FlutterEngineAbilityPluginBinding implements AbilityPluginBinding {
  private ability: UIAbility;
  private onNewWantListeners = new HashSet<NewWantListener>();
  private onWindowFocusChangedListeners = new HashSet<WindowFocusChangedListener>();
  private onSaveStateListeners = new HashSet<OnSaveStateListener>();

  constructor(ability: UIAbility) {
    this.ability = ability;

  }

  getAbility(): UIAbility {
    return this.ability;
  }

  addOnNewWantListener(listener: NewWantListener): void {
    this.onNewWantListeners.add(listener)
  }

  removeOnNewWantListener(listener: NewWantListener): void {
    this.onNewWantListeners.remove(listener)
  }

  addOnWindowFocusChangedListener(listener: WindowFocusChangedListener): void {
    this.onWindowFocusChangedListeners.add(listener)
  }

  removeOnWindowFocusChangedListener(listener: WindowFocusChangedListener): void {
    this.onWindowFocusChangedListeners.remove(listener)
  }

  addOnSaveStateListener(listener: OnSaveStateListener) {
    this.onSaveStateListeners.add(listener)
  }

  removeOnSaveStateListener(listener: OnSaveStateListener) {
    this.onSaveStateListeners.remove(listener)
  }

  onNewWant(want: Want, launchParams: AbilityConstant.LaunchParam): void {
    this.onNewWantListeners.forEach((listener, key) => {
      listener?.onNewWant(want, launchParams)
    });
  }

  onWindowFocusChanged(hasFocus: boolean): void {
    this.onWindowFocusChangedListeners.forEach((listener, key) => {
      listener?.onWindowFocusChanged(hasFocus)
    });
  }

  onSaveState(reason: AbilityConstant.StateType, wantParam: Record<string, Object>): AbilityConstant.OnSaveResult {
    this.onSaveStateListeners.forEach((listener, key) => {
      listener?.onSaveState(reason, wantParam)
    });
    return AbilityConstant.OnSaveResult.ALL_AGREE;
  }
}

class DefaultFlutterAssets implements FlutterAssets {
  private flutterLoader: FlutterLoader;

  constructor(flutterLoader: FlutterLoader) {
    this.flutterLoader = flutterLoader;
  }

  getAssetFilePathByName(assetFileName: string, packageName?: string): string {
    return this.flutterLoader.getLookupKeyForAsset(assetFileName, packageName);
  }

  getAssetFilePathBySubpath(assetSubpath: string, packageName?: string) {
    return this.flutterLoader.getLookupKeyForAsset(assetSubpath, packageName);
  }
}

class EmptyPlugin implements FlutterPlugin {
  getUniqueClassName(): string {
    return '';
  }

  onAttachedToEngine(binding: FlutterPluginBinding) {

  }

  onDetachedFromEngine(binding: FlutterPluginBinding) {

  }
}