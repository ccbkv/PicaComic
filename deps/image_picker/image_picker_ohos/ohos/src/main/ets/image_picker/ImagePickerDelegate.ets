// Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE_ODID file.
// Based on ImagePickerDelegate.java originally written by
// Copyright 2013 The Flutter Authors.

import ArrayList from '@ohos.util.ArrayList';
import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';
import fs from '@ohos.file.fs'
import common from '@ohos.app.ability.common';
import ImagePickerCache, { CacheType } from './ImagePickerCache'
import FileUtils from './FileUtils'
import { fileUri } from '@kit.CoreFileKit';
import {
  FlutterError,
  ImageSelectionOptions,
  VideoSelectionOptions,
  Result,
  CacheRetrievalResult,
  CacheRetrievalResultBuilder,
  MediaSelectionOptions,
  GeneralOptions
} from './Messages'
import ImageResizer from './ImageResizer';
import HashMap from '@ohos.util.HashMap';
import UIAbility from '@ohos.app.ability.UIAbility';
import { BusinessError } from '@ohos.base';
import { cameraPicker, camera } from '@kit.CameraKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import DateTimeUtil from './DateTimeUtil';

export default class ImagePickerDelegate {
  readonly REQUEST_CODE_CHOOSE_IMAGE_FROM_GALLERY = 2342;
  readonly REQUEST_CODE_TAKE_IMAGE_WITH_CAMERA = 2343;
  readonly REQUEST_CAMERA_IMAGE_PERMISSION = 2345;
  readonly REQUEST_CODE_CHOOSE_MULTI_IMAGE_FROM_GALLERY = 2346;
  readonly REQUEST_CODE_CHOOSE_MEDIA_FROM_GALLERY = 2347;
  readonly REQUEST_CODE_CHOOSE_VIDEO_FROM_GALLERY = 2352;
  readonly REQUEST_CODE_TAKE_VIDEO_WITH_CAMERA = 2353;
  readonly REQUEST_CAMERA_VIDEO_PERMISSION = 2355;
  private static TAG = "ImagePickerDelegate";
  private imageResizer: ImageResizer;
  private cache: ImagePickerCache;
  private pendingCameraMediaUri: string | null = null;
  private pendingCallState: PendingCallState | null = null;
  private context: common.UIAbilityContext | null = null;
  private photoPicker = new photoAccessHelper.PhotoViewPicker();
  private cameraPosition: camera.CameraPosition = camera.CameraPosition.CAMERA_POSITION_BACK;

  constructor(ability: UIAbility, imageResizer: ImageResizer, cache: ImagePickerCache, context?: common.UIAbilityContext,
    pendingImageOptions?: ImageSelectionOptions, pendingVideoOptions?: VideoSelectionOptions,
    result?: Result<ArrayList<string>>, fileUtils?: FileUtils) {
    this.imageResizer = imageResizer;
    if (result != null) {
      this.pendingCallState = new PendingCallState(pendingImageOptions as ESObject, pendingVideoOptions, result);
    }
    this.cache = cache;
    this.context = ability.context;
  }

  setCameraDevice(device: CameraDevice): void {
    if (device == CameraDevice.REAR) {
      this.cameraPosition = camera.CameraPosition.CAMERA_POSITION_BACK;
    }

    if (device == CameraDevice.FRONT) {
      this.cameraPosition = camera.CameraPosition.CAMERA_POSITION_FRONT;
    }
  }

  saveStateBeforeResult(): void {
    let localImageOptions: ImageSelectionOptions;

    if (this.pendingCallState == null) {
      return;
    }
    localImageOptions = this.pendingCallState.imageOptions;

    this.cache.saveType(localImageOptions != null ? CacheType.IMAGE : CacheType.VIDEO);
    if (localImageOptions != null) {
      this.cache.saveDimensionWithOutputOptions(localImageOptions);
    }

    let localPendingCameraMediaUri = this.pendingCameraMediaUri;
    if (localPendingCameraMediaUri != null) {
      this.cache.savePendingCameraMediaUriPath(localPendingCameraMediaUri);
    }
  }

