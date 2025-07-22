/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on PlatformChannel.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

import hiTraceMeter from '@ohos.hiTraceMeter';
import JSONMethodCodec from '../../../plugin/common/JSONMethodCodec';
import MethodCall from '../../../plugin/common/MethodCall';
import MethodChannel, { MethodCallHandler, MethodResult } from '../../../plugin/common/MethodChannel';
import Log from '../../../util/Log';
import DartExecutor from '../dart/DartExecutor';
import pasteboard from '@ohos.pasteboard';
import bundleManager from '@ohos.bundle.bundleManager';
import window from '@ohos.window';
import Any from '../../../plugin/common/Any';
import { BusinessError } from '@kit.BasicServicesKit';

export default class PlatformChannel {
  private static TAG = "PlatformChannel";
  private static CHANNEL_NAME = "flutter/platform";
  channel: MethodChannel;
  platformMessageHandler: PlatformMessageHandler | null = null;

  constructor(dartExecutor: DartExecutor) {
    this.channel = new MethodChannel(dartExecutor, PlatformChannel.CHANNEL_NAME, JSONMethodCodec.INSTANCE);
    let callback = new PlatformMethodCallback(this);
    this.channel.setMethodCallHandler(callback);
  }

  setPlatformMessageHandler(platformMessageHandler: PlatformMessageHandler | null): void {
    this.platformMessageHandler = platformMessageHandler;
  }

  systemChromeChanged(areOverlaysVisible: boolean): void {
    Log.d(PlatformChannel.TAG, "Sending 'systemUIChange' message.");
    this.channel.invokeMethod("SystemChrome.systemUIChange", [areOverlaysVisible]);
  }

  decodeOrientations(encodedOrientations: string[]): number {
    let requestedOrientation = 0x00;
    let firstRequestedOrientation = 0x00;
    for (let index = 0; index < encodedOrientations.length; index += 1) {
      let encodedOrientation = encodedOrientations[index];
      Log.d(PlatformChannel.TAG, "encodedOrientation[" + index + "]: " + encodedOrientation);
      let orientation = this.getDeviceOrientationFromValue(encodedOrientation);
      switch (orientation) {
        case DeviceOrientation.PORTRAIT_UP:
          requestedOrientation |= 0x01;
          break;
        case DeviceOrientation.PORTRAIT_DOWN:
          requestedOrientation |= 0x04;
          break;
        case DeviceOrientation.LANDSCAPE_LEFT:
          requestedOrientation |= 0x08;
          break;
        case DeviceOrientation.LANDSCAPE_RIGHT:
          requestedOrientation |= 0x02;
          break;
      }
      if (firstRequestedOrientation == 0x00) {
        firstRequestedOrientation = requestedOrientation;
      }
    }

    switch (requestedOrientation) {
      case 0x00:
        return window.Orientation.UNSPECIFIED;
      case 0x01:
        return window.Orientation.PORTRAIT;
      case 0x02:
        return window.Orientation.LANDSCAPE_INVERTED;
      case 0x03:
      case 0x04:
        return window.Orientation.PORTRAIT_INVERTED;
      case 0x05:
        return window.Orientation.AUTO_ROTATION_PORTRAIT;
      case 0x06:
      case 0x07:
      case 0x08:
        return window.Orientation.LANDSCAPE;
      case 0x09:
      case 0x0a:
        return window.Orientation.AUTO_ROTATION_LANDSCAPE;
      case 0x0b:
        return window.Orientation.LOCKED;
      case 0x0c:
      case 0x0d:
      case 0x0e:
        switch (firstRequestedOrientation) {
          case 0x01:
            return bundleManager.DisplayOrientation.PORTRAIT;
          case 0x02:
            return bundleManager.DisplayOrientation.LANDSCAPE_INVERTED;
          case 0x04:
            return bundleManager.DisplayOrientation.PORTRAIT_INVERTED;
          case 0x08:
            return bundleManager.DisplayOrientation.LANDSCAPE;
        }
      case 0x0f:
        return window.Orientation.AUTO_ROTATION_RESTRICTED;
    }
    return bundleManager.DisplayOrientation.PORTRAIT;
  }

