/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on PlatformViewsChannel.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/
import Any from '../../../plugin/common/Any';

import MethodCall from '../../../plugin/common/MethodCall';
import MethodChannel, { MethodCallHandler, MethodResult } from '../../../plugin/common/MethodChannel';
import StandardMethodCodec from '../../../plugin/common/StandardMethodCodec';
import { ByteBuffer } from '../../../util/ByteBuffer';
import Log from '../../../util/Log';
import DartExecutor from '../dart/DartExecutor';

const TAG = "PlatformViewsChannel";
const NON_TEXTURE_FALLBACK = -2;

export default class PlatformViewsChannel {
  private channel: MethodChannel;
  private handler: PlatformViewsHandler | null = null;
  private parsingHandler = new ParsingCallback();

  /**
   * Constructs a {@code PlatformViewsChannel} that connects HarmonyOS to the Dart code running in
   * {@code dartExecutor}.
   *
   * <p>The given {@code dartExecutor} is permitted to be idle or executing code.
   *
   * <p>See {@link DartExecutor}.
   */
  constructor(dartExecutor: DartExecutor) {
    this.channel = new MethodChannel(dartExecutor, "flutter/platform_views", StandardMethodCodec.INSTANCE);
    this.parsingHandler.platformChannel = this;
    this.channel.setMethodCallHandler(this.parsingHandler);
  }

  /**
   * Sets the {@link PlatformViewsHandler} which receives all events and requests that are parsed
   * from the underlying platform views channel.
   */
  public setPlatformViewsHandler(handler: PlatformViewsHandler | null): void {
    this.handler = handler;
    this.parsingHandler.handler = handler;
  }

  public invokeViewFocused(viewId: number): void {
    if (this.channel == null) {
      return;
    }
    this.channel.invokeMethod("viewFocused", viewId);
  }

  create(call: MethodCall, result: MethodResult): void {
    const createArgs: Map<string, Any> = call.args;
    const usesPlatformViewLayer: boolean = createArgs.has("hybrid") && createArgs.get("hybrid") as boolean;
    const additionalParams: ByteBuffer = createArgs.has("params") ? createArgs.get("params") : null;

    let direction: Direction = Direction.Ltr;
    if (createArgs.get("direction") == 0) {
      direction = Direction.Ltr;
    } else if (createArgs.get("direction") == 1) {
      direction = Direction.Rtl;
    }

    try {
      if (usesPlatformViewLayer) {
        const request: PlatformViewCreationRequest = new PlatformViewCreationRequest(
          createArgs.get("id"),
          createArgs.get("viewType"),
          0,
          0,
          0,
          0,
          direction,
          additionalParams,
          RequestedDisplayMode.HYBRID_ONLY
        );
        this.handler?.createForPlatformViewLayer(request);
        result.success(null);
      } else {
        const hybridFallback: boolean = createArgs.has("hybridFallback") && createArgs.get("hybridFallback");
        const displayMode: RequestedDisplayMode =
          hybridFallback ? RequestedDisplayMode.TEXTURE_WITH_HYBRID_FALLBACK
            : RequestedDisplayMode.TEXTURE_WITH_VIRTUAL_FALLBACK;
        const request: PlatformViewCreationRequest = new PlatformViewCreationRequest(
          createArgs.get("id"),
          createArgs.get("viewType"),
          createArgs.has("top") ? createArgs.get("top") : 0.0,
          createArgs.has("left") ? createArgs.get("left") : 0.0,
          createArgs.get("width"),
          createArgs.get("height"),
          direction,
          additionalParams,
          displayMode
        );

        Log.i(TAG, `Create texture param id:${request.viewId},
          type:${request.viewType},
          w:${request.logicalWidth},
          h:${request.logicalHeight},
          l:${request.logicalLeft},
          t:${request.logicalTop},
          d:${request.direction}`);

        const textureId = this.handler?.createForTextureLayer(request);
        if (textureId == NON_TEXTURE_FALLBACK) {
          if (!hybridFallback) {
            throw new Error(
              "Platform view attempted to fall back to hybrid mode when not requested.");
          }

          // A fallback to hybrid mode is indicated with a null texture ID.
          result.success(null);
        } else {
          result.success(textureId);
        }
      }
    } catch (err) {
      Log.e(TAG, "create failed" + err);
      result.error("error", err, null);
    }
  }

