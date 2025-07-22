/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on PlatformPlugin.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import { BusinessError } from '@kit.BasicServicesKit';
import PlatformChannel, {
  AppSwitcherDescription,
  Brightness,
  ClipboardContentFormat,
  HapticFeedbackType,
  PlatformMessageHandler,
  SoundType,
  SystemChromeStyle,
  SystemUiMode,
  SystemUiOverlay
} from '../embedding/engine/systemchannels/PlatformChannel';
import FlutterManager from '../embedding/ohos/FlutterManager';
import pasteboard from '@ohos.pasteboard';
import Log from '../util/Log';
import vibrator from '@ohos.vibrator';
import window from '@ohos.window';
import common from '@ohos.app.ability.common';
import { MethodResult } from './common/MethodChannel';
import Any from './common/Any';
import router from '@ohos.router';

/**
 * ohos实现platform plugin
 */
export default class PlatformPlugin {
  private static TAG = "PlatformPlugin";
  callback = new PlatformPluginCallback();

  constructor(platformChannel: PlatformChannel, context: common.Context,
    platformPluginDelegate?: PlatformPluginDelegate) {
    this.callback.platformChannel = platformChannel;
    this.callback.context = context;
    this.callback.applicationContext = context?.getApplicationContext();
    this.callback.platform = this;
    this.callback.platformPluginDelegate = platformPluginDelegate ?? null;
    this.callback.platformChannel?.setPlatformMessageHandler(this.callback);
  }

  initWindow() {
    try {
      let context = this.callback.context!!
      window.getLastWindow(context, (err, data) => {
        if (err.code) {
          Log.e(PlatformPlugin.TAG, "Failed to obtain the top window. Cause: " + JSON.stringify(err));
          return;
        }
        this.callback.lastWindow = data;
      });
      const uiAbility = FlutterManager.getInstance().getUIAbility(context);
      const windowStage = FlutterManager.getInstance().getWindowStage(uiAbility);
      this.callback.mainWindow = windowStage.getMainWindowSync();
    } catch (err) {
      Log.e(PlatformPlugin.TAG, "Failed to obtain the top window. Cause: " + JSON.stringify(err));
    }
  }


  updateSystemUiOverlays(): void {
    this.callback.mainWindow?.setWindowSystemBarEnable(this.callback.showBarOrNavigation);
    if (this.callback.currentTheme != null) {
      this.callback.setSystemChromeSystemUIOverlayStyle(this.callback.currentTheme);
    }
  }

  setUIAbilityContext(context: common.UIAbilityContext): void {
    this.callback.uiAbilityContext = context;
  }

  setSystemChromeChangeListener(): void {
    if (this.callback.callbackId == null && this.callback.applicationContext != null) {
      let that = this;
      this.callback.callbackId = this.callback.applicationContext?.on('environment', {
        onConfigurationUpdated(config) {
          Log.d(PlatformPlugin.TAG, "onConfigurationUpdated: " + that.callback.showBarOrNavigation);
          that.callback.platformChannel?.systemChromeChanged(that.callback.showBarOrNavigation.includes('status'));
        },
        onMemoryLevel(level) {
        }
      })
    }
  }

  public destroy() {
    this.callback.platformChannel?.setPlatformMessageHandler(null);
  }
}

export interface PlatformPluginDelegate {
  popSystemNavigator(): boolean;
}

export class PlatformPluginCallback implements PlatformMessageHandler {
  private static TAG = "PlatformPluginCallback";
  platform: PlatformPlugin | null = null;
  mainWindow: window.Window | null = null;
  lastWindow: window.Window | null = null;
  platformChannel: PlatformChannel | null = null;
  platformPluginDelegate: PlatformPluginDelegate | null = null;
  context: common.Context | null = null;
  showBarOrNavigation: ('status' | 'navigation')[] = ['status', 'navigation'];
  uiAbilityContext: common.UIAbilityContext | null = null;
  callbackId: number | null = null;
  applicationContext: common.ApplicationContext | null = null;
  currentTheme: SystemChromeStyle | null = null;