  getFeedbackTypeFromValue(encodedName: string): HapticFeedbackType {
    if (encodedName == null) {
      return HapticFeedbackType.STANDARD;
    }
    let feedbackTypes: string[] = [
      HapticFeedbackType.STANDARD,
      HapticFeedbackType.LIGHT_IMPACT,
      HapticFeedbackType.MEDIUM_IMPACT,
      HapticFeedbackType.HEAVY_IMPACT,
      HapticFeedbackType.SELECTION_CLICK
    ];
    if (feedbackTypes.includes(encodedName as HapticFeedbackType)) {
      return encodedName as HapticFeedbackType;
    } else {
      Log.e(PlatformChannel.TAG, "No such HapticFeedbackType:" + encodedName);
      return HapticFeedbackType.STANDARD;
    }
  }

  getClipboardContentFormatFromValue(encodedName: string): ClipboardContentFormat {
    let clipboardFormats: string[] = [ClipboardContentFormat.PLAIN_TEXT];
    if (clipboardFormats.includes(encodedName as ClipboardContentFormat)) {
      return encodedName as ClipboardContentFormat;
    }
    return ClipboardContentFormat.PLAIN_TEXT;
  }

  getSystemUiOverlayFromValue(encodedName: string): SystemUiOverlay {
    let systemUiOverlays: string[] = [SystemUiOverlay.TOP_OVERLAYS, SystemUiOverlay.BOTTOM_OVERLAYS];
    if (systemUiOverlays.includes(encodedName as SystemUiOverlay)) {
      return encodedName as SystemUiOverlay;
    }
    throw new Error("No such SystemUiOverlay: " + encodedName);
  }

  getSystemUiModeFromValue(encodedName: string): SystemUiMode {
    let systemUiModes: string[] = [
      SystemUiMode.LEAN_BACK, SystemUiMode.IMMERSIVE,
      SystemUiMode.IMMERSIVE_STICKY, SystemUiMode.EDGE_TO_EDGE
    ];
    if (systemUiModes.includes(encodedName as SystemUiMode)) {
      return encodedName as SystemUiMode;
    }
    throw new Error("No such SystemUiOverlay: " + encodedName);
  }

  getBrightnessFromValue(encodedName: string): Brightness {
    let brightnesses: string[] = [Brightness.LIGHT, Brightness.DARK];
    if (brightnesses.includes(encodedName as Brightness)) {
      return encodedName as Brightness;
    }
    throw new Error("No such Brightness: " + encodedName);
  }

  getDeviceOrientationFromValue(encodedName: string): DeviceOrientation {
    let deviceOrientations: DeviceOrientation[] = [
      DeviceOrientation.PORTRAIT_UP, DeviceOrientation.PORTRAIT_DOWN,
      DeviceOrientation.LANDSCAPE_LEFT, DeviceOrientation.LANDSCAPE_RIGHT
    ];
    if (deviceOrientations.includes(encodedName as DeviceOrientation)) {
      return encodedName as DeviceOrientation;
    }
    throw new Error("No such DeviceOrientation: " + encodedName);
  }

  getScrollActivityFromValue(activity: string): ScrollActivity {
    let activityTypes: string[] = [
      ScrollActivity.START,
      ScrollActivity.END
    ];
    if (activityTypes.includes(activity as ScrollActivity)) {
      return activity as ScrollActivity;
    }
    throw new Error("No such ScrollActivity: " + activity);
  }

}

export enum HapticFeedbackType {
  STANDARD = "STANDARD",
  LIGHT_IMPACT = "HapticFeedbackType.lightImpact",
  MEDIUM_IMPACT = "HapticFeedbackType.mediumImpact",
  HEAVY_IMPACT = "HapticFeedbackType.heavyImpact",
  SELECTION_CLICK = "HapticFeedbackType.selectionClick"
}

export interface PlatformMessageHandler {
  playSystemSound(soundType: SoundType): void;

  vibrateHapticFeedback(feedbackType: HapticFeedbackType): Promise<void>;

  setPreferredOrientations(ohosOrientation: number, result: MethodResult): void;

  setApplicationSwitcherDescription(description: AppSwitcherDescription): void;

  showSystemOverlays(overlays: SystemUiOverlay[]): void;

  showSystemUiMode(mode: SystemUiMode): void;

  setSystemUiChangeListener(): void;

  restoreSystemUiOverlays(): void;

