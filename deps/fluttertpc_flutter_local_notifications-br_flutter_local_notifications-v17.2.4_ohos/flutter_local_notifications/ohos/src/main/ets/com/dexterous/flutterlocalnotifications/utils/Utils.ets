/*
 * Copyright (c) 2024 Shenzhen Kaihong Digital Industry Development Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { image } from '@kit.ImageKit';
import { UIAbility } from '@kit.AbilityKit';
import fs from '@ohos.file.fs';
import { PictureSource } from '../models/styles/PictureSource';
import { Log } from '@ohos/flutter_ohos';
import resourceManager from '@ohos.resourceManager';

const TAG = "FlutterUtils";

export class Utils {
  static async getPixelMapFromSource(data: Object, pictureSource: PictureSource, height: number, width: number): Promise<image.PixelMap | undefined> {
    let picPixelMap: image.PixelMap | undefined = undefined;
    try {
      let uiAbility: UIAbility | undefined = globalThis.context;
      if (pictureSource == PictureSource.DrawableResource) {
        let imageArray = await getContext(uiAbility).resourceManager.getMediaByName(String(data));
        let pixelBuffer = new Uint8Array(imageArray).buffer as Object as ArrayBuffer
        if (pixelBuffer) {
          let imageResource = image.createImageSource(pixelBuffer);
          let opts: image.DecodingOptions = {
            editable: true,
            desiredPixelFormat: image.PixelMapFormat.RGBA_8888
          }
          picPixelMap = await imageResource.createPixelMap(opts);
        }
      } else if (pictureSource == PictureSource.FilePath) {
        let path = String(data);
        let stat: fs.Stat = await fs.stat(path);
        let file: fs.File = await fs.open(path);
        let arrayBuffer = new ArrayBuffer(stat.size);
        await fs.read(file.fd, arrayBuffer);
        let imageResource = await image.createImageSource(arrayBuffer);
        let opts: image.DecodingOptions = {
          editable: true,
          desiredPixelFormat: image.PixelMapFormat.RGBA_8888
        }
        picPixelMap = await imageResource.createPixelMap(opts);
      } else if (pictureSource == PictureSource.ByteArray) {
        let dataArray = data as Uint8Array;
        let imageSource: image.ImageSource = image.createImageSource(dataArray.buffer.slice(0));
        picPixelMap = await imageSource.createPixelMap();
      }
    } catch (e) {
      Log.e(TAG, "getPixelMapFromSource-->get picture fail: "+ JSON.stringify(e))
    }
    return picPixelMap;
  }

  public static fromHtml(text: string): string {
    // TODO 缺少去html标签库
    return text;
  }
}