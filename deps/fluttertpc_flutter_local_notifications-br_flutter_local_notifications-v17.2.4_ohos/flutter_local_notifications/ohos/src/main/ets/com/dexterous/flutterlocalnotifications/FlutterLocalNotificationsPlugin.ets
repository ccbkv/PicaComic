/*
 * Copyright (c) 2024 Shenzhen Kaihong Digital Industry Development Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import {
  AbilityAware,
  AbilityPluginBinding,
  FlutterPlugin,
  FlutterPluginBinding,
  MethodChannel,
  NewWantListener
} from '@ohos/flutter_ohos';
import MethodCallHandlerImpl from './MethodCallHandlerImpl';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import Want from '@ohos.app.ability.Want';

export default class FlutterLocalNotificationsPlugin implements FlutterPlugin, AbilityAware, NewWantListener {
  private channel: MethodChannel | null = null;
  private binding?: AbilityPluginBinding;
  private methodCallHandler: MethodCallHandlerImpl | null = null;

  constructor() {
  }

  onNewWant(want: Want, launchParams: AbilityConstant.LaunchParam): void {
    if (!this.channel) {
      return
    }
    this.methodCallHandler?.onNewWant(want, this.channel)
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.binding = binding;
    this.methodCallHandler?.initLaunchWant(binding?.getAbility()?.launchWant);
    globalThis.context = binding.getAbility();
    binding.addOnNewWantListener(this);
  }

  onDetachedFromAbility(): void {
    this.binding?.removeOnNewWantListener(this);
    globalThis.context = null;
    this.binding = undefined;
  }

  getUniqueClassName(): string {
    return "FlutterLocalNotificationsPlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "dexterous.com/flutter/local_notifications");
    this.methodCallHandler = new MethodCallHandlerImpl();
    this.channel.setMethodCallHandler(this.methodCallHandler);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
      this.channel = null
    }
  }
}