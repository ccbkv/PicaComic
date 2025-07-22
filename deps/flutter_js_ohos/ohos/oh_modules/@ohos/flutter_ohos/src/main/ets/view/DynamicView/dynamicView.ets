/*
 * Copyright (c) 2021-2024 Huawei Device Co., Ltd. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE_HW file.
 */
import matrix4 from '@ohos.matrix4';
import Any from '../../plugin/common/Any';
import Log from '../../util/Log';

/**
 * Dynamic View creation
 * from a recursive data structure
 *
 * exported @Component: DynamicView
 * exported view model classes:
 * - DVModelContainer
 * - DVModel
 * - DVModelParameters
 * - DVModelEvents
 * - DVModelChildren
 *
 * The purpose of exporting the DVModel classes
 * is to make them available to the converter from
 * JD's XML format and the expression parser. These
 * components are expected to generate and update the
 * DVModel.
 *
 * An application written by JS should only import
 * DynamicView, DVModelContainer to be used in their own ArkUI
 * container view.
 */

/**
 * View Model classes
 */

@Observed
export class DVModelParameters extends Object {
  /* empty, just get any instance wrapped inside an ObservedObject
  with the help of the decoration */
}

@Observed
export class DVModelEvents extends Object {
  /* empty, just get any instance wrapped inside an ObservedObject
  with the help of the decoration */
}

@Observed
export class DVModelChildren extends Array<DVModel> {
  /* empty, just get any instance wrapped inside an ObservedObject
  with the help of the decoration */
}

let nextId: number = 1;

@Observed
export class DVModel {
  id_: number;
  compType: string;
  params: DVModelParameters;
  events: DVModelEvents;
  children: DVModelChildren;
  builder: Any;

  constructor(compType: string, params: DVModelParameters, events: DVModelEvents, children: DVModelChildren,
    builder?: Any) {
    this.id_ = nextId++;
    this.compType = compType;
    this.params = params ?? new DVModelParameters;
    this.events = events;
    this.children = children;
    this.builder = builder;
  }

  public getLayoutParams(): DVModelParameters {
    return this.params;
  }
}

// includes the root DVModel objects.
export class DVModelContainer {
  model: DVModel;

  constructor(model: DVModel) {
    this.model = model;
  }
}

/**
 DynamicView is the @Component that does all the work:

 The following 4 features are the key solution elements for dynamic View
 construction and update:

 1. The if statement decides which framework component to create.
 We can not use a factory function here, because that would requite calling
 a regular function inside build() or a @Builder function.

 2. Take note of the @Builder for Row, Column containers:
 These functions create DynamicView Views inside a DynamicView
 view. This behaviour is why we talk about DynamicView as a 'recursive' View.
 All @Builder functions are member functions of the DynamicView @Component to
 retain access ('this.xyz') to its decorated state variables.

 3. The @Extend functions execute attribute and event handler registration functions
 for all attributes and events permissable on the framework component, irrespective
 if DVModelParameters or DVModelEvents objects includes a value or not. If not
 the attribute or event is set to 'undefined' by intention. This is required to unset
 any previously set value.

 4. The scope ('this') of any lambda registered as an event hander function, e.g. for onClick,
 is the @Component, in which the DVModel object is initialized. This said, it is advised to initialize
 the DVModel object in the @Component that is parent to outmost DynamicView. Thereby,
 any event handler function is able to mutate decorated state variables of that @Component

 */

@Component
export struct DynamicView {
  @ObjectLink model: DVModel;
  @ObjectLink children: DVModelChildren;
  @ObjectLink params: DVModelParameters;
  @ObjectLink events: DVModelEvents;
  @BuilderParam customBuilder?: ($$: BuilderParams) => void;
  getParams: (params: DVModelParameters, element: string) => string | Any =
    (params: DVModelParameters, element: string): string | Any => {
      let params2 = params as Record<string, Any>;
      return params2[element];
    }
  getEvents: (events: DVModelEvents, element: string) => Any = (events: DVModelEvents, element: string): Any => {
    let events2 = events as Record<string, Any>;
    return events2[element];
  }

