/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on TextInputChannel.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

import JSONMethodCodec from '../../../plugin/common/JSONMethodCodec';
import MethodCall from '../../../plugin/common/MethodCall';
import MethodChannel, { MethodCallHandler, MethodResult } from '../../../plugin/common/MethodChannel';
import TextInputPlugin from '../../../plugin/editing/TextInputPlugin';
import Log from '../../../util/Log';
import DartExecutor from '../dart/DartExecutor';
import inputMethod from '@ohos.inputMethod';
import ArrayList from '@ohos.util.ArrayList';
import { TextEditingDelta, TextEditingDeltaJson } from '../../../plugin/editing/TextEditingDelta';
import Any from '../../../plugin/common/Any';
import { display } from '@kit.ArkUI'
import { window } from '@kit.ArkUI';
import { BusinessError, print } from '@kit.BasicServicesKit';
import { PointerDeviceKind } from '../../ohos/OhosTouchProcessor';

const TAG = "TextInputChannel";
/// 规避换行标识无法显示问题，api修改后再删除
const NEWLINE_KEY_TYPE: number = 8;

export default class TextInputChannel {
  private static CHANNEL_NAME = "flutter/textinput";
  public channel: MethodChannel;
  textInputMethodHandler: TextInputMethodHandler | null = null;
  private TextInputCallback: TextInputCallback | null = null;

  constructor(dartExecutor: DartExecutor) {
    this.channel = new MethodChannel(dartExecutor, TextInputChannel.CHANNEL_NAME, JSONMethodCodec.INSTANCE);
  }

  setTextInputMethodHandler(textInputMethodHandler: TextInputMethodHandler | null): void {
    this.textInputMethodHandler = textInputMethodHandler;
    this.TextInputCallback = this.textInputMethodHandler == null
      ? null : new TextInputCallback(this.textInputMethodHandler);
    this.channel.setMethodCallHandler(this.TextInputCallback);
  }

  requestExistingInputState(): void {
    this.channel.invokeMethod("TextInputClient.requestExistingInputState", null);
  }

  createEditingStateJSON(text: string,
    selectionStart: number,
    selectionEnd: number,
    composingStart: number,
    composingEnd: number): EditingState {
    let state: EditingState = {
      text: text,
      selectionBase: selectionStart,
      selectionExtent: selectionEnd,
      composingBase: composingStart,
      composingExtent: composingEnd
    };
    return state;
  }

  createEditingDeltaJSON(batchDeltas: ArrayList<TextEditingDelta>): EditingDelta {
    let deltas: TextEditingDeltaJson[] = [];
    batchDeltas.forEach((val, idx, array) => {
      deltas.push(val.toJSON());
    })

    let state: EditingDelta = {
      deltas: deltas,
    };
    return state;
  }

  /**
   * Instructs Flutter to update its text input editing state to reflect the given configuration.
   */
  updateEditingState(inputClientId: number,
    text: string,
    selectionStart: number,
    selectionEnd: number,
    composingStart: number,
    composingEnd: number): void {
    Log.d(TAG, "updateEditingState:"
      + "Text: " + text + " Selection start: " + selectionStart + " Selection end: "
      + selectionEnd + " Composing start: " + composingStart + " Composing end: " + composingEnd);
    const state: Any = this.createEditingStateJSON(text, selectionStart, selectionEnd, composingStart, composingEnd);
    this.channel.invokeMethod('TextInputClient.updateEditingState', [inputClientId, state]);
  }

  updateEditingStateWithDeltas(inputClientId: number, batchDeltas: ArrayList<TextEditingDelta>): void {
    Log.d(TAG, "updateEditingStateWithDeltas:" + "batchDeltas length: " + batchDeltas.length);
    const state: Any = this.createEditingDeltaJSON(batchDeltas);
    this.channel.invokeMethod('TextInputClient.updateEditingStateWithDeltas', [inputClientId, state]);
  }

  newline(inputClientId: number): void {
    Log.d(TAG, "Sending 'newline' message.");
    this.channel.invokeMethod("TextInputClient.performAction", [inputClientId, "TextInputAction.newline"]);
  }