  setSystemUiOverlayStyle(systemUiOverlayStyle: SystemChromeStyle): void;

  popSystemNavigator(): void;

  getClipboardData(result: MethodResult): void;

  setClipboardData(text: string, result: MethodResult): void;

  clipboardHasStrings(): boolean;
}

export enum ClipboardContentFormat {
  PLAIN_TEXT = "text/plain",
}

export enum SoundType {
  CLICK = "SystemSoundType.click",
  ALERT = "SystemSoundType.alert",
}

export class AppSwitcherDescription {
  public readonly color: number;
  public readonly label: string;

  constructor(color: number, label: string) {
    this.color = color;
    this.label = label;
  }
}

export enum SystemUiOverlay {
  TOP_OVERLAYS = "SystemUiOverlay.top",
  BOTTOM_OVERLAYS = "SystemUiOverlay.bottom",
}

export enum SystemUiMode {
  LEAN_BACK = "SystemUiMode.leanBack",
  IMMERSIVE = "SystemUiMode.immersive",
  IMMERSIVE_STICKY = "SystemUiMode.immersiveSticky",
  EDGE_TO_EDGE = "SystemUiMode.edgeToEdge",
}

export enum Brightness {
  LIGHT = "Brightness.light",
  DARK = "Brightness.dark",
}

export class SystemChromeStyle {
  public readonly statusBarColor: number | null;
  public readonly statusBarIconBrightness: Brightness | null;
  public readonly systemStatusBarContrastEnforced: boolean | null;
  public readonly systemNavigationBarColor: number | null;
  public readonly systemNavigationBarIconBrightness: Brightness | null;
  public readonly systemNavigationBarDividerColor: number | null;
  public readonly systemNavigationBarContrastEnforced: boolean | null;

  constructor(statusBarColor: number | null,
    statusBarIconBrightness: Brightness | null,
    systemStatusBarContrastEnforced: boolean | null,
    systemNavigationBarColor: number | null,
    systemNavigationBarIconBrightness: Brightness | null,
    systemNavigationBarDividerColor: number | null,
    systemNavigationBarContrastEnforced: boolean | null) {
    this.statusBarColor = statusBarColor;
    this.statusBarIconBrightness = statusBarIconBrightness;
    this.systemStatusBarContrastEnforced = systemStatusBarContrastEnforced;
    this.systemNavigationBarColor = systemNavigationBarColor;
    this.systemNavigationBarIconBrightness = systemNavigationBarIconBrightness;
    this.systemNavigationBarDividerColor = systemNavigationBarDividerColor;
    this.systemNavigationBarContrastEnforced = systemNavigationBarContrastEnforced;
  }
}

export enum DeviceOrientation {
  PORTRAIT_UP = "DeviceOrientation.portraitUp",
  PORTRAIT_DOWN = "DeviceOrientation.portraitDown",
  LANDSCAPE_LEFT = "DeviceOrientation.landscapeLeft",
  LANDSCAPE_RIGHT = "DeviceOrientation.landscapeRight",
}

export enum ScrollActivity {
  START = "start",
  END = "end",
}

class PlatformMethodCallback implements MethodCallHandler {
  private static TAG = "PlatformMethodCallback"
  platform: PlatformChannel;

  constructor(platform: PlatformChannel) {
    this.platform = platform;
  }

