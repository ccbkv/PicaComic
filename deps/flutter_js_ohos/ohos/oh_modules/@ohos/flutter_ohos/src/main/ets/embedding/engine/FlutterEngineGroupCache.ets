/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/

import FlutterEngineGroup from './FlutterEngineGroup';

export default class FlutterEngineGroupCache {
  static readonly instance = new FlutterEngineGroupCache();
  private cachedEngineGroups = new Map<String, FlutterEngineGroup>();

  contains(engineGroupId: string): boolean {
    return this.cachedEngineGroups.has(engineGroupId);
  }

  get(engineGroupId: string): FlutterEngineGroup | null {
    return this.cachedEngineGroups.get(engineGroupId) ?? null;
  }

  put(engineGroupId: string, engineGroup?: FlutterEngineGroup) {
    if (engineGroup != null) {
      this.cachedEngineGroups.set(engineGroupId, engineGroup);
    } else {
      this.cachedEngineGroups.delete(engineGroupId);
    }
  }

  clear(): void {
    this.cachedEngineGroups.clear();
  }
}