  playSystemSound(soundType: SoundType) {
  }

  async vibrateHapticFeedback(feedbackType: HapticFeedbackType) {
    switch (feedbackType) {
      case HapticFeedbackType.STANDARD:
        await vibrator.startVibration({ type: 'time', duration: 75 },
          { id: 0, usage: 'touch' });
        break;
      case HapticFeedbackType.LIGHT_IMPACT:
        await vibrator.startVibration({ type: 'time', duration: 25 },
          { id: 0, usage: 'touch' });
        break;
      case HapticFeedbackType.MEDIUM_IMPACT:
        await vibrator.startVibration({ type: 'time', duration: 150 },
          { id: 0, usage: 'touch' });
        break;
      case HapticFeedbackType.HEAVY_IMPACT:
        await vibrator.startVibration({ type: 'time', duration: 300 },
          { id: 0, usage: 'touch' });
        break;
      case HapticFeedbackType.SELECTION_CLICK:
        await vibrator.startVibration({ type: 'time', duration: 100 },
          { id: 0, usage: 'touch' });
        break;
    }
  }

  setPreferredOrientations(ohosOrientation: number, result: MethodResult) {
    try {
      Log.d(PlatformPluginCallback.TAG, "ohosOrientation: " + ohosOrientation);
      this.mainWindow!.setPreferredOrientation(ohosOrientation, (err: BusinessError) => {
        const errCode: number = err.code;
        if (errCode) {
          Log.e(PlatformPluginCallback.TAG, "Failed to set window orientation:" + JSON.stringify(err));
          result.error("error", JSON.stringify(err), null);
          return;
        }
        result.success(null);
      });
    } catch (exception) {
      Log.e(PlatformPluginCallback.TAG, "Failed to set window orientation:" + JSON.stringify(exception));
      result.error("error", JSON.stringify(exception), null);
    }
  }

  setApplicationSwitcherDescription(description: AppSwitcherDescription) {
    Log.d(PlatformPluginCallback.TAG, "setApplicationSwitcherDescription: " + JSON.stringify(description));
    try {
      let label: string = description?.label;
      this.uiAbilityContext?.setMissionLabel(label).then(() => {
        Log.d(PlatformPluginCallback.TAG, "Succeeded in seting mission label");
      })
    } catch (err) {
      Log.d(PlatformPluginCallback.TAG, "Failed to set mission label: " + JSON.stringify(err));
    }
  }

  showSystemOverlays(overlays: SystemUiOverlay[]) {
    this.setSystemChromeEnabledSystemUIOverlays(overlays);
  }

  showSystemUiMode(mode: SystemUiMode) {
    this.setSystemChromeEnabledSystemUIMode(mode);
  }

  setSystemUiChangeListener() {
    this.platform?.setSystemChromeChangeListener();
  }

  restoreSystemUiOverlays() {
    this.platform?.updateSystemUiOverlays();
  }

  setSystemUiOverlayStyle(systemUiOverlayStyle: SystemChromeStyle) {
    Log.d(PlatformPluginCallback.TAG, "systemUiOverlayStyle:" + JSON.stringify(systemUiOverlayStyle));
    this.setSystemChromeSystemUIOverlayStyle(systemUiOverlayStyle);
  }

  popSystemNavigator() {
    if (this.platformPluginDelegate != null && this.platformPluginDelegate?.popSystemNavigator()) {
      return;
    }
    router.back();
  }

