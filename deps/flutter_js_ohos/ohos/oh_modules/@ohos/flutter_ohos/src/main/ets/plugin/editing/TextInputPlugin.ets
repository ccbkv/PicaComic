/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on TextInputPlugin.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

import TextInputChannel, {
  Configuration,
  TextEditState,
  TextInputMethodHandler
} from '../../embedding/engine/systemchannels/TextInputChannel';
import inputMethod from '@ohos.inputMethod';
import Log from '../../util/Log';
import { EditingStateWatcher, ListenableEditingState } from './ListenableEditingState';
import Any from '../common/Any';
import { inputDevice } from '@kit.InputKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { PointerDeviceKind } from '../../embedding/ohos/OhosTouchProcessor';
import deviceInfo from '@ohos.deviceInfo';

/// 临时规避缺少newline对应枚举问题
const NEWLINE_KEY_TYPE: number = 8;
const INPUT_SUPPORT_API = 15;

export default class TextInputPlugin implements EditingStateWatcher {
  private static TAG = "TextInputPlugin";
  private textInputChannel: TextInputChannel;
  private mTextInputHandler: TextInputMethodHandlerImpl;

  constructor(textInputChannel: TextInputChannel, viewId: string) {
    this.textInputChannel = textInputChannel;
    // viewId is used for requestFocus
    this.mTextInputHandler = new TextInputMethodHandlerImpl(this, viewId);
    this.textInputChannel.setTextInputMethodHandler(this.mTextInputHandler);
  }

  public clearTextInputClient() {
    this.textInputChannel.textInputMethodHandler?.clearClient();
  }

  setTextInputEditingState(state: TextEditState) {

  }

  getEditingState() {
    return this.mTextInputHandler.mEditable;
  }

  didChangeEditingState(textChanged: boolean, selectionChanged: boolean, composingRegionChanged: boolean): void {
    let editable = this.mTextInputHandler.mEditable;
    let inputTarget = this.mTextInputHandler.inputTarget;
    let configuration = this.mTextInputHandler.configuration;
    if (configuration != null && configuration.enableDeltaModel) {
      this.textInputChannel.updateEditingStateWithDeltas(inputTarget.id, editable.extractBatchTextEditingDeltas());
      editable.clearBatchDeltas();
    } else {
      this.textInputChannel.updateEditingState(inputTarget.id, editable.getStringCache(),
        editable.getSelectionStart(), editable.getSelectionEnd(),
        editable.getComposingStart(), editable.getComposingEnd())
    }
  }

  detach(): void {
    this.mTextInputHandler.inputMethodController.detach((err) => {
      if (err) {
        Log.e(TextInputPlugin.TAG, "Failed to detach: " + JSON.stringify(err));
      }
    })
  }

  destroy() {
    // Since the Dart side no longer listens to the lifecycle,
    // the keyboard must be explicitly hidden before the engine is destroyed.
    this.mTextInputHandler.hide();
    this.textInputChannel.setTextInputMethodHandler(null);
  }
}

const INPUT_TYPE_NAME =
  ['NONE', 'TEXT', 'MULTILINE', 'NUMBER', 'PHONE', 'DATETIME', 'EMAIL_ADDRESS', 'URL', 'VISIBLE_PASSWORD']

class TextInputMethodHandlerImpl implements TextInputMethodHandler {
  private static TAG = "TextInputMethodHandlerImpl";
  private textConfig: inputMethod.TextConfig;
  inputMethodController: inputMethod.InputMethodController;
  inputTarget: InputTarget;
  public configuration: Configuration | null = null;
  private lastKind?: PointerDeviceKind;
  mEditable: ListenableEditingState;
  private mRestartInputPending: boolean = false;
  private plugin: EditingStateWatcher | Any;
  private imcFlag: boolean = false;
  private keyboardStatus: inputMethod.KeyboardStatus = inputMethod.KeyboardStatus.HIDE;
  private inputAttribute: inputMethod.InputAttribute =
    { textInputType: inputMethod.TextInputType.TEXT, enterKeyType: inputMethod.EnterKeyType.NONE };
  private keyboardFocusState: boolean = false;
  private focusViewId: string = "";

  constructor(plugin: TextInputPlugin | Any, viewId: string) {
    this.textConfig = {
      inputAttribute: this.inputAttribute
    };
    this.plugin = plugin;
    this.mEditable = new ListenableEditingState(null, 0);
    this.inputMethodController = inputMethod.getController();
    this.inputTarget = new InputTarget(Type.NO_TARGET, 0);
    this.focusViewId = viewId;
  }

