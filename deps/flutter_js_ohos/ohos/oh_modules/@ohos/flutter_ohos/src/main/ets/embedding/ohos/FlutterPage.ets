/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/

import Log from '../../util/Log';
import { FlutterView } from '../../view/FlutterView';
import FlutterManager from './FlutterManager';
import { DVModel, DVModelChildren, DynamicView } from '../../view/DynamicView/dynamicView';
import Any from '../../plugin/common/Any';
import flutter from 'libflutter.so';

const TAG = "FlutterPage";


/**
 * 基础page组件，承载XComponent组件
 */
@Component
export struct FlutterPage {
  @Prop safeAreaEdges: SafeAreaEdge[] | undefined = [];
  @Prop safeAreaTypes: SafeAreaType[] | undefined = [];
  @Prop viewId: string = ""
  @Prop xComponentType: XComponentType = XComponentType.SURFACE
  /**
   * renderFit under XComponent has a default setting of RESIZE_FILL.
   * If the size of XComponent may change, this property needs to be passed in and set to a size-preserving property,
   * such as TOP_LEFT.
   */
  @Prop xComponentRenderFit: RenderFit = RenderFit.RESIZE_FILL;

  /**
   * A switch for enabling the frame cache.
   * When it is true, one frame of response latency will be increased in exchange for higher smoothness,
   * and occasional timeouts in rendering frame submissions will not result in frame dropping.
   */
  @Prop enableFrameCacheForSmooth: boolean = true;

  @Builder
  doNothingBuilder() {
  }

  defaultFocusOnTouch = false;
  
  @BuilderParam splashScreenView: () => void = this.doNothingBuilder;

  @Builder
  defaultPage() {
    Stack() {
      ForEach(this.rootDvModel!!, (child: ESObject) => {
        DynamicView({
          model: child as DVModel,
          params: child.params,
          events: child.events,
          children: child.children,
          customBuilder: child.builder
        })
      }, (child: ESObject) => `${child.id_}`)

      Text("").id("unfocus-xcomponent-node").focusable(true)

      XComponent({ id: this.viewId, type: this.xComponentType, libraryname: 'flutter' })
        .id(this.viewId)
        .focusable(true)
        .focusOnTouch(this.defaultFocusOnTouch)
        .onLoad((context) => {
          this.flutterView?.onSurfaceCreated();
          // Callback is triggered when the xcomponent window is partially visible or completely hidden.
          this.getUIContext()?.getAttachedFrameNodeById(this.viewId)?.commonEvent.setOnVisibleAreaApproximateChange(
            { ratios: [0.0, 1.0], expectedUpdateInterval: 0 },
            (isExpanding: boolean, currentRatio: number) => {
              if (isExpanding) {
                Log.i(TAG, "setOnVisibleAreaApproximateChange -> xcomponentId: " + this.viewId +
                  " isExpanding: " + isExpanding + " ratio: " + currentRatio);
                flutter.nativeUpdateCurrentXComponentId(this.viewId);
              }
            }
          )
          Log.d(TAG, "XComponent onLoad ");
        })
        .onDestroy(() => {
          Log.d(TAG, "XComponent onDestroy ");
          this.flutterView?.onSurfaceDestroyed()
        })
        .renderFit(this.xComponentRenderFit)
        .backgroundColor(this.firstFrameDisplayed && this.xComponentRenderFit == RenderFit.RESIZE_FILL ?
        this.xComponentColor : Color.Transparent)
        .expandSafeArea(this.safeAreaTypes, this.safeAreaEdges)
      if (this.showSplashScreen) {
        this.splashScreenView();
      }
    }
    .defaultFocus(true)
    .onKeyPreIme((event: KeyEvent) => {
      return this.flutterView?.onKeyPreIme(event) ?? false;
    })
    .onKeyEvent((event: KeyEvent) => {
      return this.flutterView?.onKeyEvent(event) ?? false;
    })
    .onDragEnter((event: DragEvent, extraParams: string) => {
      FlutterManager.getInstance().getDragEnterCbs().forEach(dragEnterCb => {
        dragEnterCb.do(event, extraParams);
      });
      Log.d(TAG, "onDragEnter");
    })
    .onDragMove((event: DragEvent, extraParams: string) => {
      FlutterManager.getInstance().getDragMoveCbs().forEach(dragMoveCb => {
        dragMoveCb.do(event, extraParams);
      });
      Log.d(TAG, "onDragMove");
    })
    .onDragLeave((event: DragEvent, extraParams: string) => {
      FlutterManager.getInstance().getDragLeaveCbs().forEach(dragLeaveCb => {
        dragLeaveCb.do(event, extraParams);
      });
      Log.d(TAG, "onDragLeave");
    })
    .onDrop((event: DragEvent, extraParams: string) => {
      FlutterManager.getInstance().getDropCbs().forEach(dropCb => {
        dropCb.do(event, extraParams);
      });
      Log.d(TAG, "onDrop");
    })
  }

