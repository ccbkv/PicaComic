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
import { AbilityPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityPluginBinding';
import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import { MethodCallHandler, MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodChannel from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';
import userAuth from '@ohos.userIAM.userAuth';
import { AuthenticationHelper } from './AuthenticationHelper';
import screenLock from '@ohos.screenLock';
import { BusinessError } from '@ohos.base';

const TAG = "LocalAuthPlugin";
const CHANNEL_NAME = "plugins.flutter.io/local_auth_ohos";

/**
 * Flutter plugin providing access to local authentication.
 *
 * <p>Instantiate this in an add to app scenario to gracefully handle activity and context changes.
 */

let authInProgress: boolean = false;
export default class LocalAuthPlugin implements FlutterPlugin, AbilityAware, MethodCallHandler {
  private authHelper: AuthenticationHelper | null = null;
  private abilityPluginBinding: AbilityPluginBinding | null = null;

  private channel: MethodChannel | null = null;

  getUniqueClassName(): string {
    return "LocalAuthPlugin";
  }

  onAttachedToAbility(binding: AbilityPluginBinding) {
    this.abilityPluginBinding = binding;
    this.channel?.setMethodCallHandler(this);
  }

  onDetachedFromAbility() {
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    Log.d(TAG, 'onAttachedToEngine local auth')
    this.channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME);
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    Log.d(TAG, 'onMethodCall step in')
    switch (call.method) {
      case "authenticate":
        this.authenticate(call, result);
        break;
      case "getEnrolledBiometrics":
        this.getEnrolledBiometrics(result);
        break;
      case "isDeviceSupported":
        this.isDeviceSupported(result);
        break;
      case "stopAuthentication":
        this.stopAuthentication(result);
        break;
      case "deviceSupportsBiometrics":
        this.deviceSupportsBiometrics(result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }


  async isDeviceSupported(result: MethodResult): Promise<void> {
    Log.d(TAG, 'isDeviceSupported start')
    let isDeviceSupported: boolean = await this.checkDeviceSupported();
    Log.d(TAG, `isDeviceSupported, ${isDeviceSupported}`)
    result.success(isDeviceSupported);
  }

  async checkDeviceSupported(): Promise<boolean> {
    if (this.canAuthenticateWithBiometrics()) {
      return true;
    }
    return await isDeviceSecure();
  }

  getEnrolledBiometrics(result: MethodResult) {
    Log.d(TAG, 'getEnrolledBiometrics start')
    let biometrics: Array<string> = new Array<string>();
    if (this.getAvailableStatus(userAuth.UserAuthType.FACE, userAuth.AuthTrustLevel.ATL1)) {
      biometrics.push("face");
    }
    if (this.getAvailableStatus(userAuth.UserAuthType.FINGERPRINT, userAuth.AuthTrustLevel.ATL1)) {
      biometrics.push("fingerprint");
    }
    Log.d(TAG, `getEnrolledBiometrics, ${biometrics}`)
    result.success(biometrics);
  }

  deviceSupportsBiometrics(result: MethodResult) {
    Log.d(TAG, 'deviceSupportsBiometrics start')
    let deviceCanSupportBiometrics: Boolean = this.deviceCanSupportBiometrics();
    Log.d(TAG, `deviceCanSupportBiometrics: ${deviceCanSupportBiometrics}`)
    result.success(deviceCanSupportBiometrics);
  }

  /**
   * Cancels any in-progress authentication.
   *
   * <p>Returns true only if authentication was in progress, and was successfully cancelled.
   */
  stopAuthentication(result: MethodResult): void {
    try {
      if (this.authHelper != null && authInProgress) {
        this.authHelper.stopAuthentication();
        this.authHelper = null;
      }
      authInProgress = false;
      result.success(true);
    } catch (e) {
      result.success(false);
    }
  }


  canAuthenticateWithBiometrics(): boolean {
    Log.i(TAG, `canAuthenticateWithBiometrics`);
    return this.getAvailableStatus(userAuth.UserAuthType.PIN, userAuth.AuthTrustLevel.ATL1)
      || this.getAvailableStatus(userAuth.UserAuthType.FINGERPRINT, userAuth.AuthTrustLevel.ATL1)
      || this.getAvailableStatus(userAuth.UserAuthType.FACE, userAuth.AuthTrustLevel.ATL1);
  }

  private getAvailableStatus(authType: userAuth.UserAuthType, authTrustLevel: userAuth.AuthTrustLevel): boolean {
    try {
      Log.i(TAG, `getAvailableStatus start, authType: ${authType}, authTrustLevel: ${authTrustLevel}`);
      userAuth.getAvailableStatus(authType, authTrustLevel);
    } catch (err) {
      Log.e(TAG, `Failed to getAvailableStatus, Code: ${err?.code}, message: ${err?.message}`);
      return false;
    }
    Log.d(TAG, `getAvailableStatus success, authType: ${authType}, authTrustLevel: ${authTrustLevel}`);
    return true;
  }

  /**
   * Returns true if this device can support biometric authentication, whether any biometrics are
   * enrolled or not.
   */
  deviceCanSupportBiometrics(): Boolean {
    return this.supportHardware(userAuth.UserAuthType.FINGERPRINT, userAuth.AuthTrustLevel.ATL1)
      || this.supportHardware(userAuth.UserAuthType.FACE, userAuth.AuthTrustLevel.ATL1);
  }

  private supportHardware(authType: userAuth.UserAuthType, authTrustLevel: userAuth.AuthTrustLevel): boolean {
    try {
      Log.i(TAG, `supportHardware start, authType: ${authType}, authTrustLevel: ${authTrustLevel}`);
      userAuth.getAvailableStatus(authType, authTrustLevel);
    } catch (err) {
      Log.e(TAG, `Failed to getAvailableStatus, Code: ${err?.code}, message: ${err?.message}`);
      return err?.code != userAuth.UserAuthResultCode.TYPE_NOT_SUPPORT;
    }
    Log.d(TAG, `supportHardware success, authType: ${authType}, authTrustLevel: ${authTrustLevel}`);
    return true;
  }

  /**
   * Attempts to authenticate the user with the provided [options], and using [strings] for any
   * UI.
   */
  async authenticate(call: MethodCall, result: MethodResult): Promise<void> {
    if (authInProgress) {
      result.error("auth_in_progress", "Authentication in progress", null);
      return;
    }

    if (this.abilityPluginBinding?.getAbility() == null) {
      result.error("no_ability", "local_auth plugin requires a foreground ability", null);
      return;
    }

    let isDeviceSupported: boolean = await this.checkDeviceSupported();
    if (!isDeviceSupported) {
      authInProgress = false;
      result.error("NotAvailable", "Required security features not enabled", null);
      return;
    }
    authInProgress = true;
    let isBiometricOnly: boolean = call.argument("biometricOnly");
    let allowCredentials: boolean = isBiometricOnly && await this.canAuthenticateWithDeviceCredential();
    this.sendAuthenticationRequest(call, result, allowCredentials);
  }

  sendAuthenticationRequest(call: MethodCall,
                            result: MethodResult,
                            allowCredentials: boolean ): void {
    this.authHelper = new AuthenticationHelper(this.abilityPluginBinding, call, allowCredentials);
    this.authHelper.authenticate(result);
  }

  async canAuthenticateWithDeviceCredential(): Promise<boolean> {
    return await isDeviceSecure();
  }
}

async function isDeviceSecure(): Promise<boolean> {
  Log.i(TAG, `isDeviceSecure`);
  let result = await screenLock.isSecureMode().then((data: Boolean) => {
    console.info(`Succeeded in Obtaining whether the device is in secure mode. result: ${data}`);
    return true;
  }).catch((err: BusinessError) => {
    console.error(`Failed to obtain whether the device is in secure mode, Code: ${err.code}, message: ${err.message}`);
    return false;
  });
  return result;
}


export class AuthCallback implements userAuth.IAuthCallback {
  private result: MethodResult;
  private authInProgress: boolean;

  constructor(result: MethodResult, authInProgress: boolean) {
    this.result = result;
    this.authInProgress = authInProgress;
  }

  onResult(result: userAuth.UserAuthResult): void {
    if (authInProgress) {
      setAuthInProgress(false);
    }
    switch (result.result) {
      case userAuth.UserAuthResultCode.SUCCESS:
        this.result.success(true);
        this.stop();
        break;
      case userAuth.UserAuthResultCode.FAIL:
        this.result.success(false);
        break;
      case userAuth.UserAuthResultCode.GENERAL_ERROR:
        this.result.error(result.result.toLocaleString(), "General error occured.", null);
        break;
      case userAuth.UserAuthResultCode.TIMEOUT:
        this.result.error(result.result.toLocaleString(), "This operation is time out.", null);
        break;
      case userAuth.UserAuthResultCode.TYPE_NOT_SUPPORT:
        this.result.error(result.result.toLocaleString(), "Security credentials not available.", null);
        break;
      case userAuth.UserAuthResultCode.TRUST_LEVEL_NOT_SUPPORT:
        this.result.error(result.result.toLocaleString(), "Unsupported authentication level.", null);
        break;
      case userAuth.UserAuthResultCode.BUSY:
        this.result.error(result.result.toLocaleString(), "The device is busy.", null);
        break;
      case userAuth.UserAuthResultCode.LOCKED:
        this.result.error(result.result.toLocaleString(), "The operation was canceled because the API is locked out" +
          " due to too many attempts. This occurs after 5 failed attempts, and lasts for 60 seconds.", null);
        break;
      case userAuth.UserAuthResultCode.NOT_ENROLLED:
        this.result.error(result.result.toLocaleString(), "No Biometrics enrolled on this device.", null);
        break;
      case userAuth.UserAuthResultCode.CANCELED_FROM_WIDGET:
        this.result.error(result.result.toLocaleString(), "The operation was cancelled by the user from the widget.", null);
        break;
      case userAuth.UserAuthResultCode.CANCELED:
      default:
        this.result.success(false);
    }
  }

  /** Stops the biometric listener. */
  stop(): void {
    try {
      // this.off('result', {
      //   onResult (result) {
      //     Log.i(TAG, 'auth off result: ' + JSON.stringify(result));
      //   }
      // });
      Log.i(TAG, 'auth off success');
    } catch (error) {
      Log.e(TAG, 'auth catch error: ' + JSON.stringify(error));
    }
  }
}

function setAuthInProgress(inProgress: boolean) {
  authInProgress = inProgress;
}