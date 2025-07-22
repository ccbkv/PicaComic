// Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE_ODID file.
// Based on ExifDataCopier.java originally written by
// Copyright 2013 The Flutter Authors.

import image from '@ohos.multimedia.image'
import fs from '@ohos.file.fs';
import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';

const TAG = "ExifDataCopier";

export default class ExifDataCopier {
  async copyExif(filePathOri: string, filePathDest: string): Promise<void> {
    const attributes = [
      "FNumber",
      "ExposureTime",
      "ISOSpeedRatings",
      "DateTimeOriginal",
      "Flash",
      "Orientation",
      "SceneType",
      "GPSLatitude",
      "GPSLatitudeRef",
      "GPSLongitude",
      "GPSLongitudeRef"];

    let oldImageFile: fs.File | null = null;
    let newImageFile: fs.File | null = null;
    let oldImage: image.ImageSource | null = null;
    let newImage: image.ImageSource | null = null;
    try {
      oldImageFile = fs.openSync(filePathOri);
      newImageFile = fs.openSync(filePathDest);
      oldImage = image.createImageSource(oldImageFile.fd);
      newImage = image.createImageSource(newImageFile.fd);
      for (let copyAttribute of attributes) {
        try {
          await oldImage.getImageProperty(copyAttribute).then(async (data) => {
            if (data != null && newImage) {
              await newImage.modifyImageProperty(copyAttribute, data.toString());
            }
          });
        } catch (e) {
          Log.e(TAG, "Copy " + copyAttribute + " data failed." + e);
        }
      }
    } finally {
      if (oldImage != null) {
        oldImage.release();
      }
      if (newImage != null) {
        newImage.release();
      }
      this.closFile(oldImageFile);
      this.closFile(newImageFile);
    }
  }

  private closFile(file: fs.File | null): void {
    if (file == null) {
      return;
    }

    try {
      fs.closeSync(file);
    } catch (e) {
      Log.e(TAG, "Close file failed failed " + e);
    }
  }
}