  go(inputClientId: number): void {
    Log.d(TAG, "Sending 'go' message.");
    this.channel.invokeMethod("TextInputClient.performAction", [inputClientId, "TextInputAction.go"]);
  }

  search(inputClientId: number): void {
    Log.d(TAG, "Sending 'search' message.");
    this.channel.invokeMethod("TextInputClient.performAction", [inputClientId, "TextInputAction.search"]);
  }

  send(inputClientId: number): void {
    Log.d(TAG, "Sending 'send' message.");
    this.channel.invokeMethod("TextInputClient.performAction", [inputClientId, "TextInputAction.send"]);
  }

  done(inputClientId: number): void {
    Log.d(TAG, "Sending 'done' message.");
    this.channel.invokeMethod("TextInputClient.performAction", [inputClientId, "TextInputAction.done"]);
  }

  next(inputClientId: number): void {
    Log.d(TAG, "Sending 'next' message.");
    this.channel.invokeMethod("TextInputClient.performAction", [inputClientId, "TextInputAction.next"]);
  }

  previous(inputClientId: number): void {
    Log.d(TAG, "Sending 'previous' message.");
    this.channel.invokeMethod("TextInputClient.performAction", [inputClientId, "TextInputAction.previous"]);
  }

  unspecifiedAction(inputClientId: number): void {
    Log.d(TAG, "Sending 'unspecifiedAction' message.");
    this.channel.invokeMethod("TextInputClient.performAction", [inputClientId, "TextInputAction.unspecified"]);
  }

  commitContent(inputClientId: number): void {
    Log.d(TAG, "Sending 'commitContent' message.");
    this.channel.invokeMethod("TextInputClient.performAction", [inputClientId, "TextInputAction.commitContent"]);
  }

  onConnectionClosed(inputClientId: number): void {
    Log.d(TAG, "Sending 'onConnectionClosed' message.");
    this.channel.invokeMethod("TextInputClient.onConnectionClosed", [inputClientId]);
    this.textInputMethodHandler?.hide();
  }

  performPrivateCommand(inputClientId: number, action: string, data: Any) {

  }

  public setWindowPosition(windowPosition: window.Rect) {
    this.TextInputCallback?.setWindowPosition(windowPosition);
    this.TextInputCallback?.setCursorPosition();
  }

  public setDevicePixelRatio(devicePixelRatio: number) {
    this.TextInputCallback?.setDevicePixelRatio(devicePixelRatio);
  }
}

interface EditingState {
  text: string;
  selectionBase: number;
  selectionExtent: number;
  composingBase: number;
  composingExtent: number;
}


interface EditingDelta {
  deltas: Array<TextEditingDeltaJson>;
}


export interface TextInputMethodHandler {
  show(): void;

  hide(): void;

  requestAutofill(): void;

  finishAutofillContext(shouldSave: boolean): void;

  setClient(textInputClientId: number, configuration: Configuration | null): void;

  updateConfig(configuration: Configuration | null): void;

  setPlatformViewClient(id: number, usesVirtualDisplay: boolean): void;

  setEditableSizeAndTransform(width: number, height: number, transform: number[]): void;

  setCursorSizeAndPosition(cursorInfo: inputMethod.CursorInfo): void;

  setEditingState(editingState: TextEditState): void;

  clearClient(): void;

  handleChangeFocus(focusState: boolean): void;

}

export class Configuration {
  obscureText: boolean = false;
  autocorrect: boolean = false;
  autofill: boolean = false;
  enableSuggestions: boolean = false;
  enableIMEPersonalizedLearning: boolean = false;
  enableDeltaModel: boolean = false;
  inputType: InputType | null = null;
  inputAction: Number = 0;
  actionLabel: String = "";
  contentCommitMimeTypes: String[] = [];
  deviceKind: PointerDeviceKind = PointerDeviceKind.UNKNOWN;
  fields: Configuration[] = [];

