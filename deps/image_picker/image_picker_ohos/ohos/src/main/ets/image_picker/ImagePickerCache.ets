// Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE_ODID file.
// Based on ImagePickerCache.java originally written by
// Copyright 2013 The Flutter Authors.

import common from '@ohos.app.ability.common';
import data_preferences from '@ohos.data.preferences'
import ArrayList from '@ohos.util.ArrayList';
import HashMap from '@ohos.util.HashMap';
import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';
import { ImageSelectionOptions, CacheRetrievalError, CacheRetrievalType, CacheRetrievalErrorBuilder } from './Messages';

export enum CacheType {
  IMAGE,
  VIDEO
}
;
const TAG = "ImagePickerCache";

export default class ImagePickerCache {
  static MAP_KEY_PATH_LIST = "pathList";
  static MAP_KEY_MAX_WIDTH = "maxWidth";
  static MAP_KEY_MAX_HEIGHT = "maxHeight";
  static MAP_KEY_IMAGE_QUALITY = "imageQuality";
  static MAP_KEY_TYPE = "type";
  static MAP_KEY_ERROR = "error";
  private static MAP_TYPE_VALUE_IMAGE = "image";
  private static MAP_TYPE_VALUE_VIDEO = "video";
  private static FLUTTER_IMAGE_PICKER_IMAGE_PATH_KEY =
    "flutter_image_picker_image_path";
  private static SHARED_PREFERENCE_ERROR_CODE_KEY = "flutter_image_picker_error_code";
  private static SHARED_PREFERENCE_ERROR_MESSAGE_KEY =
    "flutter_image_picker_error_message";
  private static SHARED_PREFERENCE_MAX_WIDTH_KEY = "flutter_image_picker_max_width";
  private static SHARED_PREFERENCE_MAX_HEIGHT_KEY = "flutter_image_picker_max_height";
  private static SHARED_PREFERENCE_IMAGE_QUALITY_KEY =
    "flutter_image_picker_image_quality";
  private static SHARED_PREFERENCE_TYPE_KEY = "flutter_image_picker_type";
  private static SHARED_PREFERENCE_PENDING_IMAGE_URI_PATH_KEY =
    "flutter_image_picker_pending_image_uri";
  private static SHARED_PREFERENCES_NAME = "flutter_image_picker_shared_preference";
  private context: common.Context;
  private preferences: data_preferences.Preferences = {} as data_preferences.Preferences;

  constructor(context: common.Context) {
    this.context = context;
    data_preferences.getPreferences(this.context, ImagePickerCache.SHARED_PREFERENCES_NAME)
      .then((preferences) => {
        this.preferences = preferences;
      })
      .catch(() => {
        Log.e(TAG, "getPreferences failed");
      });
  }

  saveType(type: CacheType): void {
    switch (type) {
      case CacheType.IMAGE: {
        this.setType(ImagePickerCache.MAP_TYPE_VALUE_IMAGE);
        break;
      }
      case CacheType.VIDEO: {
        this.setType(ImagePickerCache.MAP_TYPE_VALUE_VIDEO)
        break;
      }
    }
  }

  private setType(type: string): void {
    try {
      this.setPreferenceData(ImagePickerCache.SHARED_PREFERENCES_NAME, type);
    } catch (err) {
      Log.e(TAG, "setType failed");
    }
  }

  private setPreferenceData(key: string, data: data_preferences.ValueType): void {
    if (this.preferences == null) {
      return;
    }
    this.preferences.put(key, data)
      .then(() => {
        this.preferences.flush().catch(() => {
          Log.e(TAG, "preferences flush failed");
        });
      })
      .catch(() => {
        Log.e(TAG, "preferences put failed");
      });
  }

  private async getPreferenceData(key: string, defValue: data_preferences.ValueType | null): Promise<data_preferences.ValueType | null> {
    if (this.preferences == null) {
      return defValue;
    }
    const result = await this.preferences.get(key, defValue)
      .then((data) => {
        return data;
      })
      .catch(() => {
        Log.e(TAG, "preferences get failed");
        return defValue;
      });
    return result;
  }

  private async hasKey(key: string): Promise<boolean> {
    if (this.preferences == null) {
      return false;
    }
    try {
      const hasKey = await this.preferences.has(key)
        .then((result) => {
          return result;
        })
        .catch(() => {
          Log.e(TAG, "preferences has failed");
          return false;
        })
      return hasKey;
    } catch (err) {
      Log.e(TAG, "preferences hasKey failed");
    }
    return false;
  }

  saveDimensionWithOutputOptions(options: ImageSelectionOptions): void {
    if (options.getMaxWidth() != null) {
      this.setPreferenceData(ImagePickerCache.SHARED_PREFERENCE_MAX_WIDTH_KEY, options.getMaxWidth());
    }
    if (options.getMaxHeight() != null) {
      this.setPreferenceData(ImagePickerCache.SHARED_PREFERENCE_MAX_HEIGHT_KEY, options.getMaxHeight());
    }
    this.setPreferenceData(ImagePickerCache.SHARED_PREFERENCE_IMAGE_QUALITY_KEY, options.getQuality());
  }

  savePendingCameraMediaUriPath(uri: string): void {
    try {
      this.setPreferenceData(ImagePickerCache.SHARED_PREFERENCE_PENDING_IMAGE_URI_PATH_KEY, uri);
    } catch (err) {
      Log.e(TAG, "savePendingCameraMediaUriPath failed");
    }
  }