  /*
    we use this @Styles member function to set all common attributes and event handlers
    and set component specific attribute and event handler functions in the @Builder function
  */
  @Styles
  common_attrs() {
    .width(this.getParams(this.params, "width"))
    .height(this.getParams(this.params, "height"))
    .backgroundColor(this.getParams(this.params, "backgroundColor"))
    .onClick(this.getEvents(this.events, "onClick"))
    .margin({
      left: this.getParams(this.params, "marginLeft"),
      right: this.getParams(this.params, "marginRight"),
      top: this.getParams(this.params, "marginTop"),
      bottom: this.getParams(this.params, "marginBottom")
    })
    .onTouch(this.getEvents(this.events, "onTouch"))
    .onFocus(this.getEvents(this.events, "onFocus"))
    .onBlur(this.getEvents(this.events, "onBlur"))
    .translate({
      x: this.getParams(this.params, "translateX"),
      y: this.getParams(this.params, "translateY"),
      z: this.getParams(this.params, "translateZ")
    })
    .transform(this.getParams(this.params, "matrix"))
    .direction(this.getParams(this.params, "direction"))
  }

  @Styles
  clip_attrs() {
    .clip(this.getParams(this.params, "rectWidth") ? new Rect({
      width: this.getParams(this.params, "rectWidth"),
      height: this.getParams(this.params, "rectHeight"),
      radius: this.getParams(this.params, "rectRadius")
    }) : null)
    .clip(this.getParams(this.params, "pathWidth") ? new Path({
      width: this.getParams(this.params, "pathWidth"),
      height: this.getParams(this.params, "pathHeight"),
      commands: this.getParams(this.params, "pathCommands")
    }) : null)
  }

  @Builder
  buildChildren() {
    ForEach(this.children,
      (child: Any) => {
        DynamicView({
          model: child as DVModel,
          params: child.params,
          events: child.events,
          children: child.children,
          customBuilder: child.builder
        })
      },
      (child: Any) => `${child.id_}`
    )
  }

  @Builder
  buildRow() {
    Row() {
      this.buildChildren()
    }
    .common_attrs()
    .clip_attrs()
  }

  @Builder
  buildColumn() {
    Column() {
      this.buildChildren()
    }
    .common_attrs()
    .clip_attrs()
  }

  @Builder
  buildStack() {
    Stack() {
      this.buildChildren()
    }
    .common_attrs()
    .clip_attrs()
    .alignContent(this.getParams(this.params, "alignContent"))
  }

  @Builder
  buildText() {
    Text(`${this.getParams(this.params, "value")}`)
      .common_attrs()
      .fontColor(this.getParams(this.params, "fontColor"))
  }

  @Builder
  buildImage() {
    Image(this.getParams(this.params, "src"))
      .common_attrs()
  }

  // Button with label
  @Builder
  buildButton() {
    Button(this.getParams(this.params, "value"))
      .common_attrs()
  }

  @Builder
  buildNodeContainer() {
    NodeContainer(this.getParams(this.params, "nodeController"))
      .common_attrs()
      .position({
        x: (this.params as Record<string, Any>)['left'] as number,
        y: (this.params as Record<string, Any>)['top'] as number
      })
  }

  @Builder
  buildCustom() {
    if (this.customBuilder) {
      this.customBuilder(new BuilderParams(this.params));
    }
  }

  build() {
    if (this.model.compType == "Column") {
      this.buildColumn()
    } else if (this.model.compType == "Row") {
      this.buildRow()
    } else if (this.model.compType == "Stack") {
      this.buildStack()
    } else if (this.model.compType == "Text") {
      this.buildText()
    } else if (this.model.compType == "Image") {
      this.buildImage()
    } else if (this.model.compType == "Button") {
      this.buildButton()
    } else if (this.model.compType == "NodeContainer") {
      this.buildNodeContainer()
    } else {
      this.buildCustom()
    }
  }
}

export class BuilderParams {
  params: DVModelParameters;

  constructor(params: DVModelParameters) {
    this.params = params;
  }
}