  dispose(call: MethodCall, result: MethodResult): void {
    const disposeArgs: Map<string, Any> = call.args;
    const viewId: number = disposeArgs.get("id");
    try {
      this.handler?.dispose(viewId);
      result.success(null);
    } catch (err) {
      Log.e(TAG, "dispose failed", err);
      result.error("error", err, null);
    }
  }

  resize(call: MethodCall, result: MethodResult): void {
    const resizeArgs: Map<string, Any> = call.args;
    const resizeRequest: PlatformViewResizeRequest = new PlatformViewResizeRequest(
      resizeArgs.get("id"),
      resizeArgs.get("width"),
      resizeArgs.get("height")
    );
    try {
      let resizeCallback = new ResizeCallback();
      resizeCallback.result = result;
      this.handler?.resize(resizeRequest, resizeCallback);
    } catch (err) {
      Log.e(TAG, "resize failed", err);
      result.error("error", err, null);
    }
  }

  offset(call: MethodCall, result: MethodResult): void {
    const offsetArgs: Map<string, Any> = call.args;
    try {
      this.handler?.offset(
        offsetArgs.get("id"),
        offsetArgs.get("top"),
        offsetArgs.get("left"));
      result.success(null);
    } catch (err) {
      Log.e(TAG, "offset failed", err);
      result.error("error", err, null);
    }
  }

  touch(call: MethodCall, result: MethodResult): void {
    const args: Array<Any> = call.args;
    let index = 0;
    const touch: PlatformViewTouch = new PlatformViewTouch(
      args[index++],
      args[index++],
      args[index++],
      args[index++],
      args[index++],
      args[index++],
      args[index++],
      args[index++],
      args[index++],
      args[index++],
      args[index++],
      args[index++],
      args[index++],
      args[index++],
      args[index++],
      args[index]
    );

    try {
      this.handler?.onTouch(touch);
      result.success(null);
    } catch (err) {
      Log.e(TAG, "offset failed", err);
      result.error("error", err, null);
    }
  }

  setDirection(call: MethodCall, result: MethodResult): void {
    const setDirectionArgs: Map<string, Any> = call.args;
    const newDirectionViewId: number = setDirectionArgs.get("id");
    const direction: number = setDirectionArgs.get("direction");

    try {
      this.handler?.setDirection(newDirectionViewId, direction);
      result.success(null);
    } catch (err) {
      Log.e(TAG, "setDirection failed", err);
      result.error("error", err, null);
    }
  }

  clearFocus(call: MethodCall, result: MethodResult): void {
    const viewId: number = call.args;
    try {
      this.handler?.clearFocus(viewId);
      result.success(null);
    } catch (err) {
      Log.e(TAG, "clearFocus failed", err);
      result.error("error", err, null);
    }
  }

  synchronizeToNativeViewHierarchy(call: MethodCall, result: MethodResult): void {
    const yes: boolean = call.args;
    try {
      this.handler?.synchronizeToNativeViewHierarchy(yes);
      result.success(null);
    } catch (err) {
      Log.e(TAG, "synchronizeToNativeViewHierarchy failed", err);
      result.error("error", err, null);
    }
  }
}

/**
 * Handler that receives platform view messages sent from Flutter to Ohos through a given
 * {@link PlatformViewsChannel}.
 *
 * <p>To register a {@code PlatformViewsHandler} with a {@link PlatformViewsChannel}, see {@link
 * PlatformViewsChannel#setPlatformViewsHandler(PlatformViewsHandler)}.
 */
export interface PlatformViewsHandler {
  /*
  * The ID returned by {@code createForTextureLayer} to indicate that the requested texture mode
  * was not available and the view creation fell back to {@code PlatformViewLayer} mode.
  *
  * This can only be returned if the {@link PlatformViewCreationRequest} sets
  * {@code TEXTURE_WITH_HYBRID_FALLBACK} as the requested display mode.
  */

  /**
   * The Flutter application would like to display a new Ohos {@code View}, i.e., platform
   * view.
   *
   * <p>The Ohos View is added to the view hierarchy. This view is rendered in the Flutter
   * framework by a PlatformViewLayer.
   *
   * @param request The metadata sent from the framework.
   */
  createForPlatformViewLayer(request: PlatformViewCreationRequest): void;