  /// 通过判断是否是TextInputType.none来决定是否弹出键盘
  show(): void {
    if (this.canShowTextInput()) {
      // Ensure the Xcomponent gains focus before the soft keyboard is displayed.
      focusControl.requestFocus(this.focusViewId);
      this.keyboardFocusState = true;
      this.showTextInput();
    } else {
      this.hide();
    }
  }

  hide(): void {
    // Ensure the Xcomponent loses focus before the soft keyboard is hided.
    focusControl.requestFocus("unfocus-xcomponent-node");
    this.keyboardFocusState = false;
    this.hideTextInput();
  }

  requestAutofill(): void {

  }

  finishAutofillContext(shouldSave: boolean): void {

  }

  setClient(textInputClientId: number, configuration: Configuration | null): void {
    this.setTextInputClient(textInputClientId, configuration);
  }

  updateConfig(configuration: Configuration | null) {
    if (configuration) {
      this.lastKind = this.configuration?.deviceKind;
      this.configuration = configuration;
      if (configuration.inputType) {
        this.textConfig.inputAttribute.textInputType = configuration.inputType.type;
        this.textConfig.inputAttribute.enterKeyType = configuration.inputAction as Any;
      }
    }
  }

  setPlatformViewClient(id: number, usesVirtualDisplay: boolean): void {

  }

  setEditableSizeAndTransform(width: number, height: number, transform: number[]): void {

  }

  setCursorSizeAndPosition(cursorInfo: inputMethod.CursorInfo) {
    try {
      this.inputMethodController.updateCursor(cursorInfo, (err: BusinessError) => {
        if (err) {
          Log.e(TextInputMethodHandlerImpl.TAG, "Failed to updateCursor:" + JSON.stringify(err));
          return;
        }
      })
    } catch (err) {
      Log.e(TextInputMethodHandlerImpl.TAG, "Failed to updateCursor:" + JSON.stringify(err));
    }
  }

  setEditingState(editingState: TextEditState): void {
    Log.d(TextInputMethodHandlerImpl.TAG,
      "text:" + editingState.text + " selectionStart:" + editingState.selectionStart + " selectionEnd:"
        + editingState.selectionEnd + " composingStart:" + editingState.composingStart + " composingEnd" +
      editingState.composingEnd);
    this.mEditable.updateTextInputState(editingState);
    this.inputMethodController.changeSelection(this.mEditable.getSelectionString(), this.mEditable.getSelectionStart(),
      this.mEditable.getSelectionEnd());
  }

  clearClient(): void {
    this.clearTextInputClient();
  }

  private async showTextInput(): Promise<void> {
    if (this.keyboardStatus == inputMethod.KeyboardStatus.SHOW) {
      if (this.lastKind != this.configuration?.deviceKind) {
        if (deviceInfo.sdkApiVersion >= INPUT_SUPPORT_API) {
          await this.inputMethodController.showTextInput(this.getRequestReason());
        } else {
          await this.inputMethodController.showTextInput();
        }
      }
      return;
    }
    await this.attach(true);
    if (!this.imcFlag) {
      this.listenKeyBoardEvent();
    }
  }

  private async hideTextInput(): Promise<void> {
    await this.inputMethodController.detach().then(() => {
      this.keyboardStatus = inputMethod.KeyboardStatus.HIDE;
      this.cancelListenKeyBoardEvent();
    }).catch((err: BusinessError) => {
      Log.e(TextInputMethodHandlerImpl.TAG, "Failed to detach: " + JSON.stringify(err));
      this.keyboardStatus = inputMethod.KeyboardStatus.NONE;
    });
  }

  async attach(showKeyboard: boolean): Promise<void> {
    try {
      if (deviceInfo.sdkApiVersion >= INPUT_SUPPORT_API) {
        await this.inputMethodController.attach(showKeyboard, this.textConfig, this.getRequestReason());
      } else {
        await this.inputMethodController.attach(showKeyboard, this.textConfig);
      }
      this.keyboardStatus = inputMethod.KeyboardStatus.SHOW;
    } catch (err) {
      Log.e(TextInputMethodHandlerImpl.TAG, "Failed to attach:" + JSON.stringify(err));
      this.keyboardStatus = inputMethod.KeyboardStatus.NONE;
    }
  }

