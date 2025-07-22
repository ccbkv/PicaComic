/*
 * Copyright 2013 The Flutter Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
*/

import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import Want from '@ohos.app.ability.Want';
import UIAbility from '@ohos.app.ability.UIAbility';
import ExclusiveAppComponent from '../../../ohos/ExclusiveAppComponent';

export default interface ActivityControlSurface {
  attachToAbility(exclusiveActivity: ExclusiveAppComponent<UIAbility>): void;

  detachFromAbility(): void;

  onNewWant(want: Want, launchParams: AbilityConstant.LaunchParam): void;

  onWindowFocusChanged(hasFocus: boolean): void;

  onSaveState(reason: AbilityConstant.StateType, wantParam: Record<string, Object>): AbilityConstant.OnSaveResult;
}