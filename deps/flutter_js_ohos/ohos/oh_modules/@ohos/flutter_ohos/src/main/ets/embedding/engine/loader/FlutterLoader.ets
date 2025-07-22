/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on FlutterLoader.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

/**
 * flutterLoader，负责dart虚拟机启动和dart代码加载
 */
import FlutterShellArgs from '../FlutterShellArgs';
import FlutterNapi from '../FlutterNapi';
import Log from '../../../util/Log';
import FlutterApplicationInfo from './FlutterApplicationInfo';
import common from '@ohos.app.ability.common';
import StringUtils from '../../../util/StringUtils';
import ApplicationInfoLoader from './ApplicationInfoLoader';
import bundleManager from '@ohos.bundle.bundleManager';
import fs from '@ohos.file.fs';
import { BusinessError } from '@ohos.base';
import data_preferences from '@ohos.data.preferences';
import { util } from '@kit.ArkTS';
import deviceInfo from '@ohos.deviceInfo';

const TAG = "FlutterLoader";

//flutter引擎so
const DEFAULT_LIBRARY = "libflutter.so";
//jit产物默认kenel文件
const DEFAULT_KERNEL_BLOB = "kernel_blob.bin";
//jit产物，默认快照文件
const VMSERVICE_SNAPSHOT_LIBRARY = "libvmservice_snapshot.so";
//key值
const SNAPSHOT_ASSET_PATH_KEY = "snapshot-asset-path";
//key值
const VM_SNAPSHOT_DATA_KEY = "vm-snapshot-data";
//key值
const ISOLATE_SNAPSHOT_DATA_KEY = "isolate-snapshot-data";


const AOT_SHARED_LIBRARY_NAME = "aot-shared-library-name";

const AOT_VMSERVICE_SHARED_LIBRARY_NAME = "aot-vmservice-shared-library-name";

//文件路径分隔符
const FILE_SEPARATOR = "/";

const TIMESTAMP_PREFIX = "res_timestamp-";

const ENABLE_IMPELLER_TAG = "enable_impeller";

const TRUE_STRING = "true";

const BUILD_INFO_FILE_NAME = "buildinfo.json5";

interface StringItem {
  name: string;
  value: string;
}

interface InfoData {
  string: StringItem[];
}

async function prefetchDefaultFontManager(): Promise<void> {
  await new Promise<void>((resolve: Function) => {
    FlutterNapi.prefetchDefaultFontManager()
    resolve()
  })
}

/**
 * 定位在hap包中的flutter资源，并且加载flutter native library.
 */
export default class FlutterLoader {
  flutterNapi: FlutterNapi;
  initResult: InitResult | null = null;
  flutterApplicationInfo: FlutterApplicationInfo | null = null;
  context: common.Context | null = null;
  initialized: boolean = false;
  //初始化开始时间戳
  initStartTimestampMillis: number = 0;
  isEnableImpeller: boolean = false;

  constructor(flutterNapi: FlutterNapi) {
    this.flutterNapi = flutterNapi;
  }

 private getBuildInfo(context: common.Context): Map<string, string> {
    let buildInfoMap: Map<string, string> = new Map();
    try {
      let rawFile = context.resourceManager.getRawFileContentSync(BUILD_INFO_FILE_NAME);
        let textDecoder = util.TextDecoder.create('utf-8', {
          ignoreBOM: true
        });
        let record = textDecoder.decodeWithStream(rawFile, {
          stream: false
        });
        let jsonRecord: InfoData = JSON.parse(record);
        jsonRecord.string.forEach((item: StringItem) => {
          buildInfoMap.set(item.name, item.value);
        });
      return buildInfoMap;
    } catch (error) {
      Log.e(TAG, "can not find buildinfo.json5 file.")
      return buildInfoMap;
    }

  }

  /**
   * Starts initialization of the native system.
   *
   * <p>This loads the Flutter engine's native library to enable subsequent NAPI calls. This also
   * starts locating and unpacking Dart resources packaged in the app's HAP.
   *
   * <p>Calling this method multiple times has no effect.
   *
   * @param applicationContext The HarmonyOS application context.
   * @param settings Configuration settings.
   */
  startInitialization(context: common.Context) {
    Log.d(TAG, "flutterLoader start init")
    this.initStartTimestampMillis = Date.now();
    this.context = context;
    this.flutterApplicationInfo = ApplicationInfoLoader.load(context);
    prefetchDefaultFontManager();
    if (this.flutterApplicationInfo!.isDebugMode) {
      this.copyResource(context)
    }
    let buildInfoMap = this.getBuildInfo(this.context!); 
    if (!buildInfoMap.has(ENABLE_IMPELLER_TAG) || buildInfoMap.get(ENABLE_IMPELLER_TAG) == TRUE_STRING) {
        this.isEnableImpeller = true;
    } else {
      this.isEnableImpeller = false;
    }
    this.initResult = new InitResult(
      `${context.filesDir}/`,
      `${context.cacheDir}/`,
      `${context.filesDir}`
    )
    Log.d(TAG, "flutterLoader end init")
  }

