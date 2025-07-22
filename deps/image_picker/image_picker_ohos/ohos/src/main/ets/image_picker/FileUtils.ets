// Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE_ODID file.
// Based on FileUtils.java originally written by
// Copyright 2013 The Flutter Authors.

import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import util from '@ohos.util';
import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';

const TAG = "FileUtils";

export default class FileUtils {
  static getPathFromUri(context: common.Context | null, uri: string, defExtension?: string) {
    Log.i(TAG, "getPathFromUri : " + uri);
    let inputFile: fs.File;
    try {
      inputFile = fs.openSync(uri);
    } catch (err) {
      Log.e(TAG, "open uri file failed err:" + err)
      return null;
    }
    if (inputFile == null) {
      return null;
    }
    const uuid = util.generateRandomUUID();
    if (!context) {
      return
    }
    {
      const targetDirectoryPath = context.cacheDir + "/" + uuid;
      try {
        fs.mkdirSync(targetDirectoryPath);
        let targetDir = fs.openSync(targetDirectoryPath);
        Log.i(TAG, "mkdirSync success targetDirectoryPath:" + targetDirectoryPath + " fd: " + targetDir.fd);
        fs.closeSync(targetDir);
      } catch (err) {
        Log.e(TAG, "mkdirSync failed err:" + err);
        return null;
      }

      const inputFilePath = uri.substring(uri.lastIndexOf("/") + 1);
      const inputFilePathSplits = inputFilePath.split(".");
      Log.i(TAG, "getPathFromUri inputFilePath: " + inputFilePath);
      const outputFileName = inputFilePathSplits[0];
      let extension: string;
      if (inputFilePathSplits.length == 2) {
        extension = "." + inputFilePathSplits[1];
      } else {
        if (defExtension) {
          extension = defExtension;
        } else {
          extension = ".jpg";
        }
      }
      const outputFilePath = targetDirectoryPath + "/" + outputFileName + extension;
      const outputFile = fs.openSync(outputFilePath, fs.OpenMode.CREATE);
      try {
        Log.i(TAG, "copyFileSync inputFile fd:" + inputFile.fd + " outputFile fd:" + outputFile.fd);
        fs.copyFileSync(inputFile.fd, outputFilePath);
      } catch (err) {
        Log.e(TAG, "copyFileSync failed err:" + err);
        return null;
      } finally {
        fs.closeSync(inputFile);
        fs.closeSync(outputFile);
      }
      return outputFilePath;
    }
  }
}