  @Builder
  mouseWheelPage() {
    Stack() {
      ForEach(this.rootDvModel!!, (child: Any) => {
        DynamicView({
          model: child as DVModel,
          params: child.params,
          events: child.events,
          children: child.children,
          customBuilder: child.builder
        })
      }, (child: ESObject) => `${child.id_}`)

      Text("").id("unfocus-xcomponent-node").focusable(true)

      XComponent({ id: this.viewId, type: this.xComponentType, libraryname: 'flutter' })
        .id(this.viewId)
        .focusable(true)
        .focusOnTouch(this.defaultFocusOnTouch)
        .onLoad((context) => {
          this.flutterView?.onSurfaceCreated();
          // Callback is triggered when the xcomponent window is partially visible or completely hidden.
          this.getUIContext()?.getAttachedFrameNodeById(this.viewId)?.commonEvent.setOnVisibleAreaApproximateChange(
            { ratios: [0.0, 1.0], expectedUpdateInterval: 0 },
            (isExpanding: boolean, currentRatio: number) => {
              if (isExpanding) {
                Log.i(TAG, "setOnVisibleAreaApproximateChange -> xcomponentId: " + this.viewId +
                  " isExpanding: " + isExpanding + " ratio: " + currentRatio);
                flutter.nativeUpdateCurrentXComponentId(this.viewId);
              }
            }
          )
          Log.d(TAG, "XComponent onLoad ");
        })
        .onDestroy(() => {
          Log.d(TAG, "XComponent onDestroy ");
          this.flutterView?.onSurfaceDestroyed()
        })
        .renderFit(this.xComponentRenderFit)
        .backgroundColor(this.firstFrameDisplayed && this.xComponentRenderFit == RenderFit.RESIZE_FILL ?
        this.xComponentColor : Color.Transparent)
        .expandSafeArea(this.safeAreaTypes, this.safeAreaEdges)

      if (this.showSplashScreen) {
        this.splashScreenView();
      }
    }
    .defaultFocus(true)
    .onKeyPreIme((event: KeyEvent) => {
      return this.flutterView?.onKeyPreIme(event) ?? false;
    })
    .onKeyEvent((event: KeyEvent) => {
      this.flutterView?.onKeyEvent(event)
    })
    .onDragEnter((event: DragEvent, extraParams: string) => {
      FlutterManager.getInstance().getDragEnterCbs().forEach(dragEnterCb => {
        dragEnterCb.do(event, extraParams);
      });
      Log.d(TAG, "onDragEnter");
    })
    .onDragMove((event: DragEvent, extraParams: string) => {
      FlutterManager.getInstance().getDragMoveCbs().forEach(dragMoveCb => {
        dragMoveCb.do(event, extraParams);
      });
      Log.d(TAG, "onDragMove");
    })
    .onDragLeave((event: DragEvent, extraParams: string) => {
      FlutterManager.getInstance().getDragLeaveCbs().forEach(dragLeaveCb => {
        dragLeaveCb.do(event, extraParams);
      });
      Log.d(TAG, "onDragLeave");
    })
    .onDrop((event: DragEvent, extraParams: string) => {
      FlutterManager.getInstance().getDropCbs().forEach(dropCb => {
        dropCb.do(event, extraParams);
      });
      Log.d(TAG, "onDrop");
    })
    .gesture(
      PanGesture(this.panOption)
        .onActionStart((event: GestureEvent) => {
          this.flutterView?.onMouseWheel("actionStart", event);
        })
        .onActionUpdate((event: GestureEvent) => {
          this.flutterView?.onMouseWheel("actionUpdate", event);
        })
        .onActionEnd((event: GestureEvent) => {
          this.flutterView?.onMouseWheel("actionEnd", event);
        })
    )
  }

  @State showSplashScreen: boolean = true;
  /**
   * To address the black(or other color set by usr) flashing frame when switching between ArkUI and Flutter pages,
   * the background color should be kept transparent until the onFirstFrame is called.
   * When the window size changes, modifying the renderFit property in the relevant callback does not take effect immediately.
   * The first frame will use the old renderFit property and the old background color, resulting in visual artifacts (such as stretching or a black screen).
   * Therefore, we cannot automatically change the relevant properties through state variables at this time.
   */
  @State firstFrameDisplayed: boolean = false;
  @State xComponentColor: Color = Color.Black

  @State checkFullScreen: boolean = true;
  @State checkKeyboard: boolean = true;
  @State checkGesture: boolean = true;
  @State checkMouseWheel: boolean = true;
  @State checkAiBar: boolean = true;
  @Prop @Watch("onPaddingChange")paddingTop?: number = undefined;
  @StorageLink('nodeWidth') storageLinkWidth: number = 0;
  @StorageLink('nodeHeight') storageLinkHeight: number = 0;


  @State rootDvModel: DVModelChildren | undefined = undefined

  private flutterView?: FlutterView | null
  private panOption: PanGestureOptions = new PanGestureOptions({ direction: PanDirection.Up | PanDirection.Down });

  aboutToAppear() {
    this.flutterView = FlutterManager.getInstance().getFlutterView(this.viewId);
    this.flutterView?.addFirstFrameListener(this)
    this.flutterView?.addFirstPreloadFrameListener(this)

    this.flutterView?.setCheckFullScreen(this.checkFullScreen)
    this.flutterView?.setCheckKeyboard(this.checkKeyboard)
    this.flutterView?.setCheckGesture(this.checkGesture)
    this.flutterView?.setPaddingTop(this.paddingTop)
    this.flutterView?.setCheckAiBar(this.checkAiBar)
    this.flutterView?.enableFrameCache(this.enableFrameCacheForSmooth);

    this.rootDvModel = this.flutterView!!.getDVModel().children
  }

  aboutToDisappear() {
    this.flutterView?.removeFirstFrameListener(this);
    this.flutterView?.removeFirstPreloadFrameListener(this)
  }

  onFirstFrame() {
    this.showSplashScreen = false;
    this.firstFrameDisplayed = true;
  }

  onFirstPreloadFrame() {
  }

  onPaddingChange() {
    this.flutterView?.setPaddingTop(this.paddingTop);
  }

  build() {
    if (this.checkMouseWheel) {
      this.mouseWheelPage();
    } else {
      this.defaultPage();
    }
  }
}
