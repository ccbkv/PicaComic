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
import { FileSelectorApiImpl } from './FileSelectorApiImpl'

const TAG = "FileSelectorOhosPlugin"

export default class FileSelectorOhosPlugin implements FlutterPlugin, AbilityAware {

  private pluginBinding: FlutterPluginBinding | null = null;
  private fileSelectorApi: FileSelectorApiImpl | null = null;

  getUniqueClassName(): string {
    return "FileSelectorOhosPlugin"
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.fileSelectorApi = new FileSelectorApiImpl(binding);
    if (this.pluginBinding != null) {
      this.fileSelectorApi.setup(this.pluginBinding.getBinaryMessenger(), binding);
    }
  }

  onDetachedFromAbility(): void {
    this.fileSelectorApi = null;
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    console.debug(TAG, 'onAttachedToEngine file selector  ')
    this.pluginBinding = binding;
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.pluginBinding = null;
  }
}