  /**
   * The Flutter application would like to display a new HarmonyOS {@code View}, i.e., platform
   * view.
   *
   * <p>The HarmonyOS View is added to the view hierarchy. This view is rendered in the Flutter
   * framework by a TextureLayer.
   *
   * @param request The metadata sent from the framework.
   * @return The texture ID.
   */
  createForTextureLayer(request: PlatformViewCreationRequest): number;

  /** The Flutter application would like to dispose of an existing HarmonyOS {@code View}. */
  dispose(viewId: number): void;

  /**
   * The Flutter application would like to resize an existing HarmonyOS {@code View}.
   *
   * @param request The request to resize the platform view.
   * @param onComplete Once the resize is completed, this is the handler to notify the size of the
   *     platform view buffer.
   */
  resize(request: PlatformViewResizeRequest, onComplete: PlatformViewBufferResized): void;

  /**
   * The Flutter application would like to change the offset of an existing HarmonyOS {@code View}.
   */
  offset(viewId: number, top: number, left: number): void;

  /**
   * The user touched a platform view within Flutter.
   *
   * <p>Touch data is reported in {@code touch}.
   */
  onTouch(touch: PlatformViewTouch): void;

  /**
   * The Flutter application would like to change the layout direction of an existing HarmonyOS
   * {@code View}, i.e., platform view.
   */
  setDirection(viewId: number, direction: Direction): void;

  /** Clears the focus from the platform view with a give id if it is currently focused. */
  clearFocus(viewId: number): void;

  /**
   * Whether the render surface of {@code FlutterView} should be converted to a {@code
   * FlutterImageView} when a {@code PlatformView} is added.
   *
   * <p>This is done to synchronize the rendering of the PlatformView and the FlutterView. Defaults
   * to true.
   */
  synchronizeToNativeViewHierarchy(yes: boolean): void;
}

/** Platform view display modes that can be requested at creation time. */
enum RequestedDisplayMode {
  /** Use Texture Layer if possible, falling back to Virtual Display if not. */
  TEXTURE_WITH_VIRTUAL_FALLBACK,
  /** Use Texture Layer if possible, falling back to Hybrid Composition if not. */
  TEXTURE_WITH_HYBRID_FALLBACK,
  /** Use Hybrid Composition in all cases. */
  HYBRID_ONLY,
}

/** Request sent from Flutter to create a new platform view. */
export class PlatformViewCreationRequest {
  /** The ID of the platform view as seen by the Flutter side. */
  public viewId: number;
  /** The type of view to create for this platform view. */
  public viewType: string;
  /** The density independent width to display the platform view. */
  public logicalWidth: number;
  /** The density independent height to display the platform view. */
  public logicalHeight: number;
  /** The density independent top position to display the platform view. */
  public logicalTop: number;
  /** The density independent left position to display the platform view. */
  public logicalLeft: number;
  /**
   * The layout direction of the new platform view.
   */
  public direction: Direction;
  public displayMode: RequestedDisplayMode;
  /** Custom parameters that are unique to the desired platform view. */
  public params: ByteBuffer;

  constructor(viewId: number, viewType: string, logicalTop: number, logicalLeft: number, logicalWidth: number,
    logicalHeight: number, direction: Direction, params: ByteBuffer, displayMode?: RequestedDisplayMode) {
    this.viewId = viewId;
    this.viewType = viewType;
    this.logicalTop = logicalTop;
    this.logicalLeft = logicalLeft;
    this.logicalWidth = logicalWidth;
    this.logicalHeight = logicalHeight;
    this.direction = direction;
    this.displayMode = displayMode ? displayMode : RequestedDisplayMode.TEXTURE_WITH_VIRTUAL_FALLBACK;
    this.params = params;
  }
}

/** Request sent from Flutter to resize a platform view. */
export class PlatformViewResizeRequest {
  /** The ID of the platform view as seen by the Flutter side. */
  public viewId: number;
  /** The new density independent width to display the platform view. */
  public newLogicalWidth: number;
  /** The new density independent height to display the platform view. */
  public newLogicalHeight: number;