  getRequestReason() : inputMethod.RequestKeyboardReason {
    let deviceKind : PointerDeviceKind = this.configuration?.deviceKind ?? PointerDeviceKind.UNKNOWN
    Log.i(TextInputMethodHandlerImpl.TAG, "getRequestReason: deviceKind=" + deviceKind);
    switch (deviceKind) {
      case PointerDeviceKind.TOUCH:
        return inputMethod.RequestKeyboardReason.TOUCH;
      case PointerDeviceKind.MOUSE:
        return inputMethod.RequestKeyboardReason.MOUSE;
      case PointerDeviceKind.STYLUS:
      case PointerDeviceKind.INVERTED_STYLUS:
      case PointerDeviceKind.TRACKPAD:
        return inputMethod.RequestKeyboardReason.OTHER;
      default:
        return inputMethod.RequestKeyboardReason.NONE;
    }
  }

  handleChangeFocus(focusState: boolean) {
    if (focusState && this.keyboardFocusState) {
      // When the app loses focus, the system automatically detaches the input method.
      // Upon regaining focus, if the input method should be displayed, it must be reattached.
      this.show();
    }
    try {
      inputDevice.getDeviceList((Error: Error, ids: Array<number>) => {
        let isPhysicalKeyboard = false;
        for (let i = 0; i < ids.length; i++) {
          const type = inputDevice.getKeyboardTypeSync(ids[i]);
          if (type == inputDevice.KeyboardType.ALPHABETIC_KEYBOARD || type == inputDevice.KeyboardType.DIGITAL_KEYBOARD) {
            isPhysicalKeyboard = true;
            break;
          }
        }

        if(focusState && isPhysicalKeyboard && this.keyboardFocusState) {
          this.cancelListenKeyBoardEvent();
          this.inputMethodController.detach().then(async () =>{
            await this.attach(true);
            this.listenKeyBoardEvent();
          })
        }
      })
    } catch (error) {
      Log.e(TextInputMethodHandlerImpl.TAG, `Failed to query device. Code is ${error.code}, message is ${error.message}`)
    }
  }

  async updateAttribute(): Promise<void> {
    if (this.keyboardStatus != inputMethod.KeyboardStatus.SHOW) {
      return;
    }
    try {
      await this.inputMethodController.updateAttribute(this.inputAttribute);
    } catch (err) {
      Log.e(TextInputMethodHandlerImpl.TAG, "Failed to updateAttribute:" + JSON.stringify(err));
    }
  }

  setTextInputClient(client: number, configuration: Configuration | null): void {
    if (configuration) {
      this.configuration = configuration;
      if (configuration.inputType) {
        this.textConfig.inputAttribute.textInputType = configuration.inputType.type;
        this.textConfig.inputAttribute.enterKeyType = configuration.inputAction as Any;
      }
    }
    if (this.canShowTextInput()) {
      this.inputTarget = new InputTarget(Type.FRAMEWORK_CLIENT, client);
    } else {
      this.inputTarget = new InputTarget(Type.NO_TARGET, client);
    }
    this.mEditable.removeEditingStateListener(this.plugin);

    this.mEditable = new ListenableEditingState(this.plugin.textInputChannel, this.inputTarget.id);

    this.mRestartInputPending = true;
    this.mEditable.addEditingStateListener(this.plugin);

    this.inputAttribute = this.textConfig.inputAttribute;

    this.updateAttribute();
  }

  canShowTextInput(): boolean {
    if (this.configuration == null || this.configuration.inputType == null) {
      return true;
    }
    return this.configuration.inputType.type != inputMethod.TextInputType.NONE;
  }

