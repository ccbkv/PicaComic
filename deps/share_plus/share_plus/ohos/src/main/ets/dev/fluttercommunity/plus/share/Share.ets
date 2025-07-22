/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd.
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

import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';
import common from '@ohos.app.ability.common';
import UIAbility from '@ohos.app.ability.UIAbility';
import List from '@ohos.util.List';
import fs from '@ohos.file.fs';
import { fileUri } from '@kit.CoreFileKit';
import { MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import systemShare from '@hms.collaboration.systemShare';
import uniformTypeDescriptor from '@ohos.data.uniformTypeDescriptor';

const TAG = 'Share';

export default class Share {
  public context: common.Context | null = null;
  public ability?: UIAbility | null = null;

  constructor(context: common.Context, ability?: UIAbility) {
    this.context = context;
  }

  public setAbility(ability: UIAbility | null): void {
    this.ability = ability;
  }

  public async share(text: string, subject: string | null, withResult: boolean, result: MethodResult,): Promise<void> {
    Log.i(TAG, "share");
    let record: systemShare.SharedRecord = {
      utd: uniformTypeDescriptor.getUniformDataTypeByMIMEType('text/plain'),
      content: text,
      title: subject!
    }
    let data = new systemShare.SharedData(record);
    this.startShare(data, withResult, result);
  }

  public async shareFiles(paths: List<string>, mimeTypes: List<string> | null, text: string, subject: string | null,
    fileNameOverrides: string | null, withResult: boolean, result: MethodResult): Promise<void> {
    Log.i(TAG, "shareFiles");
    this.clearShareCacheFolder()
    let fileUris = await this.getUrisForPaths(paths)
    try {
      let data: systemShare.SharedData | null = null;
      if (fileUris.length == 0 && text.length !== 0) {
        this.share(text, subject, withResult, result)
        return
      } else if (fileUris.length == 1) {
        let record: systemShare.SharedRecord = {
          utd: this.getUniformTypeDescriptor(fileUris![0]),
          uri: fileUris[0],
          content: text,
          title: fileNameOverrides?.toString(),
        }
        data = new systemShare.SharedData(record);
      } else {
        if (text) {
          let record: systemShare.SharedRecord = {
            utd: uniformTypeDescriptor.getUniformDataTypeByMIMEType('text/plain'),
            content: text,
            title: subject!
          }
          data = new systemShare.SharedData(record);
        }
        fileUris.forEach((uri: string, index: number) => {
          let record: systemShare.SharedRecord = {
            utd: this.getUniformTypeDescriptor(uri),
            uri: uri,
          }
          if (data) {
            data.addRecord(record);
          } else {
            data = new systemShare.SharedData(record);
          }
        })
      }
      this.startShare(data!, withResult, result);
    } catch (err) {
      Log.e(TAG, 'err:' + JSON.stringify(err));
    }
  }

  private startShare(data: systemShare.SharedData, withResult: boolean, result: MethodResult): void {
    Log.i(TAG, "startShare");
    try {
      let controller = new systemShare.ShareController(data);
      if (withResult) {
        controller.on('dismiss', () => {
          result.success('');
        });
        withResult = false;
      }
      controller.show(this.ability?.context, {
        previewMode: systemShare.SharePreviewMode.DETAIL,
        selectionMode: systemShare.SelectionMode.BATCH
      });
      withResult = true;
    } catch (err) {
      Log.e(TAG, 'err:' + JSON.stringify(err));
    }
  }

  private getUniformTypeDescriptor(fileUri: string): string {
    const dotIndex = fileUri.lastIndexOf('.');
    if (dotIndex != -1) {
      const fileExtension = '.' + fileUri.substring(dotIndex + 1);
      return uniformTypeDescriptor.getUniformDataTypeByFilenameExtension(fileExtension) ?? 'general.file';
    }
    return 'general.file';
  }

  private shareCacheFolder(): string {
    Log.i(TAG, "shareCacheFolder");
    return this.context?.cacheDir + '/share_plus';
  }

  private async getUrisForPaths(paths: List<string>): Promise<Array<string>> {
    Log.i(TAG, "getUrisForPaths");
    let uris = new Array<string>();
    try {
      paths.forEach(async path => {
        let file: string;
        if (this.fileIsInShareCache(path)) {
          throw new Error(`Shared file can not be located in '${this.shareCacheFolder()}`);
        }
        file = await this.copyToShareCacheFolder(path);
        uris.push(fileUri.getUriFromPath(file));
      })
    } catch (err) {
      Log.e(TAG, 'err:' + JSON.stringify(err));
    }
    return uris
  }

  private fileIsInShareCache(file: string): boolean {
    Log.i(TAG, "fileIsInShareCache");
    try {
      let filePath: fs.File = fs.openSync(file);
      let filePathFold = filePath.getParent();
      if (filePathFold.startsWith(this.shareCacheFolder())) {
        return true;
      }
    } catch (err) {
      Log.e(TAG, 'err:' + JSON.stringify(err));
    }
    return false;
  }

  private async clearShareCacheFolder(): Promise<void> {
    Log.i(TAG, "clearShareCacheFolder");
    try {
      let folder: string = this.shareCacheFolder();
      if (fs.accessSync(folder)) {
        let files = fs.listFileSync(folder);
        if (files.length > 0) {
          files.forEach(item => {
            fs.unlinkSync(folder + '/' + item);
          })
          fs.rmdirSync(folder);
        }
      }
    } catch (err) {
      Log.e(TAG, 'err:' + JSON.stringify(err));
    }
  }

  private async copyToShareCacheFolder(file: string): Promise<string> {
    Log.i(TAG, "copyToShareCacheFolder");
    let folder = this.shareCacheFolder();
    if (!fs.accessSync(folder)) {
      fs.mkdirSync(folder);
    }
    let oldFile: fs.File = fs.openSync(file);
    let newFile = folder + '/' + oldFile.name;
    fs.copyFileSync(oldFile.fd, newFile);
    return newFile
  }
}
