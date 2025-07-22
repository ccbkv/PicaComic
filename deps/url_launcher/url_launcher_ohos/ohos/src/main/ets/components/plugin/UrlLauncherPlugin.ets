/*
 * Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd.
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
import AbilityAware from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityAware';
import {
  AbilityPluginBinding
} from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityPluginBinding';
import {
  FlutterPlugin,
  FlutterPluginBinding
} from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import { UrlLauncherApi } from './Messages';
import { UrlLauncher } from './UrlLauncher';

const TAG = "UrlLauncherPlugin"

export default class UrlLauncherPlugin implements FlutterPlugin, AbilityAware {

  private pluginBinding: FlutterPluginBinding | null = null;
  private urlLauncherApi: UrlLauncherApi | null = null;

  getUniqueClassName(): string {
    return "UrlLauncherPlugin"
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    console.debug(TAG, 'onAttachedToAbility ')
    this.urlLauncherApi = new UrlLauncher(binding.getAbility().context);
    this.urlLauncherApi.setup(
      this.pluginBinding?.getBinaryMessenger() ?? null, this.urlLauncherApi);
  }
  onDetachedFromAbility(): void {
    this.urlLauncherApi?.setup(null, null);
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    console.debug(TAG, 'onAttachedToEngine')
    this.pluginBinding = binding;
  }


  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.urlLauncherApi?.setup(this.pluginBinding?.getBinaryMessenger() ?? null, null);
    this.pluginBinding = null;
  }
}