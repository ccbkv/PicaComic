/*
 * Copyright 2013 The Flutter Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
*/

import UIAbility from '@ohos.app.ability.UIAbility'
import Want from '@ohos.app.ability.Want';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';

export interface AbilityPluginBinding {
  getAbility(): UIAbility;

  /**
   * Adds a listener that is invoked whenever the associated {@link ohos.app.ability.UIAbility}'s {@code
   * onNewWant(...)} method is invoked.
   */
  addOnNewWantListener(listener: NewWantListener): void;

  /**
   * Removes a listener that was added in {@link
   * #addOnNewWantListener(NewWantListener)}.
   */
  removeOnNewWantListener(listener: NewWantListener): void;

  /**
   * Adds a listener that is invoked whenever the associated {@link ohos.app.ability.UIAbility}'s {@code
   * windowStageEvent} method is invoked.
   */
  addOnWindowFocusChangedListener(listener: WindowFocusChangedListener): void;

  /**
   * Removes a listener that was added in {@link
   * #addOnWindowFocusChangedListener(WindowFocusChangedListener)}.
   */
  removeOnWindowFocusChangedListener(listener: WindowFocusChangedListener): void;

  /**
   * Adds a listener that is invoked when the associated {@code UIAbility} saves
   * and restores instance state.
   */
  addOnSaveStateListener(listener: OnSaveStateListener): void;

  /**
   * Removes a listener that was added in {@link
   * #addOnSaveStateListener(OnSaveStateListener)}.
   */
  removeOnSaveStateListener(listener: OnSaveStateListener): void;
}

/**
 * Delegate interface for handling new wants on behalf of the main {@link ohos.app.ability.UIAbility}.
 */
export interface NewWantListener {
  /**
   * @param intent The new want that was started for the UIAbility.
   * @return true if the new want has been handled.
   */
  onNewWant(want: Want, launchParams: AbilityConstant.LaunchParam): void;
}

/**
 * Delegate interface for handling window focus changes on behalf of the main {@link
 * ohos.app.ability.UIAbility}.
 */
export interface WindowFocusChangedListener {
  onWindowFocusChanged(hasFocus: boolean): void;
}

export interface OnSaveStateListener {
  /**
   * Invoked when the associated {@code UIAbility} or {@code Fragment} executes {@link
   * Activity#onSaveState(Bundle)}.
   */
  onSaveState(reason: AbilityConstant.StateType, wantParam: Record<string, Object>): AbilityConstant.OnSaveResult;
}