  constructor(obscureText: boolean,
    autocorrect: boolean,
    enableSuggestions: boolean,
    enableIMEPersonalizedLearning: boolean,
    enableDeltaModel: boolean,
    inputType: InputType,
    inputAction: Number,
    actionLabel: String,
    autofill: boolean,
    contentListString: [],
    deviceKind: PointerDeviceKind,
    fields: Configuration[]
  ) {
    this.obscureText = obscureText;
    this.autocorrect = autocorrect;
    this.enableSuggestions = enableSuggestions;
    this.enableIMEPersonalizedLearning = enableIMEPersonalizedLearning;
    this.enableDeltaModel = enableDeltaModel;
    this.inputType = inputType;
    this.inputAction = inputAction;
    this.actionLabel = actionLabel;
    this.autofill = autofill;
    this.contentCommitMimeTypes = contentListString;
    this.fields = fields
    this.deviceKind = deviceKind
  }

  private static inputActionFromTextInputAction(inputActionName: string): number {
    switch (inputActionName) {
      case "TextInputAction.previous":
        return inputMethod.EnterKeyType.PREVIOUS
      case "TextInputAction.unspecified":
        return inputMethod.EnterKeyType.UNSPECIFIED
      case "TextInputAction.none":
        return inputMethod.EnterKeyType.NONE
      case "TextInputAction.go":
        return inputMethod.EnterKeyType.GO
      case "TextInputAction.search":
        return inputMethod.EnterKeyType.SEARCH
      case "TextInputAction.send":
        return inputMethod.EnterKeyType.SEND
      case "TextInputAction.next":
        return inputMethod.EnterKeyType.NEXT
      case "TextInputAction.newline":
        return NEWLINE_KEY_TYPE
      case "TextInputAction.done":
        return inputMethod.EnterKeyType.DONE
      default:
      // Present default key if bad input type is given.
        return inputMethod.EnterKeyType.UNSPECIFIED
    }
  }

  static fromJson(json: Any) {
    const inputActionName: string = json.inputAction;
    if (!inputActionName) {
      throw new Error("Configuration JSON missing 'inputAction' property.");
    }

    let fields: Array<Any> = new Array();
    if (json.fields !== null && json.fields !== undefined) {
      fields = json.fields.map((field: Any): Any => Configuration.fromJson(field));
    }

    const inputAction: number = Configuration.inputActionFromTextInputAction(inputActionName);

    // Build list of content commit mime types from the data in the JSON list.
    const contentList: Array<Any> = [];
    if (json.contentCommitMimeTypes !== null && json.contentCommitMimeTypes !== undefined) {
      json.contentCommitMimeTypes.forEach((type: Any) => {
        contentList.push(type);
      });
    }
    return new Configuration(
      json.obscureText ?? false,
      json.autocorrect ?? true,
      json.enableSuggestions ?? false,
      json.enableIMEPersonalizedLearning ?? false,
      json.enableDeltaModel ?? false,
      InputType.fromJson(json.inputType),
      inputAction,
      json.actionLabel ?? null,
      json.autofill ?? null,
      contentList as Any,
      json.deviceKind ?? PointerDeviceKind.UNKNOWN,
      fields
    );
  }

  static fromMap(map: Map<String, Any>) {
    let inputTypeSrc: Any = map.get('inputType');
    let type = TextInputType.get(inputTypeSrc.name) ?? inputMethod.TextInputType.TEXT;
    let inputType = new InputType(type, inputTypeSrc.decimal, inputTypeSrc.signed);
    let inputAction = Configuration.inputActionFromTextInputAction(map.get('inputAction'));

    let fields: Array<Any> = new Array();
    if (map.get('fields')) {
      fields = map.get('fields').map((field: Any): Any => Configuration.fromJson(field));
    }

    // Build list of content commit mime types from the data in the JSON list.
    const contentList: Array<Any> = [];
    if (map.get('contentCommitMimeTypes')) {
      map.get('contentCommitMimeTypes').forEach((type: Any) => {
        contentList.push(type);
      });
    }
    return new Configuration(
      map.get('obscureText') ?? false,
      map.get('autocorrect') ?? true,
      map.get('enableSuggestions') ?? false,
      map.get('enableIMEPersonalizedLearning') ?? false,
      map.get('enableDeltaModel') ?? false,
      inputType,
      inputAction,
      map.get('actionLabel') ?? null,
      map.get('autofill') ?? null,
      contentList as Any,
      map.get('deviceKind') ?? PointerDeviceKind.UNKNOWN,
      fields
    );
  }
}