  async retrieveLostImage(): Promise<CacheRetrievalResult | null> {
    // let cacheMap: HashMap<string, ESObject|null> = await this.cache.getCacheMap().then(map=> {
    //   return map;
    // });
    let cacheMap: HashMap<string, ESObject | null> = await this.cache.getCacheMap()
    if (cacheMap.isEmpty()) {
      return null;
    }
    let result = new CacheRetrievalResultBuilder(null, null, null, null);
    let type: ESObject = cacheMap.get(ImagePickerCache.MAP_KEY_TYPE);
    if (type != null && result.setType) {
      result.setType(type);
    }
    if (result.setError) {
      result.setError(cacheMap.get(ImagePickerCache.MAP_KEY_ERROR));
    }

    let pathList: ArrayList<string> = cacheMap.get(ImagePickerCache.MAP_KEY_PATH_LIST) as ArrayList<string>;
    if (pathList != null) {
      let newPathList: ArrayList<string> = new ArrayList();
      for (let path of pathList) {
        let maxWidth: number = cacheMap.get(ImagePickerCache.MAP_KEY_MAX_WIDTH) as number;
        let maxHeight: number = cacheMap.get(ImagePickerCache.MAP_KEY_MAX_HEIGHT) as number;
        let boxedImageQuality: number = cacheMap.get(ImagePickerCache.MAP_KEY_IMAGE_QUALITY) as number;
        let imageQulity: number = boxedImageQuality == null ? 100 : boxedImageQuality;

        newPathList.add(await this.imageResizer.resizeImageIfNeeded(path, maxWidth, maxHeight, imageQulity)
          .then((fileName) => {
            return fileName;
          })
        );
      }
      if (result.setPaths) {
        result.setPaths(newPathList);
      }

    }
    this.cache.clear();
    return result.build ? result.build() : null;
  }

  chooseMedia(maxMultiple: number, handleType: string, type?: photoAccessHelper.PhotoViewMIMETypes) {
    let photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
    photoSelectOptions.MIMEType = type;
    photoSelectOptions.maxSelectNumber = maxMultiple;

    this.photoPicker.select(photoSelectOptions).then((photoSelectResult: photoAccessHelper.PhotoSelectResult) => {
      this.handleResultType(handleType, 0, photoSelectResult.photoUris)
    }).catch((err: BusinessError) => {
      this.handleResultType(handleType, -1, [])
      Log.e(ImagePickerDelegate.TAG, `PhotoViewPicker.select failed whih err: ${err}`)
    })
  }

  handleResultType(handleType: string, code: number, uris: Array<string>) {
    switch (handleType) {
      case 'handleChooseVideoResult':
        this.handleChooseVideoResult(code, uris);
        break;
      case 'handleChooseImageResult':
        this.handleChooseImageResult(code, uris);
        break;
      case 'handleChooseMediaResult':
        this.handleChooseMediaResult(code, uris);
        break;
    }
  }

  // 选择多个图片或者多个视频
  chooseMediaFromGallery(options: MediaSelectionOptions, generalOptions: GeneralOptions,
    result: Result<ArrayList<string>>): void {
    if (!this.setPendingOptionsAndResult(options.getImageSelectionOptions(), null, result)) {
      this.finishWithAlreadyActiveError(result);
      return;
    }
    let limit = 1;
    if (generalOptions.getAllowMultiple()) {
      limit = generalOptions.getLimit();
    }
    this.chooseMedia(limit, 'handleChooseMediaResult')
  }

  handleChooseMediaResult(code: number, uris: Array<string>): void {
    if (code == 0) {
      this.handleMediaResultTwo(uris);
    } else {
      this.finishWithListSuccess(null);
    }
  }

  async handleMediaResultTwo(uris: Array<string>): Promise<void> {
    let localImageOptions: ImageSelectionOptions | null = null;
    if (this.pendingCallState != null) {
      localImageOptions = this.pendingCallState.imageOptions;
    }
    let pathList: ArrayList<string> = new ArrayList();
    if (localImageOptions != null && localImageOptions != undefined) {
      for (let path of uris) {
        if (path.search("video") < 0 && this.pendingCallState) {
          path = await this.getResizedImagePath(path, this.pendingCallState.imageOptions);
        }
        let realPath = FileUtils.getPathFromUri(this.context, path);
        Log.i(ImagePickerDelegate.TAG, "getPathFromUri : " + realPath);
        pathList.add(realPath);
      }
    } else {
      for (let path of uris) {
        let realPath = FileUtils.getPathFromUri(this.context, path);
        pathList.add(realPath);
      }
    }
    this.finishWithListSuccess(pathList);
  }

  // 选择一个视频
  chooseVideoFromGallery(options: VideoSelectionOptions, usePhotoPicker: boolean, result: Result<ArrayList<string>>): void {
    if (!this.setPendingOptionsAndResult(null, options, result)) {
      this.finishWithAlreadyActiveError(result);
      return;
    }

    this.chooseMedia(1, 'handleChooseVideoResult', photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE);
  }