  getClipboardData(result: MethodResult): void {
    let atManager = abilityAccessCtrl.createAtManager();
    atManager.requestPermissionsFromUser(this.uiAbilityContext, ['ohos.permission.READ_PASTEBOARD']).then((data) => {
      // https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-permissionrequestresult-V5
      // 相应请求权限的结果：
      // -1：未授权，表示权限已设置，无需弹窗，需要用户在"设置"中修改
      //  0：已授权
      //  2：未授权，表示请求无效，可能原因有：
      //   -未在设置文件中声明目标权限。
      //   -权限名非法。
      //   -部分权限存在特殊申请条件，在申请对应权限时未满足其指定的条件
      enum AuthResultStatus {
        NOT_CONFIGURED = -1,
        GRANTED = 0,
        INVALID_REQ = 2
      }

      let message: string = 'Failed to request permissions from user.';
      let authResult: number = data.authResults[0];
      switch (authResult) {
        case AuthResultStatus.GRANTED: {
          let systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
          systemPasteboard.getData().then(async (pasteData: pasteboard.PasteData) => {
            let pasteText: string = '';
            const recordCount: number = pasteData.getRecordCount();
            for (let i = 0; i < recordCount; i++) {
              const record = pasteData.getRecord(i);
              if (record.mimeType != pasteboard.MIMETYPE_TEXT_PLAIN
                && record.mimeType != pasteboard.MIMETYPE_TEXT_HTML) {
                continue;
              }
              let text: string = '';
              if (record.mimeType == pasteboard.MIMETYPE_TEXT_PLAIN){
                text = record.plainText;
              } else if (record.mimeType == pasteboard.MIMETYPE_TEXT_HTML) {
                const htmlText: StyledString = await StyledString.fromHtml(record.htmlText);
                text = htmlText.getString();
              }
              pasteText += text;
            }
            let response: Any = new Map().set("text", pasteText);
            result.success(response);
          }).catch((err: BusinessError) => {
            Log.e(PlatformPluginCallback.TAG, "Failed to get PasteData. Cause: " + JSON.stringify(err));
            result.error("error", JSON.stringify(err), null);
          });
          break;
        }
        case AuthResultStatus.NOT_CONFIGURED: {
          message += 'Cause: Not configured in Settings';
          Log.i(PlatformPluginCallback.TAG, message);
          result.success(null);
          break;
        }
        case AuthResultStatus.INVALID_REQ: {
          message += 'Cause: Invalid request';
          Log.i(PlatformPluginCallback.TAG, message);
          result.success(null);
          break;
        }
        default: {
          message += `Unknown error: authResult=${authResult}`;
          result.error("error", message, null);
          break;
        }
      }
    }).catch((err: BusinessError) => {
      Log.e(PlatformPluginCallback.TAG, "Failed to request permissions from user. Cause: " + JSON.stringify(err));
      result.error("error", JSON.stringify(err), null);
    })
  }

  setClipboardData(text: string, result: MethodResult) {
    let pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    let systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
    try {
      systemPasteboard.setDataSync(pasteData);
      result.success(null);
    } catch (err) {
      Log.d(PlatformPluginCallback.TAG, "Failed to set PasteData. Cause: " + JSON.stringify(err));
      result.error("error", JSON.stringify(err), null);
    }
  }

  clipboardHasStrings(): boolean {
    return false;
  }

  setSystemChromeEnabledSystemUIMode(mode: SystemUiMode): void {
    Log.d(PlatformPluginCallback.TAG, "mode: " + mode);
    let uiConfig: ('status' | 'navigation')[] = [];
    if (mode == SystemUiMode.LEAN_BACK) {
      //全屏显示，通过点击显示器上的任何位置都可以显示状态和导航栏
      FlutterManager.getInstance().setUseFullScreen(true, null);
    } else if (mode == SystemUiMode.IMMERSIVE) {
      //全屏显示，通过在显示器边缘的滑动手势可以显示状态和导航栏,应用程序不会接收到此手势
      FlutterManager.getInstance().setUseFullScreen(true, null);
    } else if (mode == SystemUiMode.IMMERSIVE_STICKY) {
      //全屏显示，通过在显示器边缘的滑动手势可以显示状态和导航栏,此手势由应用程序接收
      FlutterManager.getInstance().setUseFullScreen(true, null);
    } else if (mode == SystemUiMode.EDGE_TO_EDGE) {
      uiConfig = ['status', 'navigation'];
    } else {
      return;
    }
    this.showBarOrNavigation = uiConfig;
    this.platform?.updateSystemUiOverlays();
  }