/*
/// All possible enum values from flutter.
static const List<TextInputType> values = <TextInputType>[
  text, multiline, number, phone, datetime, emailAddress, url, visiblePassword, name, streetAddress, none,
];

// Corresponding string name for each of the [values].
static const List<String> _names = <String>[
  'text', 'multiline', 'number', 'phone', 'datetime', 'emailAddress', 'url', 'visiblePassword', 'name', 'address', 'none',
];

// Because TextInputType.name and TextInputType.streetAddress do not exist on ohos,
// these two types will be mapped to the default keyboard.
*/
const TextInputType: Map<String, inputMethod.TextInputType> = new Map<String, inputMethod.TextInputType>([
  ["TextInputType.text", inputMethod.TextInputType.TEXT],
  ["TextInputType.multiline", inputMethod.TextInputType.MULTILINE],
  ["TextInputType.number", inputMethod.TextInputType.NUMBER],
  ["TextInputType.phone", inputMethod.TextInputType.PHONE],
  ["TextInputType.datetime", inputMethod.TextInputType.DATETIME],
  ["TextInputType.emailAddress", inputMethod.TextInputType.EMAIL_ADDRESS],
  ["TextInputType.url", inputMethod.TextInputType.URL],
  ["TextInputType.visiblePassword", inputMethod.TextInputType.VISIBLE_PASSWORD],
  ["TextInputType.name", inputMethod.TextInputType.TEXT],
  ["TextInputType.address", inputMethod.TextInputType.TEXT],
  ["TextInputType.none", inputMethod.TextInputType.NONE],
]);

export class InputType {
  type: inputMethod.TextInputType;
  isSigned: boolean;
  isDecimal: boolean;

  constructor(type: inputMethod.TextInputType, isSigned: boolean, isDecimal: boolean) {
    this.type = type;
    this.isSigned = isSigned;
    this.isDecimal = isDecimal;
  }

  static fromJson(json: Any): InputType {
    if (TextInputType.has(json.name as string)) {
      return new InputType(TextInputType.get(json.name as string) as inputMethod.TextInputType,
        json.signed as boolean, json.decimal as boolean)
    }
    throw new Error("No such TextInputType: " + json.name as string);
  }
}

export class TextEditState {
  private static TAG = "TextEditState";
  text: string;
  selectionStart: number;
  selectionEnd: number;
  composingStart: number;
  composingEnd: number;

  constructor(text: string,
    selectionStart: number,
    selectionEnd: number,
    composingStart: number,
    composingEnd: number) {
    if ((selectionStart != -1 || selectionEnd != -1)
      && (selectionStart < 0 || selectionEnd < 0)) {
      throw new Error("invalid selection: (" + selectionStart + ", " + selectionEnd + ")");
    }

    if ((composingStart != -1 || composingEnd != -1)
      && (composingStart < 0 || composingStart > composingEnd)) {
      throw new Error("invalid composing range: (" + composingStart + ", " + composingEnd + ")");
    }

    if (composingEnd > text.length) {
      throw new Error("invalid composing start: " + composingStart);
    }

    if (selectionStart > text.length) {
      throw new Error("invalid selection start: " + selectionStart);
    }

    if (selectionEnd > text.length) {
      throw new Error("invalid selection end: " + selectionEnd);
    }

    this.text = text;
    this.selectionStart = selectionStart;
    this.selectionEnd = selectionEnd;
    this.composingStart = composingStart;
    this.composingEnd = composingEnd;
  }

  hasSelection(): boolean {
    // When selectionStart == -1, it's guaranteed that selectionEnd will also
    // be -1.
    return this.selectionStart >= 0;
  }

  hasComposing(): boolean {
    return this.composingStart >= 0 && this.composingEnd > this.composingStart;
  }