  constructor(viewId: number, newLogicalWidth: number, newLogicalHeight: number) {
    this.viewId = viewId;
    this.newLogicalWidth = newLogicalWidth;
    this.newLogicalHeight = newLogicalHeight;
  }
}

/** The platform view buffer size. */
export class PlatformViewBufferSize {
  /** The width of the screen buffer. */
  public width: number;
  /** The height of the screen buffer. */
  public height: number;

  constructor(width: number, height: number) {
    this.width = width;
    this.height = height;
  }
}

/** Allows to notify when a platform view buffer has been resized. */
export abstract class PlatformViewBufferResized {
  abstract run(bufferSize: PlatformViewBufferSize): void;
}

/** The state of a touch event in Flutter within a platform view. */
export class PlatformViewTouch {
  /** The ID of the platform view as seen by the Flutter side. */
  public viewId: number;
  /** The amount of time that the touch has been pressed. */
  public downTime: number;
  public eventTime: number;
  public action: number;
  /** The number of pointers (e.g, fingers) involved in the touch event. */
  public pointerCount: number;
  /** Properties for each pointer, encoded in a raw format. */
  public rawPointerPropertiesList: Any;
  /** Coordinates for each pointer, encoded in a raw format. */
  public rawPointerCoords: Any;
  public metaState: number;
  public buttonState: number;
  /** Coordinate precision along the x-axis. */
  public xPrecision: number;
  /** Coordinate precision along the y-axis. */
  public yPrecision: number;
  public deviceId: number;
  public edgeFlags: number;
  public source: number;
  public flags: number;
  public motionEventId: number;

  constructor(viewId: number,
    downTime: number,
    eventTime: number,
    action: number,
    pointerCount: number,
    rawPointerPropertiesList: Any,
    rawPointerCoords: Any,
    metaState: number,
    buttonState: number,
    xPrecision: number,
    yPrecision: number,
    deviceId: number,
    edgeFlags: number,
    source: number,
    flags: number,
    motionEventId: number) {
    this.viewId = viewId;
    this.downTime = downTime;
    this.eventTime = eventTime;
    this.action = action;
    this.pointerCount = pointerCount;
    this.rawPointerPropertiesList = rawPointerPropertiesList;
    this.rawPointerCoords = rawPointerCoords;
    this.metaState = metaState;
    this.buttonState = buttonState;
    this.xPrecision = xPrecision;
    this.yPrecision = yPrecision;
    this.deviceId = deviceId;
    this.edgeFlags = edgeFlags;
    this.source = source;
    this.flags = flags;
    this.motionEventId = motionEventId;
  }
}

class ParsingCallback implements MethodCallHandler {
  platformChannel: PlatformViewsChannel | null = null;
  handler: PlatformViewsHandler | null = null;

  onMethodCall(call: MethodCall, result: MethodResult) {
    if (this.handler == null) {
      return;
    }

    Log.i(TAG, "Received '" + call.method + "' message.");
    switch (call.method) {
      case "create": {
        this.platformChannel?.create(call, result);
        break;
      }
      case "dispose": {
        this.platformChannel?.dispose(call, result);
        break;
      }
      case "resize": {
        this.platformChannel?.resize(call, result);
        break;
      }
      case "offset": {
        this.platformChannel?.offset(call, result);
        break;
      }
      case "touch": {
        this.platformChannel?.touch(call, result);
        break;
      }
      case "setDirection": {
        this.platformChannel?.setDirection(call, result);
        break;
      }
      case "clearFocus": {
        this.platformChannel?.clearFocus(call, result);
        break;
      }
      case "synchronizeToNativeViewHierarchy": {
        this.platformChannel?.synchronizeToNativeViewHierarchy(call, result);
        break;
      }
      default:
        result.notImplemented();
    }
  }
}

class ResizeCallback extends PlatformViewBufferResized {
  result: MethodResult | null = null;

  run(bufferSize: PlatformViewBufferSize) {
    if (bufferSize == null) {
      this.result?.error("error", "Failed to resize the platform view", null);
    } else {
      const response: Map<string, Any> = new Map();
      response.set("width", bufferSize.width);
      response.set("height", bufferSize.height);
      this.result?.success(response);
    }
  }
}