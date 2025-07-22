/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/


import { FlutterView } from '../../view/FlutterView';
import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import Log from '../../util/Log';
import HashMap from '@ohos.util.HashMap';
import List from '@ohos.util.List';

const TAG = "FlutterManager"

export default class FlutterManager {
  private static instance: FlutterManager;

  static getInstance(): FlutterManager {
    if (FlutterManager.instance == null) {
      FlutterManager.instance = new FlutterManager();
    }
    return FlutterManager.instance;
  }

  private flutterViewList = new Map<String, FlutterView>();
  private flutterViewIndex = 1;
  private uiAbilityList = new Array<UIAbility>();
  private windowStageList = new Map<UIAbility, window.WindowStage>();
  private mFullScreenListener: FullScreenListener = new DefaultFullScreenListener();

  private dragEnterCbId: number = 1;
  private dragMoveCbId: number = 1;
  private dragLeaveCbId: number = 1;
  private dropCbId: number = 1;

  private dragEnterCbs: HashMap<number, DragDropCallback> = new HashMap();
  private dragMoveCbs: HashMap<number, DragDropCallback> = new HashMap();
  private dragLeaveCbs: HashMap<number, DragDropCallback> = new HashMap();
  private dropCbs: HashMap<number, DragDropCallback> = new HashMap();

  private getValuesFromMap(map: HashMap<number, DragDropCallback>): List<DragDropCallback> {
    let list: List<DragDropCallback> = new List();
    map.forEach((value, key) => {
      list.add(value);
    });
    return list;
  }

  getDragEnterCbs(): List<DragDropCallback> {
    return this.getValuesFromMap(this.dragEnterCbs);
  }

  getDragMoveCbs(): List<DragDropCallback> {
    return this.getValuesFromMap(this.dragMoveCbs);
  }

  getDragLeaveCbs(): List<DragDropCallback> {
    return this.getValuesFromMap(this.dragLeaveCbs);
  }

  getDropCbs(): List<DragDropCallback> {
    return this.getValuesFromMap(this.dropCbs);
  }

  addDragEnterCb(callback: DragDropCallback): number {
    this.dragEnterCbs.set(this.dragEnterCbId, callback);
    return this.dragEnterCbId++;
  }

  addDragMoveCb(callback: DragDropCallback): number {
    this.dragMoveCbs.set(this.dragMoveCbId, callback);
    return this.dragMoveCbId++;
  }

  addDragLeaveCb(callback: DragDropCallback): number {
    this.dragLeaveCbs.set(this.dragLeaveCbId, callback);
    return this.dragLeaveCbId++;
  }

  addDropCb(callback: DragDropCallback): number {
    this.dropCbs.set(this.dropCbId, callback);
    return this.dropCbId++;
  }

  removeDragEnterCb(id: number) {
    this.dragEnterCbs.remove(id);
  }

  removeDragMoveCb(id: number) {
    this.dragMoveCbs.remove(id);
  }

  removeDragLeaveCb(id: number) {
    this.dragLeaveCbs.remove(id);
  }

  removeDropCb(id: number) {
    this.dropCbs.remove(id);
  }

  pushUIAbility(uiAbility: UIAbility) {
    this.uiAbilityList.push(uiAbility);
  }

  popUIAbility(uiAbility: UIAbility) {
    let index = this.uiAbilityList.findIndex((item: UIAbility) => item == uiAbility)
    if (index >= 0) {
      this.uiAbilityList.splice(index, 1)
    }
  }

  pushWindowStage(uiAbility: UIAbility, windowStage: window.WindowStage) {
    this.windowStageList.set(uiAbility, windowStage)
  }

  popWindowStage(uiAbility: UIAbility) {
    this.windowStageList.delete(uiAbility)
  }

  getWindowStage(uiAbility: UIAbility): window.WindowStage {
    return this.windowStageList.get(uiAbility)!!
  }

  getUIAbility(context?: Context): UIAbility {
    if (!context && this.uiAbilityList.length > 0) {
      return this.uiAbilityList[0];
    }
    return this.uiAbilityList.find((item: UIAbility) => item.context == context)!!
  }

  hasFlutterView(viewId: string): boolean {
    return this.flutterViewList.has(viewId);
  }

  getFlutterView(viewId: string): FlutterView | null {
    return this.flutterViewList.get(viewId) ?? null;
  }

  getFlutterViewList(): Map<String, FlutterView> {
    return this.flutterViewList;
  }

  private putFlutterView(viewId: string, flutterView?: FlutterView): void {
    if (flutterView != null) {
      this.flutterViewList.set(viewId, flutterView);
    } else {
      this.flutterViewList.delete(viewId);
    }
  }

  /**
   * It's suggested to keep 'oh_flutter_' as the prefix for xcomponent_id.
   * Otherwise it might affect the performance.
   */
  createFlutterView(context: Context): FlutterView {
    let flutterView = new FlutterView(`oh_flutter_${this.flutterViewIndex++}`, context);
    this.putFlutterView(flutterView.getId(), flutterView);
    return flutterView;
  }

  getNextFlutterViewId(idOffset: number = 0): string {
    return `oh_flutter_${this.flutterViewIndex + idOffset}`;
  }

  clear(): void {
    this.flutterViewList.clear();
  }

  setFullScreenListener(listener: FullScreenListener) {
    this.mFullScreenListener = listener
  }

  getFullScreenListener(): FullScreenListener {
    return this.mFullScreenListener;
  }

  setUseFullScreen(use: boolean, context?: Context | null | undefined) {
    this.mFullScreenListener.setUseFullScreen(use, context);
  }

  useFullScreen(): boolean {
    return this.mFullScreenListener.useFullScreen();
  }

  deleteFlutterView(viewId: string, flutterView?: FlutterView): void {
    if (flutterView != null) {
      this.flutterViewList.delete(viewId);
    }
  }
}

export interface DragDropCallback {
  do(event: DragEvent, extraParams: string): void;
}

export interface FullScreenListener {
  useFullScreen(): boolean;

  setUseFullScreen(useFullScreen: boolean, context?: Context | null | undefined): void;
  
  onScreenStateChanged(data: window.WindowStatusType): void;
}

export class DefaultFullScreenListener implements FullScreenListener {
  private fullScreen: boolean = true;
  private skipCheck: boolean = false;

  useFullScreen(): boolean {
    return this.fullScreen;
  }

  setUseFullScreen(useFullScreen: boolean, context?: Context | null | undefined): void {
    this.fullScreen = useFullScreen;
    this.skipCheck = true;

    context = context??getContext(this);
    let window = FlutterManager.getInstance()
      .getWindowStage(FlutterManager.getInstance().getUIAbility(context));
    window.getMainWindowSync().setWindowLayoutFullScreen(useFullScreen);
    Log.i(TAG, "WindowLayoutFullScreen is on")
  }

  onScreenStateChanged(data: window.WindowStatusType): void {
    if (this.skipCheck) {
      Log.i(TAG, "onScreenStateChanged: skipCheck is on, WindowStatusType = " + data)
      return;
    }
    switch (data) {
      case window.WindowStatusType.FULL_SCREEN:

      case window.WindowStatusType.SPLIT_SCREEN:
      case window.WindowStatusType.FLOATING:
      case window.WindowStatusType.MAXIMIZE:
        this.fullScreen = true;
        Log.i(TAG, "onScreenStateChanged: fullScreen = true")
        break;
      default:
        this.fullScreen = false;
        Log.i(TAG, "onScreenStateChanged: fullScreen = false")
        break;
    }
  }
}