  onMethodCall(call: MethodCall, result: MethodResult) {
    if (this.platform.platformMessageHandler == null) {
      Log.w(PlatformMethodCallback.TAG, "platformMessageHandler is null");
      return;
    }

    let method: string = call.method;
    let args: Any = call.args;
    Log.d(PlatformMethodCallback.TAG, "Received '" + method + "' message.");
    try {
      switch (method) {
        case "SystemSound.play":
          break;
        case "HapticFeedback.vibrate":
          try {
            Log.d(PlatformMethodCallback.TAG, "HapticFeedback: " + args as string);
            let feedbackType = this.platform.getFeedbackTypeFromValue(args as string);
            this.platform.platformMessageHandler.vibrateHapticFeedback(feedbackType)
              .then(() => {
                result.success(null);
              })
              .catch((e: BusinessError) => {
                Log.e(PlatformMethodCallback.TAG, `HapticFeedback.vibrate error: ${e.code} - ${e.message}`);
              });
          } catch (e) {
            Log.e(PlatformMethodCallback.TAG, "HapticFeedback.vibrate error:" + JSON.stringify(e));
          }
          break;
        case "SystemChrome.setPreferredOrientations":
          Log.d(PlatformMethodCallback.TAG, "setPreferredOrientations: " + JSON.stringify(args));
          let ohosOrientation = this.platform.decodeOrientations(args as string[]);
          this.platform.platformMessageHandler.setPreferredOrientations(ohosOrientation, result);
          break;
        case "SystemChrome.setApplicationSwitcherDescription":
          Log.d(PlatformMethodCallback.TAG, "setApplicationSwitcherDescription: " + JSON.stringify(args));
          try {
            let description: AppSwitcherDescription = this.decodeAppSwitcherDescription(args);
            this.platform.platformMessageHandler.setApplicationSwitcherDescription(description);
            result.success(null);
          } catch (err) {
            Log.e(PlatformMethodCallback.TAG, "setApplicationSwitcherDescription err:" + JSON.stringify(err));
            result.error("error", JSON.stringify(err), null);
          }
          break;
        case "SystemChrome.setEnabledSystemUIOverlays":
          try {
            let overlays: SystemUiOverlay[] = this.decodeSystemUiOverlays(args);
            Log.d(PlatformMethodCallback.TAG, "overlays: " + overlays);
            this.platform.platformMessageHandler.showSystemOverlays(overlays);
            result.success(null);
          } catch (err) {
            Log.e(PlatformMethodCallback.TAG, "setEnabledSystemUIOverlays err:" + JSON.stringify(err));
            result.error("error", JSON.stringify(err), null);
          }
          break;
        case "SystemChrome.setEnabledSystemUIMode":
          try {
            Log.d(PlatformMethodCallback.TAG, "setEnabledSystemUIMode args:" + args as string);
            let mode: SystemUiMode = this.decodeSystemUiMode(args as string)
            this.platform.platformMessageHandler.showSystemUiMode(mode);
          } catch (err) {
            Log.e(PlatformMethodCallback.TAG, "setEnabledSystemUIMode err:" + JSON.stringify(err));
            result.error("error", JSON.stringify(err), null);
          }
          break;
        case "SystemChrome.setSystemUIChangeListener":
          this.platform.platformMessageHandler.setSystemUiChangeListener();
          result.success(null);
          break;
        case "SystemChrome.restoreSystemUIOverlays":
          this.platform.platformMessageHandler.restoreSystemUiOverlays();
          result.success(null);
          break;
        case "SystemChrome.setSystemUIOverlayStyle":
          try {
            Log.d(PlatformMethodCallback.TAG, "setSystemUIOverlayStyle asrgs: " + JSON.stringify(args));
            let systemChromeStyle: SystemChromeStyle = this.decodeSystemChromeStyle(args);
            this.platform.platformMessageHandler.setSystemUiOverlayStyle(systemChromeStyle);
            result.success(null);
          } catch (err) {
            Log.e(PlatformMethodCallback.TAG, "setSystemUIOverlayStyle err:" + JSON.stringify(err));
            result.error("error", JSON.stringify(err), null);
          }
          break;
        case "SystemNavigator.pop":
          this.platform.platformMessageHandler.popSystemNavigator();
          result.success(null);
          break;
        case "Clipboard.getData":
          this.platform.platformMessageHandler.getClipboardData(result);
          break;
        case "Clipboard.setData":
          let clipboardContent: string = args.get('text');
          this.platform.platformMessageHandler.setClipboardData(clipboardContent, result);
          break;
        case "Clipboard.hasStrings":
          let response: Any = new Map().set("value", false);
          let systemPasteboard = pasteboard.getSystemPasteboard();
          systemPasteboard.hasData().then((hasData) => {
            response.set("value", hasData);
            result.success(response);
          }).catch((err: Any) => {
            Log.e(PlatformMethodCallback.TAG, "systemPasteboard.hasData err: " + JSON.stringify(err));
          })
          break;
        case "Scroll.Activity":
          this.recordScrollActivity(args as string);
          break;
        default:
          result.notImplemented();
          break;
      }
    } catch (e) {
      result.error("error", JSON.stringify(e), null);
    }
  }