  setSystemChromeSystemUIOverlayStyle(systemChromeStyle: SystemChromeStyle): void {
    let isStatusBarLightIconValue: boolean = false;
    let statusBarContentColorValue: string | undefined = undefined;
    let statusBarColorValue: string | undefined = undefined;
    let navigationBarColorValue: string | undefined = undefined;
    let isNavigationBarLightIconValue: boolean = false;

    const currentProps = this.mainWindow?.getWindowSystemBarProperties();

    if (systemChromeStyle.statusBarIconBrightness != null) {
      switch (systemChromeStyle.statusBarIconBrightness) {
        case Brightness.DARK:
          isStatusBarLightIconValue = false;
          statusBarContentColorValue = '#000000';
          break;
        case Brightness.LIGHT:
          isStatusBarLightIconValue = true;
          statusBarContentColorValue = '#FFFFFF';
          break;
      }
    } else {
      isStatusBarLightIconValue = currentProps?.isStatusBarLightIcon ?? false
    }

    if (systemChromeStyle.statusBarColor != null) {
      statusBarColorValue = "#" + systemChromeStyle.statusBarColor.toString(16).padStart(8, '0');
    } else {
      statusBarColorValue = currentProps?.statusBarColor
    }

    if (systemChromeStyle.systemStatusBarContrastEnforced != null) {

    }

    if (systemChromeStyle.systemNavigationBarIconBrightness != null) {
      switch (systemChromeStyle.systemNavigationBarIconBrightness) {
        case Brightness.DARK:
          isNavigationBarLightIconValue = true;
          break;
        case Brightness.LIGHT:
          isNavigationBarLightIconValue = false;
      }
    } else {
      isNavigationBarLightIconValue = currentProps?.isNavigationBarLightIcon ?? false
    }

    if (systemChromeStyle.systemNavigationBarColor != null) {
      navigationBarColorValue = "#" + systemChromeStyle.systemNavigationBarColor.toString(16).padStart(8, '0');
    } else {
      navigationBarColorValue = currentProps?.navigationBarColor
    }

    if (systemChromeStyle.systemNavigationBarContrastEnforced != null) {

    }
    this.currentTheme = systemChromeStyle;
    const systemBarProperties: window.SystemBarProperties = {
      statusBarColor: statusBarColorValue,
      isStatusBarLightIcon: isStatusBarLightIconValue,
      statusBarContentColor: statusBarContentColorValue,
      navigationBarColor: navigationBarColorValue,
      isNavigationBarLightIcon: isNavigationBarLightIconValue,
      navigationBarContentColor: currentProps?.navigationBarContentColor,
      enableStatusBarAnimation: currentProps?.enableStatusBarAnimation,
      enableNavigationBarAnimation: currentProps?.enableNavigationBarAnimation,
    }
    Log.d(PlatformPluginCallback.TAG, "systemBarProperties: " + JSON.stringify(systemBarProperties));
    this.mainWindow?.setWindowSystemBarProperties(systemBarProperties);
  }

  setSystemChromeEnabledSystemUIOverlays(overlays: SystemUiOverlay[]): void {
    let uiConfig: ('status' | 'navigation')[] = [];
    if (overlays.length == 0) {

    }
    for (let index = 0; index < overlays.length; ++index) {
      let overlayToShow = overlays[index];
      switch (overlayToShow) {
        case SystemUiOverlay.TOP_OVERLAYS:
          uiConfig.push('status'); //hide navigation
          break;
        case SystemUiOverlay.BOTTOM_OVERLAYS:
          uiConfig.push('navigation'); //hide bar
          break;
      }
    }
    this.showBarOrNavigation = uiConfig;
    this.platform?.updateSystemUiOverlays();
  }
}