  async retrievePendingCameraMediaUriPath(): Promise<string | null> {
    let result: data_preferences.ValueType | null = null;
    try {
      result = await this.getPreferenceData(ImagePickerCache.SHARED_PREFERENCE_PENDING_IMAGE_URI_PATH_KEY, "")
        .then((data) => {
          return data;
        });
    } catch (err) {
      Log.e(TAG, "retrievePendingCameraMediaUriPath failed");
    }
    if (typeof result != 'string') {
      result = "";
    }
    return result;
  }

  saveResult(path: ArrayList<string>, errorCode: string | null, errorMessage: string | null): void {
    if (path != null) {
      let pathArray = path.convertToArray();
      this.setPreferenceData(ImagePickerCache.FLUTTER_IMAGE_PICKER_IMAGE_PATH_KEY, pathArray);
    }
    if (errorCode != null) {
      this.setPreferenceData(ImagePickerCache.SHARED_PREFERENCE_ERROR_CODE_KEY, errorCode);
    }
    if (errorMessage != null) {
      this.setPreferenceData(ImagePickerCache.SHARED_PREFERENCE_ERROR_MESSAGE_KEY, errorMessage);
    }
  }

  clear(): void {
    if (this.preferences == null) {
      return;
    }
    try {
      this.preferences.clear().catch(() => {
        Log.e(TAG, "preferences clear failed");
      });
    } catch (err) {
      Log.e(TAG, "preferences clear failed");
    }
  }

  async getCacheMap(): Promise<HashMap<string, ArrayList<data_preferences.ValueType>>> {
    const resultMap: HashMap<string, ArrayList<data_preferences.ValueType> | ESObject> = new HashMap<string, ArrayList<data_preferences.ValueType> | ESObject>();
    let hasData = false;
    let hasKey = await this.hasKey(ImagePickerCache.FLUTTER_IMAGE_PICKER_IMAGE_PATH_KEY).then((result) => {
      return result;
    });
    if (hasKey) {
      let pathArray = await this.getPreferenceData(ImagePickerCache.FLUTTER_IMAGE_PICKER_IMAGE_PATH_KEY, null)
        .then((data) => {
          return data;
        });
      if (pathArray != null && Array.isArray(pathArray)) {
        let pathList: ArrayList<data_preferences.ValueType> = new ArrayList();
        pathArray.forEach((path: data_preferences.ValueType) => {
          pathList.add(path);
        });
        resultMap.set(ImagePickerCache.MAP_KEY_PATH_LIST, pathList);
        hasData = true;
      }
    }

    hasKey = await this.hasKey(ImagePickerCache.SHARED_PREFERENCE_ERROR_CODE_KEY).then((result) => {
      return result;
    });
    if (hasKey) {
      let errorCode = await this.getPreferenceData(ImagePickerCache.SHARED_PREFERENCE_ERROR_CODE_KEY, "")
        .then((data) => {
          return data;
        });
      let error = new CacheRetrievalErrorBuilder(null, null, null);
      if (error.setCode) {
        error.setCode(errorCode as string);
      }

      hasData = true;
      hasKey = await this.hasKey(ImagePickerCache.SHARED_PREFERENCE_ERROR_MESSAGE_KEY).then((result) => {
        return result;
      });
      if (hasKey) {
        let errorMessage = await this.getPreferenceData(ImagePickerCache.SHARED_PREFERENCE_ERROR_MESSAGE_KEY, "")
          .then((data) => {
            return data;
          });
        if (error.setMessage) {
          error.setMessage(errorMessage as string);
        }

      }
      if (resultMap.set && error.build) {
        resultMap.set(ImagePickerCache.MAP_KEY_ERROR, error.build());
      }
    }

    if (hasData) {
      hasKey = await this.hasKey(ImagePickerCache.SHARED_PREFERENCE_TYPE_KEY).then((result) => {
        return result;
      });
      if (hasKey) {
        let type = await this.getPreferenceData(ImagePickerCache.SHARED_PREFERENCE_TYPE_KEY, "")
          .then((data) => {
            return data;
          });

        resultMap.set(ImagePickerCache.MAP_KEY_TYPE, type == ImagePickerCache.MAP_TYPE_VALUE_VIDEO ? CacheRetrievalType.VIDEO : CacheRetrievalType.IMAGE);
      }
      hasKey = await this.hasKey(ImagePickerCache.SHARED_PREFERENCE_MAX_WIDTH_KEY).then((result) => {
        return result;
      });
      if (hasKey) {
        let maxWidthValue = await this.getPreferenceData(ImagePickerCache.SHARED_PREFERENCE_MAX_WIDTH_KEY, 0)
          .then((data) => {
            return data;
          });
        resultMap.set(ImagePickerCache.MAP_KEY_MAX_WIDTH, maxWidthValue);
      }
      hasKey = await this.hasKey(ImagePickerCache.SHARED_PREFERENCE_MAX_HEIGHT_KEY).then((result) => {
        return result;
      });
      if (hasKey) {
        let maxHeightValue = await this.getPreferenceData(ImagePickerCache.SHARED_PREFERENCE_MAX_HEIGHT_KEY, 0)
          .then((data) => {
            return data;
          });
        resultMap.set(ImagePickerCache.MAP_KEY_MAX_HEIGHT, maxHeightValue);
      }
      await this.getPreferenceData(ImagePickerCache.SHARED_PREFERENCE_IMAGE_QUALITY_KEY, 100)
        .then((data) => {
          return data;
        });
      resultMap.set(ImagePickerCache.MAP_KEY_IMAGE_QUALITY, ImagePickerCache);
    }

    return resultMap;
  }
}