  private decodeAppSwitcherDescription(encodedDescription: Map<string, Object>): AppSwitcherDescription {
    let color: number = encodedDescription.get('color') as number;
    let label: string = encodedDescription.get('label') as string;
    return new AppSwitcherDescription(color, label);
  }

  private decodeSystemUiOverlays(encodedSystemUiOverlay: string[]): SystemUiOverlay[] {
    let overlays: SystemUiOverlay[] = [];
    for (let i = 0; i < encodedSystemUiOverlay.length; i++) {
      const encodedOverlay = encodedSystemUiOverlay[i];
      const overlay = this.platform.getSystemUiOverlayFromValue(encodedOverlay);
      switch (overlay) {
        case SystemUiOverlay.TOP_OVERLAYS:
          overlays.push(SystemUiOverlay.TOP_OVERLAYS);
          break;
        case SystemUiOverlay.BOTTOM_OVERLAYS:
          overlays.push(SystemUiOverlay.BOTTOM_OVERLAYS);
          break;
      }
    }
    return overlays;
  }

  private decodeSystemUiMode(encodedSystemUiMode: string): SystemUiMode {
    let mode: SystemUiMode = this.platform.getSystemUiModeFromValue(encodedSystemUiMode);
    switch (mode) {
      case SystemUiMode.LEAN_BACK:
        return SystemUiMode.LEAN_BACK;
      case SystemUiMode.IMMERSIVE:
        return SystemUiMode.IMMERSIVE;
      case SystemUiMode.IMMERSIVE_STICKY:
        return SystemUiMode.IMMERSIVE_STICKY;
      case SystemUiMode.EDGE_TO_EDGE:
      default:
        return SystemUiMode.EDGE_TO_EDGE;
    }
  }

  private decodeSystemChromeStyle(encodedStyle: Map<string, Object> | null): SystemChromeStyle {
    let statusBarColor: number | null = null;
    let statusBarIconBrightness: Brightness | null = null;
    let systemStatusBarContrastEnforced: boolean | null = null;
    let systemNavigationBarColor: number | null = null;
    let systemNavigationBarIconBrightness: Brightness | null = null;
    let systemNavigationBarDividerColor: number | null = null;
    let systemNavigationBarContrastEnforced: boolean | null = null;
    if (encodedStyle?.get('statusBarColor') != null) {
      statusBarColor = encodedStyle.get('statusBarColor') as number;
    }
    if (encodedStyle?.get('statusBarIconBrightness') != null) {
      statusBarIconBrightness =
        this.platform.getBrightnessFromValue(encodedStyle.get('statusBarIconBrightness') as string);
    }
    if (encodedStyle?.get('systemStatusBarContrastEnforced') != null) {
      systemStatusBarContrastEnforced = encodedStyle.get('systemStatusBarContrastEnforced') as boolean;
    }
    if (encodedStyle?.get('systemNavigationBarColor') != null) {
      systemNavigationBarColor = encodedStyle.get('systemNavigationBarColor') as number;
    }
    if (encodedStyle?.get('systemNavigationBarIconBrightness') != null) {
      systemNavigationBarIconBrightness =
        this.platform.getBrightnessFromValue(encodedStyle.get('systemNavigationBarIconBrightness') as string);
    }
    if (encodedStyle?.get('systemNavigationBarDividerColor') != null) {
      systemNavigationBarDividerColor = encodedStyle.get('systemNavigationBarDividerColor') as number;
    }
    if (encodedStyle?.get('systemNavigationBarContrastEnforced') != null) {
      systemNavigationBarContrastEnforced = encodedStyle.get('systemNavigationBarContrastEnforced') as boolean;
    }
    return new SystemChromeStyle(
      statusBarColor,
      statusBarIconBrightness,
      systemStatusBarContrastEnforced,
      systemNavigationBarColor,
      systemNavigationBarIconBrightness,
      systemNavigationBarDividerColor,
      systemNavigationBarContrastEnforced
    );
  }

  private recordScrollActivity(scrollActivity: string) {
    let activityType = this.platform.getScrollActivityFromValue(scrollActivity);
    switch(activityType) {
      case ScrollActivity.START:
        hiTraceMeter.startTrace('flutter::APP_LIST_FLING', 0);
        break;
      case ScrollActivity.END:
        hiTraceMeter.finishTrace('flutter::APP_LIST_FLING', 0);
        break;
    }
  }
}