  private copyResource(context: common.Context) {
    let filePath = context.filesDir + FILE_SEPARATOR + this.flutterApplicationInfo!.flutterAssetsDir
    const timestamp = this.checkTimestamp(filePath);
    if (timestamp == null) {
      Log.d(TAG, "no need copyResource")
      return;
    }
    if (this.context != null) {
      Log.d(TAG, "start copyResource")
      if (fs.accessSync(filePath + FILE_SEPARATOR + DEFAULT_KERNEL_BLOB)) {
        Log.d(TAG, "hap has changed, start delete previous file")
        fs.rmdirSync(filePath);
      }

      if (!fs.accessSync(filePath)) {
        fs.mkdirSync(filePath)
      }

      let kernelBuffer =
        this.context.resourceManager.getRawFileContentSync(this.flutterApplicationInfo!.flutterAssetsDir +
          FILE_SEPARATOR + DEFAULT_KERNEL_BLOB)
      let kernelFile =
        fs.openSync(filePath + FILE_SEPARATOR + DEFAULT_KERNEL_BLOB, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
      fs.writeSync(kernelFile.fd, kernelBuffer.buffer)

      let vmBuffer =
        this.context.resourceManager.getRawFileContentSync(this.flutterApplicationInfo!.flutterAssetsDir +
          FILE_SEPARATOR + this.flutterApplicationInfo!.vmSnapshotData)
      let vmFile = fs.openSync(filePath + FILE_SEPARATOR + this.flutterApplicationInfo!.vmSnapshotData,
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
      fs.writeSync(vmFile.fd, vmBuffer.buffer)

      let isolateBuffer =
        this.context.resourceManager.getRawFileContentSync(this.flutterApplicationInfo!.flutterAssetsDir +
          FILE_SEPARATOR + this.flutterApplicationInfo!.isolateSnapshotData)
      let isolateFile = fs.openSync(filePath + FILE_SEPARATOR + this.flutterApplicationInfo!.isolateSnapshotData,
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
      fs.writeSync(isolateFile.fd, isolateBuffer.buffer)

      if (timestamp != null) {
        fs.closeSync(fs.openSync(filePath + FILE_SEPARATOR + timestamp, fs.OpenMode.READ_ONLY | fs.OpenMode.CREATE))
      }
      fs.closeSync(kernelFile)
      fs.closeSync(vmFile)
      fs.closeSync(isolateFile)
      Log.d(TAG, "copyResource end")
    } else {
      Log.d(TAG, "no copyResource")
    }
  }

  /**
   * 初始化dart虚拟机方法
   * @param flutterShellArgs
   */
  ensureInitializationComplete(shellArgs: Array<string> | null) {
    if (this.initialized) {
      return;
    }
    if (shellArgs == null) {
      shellArgs = new Array<string>();
    }
    shellArgs.push("--icu-symbol-prefix=_binary_icudtl_dat");
    shellArgs.push(
      "--icu-native-lib-path="
        + this.flutterApplicationInfo!.nativeLibraryDir
        + FILE_SEPARATOR + DEFAULT_LIBRARY
    );

    let kernelPath: string = "";
    if (this.flutterApplicationInfo!.isDebugMode) {
      Log.d(TAG, "this.initResult!.dataDirPath=" + this.initResult!.dataDirPath)
      const snapshotAssetPath =
        this.initResult!.dataDirPath + FILE_SEPARATOR + this.flutterApplicationInfo!.flutterAssetsDir;
      kernelPath = snapshotAssetPath + FILE_SEPARATOR + DEFAULT_KERNEL_BLOB;
      shellArgs.push("--" + SNAPSHOT_ASSET_PATH_KEY + "=" + snapshotAssetPath);
      shellArgs.push("--" + VM_SNAPSHOT_DATA_KEY + "=" + this.flutterApplicationInfo!.vmSnapshotData);
      shellArgs.push(
        "--" + ISOLATE_SNAPSHOT_DATA_KEY + "=" + this.flutterApplicationInfo!.isolateSnapshotData);
      shellArgs.push('--enable-checked-mode')
      shellArgs.push('--verbose-logging')
    } else {
      shellArgs.push(
        "--" + AOT_SHARED_LIBRARY_NAME + "=" + this.flutterApplicationInfo!.aotSharedLibraryName);
      shellArgs.push(
        "--"
          + AOT_SHARED_LIBRARY_NAME
          + "="
          + this.flutterApplicationInfo!.nativeLibraryDir
          + FILE_SEPARATOR
          + this.flutterApplicationInfo!.aotSharedLibraryName);

      const snapshotAssetPath =
        this.initResult!.dataDirPath + FILE_SEPARATOR + this.flutterApplicationInfo!.flutterAssetsDir;

      if (this.flutterApplicationInfo!.isProfile) {
        shellArgs.push("--" + AOT_VMSERVICE_SHARED_LIBRARY_NAME + "=" + VMSERVICE_SNAPSHOT_LIBRARY);
      }
    }
    shellArgs.push("--cache-dir-path=" + this.initResult!.engineCachesPath);
    if (StringUtils.isNotEmpty(this.flutterApplicationInfo!.domainNetworkPolicy)) {
      shellArgs.push("--domain-network-policy=" + this.flutterApplicationInfo!.domainNetworkPolicy);
    }

    const resourceCacheMaxBytesThreshold = 1080 * 1920 * 12 * 4;
    shellArgs.push("--resource-cache-max-bytes-threshold=" + resourceCacheMaxBytesThreshold);

    shellArgs.push("--prefetched-default-font-manager");

    shellArgs.push("--leak-vm=" + true);

    if (this.isEnableImpeller == true && deviceInfo.productModel != "emulator") {
        shellArgs.push("--enable-impeller");
        Log.d(TAG, "Enable Impeller in Ohos.");
    } else {
      Log.d(TAG, "Do not find enableImpeller tag or enableImpeller tag set to false, enable Skia in Ohos.");
    }

    // //最终初始化操作
    const costTime = Date.now() - this.initStartTimestampMillis;
    this.flutterNapi.init(
      this.context!,
      shellArgs,
      kernelPath,
      this.initResult!.appStoragePath,
      this.initResult!.engineCachesPath!,
      costTime
    );
    this.initialized = true;
    Log.d(TAG, "ensureInitializationComplete")
  }

  findAppBundlePath(): string {
    return this.flutterApplicationInfo == null ? "" : this.flutterApplicationInfo!.flutterAssetsDir;
  }

  getLookupKeyForAsset(asset: string, packageName?: string): string {
    return this.fullAssetPathFrom(asset);
  }

  fullAssetPathFrom(filePath: string): string {
    return this.flutterApplicationInfo == null ? "" : this.flutterApplicationInfo!.flutterAssetsDir + "/" + filePath;
  }

  private checkTimestamp(dataDir: string): string | null {
    let bundleInfo = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
    const expectedTimestamp = TIMESTAMP_PREFIX + bundleInfo.versionCode + "-" + bundleInfo.updateTime;
    const existingTimestamps = this.getExistingTimestamps(dataDir);
    if (existingTimestamps == null) {
      Log.i(TAG, "No extracted resources found");
      return expectedTimestamp;
    }

    if (existingTimestamps.length == 1) {
      Log.i(TAG, "Found extracted resources " + existingTimestamps[0]);
    }

    if (existingTimestamps.length != 1 || !(expectedTimestamp == existingTimestamps[0])) {
      Log.i(TAG, "Resource version mismatch " + expectedTimestamp);
      return expectedTimestamp;
    }

    return null;
  }

  private getExistingTimestamps(dataDir: string): string[] {
    return fs.accessSync(dataDir) ? fs.listFileSync(dataDir, {
      filter: {
        displayName: [`${TIMESTAMP_PREFIX}*`]
      }
    }) : new Array();
  }

  isInitialized(): boolean {
    return this.initialized;
  }
}

class InitResult {
  appStoragePath: string;
  engineCachesPath: string;
  dataDirPath: string;

  constructor(appStoragePath: string,
    engineCachesPath: string,
    dataDirPath: string) {
    this.appStoragePath = appStoragePath;
    this.engineCachesPath = engineCachesPath;
    this.dataDirPath = dataDirPath;
  }
}
