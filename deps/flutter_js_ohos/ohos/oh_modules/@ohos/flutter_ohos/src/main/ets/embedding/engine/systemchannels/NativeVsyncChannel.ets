/*
* Copyright (c) 2024 Hunan OpenValley Digital Industry Development Co., Ltd.
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

import Log from '../../../util/Log';
import DartExecutor from '../dart/DartExecutor';
import HashMap from '@ohos.util.HashMap';
import StringUtils from '../../../util/StringUtils';
import Any from '../../../plugin/common/Any';
import FlutterNapi from '../FlutterNapi';
import MethodChannel, { MethodCallHandler, MethodResult } from '../../../plugin/common/MethodChannel';
import MethodCall from '../../../plugin/common/MethodCall';
import StandardMethodCodec from '../../../plugin/common/StandardMethodCodec';

enum AnimationVotingType {
  TRANSLATE = 0,
  SCALE,
  RATATION,
}

/**
* nativeVsync功能channel
*/
export default class NativeVsyncChannel implements MethodCallHandler {
    private static TAG = "NativeVsyncChannel";
    private static CHANNEL_NAME = "flutter/nativevsync";
    public channel: MethodChannel;
    private flutterNapi: FlutterNapi;

    onMethodCall(call: MethodCall, result: MethodResult): void {
        let method: string = call.method;
        try {
            switch (method) {
                case "isEnable":
                    // 是否开启DVsync
                    let isEnable: boolean = call.argument('isEnable');
                    this.flutterNapi.SetDVsyncSwitch(isEnable);
                    break;
                case "sendVelocity":
                    // 发送动画的速率
                    let type: string = call.argument('type');
                    let velocity: number = call.argument('velocity');
                    if (type == "translate") {
                        FlutterNapi.animationVoting(AnimationVotingType.TRANSLATE, velocity);
                    }
                    break;
                case "checkLTPOSwtichState":
                    // 查询ltpo功能开启状态
                    result.success(FlutterNapi.checkLTPOSwitchState());
                    break;
                default:
                    break;
            }
        } catch (error) {
            result.error("error", "UnHandled error: " + JSON.stringify(error), null)
        }
    }

    constructor(dartExecutor: DartExecutor, flutterNapi: FlutterNapi) {
        this.channel = new MethodChannel(dartExecutor, NativeVsyncChannel.CHANNEL_NAME, StandardMethodCodec.INSTANCE);
        this.channel.setMethodCallHandler(this);
        this.flutterNapi = flutterNapi;
    }
}