  static fromJson(textEditState: Any): TextEditState {
    if (textEditState.text != null && textEditState.text != undefined && textEditState.text != "") {
      return new TextEditState(
        textEditState.text,
        textEditState.selectionBase,
        textEditState.selectionExtent,
        textEditState.composingBase,
        textEditState.composingExtent
      )
    } else {
      return new TextEditState(
        textEditState.get('text'),
        textEditState.get('selectionBase'),
        textEditState.get('selectionExtent'),
        textEditState.get('composingBase'),
        textEditState.get('composingExtent')
      )
    }
  }
}

class TextInputCallback implements MethodCallHandler {
  textInputMethodHandler: TextInputMethodHandler;
  windowPosition: window.Rect | null = null;
  cursorPosition: window.Rect = {
    left: 0,
    top: 0,
    width: 0,
    height: 0,
  }
  devicePixelRatio = display.getDefaultDisplaySync()?.densityPixels as number;
  inputPosition: window.Rect = {
    left: 0,
    top: 0,
    width: 0,
    height: 0,
  }

  constructor(handler: TextInputMethodHandler) {
    this.textInputMethodHandler = handler;
  }

  setWindowPosition(windowPosition: window.Rect) {
    this.windowPosition = windowPosition;
  }

  setDevicePixelRatio(devicePixelRatio: number) {
    this.devicePixelRatio = devicePixelRatio;
  }

  setCursorPosition() {
    const left = (this.windowPosition?.left ?? 0 as number) + (this.cursorPosition.left + this.inputPosition.left) * this.devicePixelRatio;
    const top = (this.windowPosition?.top ?? 0 as number) + (this.cursorPosition.top + this.inputPosition.top) * this.devicePixelRatio;
    this.textInputMethodHandler.setCursorSizeAndPosition({
      left: left,
      top: top,
      width: 100,
      height: 50,
    })
  }


  onMethodCall(call: MethodCall, result: MethodResult) {
    if (this.textInputMethodHandler == null) {
      return;
    }
    let method: string = call.method;
    let args: Any = call.args;
    Log.d(TAG, "Received '" + method + "' message.");
    switch (method) {
      case "TextInput.show":
        this.textInputMethodHandler.show();
        Log.d(TAG, "textInputMethodHandler.show()");
        result.success(null);
        break;
      case "TextInput.hide":
        this.textInputMethodHandler.hide();
        result.success(null);
        break;
      case "TextInput.setClient":
        const textInputClientId: number = args[0] as number;
        const jsonConfiguration: string = args[1];
        const config: Configuration | null = Configuration.fromJson(jsonConfiguration);

        this.textInputMethodHandler.setClient(textInputClientId, config);
        result.success(null);
        break;
      case 'TextInput.updateConfig':
        const newConfig: Configuration | null = Configuration.fromMap(args as Map<String, Any>);
        this.textInputMethodHandler.updateConfig(newConfig);
        result.success(null);
        break;
      case "TextInput.requestAutofill":
      //TODO: requestAutofill
        result.notImplemented();
        break;
      case "TextInput.setPlatformViewClient":
      //TODO:
        result.notImplemented();
        break;
      case "TextInput.setEditingState":
        this.textInputMethodHandler.setEditingState(TextEditState.fromJson(args));
        result.success(null);
        break;
      case "TextInput.setCaretRect":
        this.cursorPosition.top = args.get('y');
        this.cursorPosition.left = args.get('x');
        this.cursorPosition.width = args.get('width');
        this.cursorPosition.height = args.get('height');
        this.setCursorPosition();
        break;
      case "TextInput.setEditableSizeAndTransform":
        this.inputPosition.left = args.get('transform')[12];
        this.inputPosition.top = args.get('transform')[13];
        this.setCursorPosition();
        break;
      case "TextInput.clearClient":
        this.textInputMethodHandler.clearClient();
        result.success(null);
        break;
      case "TextInput.sendAppPrivateCommand":
      //TODO:
        result.notImplemented();
        break;
      case "TextInput.finishAutofillContext":
      //TODO:
        result.notImplemented();
        break;
      default:
        result.notImplemented();
        break;
    }
  }
}