  handleChooseVideoResult(code: number, uris: Array<string>): void {
    if (code == 0) {
      let realPath = FileUtils.getPathFromUri(this.context, uris[0]);
      this.handleVideoResult(realPath as string, false);
    } else {
      this.finishWithSuccess(null);
    }
  }

  // 唤起相机录像
  takeVideoWithCamera(options: VideoSelectionOptions, result: Result<ArrayList<string>>): void {
    if (!this.setPendingOptionsAndResult(null, options, result)) {
      this.finishWithAlreadyActiveError(result);
      return;
    }

    Log.i(ImagePickerDelegate.TAG, "launchTakeVideoWithCameraWant duration: " + options.getMaxDurationSeconds());
    this.launchTakeVideoWithCameraWant(options.getMaxDurationSeconds());
  }

  async launchTakeVideoWithCameraWant(duration: number): Promise<void> {
    const fileName = this.saveFileName(false);
    let filePath = `${(this.context as Context).cacheDir}/${fileName}`;
    let pickerProfile: cameraPicker.PickerProfile = {
      cameraPosition: this.cameraPosition,
      videoDuration: duration,
      saveUri: this.saveFileUri(filePath)
    }

    cameraPicker.pick(this.context, [cameraPicker.PickerMediaType.VIDEO], pickerProfile).then((pickerResult: cameraPicker.PickerResult) => {
      this.handlerCaptureVideoResult(pickerResult.resultCode, filePath);
    })
  }

  private saveFileUri(filePath: string): string{
    fs.createRandomAccessFileSync(filePath, fs.OpenMode.CREATE);
    return fileUri.getUriFromPath(filePath)
  }

  private saveFileName(isPhoto: boolean): string{
    const mDateTimeUtil : DateTimeUtil = new DateTimeUtil();
    const mData: string = mDateTimeUtil.getDate();
    const mTime: string = mDateTimeUtil.getTime();
    if (isPhoto) {
      return `${`IMG_${mData}_${mTime}`}.jpg`;
    }else {
      return `${`VID_${mData}_${mTime}`}.mp4`;
    }
  }

  // 选择单个图片
  chooseImageFromGallery(options: ImageSelectionOptions, usePhotoPicker: boolean, result: Result<ArrayList<string>>) {
    Log.i(ImagePickerDelegate.TAG, "chooseImageFromGallery enter");
    if (!this.setPendingOptionsAndResult(options, null, result)) {
      this.finishWithAlreadyActiveError(result);
      return;
    }

    this.chooseMedia(1, 'handleChooseImageResult', photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE)
  }

  handleChooseImageResult(code: number, uris: Array<string>): void {
    if (code == 0) {
      let realPath = FileUtils.getPathFromUri(this.context, uris[0]);
      this.handleImageResult(realPath as string, false);
    } else {
      this.finishWithSuccess(null);
    }
  }

  // 选择多个图片
  chooseMultiImagesFromGallery(options: ImageSelectionOptions, generalOptions: GeneralOptions, result: Result<ArrayList<string>>): void {
    if (!this.setPendingOptionsAndResult(options, null, result)) {
      this.finishWithAlreadyActiveError(result);
      return;
    }
    let limit = generalOptions.getLimit();
    this.chooseMedia(limit, 'handleChooseMediaResult', photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE)
  }

  // 唤起相机拍照
  takeImageWithCamera(options: ImageSelectionOptions, result: Result<ArrayList<string>>): void {
    if (!this.setPendingOptionsAndResult(options, null, result)) {
      this.finishWithAlreadyActiveError(result);
      return;
    }
    this.launchTakeImageWithCameraWant();
  }

  launchTakeImageWithCameraWant() {
    const fileName = this.saveFileName(true);
    let filePath = `${(this.context as Context).cacheDir}/${fileName}`;
    let pickerProfile: cameraPicker.PickerProfile = {
      cameraPosition: this.cameraPosition,
      saveUri: this.saveFileUri(filePath)
    }

    cameraPicker.pick(this.context, [cameraPicker.PickerMediaType.PHOTO], pickerProfile).then((pickerResult: cameraPicker.PickerResult) => {
      this.pendingCameraMediaUri = pickerResult.resultUri;
      this.handlerCaptureImageResult(pickerResult.resultCode, filePath);
    })
  }

