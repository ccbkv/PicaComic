/*
 * Copyright (c) 2021-2024 Huawei Device Co., Ltd. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE_HW file.
 */
import Any from '../../plugin/common/Any';

import { DVModel, DVModelParameters, DVModelEvents, DVModelChildren } from "./dynamicView";
import Log from '../../util/Log';
const TAG = "dynamicViewJson";

export function createDVModelFromJson(json: Object): DVModel {

  /* private use helper functions */
  let createChildrenFrom: (children: Array<Object>) => DVModelChildren = (children: Array<Object>): DVModelChildren => {
    let result = new DVModelChildren();
    if (Array.isArray(children)) {
      (children as Array<Object>).forEach(child => {
        const childView = createDVModelFromJson(child);
        if (childView != undefined) {
          result.push(childView);
        }
      });
    }
    return result;
  }

  let setParams: (result: DVModelParameters | DVModelEvents, key: Any, element: Object) => void =
    (result: DVModelParameters, key: Any, element: Any): void => {
      let newResult = result as Record<string, Any>;
      newResult[key] = element[key];
    }

  let createAttributesFrom: (attributes: Object) => DVModelParameters = (attributes: Object): DVModelParameters => {
    let result = new DVModelParameters();
    if ((typeof attributes == "object") && (!Array.isArray(attributes))) {
      Object.keys(attributes).forEach(k => {
        setParams(result, k, attributes)
      });
    }
    return result;
  }

  let createEventsFrom: (events: Object) => DVModelEvents = (events: Object): DVModelEvents => {
    let result = new DVModelEvents();
    if ((typeof events == "object") && (!Array.isArray(events))) {
      Object.keys(events).forEach(k => {
        setParams(result, k, events)
      });
    }
    return result;
  }

  if (typeof json !== 'object') {
    Log.e(TAG, "createDVModelFromJson: input is not JSON");
    return new DVModel("", "", "", createChildrenFrom([]));
  }

  let jsonObject = json as Record<string, string | Any>;
  return new DVModel(
    jsonObject["compType"],
    createAttributesFrom(jsonObject["attributes"]),
    createEventsFrom(jsonObject["events"]),
    createChildrenFrom(jsonObject["children"]),
    jsonObject["build"]
  );
}
