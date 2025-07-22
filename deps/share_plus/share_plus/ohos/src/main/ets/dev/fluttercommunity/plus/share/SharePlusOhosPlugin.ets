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

import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';
import AbilityAware from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityAware';
import {
  AbilityPluginBinding
} from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityPluginBinding';
import {
  FlutterPlugin,
  FlutterPluginBinding
} from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import MethodChannel from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import Share from './Share';
import MethodChannelHandlerImpl from './MethodChannelHandlerImpl';

const TAG = "SharePlusOhosPlugin";
const CHANNEL_NAME = 'dev.fluttercommunity.plus/share';

export default class SharePlusOhosPlugin implements FlutterPlugin, AbilityAware {
  private methodChannel: MethodChannel | null = null;
  private methodChannelHandlerImpl: MethodChannelHandlerImpl | null = null;
  private share: Share | null = null

  getUniqueClassName(): string {
    return TAG;
  }

  onAttachedToAbility(binding: AbilityPluginBinding) {
    Log.i(TAG, "onAttachedToAbility");
    this.share?.setAbility(binding.getAbility());
  }

  onDetachedFromAbility() {
    Log.i(TAG, "onDetachedFromAbility");
    this.share?.setAbility(null);
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    Log.i(TAG, "onAttachedToEngine");
    this.methodChannel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME);
    this.share = new Share(binding.getApplicationContext());
    this.methodChannelHandlerImpl = new MethodChannelHandlerImpl(this.share);
    this.methodChannel.setMethodCallHandler(this.methodChannelHandlerImpl);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    Log.i(TAG, "onDetachedFromEngine");
    this.methodChannel?.setMethodCallHandler(null);
    this.methodChannel = null;
  }
}