  setPendingOptionsAndResult(imageOptions: ImageSelectionOptions | null, videoOptions: VideoSelectionOptions | null,
    result: Result<ArrayList<string>>): boolean {
    if (this.pendingCallState !== null && this.pendingCallState !== undefined) {
      Log.i(ImagePickerDelegate.TAG, "There is already an open gallery, use it directly to select images");
    } else {
      Log.i(ImagePickerDelegate.TAG, "Prepare to awaken a new one");
      this.pendingCallState = new PendingCallState(imageOptions, videoOptions, result);
    }
    this.cache.clear();
    return true;
  }

  finishWithAlreadyActiveError(result: Result<ArrayList<string>>) {
    result.error(new FlutterError("already_active", "Image picker is already active", null));
  }

  handlerCaptureImageResult(code: number, path: string): void {
    if (code === 0) {
      this.handleImageResult(path, true);
    } else {
      this.finishWithSuccess(null);
    }
  }

  handlerCaptureVideoResult(code: number, path: string): void {
    this.finishWithSuccess(code === 0 ? path : null);
  }

  async handleImageResult(path: string, shouldDeleteOriginalIfScaled: boolean): Promise<void> {
    Log.i(ImagePickerDelegate.TAG, 'handleImageResult enter');
    let localImageOptions: ImageSelectionOptions | null = null;
    if (this.pendingCallState != null) {
      localImageOptions = this.pendingCallState.imageOptions;
    }

    if (localImageOptions != null) {
      let finalImagePath = await this.getResizedImagePath(path, localImageOptions);
      if (finalImagePath != null && finalImagePath != path && shouldDeleteOriginalIfScaled) {
        fs.unlink(path);
      }
      this.finishWithSuccess(finalImagePath);
    } else {
      this.finishWithSuccess(path);
    }
  }

  async handleMediaResult(paths: Array<string>) {
    let localImageOptions: ImageSelectionOptions | null = null;
    if (this.pendingCallState !== null) {
      localImageOptions = this.pendingCallState.imageOptions;
    }

    if (localImageOptions !== null) {
      for (let i: number = 0; i < paths.length; i++) {
        let path = paths[i];
        Log.i("yjm 0801 path" + i, ":" + path);
        let finalImagePath = await this.getResizedImagePath(path, localImageOptions).then((path) => {
          return path;
        });
        if (finalImagePath !== null && finalImagePath === path) {
          fs.unlink(path);
        }
        this.finishWithSuccess(finalImagePath);
      }
    }
  }

  handleVideoResult(path: string | null, shouldDeleteOriginalIfScaled: boolean): void {
    this.finishWithSuccess(path);
  }

  finishWithSuccess(path: string | null): void {
    Log.i(ImagePickerDelegate.TAG, path);
    let pathList: ArrayList<string> = new ArrayList();
    if (path !== null) {
      pathList.add(path)
    }
    let localResult: Result<ArrayList<string>> | null = null;

    if (this.pendingCallState !== null) {
      localResult = this.pendingCallState.result;
    }
    this.pendingCallState = null;

    if (localResult === null) {
      if (!pathList.isEmpty()) {
        this.cache.saveResult(pathList, null, null);
      }
    } else {
      localResult.success(pathList);
    }
  }

  finishWithListSuccess(path: ArrayList<string> | null): void {
    let localResult: Result<ArrayList<string>> | null = null;
    if (this.pendingCallState != null) {
      localResult = this.pendingCallState.result;
    }
    this.pendingCallState = null;

    if (localResult === null) {
      this.cache.saveResult(path as ArrayList<string>, null, null);
    } else if (path) {
      localResult.success(path);
    }
  }

  async getResizedImagePath(path: string, outputOptions: ImageSelectionOptions): Promise<string> {
    return this.imageResizer.resizeImageIfNeeded(path, outputOptions.getMaxWidth(), outputOptions.getMaxHeight(),
      outputOptions.getQuality());
  }
}

interface OnPathReadyListener {
  onPathReady(path: string): void;
}

class PendingCallState {
  imageOptions: ImageSelectionOptions;
  videoOptions: VideoSelectionOptions;
  result: Result<ArrayList<string>>;

  constructor(imageOptions: ImageSelectionOptions | ESObject, videoOptions: VideoSelectionOptions | ESObject,
    result: Result<ArrayList<string>>) {
    this.imageOptions = imageOptions;
    this.videoOptions = videoOptions;
    this.result = result;
  }
}

export enum CameraDevice {
  REAR,
  FRONT
}