  listenKeyBoardEvent(): void {
    try {
      this.inputMethodController.on('insertText', this.insertTextCallback);
    } catch (err) {
      Log.e(TextInputMethodHandlerImpl.TAG, "Failed to subscribe insertText:" + JSON.stringify(err));
      this.cancelListenKeyBoardEvent();
      return;
    }

    try {
      this.inputMethodController.on('deleteLeft', this.deleteLeftCallback)
    } catch (err) {
      Log.e(TextInputMethodHandlerImpl.TAG, "Failed to subscribe deleteLeft:" + JSON.stringify(err));
      this.cancelListenKeyBoardEvent();
      return;
    }

    try {
      this.inputMethodController.on('deleteRight', this.deleteRightCallback)
    } catch (err) {
      Log.e(TextInputMethodHandlerImpl.TAG, "Failed to subscribe deleteRight:" + JSON.stringify(err));
      this.cancelListenKeyBoardEvent();
      return;
    }

    try {
      this.inputMethodController.on('sendFunctionKey', this.sendFunctionKeyCallback)
    } catch (err) {
      Log.e(TextInputMethodHandlerImpl.TAG, "Failed to subscribe sendFunctionKey:" + JSON.stringify(err));
      this.cancelListenKeyBoardEvent();
      return;
    }

    try {
      this.inputMethodController.on('sendKeyboardStatus', this.sendKeyboardStatusCallback)
    } catch (err) {
      Log.e(TextInputMethodHandlerImpl.TAG, "Failed to subscribe sendKeyboardStatus:" + JSON.stringify(err));
      this.cancelListenKeyBoardEvent();
      return;
    }

    try {
      this.inputMethodController.on('selectByRange', this.selectByRangeCallback)
    } catch (err) {
      Log.e(TextInputMethodHandlerImpl.TAG, "Failed to subscribe selectByRange:" + JSON.stringify(err));
      this.cancelListenKeyBoardEvent();
      return;
    }

    try {
      this.inputMethodController.on('moveCursor', this.moveCursorCallback)
    } catch (err) {
      Log.e(TextInputMethodHandlerImpl.TAG, "Failed to subscribe moveCursor:" + JSON.stringify(err));
      this.cancelListenKeyBoardEvent();
      return;
    }

    Log.d(TextInputMethodHandlerImpl.TAG, "listenKeyBoardEvent success");
    this.imcFlag = true;
  }

  private insertTextCallback = (text: string) => {
    Log.d(TextInputMethodHandlerImpl.TAG, "insertText: " + text);
    this.mEditable.handleInsertTextEvent(text);
    this.inputMethodController.changeSelection(this.mEditable.getSelectionString(), this.mEditable.getSelectionStart(),
      this.mEditable.getSelectionEnd());
  }

  private deleteLeftCallback = (length: number) => {
    this.mEditable.handleDeleteEvent(false, length);
  }

  private deleteRightCallback = (length: number) => {
    this.mEditable.handleDeleteEvent(true, length);
  }

  private sendFunctionKeyCallback = (functionKey: inputMethod.FunctionKey) => {
    /// 临时规避缺少newline对应枚举类型问题
    if (functionKey.enterKeyType == NEWLINE_KEY_TYPE) {
      this.mEditable.handleNewlineEvent();
    }
    this.mEditable.handleFunctionKey(functionKey);
  }

  private sendKeyboardStatusCallback = (state: inputMethod.KeyboardStatus) => {
    this.keyboardStatus = state;
    if (state == inputMethod.KeyboardStatus.HIDE) {
      this.plugin.textInputChannel.onConnectionClosed(this.inputTarget.id);
    }
  }

  private selectByRangeCallback = (range: inputMethod.Range) => {
    this.mEditable.handleSelectByRange(range);
  }

  private moveCursorCallback = (direction: inputMethod.Direction) => {
    this.mEditable.handleMoveCursor(direction);
  }

  cancelListenKeyBoardEvent(): void {
    this.inputMethodController?.off('insertText', this.insertTextCallback);
    this.inputMethodController?.off('deleteLeft', this.deleteLeftCallback);
    this.inputMethodController?.off('deleteRight', this.deleteRightCallback);
    this.inputMethodController?.off('sendFunctionKey', this.sendFunctionKeyCallback);
    this.inputMethodController?.off('sendKeyboardStatus', this.sendKeyboardStatusCallback);
    this.inputMethodController?.off('selectByRange', this.selectByRangeCallback);
    this.inputMethodController?.off('moveCursor', this.moveCursorCallback);
    this.imcFlag = false;
  }

  public clearTextInputClient(): void {
    if (this.inputTarget.type == Type.VIRTUAL_DISPLAY_PLATFORM_VIEW) {
      return;
    }
    this.mEditable.removeEditingStateListener(this.plugin);
    this.configuration = null;
    this.inputTarget = new InputTarget(Type.NO_TARGET, 0);
  }
}

enum Type {
  NO_TARGET,
  // InputConnection is managed by the TextInputPlugin, and events are forwarded to the Flutter
  // framework.
  FRAMEWORK_CLIENT,
  // InputConnection is managed by a platform view that is presented on a virtual display.
  VIRTUAL_DISPLAY_PLATFORM_VIEW,
  PHYSICAL_DISPLAY_PLATFORM_VIEW,
}

export class InputTarget {
  type: Type;
  id: number;

  constructor(type: Type, id: number) {
    this.type = type;
    this.id = id;
  }
}