// Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE_ODID file.
// Based on Messages.java originally written by
// Copyright 2013 The Flutter Authors.

import ArrayList from '@ohos.util.ArrayList';
import StandardMessageCodec from '@ohos/flutter_ohos/src/main/ets/plugin/common/StandardMessageCodec';
import { ByteBuffer } from '@ohos/flutter_ohos/src/main/ets/util/ByteBuffer';
import MessageCodec from '@ohos/flutter_ohos/src/main/ets/plugin/common/MessageCodec';
import { BinaryMessenger } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BinaryMessenger';
import BasicMessageChannel from '@ohos/flutter_ohos/src/main/ets/plugin/common/BasicMessageChannel';
import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';

export const MAX_SELECT_NUMBER: number = 500;

export enum SourceCamera {
  REAR = 0,
  FRONT = 1
}

export enum SourceType {
  CAMERA = 0,
  GALLERY = 1
}

export enum CacheRetrievalType {
  IMAGE = 0,
  VIDEO = 1
}

const TAG: string = "Message";

export default class Messages {
  static wrapError(exception: Error): ArrayList<ESObject> {
    const errorList: ArrayList<ESObject> = new ArrayList<ESObject>();
    if (exception instanceof FlutterError) {
      const error = exception;
      errorList.add(error.code);
      errorList.add(error.message);
      errorList.add(error.details);
    } else {
      errorList.add(exception.name);
      errorList.add(exception.message);
      errorList.add(exception.stack);
    }
    return errorList;
  }
}

export class FlutterError extends Error {
  code: string;
  details: ESObject;

  constructor(code: string, message: string, details: ESObject) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

class GeneralOptionsBuilder {
  setAllowMultiple: (setterArg: boolean) => ESObject
  setUsePhotoPicker: (setterArg: boolean) => ESObject
  setLimit:(setterArg: number) => ESObject
  build: () => ESObject

  constructor(setAllowMultiple: (setterArg: boolean) => ESObject, setUsePhotoPicker: (setterArg: boolean) => ESObject,
    setLimit: (setterArg: number) => ESObject, build: () => ESObject) {
    this.setAllowMultiple = setAllowMultiple
    this.setUsePhotoPicker = setUsePhotoPicker
    this.setLimit = setLimit
    this.build = build
  }
}

export class GeneralOptions {
  private allowMultiple: boolean = false;
  private usePhotoPicker: boolean = false;
  private limit: number = 1;

  private constructor() {
  }

  getLimit(): number {
    if(this.limit !== null) {
        return this.limit > MAX_SELECT_NUMBER ? MAX_SELECT_NUMBER : this.limit;
    }
    return MAX_SELECT_NUMBER;
  }

  setLimit(setterArg: number): void {
    this.limit = setterArg ?? MAX_SELECT_NUMBER;
  }

  getAllowMultiple(): boolean {
    return this.allowMultiple;
  }

  setAllowMultiple(setterArg: boolean): void {
    if (setterArg == null) {
      throw new Error("Nonnull field \"allowMultiple\" is null.");
    }
    this.allowMultiple = setterArg;
  }

  getUsePhotoPicker(): boolean {
    return this.usePhotoPicker;
  }

  setUsePhotoPicker(setterArg: boolean): void {
    if (setterArg == null) {
      throw new Error("Nonnull field \"usePhotoPicker\" is null.");
    }
    this.usePhotoPicker = setterArg;
  }

  public Builder: ESObject = new GeneralOptionsBuilder((setterArg: boolean) => {
    this.allowMultiple = setterArg;
    return this;
  }, (setterArg: boolean) => {
    this.usePhotoPicker = setterArg;
    return this;
  }, (setterArg: number) => {
    this.limit = setterArg;
    return this;
  }, (): ESObject => {
    const pigeonReturn: ESObject = new GeneralOptions();
    pigeonReturn.setAllowMultiple(this.allowMultiple);
    pigeonReturn.setUsePhotoPicker(this.usePhotoPicker);
    pigeonReturn.setLimit(this.limit);
    return pigeonReturn;
  }
  )

  toList(): ArrayList<ESObject> {
    const toListResult: ArrayList<ESObject> = new ArrayList<ESObject>();
    toListResult.add(this.allowMultiple);
    toListResult.add(this.usePhotoPicker);
    toListResult.add(this.limit);
    return toListResult;
  }

  static fromList(list: ArrayList<ESObject>): GeneralOptions {
    const pigeonResult = new GeneralOptions();
    const allowMultiple: ESObject = list[0];
    pigeonResult.setAllowMultiple(allowMultiple);
    const usePhotoPicker: ESObject = list[1];
    pigeonResult.setUsePhotoPicker(usePhotoPicker);
    const limit: ESObject = list[2];
    pigeonResult.setLimit(limit);
    return pigeonResult;
  }
}

class ImageSelectionOptionsBuilder {
  setMaxWidth: (setterArg: number) => ESObject
  setMaxHeight: (setterArg: number) => ESObject
  setQuality: (setterArg: number) => ESObject
  build: () => ESObject

  constructor(setMaxWidth: (setterArg: number) => ESObject, setMaxHeight: (setterArg: number) => ESObject, setQuality: (setterArg: number) => ESObject, build: () => ESObject) {
    this.setMaxWidth = setMaxWidth
    this.setMaxHeight = setMaxHeight
    this.setQuality = setQuality
    this.build = build
  }
}

export class ImageSelectionOptions {
  private maxWidth: number = -1;
  private maxHeight: number = -1;
  private quality: number = -1;

  private constructor() {
  }

  getMaxWidth(): number {
    return this.maxWidth;
  }

  setMaxWidth(setterArg: number): void {
    this.maxWidth = setterArg;
  }

  getMaxHeight(): number {
    return this.maxHeight;
  }

  setMaxHeight(setterArg: number): void {
    this.maxHeight = setterArg;
  }

  getQuality(): number {
    return this.quality;
  }

  setQuality(setterArg: number): void {
    if (setterArg == null) {
      throw new Error("Nonnull field \"quality\" is null.")
    }
    this.quality = setterArg;
  }

  public Builder = new ImageSelectionOptionsBuilder((setterArg: number) => {
    this.maxWidth = setterArg;
    return this;
  },

    (setterArg: number) => {
      this.maxHeight = setterArg;
      return this;
    },

    (setterArg: number) => {
      this.quality = setterArg;
      return this;
    },
    () => {
      const pigeonReturn = new ImageSelectionOptions();
      pigeonReturn.setMaxWidth(this.maxWidth);
      pigeonReturn.setMaxHeight(this.maxHeight);
      pigeonReturn.setQuality(this.quality);
      return pigeonReturn;
    }

  )

  toList(): ArrayList<ESObject> {
    const toListResult: ArrayList<ESObject> = new ArrayList<ESObject>();
    toListResult.add(this.maxWidth);
    toListResult.add(this.maxHeight);
    toListResult.add(this.quality);
    return toListResult;
  }

  static fromList(list: ArrayList<ESObject>): ImageSelectionOptions {
    const pigeonResult = new ImageSelectionOptions();
    const maxWidth: ESObject = list[0];
    pigeonResult.setMaxWidth(maxWidth);
    const maxHeight: ESObject = list[1];
    pigeonResult.setMaxHeight(maxHeight);
    const quality: ESObject = list[2];
    pigeonResult.setQuality(quality);
    return pigeonResult;
  }
}

class MediaSelectionOptionsBuilder {
  setImageSelectionOptions: (setterArg: ImageSelectionOptions) => ESObject
  build: () => ESObject

  constructor(setImageSelectionOptions: (setterArg: ImageSelectionOptions) => ESObject, build: () => ESObject) {
    this.setImageSelectionOptions = setImageSelectionOptions
    this.build = build
  }
}

export class MediaSelectionOptions {
  private imageSelectionOptions: ImageSelectionOptions | null = null;
  static imageSelectionOptions: ImageSelectionOptions | null = null;

  constructor() {
  }

  getImageSelectionOptions(): ImageSelectionOptions | null {
    return this.imageSelectionOptions;
  }

  setImageSelectionOptions(setterArg: ImageSelectionOptions | null): void {
    if (setterArg == null) {
      throw new Error("Nonnull field \"imageSelectionOptions\" is null.")
    }
    this.imageSelectionOptions = setterArg;
  }

  public Builder = new MediaSelectionOptionsBuilder(
    (setterArg: ImageSelectionOptions) => {
      this.imageSelectionOptions = setterArg;
      return this;
    }, () => {
    const pigeonReturn = new MediaSelectionOptions();
    pigeonReturn.setImageSelectionOptions(this.imageSelectionOptions);
    return pigeonReturn;
  }
  )

  toList(): ArrayList<ESObject> {
    const toListResult: ArrayList<ESObject> = new ArrayList<ESObject>();
    toListResult.add(this.imageSelectionOptions == null ? null : this.imageSelectionOptions.toList());
    return toListResult;
  }

  fromList(list: ArrayList<ESObject>): MediaSelectionOptions {
    const pigeonResult = new MediaSelectionOptions();
    const imageSelectionOptions: ESObject = list[0];
    pigeonResult.setImageSelectionOptions(imageSelectionOptions == null ?
      null : ImageSelectionOptions.fromList(imageSelectionOptions));
    return pigeonResult;
  }
}

class VideoSelectionOptionsBuilder {
  setMaxDurationSeconds: (setterArg: number) => ESObject
  build: () => ESObject

  constructor(setMaxDurationSeconds: (setterArg: number) => ESObject, build: () => ESObject) {
    this.setMaxDurationSeconds = setMaxDurationSeconds
    this.build = build
  }
}

export class VideoSelectionOptions {
  private maxDurationSeconds: number = 0;
  static maxDurationSeconds: number = 0;

  private constructor() {
  }

  getMaxDurationSeconds(): number {
    return this.maxDurationSeconds;
  }

  setMaxDurationSeconds(setterArg: number): void {
    this.maxDurationSeconds = setterArg;
  }

  public Builder = new VideoSelectionOptionsBuilder((setterArg: number) => {
    this.maxDurationSeconds = setterArg;
    return this;
  },
    () => {
      const pigeonReturn = new VideoSelectionOptions();
      pigeonReturn.setMaxDurationSeconds(this.maxDurationSeconds);
      return pigeonReturn;
    })

  toList(): ArrayList<ESObject> {
    const toListResult: ArrayList<ESObject> = new ArrayList<ESObject>();
    toListResult.add(this.maxDurationSeconds);
    return toListResult;
  }

  static fromList(list: ArrayList<ESObject>): VideoSelectionOptions {
    const pigeonResult = new VideoSelectionOptions();
    const maxDurationSeconds: ESObject = list[0];
    pigeonResult.setMaxDurationSeconds(maxDurationSeconds);
    return pigeonResult;
  }
}

class SourceSpecificationBuilder {
  setType: (setterArg: SourceType) => ESObject
  setCamera: (setterArg: SourceCamera) => ESObject
  build: () => ESObject

  constructor(setType: (setterArg: SourceType) => ESObject, setCamera: (setterArg: SourceCamera) => ESObject, build: () => ESObject) {
    this.setType = setType
    this.setCamera = setCamera
    this.build = build
  }
}

export class SourceSpecification {
  private type: SourceType | null = null;
  private camera: SourceCamera | null = null;

  private constructor() {
  }

  getType(): SourceType {
    return this.type as SourceType;
  }

  setType(setterArg: SourceType): void {
    if (setterArg == null) {
      throw new Error("Nonnull field \"type\" is null.")
    }
    this.type = setterArg;
  }

  getCamera(): SourceCamera {
    return this.camera as SourceCamera;
  }

  setCamera(setterArg: SourceCamera): void {
    this.camera = setterArg;
  }

  public Builder = new SourceSpecificationBuilder(
    (setterArg: SourceType) => {
      this.type = setterArg;
      return this;
    },
    (setterArg: SourceCamera) => {
      this.camera = setterArg;
      return this;
    },
    () => {
      const pigeonReturn = new SourceSpecification();
      pigeonReturn.setType(this.type as SourceType);
      pigeonReturn.setCamera(this.camera as SourceCamera);
      return pigeonReturn;
    }
  )

  toList(): ArrayList<ESObject> {
    const toListResult: ArrayList<ESObject> = new ArrayList<ESObject>();
    toListResult.add(this.type);
    toListResult.add(this.camera);
    return toListResult;
  }

  static fromList(list: ArrayList<ESObject>): SourceSpecification {
    const pigeonResult = new SourceSpecification();
    const type: ESObject = list[0];
    pigeonResult.setType(type);
    const camera: ESObject = list[1];
    pigeonResult.setCamera(camera);
    return pigeonResult;
  }
}

export class CacheRetrievalErrorBuilder {
  setCode: null | ((setterArg: string) => ESObject)
  setMessage: ((setterArg: string) => ESObject) | null
  build: (() => ESObject) | null

  constructor(setCode: null | ((setterArg: string) => ESObject), setMessage: ((setterArg: string) => ESObject) | null, build: (() => ESObject) | null) {
    this.setCode = setCode
    this.setMessage = setMessage
    this.build = build
  }
}

export class CacheRetrievalError {
  private code: string = "";
  private message: string = "";

  constructor() {
  }

  getCode(): string {
    return this.code;
  }

  setCode(setterArg: string): void {
    if (setterArg == null) {
      throw new Error("Nonnull field \"code\" is null.")
    }
    this.code = setterArg;
  }

  getMessage(): string {
    return this.message;
  }

  setMessage(setterArg: string): void {
    this.message = setterArg;
  }

  Builder = new CacheRetrievalErrorBuilder(
    (setterArg: string) => {
      this.code = setterArg;
      return this;
    },
    (setterArg: string) => {
      this.message = setterArg;
      return this;
    },
    () => {
      const pigeonReturn = new CacheRetrievalError();
      pigeonReturn.setCode(this.code);
      pigeonReturn.setMessage(this.message);
      return pigeonReturn;
    }
  )

  toList(): ArrayList<ESObject> {
    const toListResult: ArrayList<ESObject> = new ArrayList<ESObject>();
    toListResult.add(this.code);
    toListResult.add(this.message);
    return toListResult;
  }

  fromList(list: ArrayList<ESObject>): CacheRetrievalError {
    const pigeonResult = new CacheRetrievalError();
    const code: ESObject = list[0];
    pigeonResult.setCode(code);
    const message: ESObject = list[1];
    pigeonResult.setMessage(message);
    return pigeonResult;
  }
}

export class CacheRetrievalResultBuilder {
  private type: CacheRetrievalType | null = null;
  private error: CacheRetrievalError | null = null;
  private paths: ArrayList<string> | null = null;
  setType: ((setterArg: CacheRetrievalType) => ESObject) | null
  setError: ((setterArg: CacheRetrievalError) => ESObject) | null
  setPaths: ((setterArg: ArrayList<string>) => ESObject) | null
  build: (() => ESObject) | null

  constructor(setType: ((setterArg: CacheRetrievalType) => ESObject) | null, setError: ((setterArg: CacheRetrievalError) => ESObject) | null, setPaths: ((setterArg: ArrayList<string>) => ESObject) | null, build: (() => ESObject) | null) {
    this.setType = setType
    this.setError = setError
    this.setPaths = setPaths
    this.build = build
  }
}

export class CacheRetrievalResult {
  private type: CacheRetrievalType | null = null;
  private error: CacheRetrievalError | null = null;
  private paths: ArrayList<string> | null = null;

  constructor() {
  }

  getType(): CacheRetrievalType {
    return this.type as CacheRetrievalType;
  }

  setType(setterArg: CacheRetrievalType): void {
    if (setterArg == null) {
      throw new Error("Nonnull field \"type\" is null.")
    }
    this.type = setterArg;
  }

  getError(): CacheRetrievalError | null {
    return this.error;
  }

  setError(setterArg: CacheRetrievalError | null): void {
    this.error = setterArg;
  }

  getPaths(): ArrayList<string> {
    return this.paths as ArrayList<string>;
  }

  setPaths(setterArg: ArrayList<string>): void {
    if (setterArg == null) {
      throw new Error("Nonnull field \"paths\" is null.")
    }
    this.paths = setterArg;
  }

  public Builder = new CacheRetrievalResultBuilder(
    (setterArg: CacheRetrievalType) => {
      this.type = setterArg;
      return this;
    },
    (setterArg: CacheRetrievalError) => {
      this.error = setterArg;
      return this;
    },
    (setterArg: ArrayList<string>) => {
      this.paths = setterArg;
      return this;
    },
    () => {
      const pigeonReturn = new CacheRetrievalResult();
      pigeonReturn.setType(this.type as CacheRetrievalType);
      pigeonReturn.setError(this.error as CacheRetrievalError);
      pigeonReturn.setPaths(this.paths as ArrayList<string>);
      return pigeonReturn;
    })

  toList(): ArrayList<ESObject> {
    const toListResult: ArrayList<ESObject> = new ArrayList<ESObject>();
    toListResult.add(this.type);
    let t = new CacheRetrievalResult()
    toListResult.add(this.error == null ? null : t.error ? t.error.toList() : "");
    toListResult.add(this.paths);
    return toListResult;
  }

  fromList(list: ArrayList<ESObject>): CacheRetrievalResult {
    const pigeonResult = new CacheRetrievalResult();
    const type: ESObject = list[0];
    pigeonResult.setType(type);
    const error: ESObject = list[1];
    let t = new CacheRetrievalResult()
    pigeonResult.setError(error == null ? null : t.fromList(error) as ESObject);
    const paths: ESObject = list[2];
    pigeonResult.setPaths(paths);
    return pigeonResult;
  }
}

export interface Result<T> {
  success(result: T): void;

  error(error: Error | ESObject): Error | ESObject;
}

export class ImagePickerApiCodec extends StandardMessageCodec {
  static INSTANCE = new ImagePickerApiCodec();

  private constructor() {
    super();
  }

  readValueOfType(type: number, buffer: ByteBuffer): ESObject {
    let t: ESObject = {};
    switch (type) {
      case 128:
        t = new CacheRetrievalError()
        return t.fromList(this.readValue(buffer));
      case 129:
        t = new CacheRetrievalResult()
        return t.fromList(this.readValue(buffer));
      case 130:
        return GeneralOptions.fromList(this.readValue(buffer));
      case 131:
        return ImageSelectionOptions.fromList(this.readValue(buffer));
      case 132:
        t = new MediaSelectionOptions()
        return t.fromList(this.readValue(buffer));
      case 133:
        return SourceSpecification.fromList(this.readValue(buffer));
      case 134:
        return VideoSelectionOptions.fromList(this.readValue(buffer));
      default:
        return super.readValueOfType(type, buffer);
    }
  }

  writeValue(stream: ByteBuffer, value: ESObject): void {
    if (value instanceof CacheRetrievalError) {
      stream.writeInt8(128);
      super.writeValue(stream, value.toList());
    } else if (value instanceof CacheRetrievalResult) {
      stream.writeInt8(129);
      super.writeValue(stream, value.toList());
    } else if (value instanceof GeneralOptions) {
      stream.writeInt8(129);
      super.writeValue(stream, value.toList());
    } else if (value instanceof ImageSelectionOptions) {
      stream.writeInt8(130);
      super.writeValue(stream, value.toList());
    } else if (value instanceof MediaSelectionOptions) {
      stream.writeInt8(131);
      super.writeValue(stream, value.toList());
    } else if (value instanceof SourceSpecification) {
      stream.writeInt8(132);
      super.writeValue(stream, value.toList());
    } else if (value instanceof VideoSelectionOptions) {
      stream.writeInt8(134);
      super.writeValue(stream, value.toList());
    } else {
      super.writeValue(stream, value);
    }
  }
}

export abstract class ImagePickerApi {
  abstract pickImages(
    source: SourceSpecification,
    options: ImageSelectionOptions,
    generalOptions: GeneralOptions,
    result: Result<ArrayList<string>>): void;

  abstract pickVideos(
    source: SourceSpecification,
    options: VideoSelectionOptions,
    generalOptions: GeneralOptions,
    result: Result<ArrayList<string>>): void;

  abstract pickMedia(
    mediaSelectionOptions: MediaSelectionOptions,
    generalOptions: GeneralOptions,
    result: Result<ArrayList<string>>): void;

  abstract retrieveLostResults(): Promise<CacheRetrievalResult>;

  static getCodec(): MessageCodec<ESObject> {
    return ImagePickerApiCodec.INSTANCE;
  }

  static setup(binaryMessenger: BinaryMessenger | null, api?: ImagePickerApi | null) {
    if (!binaryMessenger) {
      return
    }
    Log.i(TAG, "setup");

    {
      const channel: BasicMessageChannel<ESObject> =
      new BasicMessageChannel<ESObject>(
        binaryMessenger,
        "dev.flutter.pigeon.image_picker_ohos.ImagePickerApi.pickImages",
        ImagePickerApi.getCodec());
      if (api != null) {
        channel.setMessageHandler({
          onMessage: (message: ESObject, reply: ESObject) => {
            Log.i(TAG, "setup on message : " + message);
            const wrapped: ArrayList<ESObject> = new ArrayList<ESObject>();
            const args: Array<ESObject> = message;
            const sourceArg: SourceSpecification = args[0];
            const optionsArg: ImageSelectionOptions = args[1];
            const generalOptionsArg: GeneralOptions = args[2];
            const resultCallback: Result<ArrayList<string>> = new ResultBuilder((result: ArrayList<string>): void => {
              wrapped.insert(result.convertToArray(), 0);
              reply.reply(wrapped.convertToArray());
            }, (error: Error): void => {
              const wrappedError: ArrayList<ESObject> = Messages.wrapError(error);
              reply.reply(wrappedError.convertToArray());
            })

            api.pickImages(sourceArg, optionsArg, generalOptionsArg, resultCallback);
          }
        })
      } else {
        channel.setMessageHandler(null);
      }
    }
    {
      const channel: BasicMessageChannel<ESObject> =
      new BasicMessageChannel<ESObject>(
        binaryMessenger,
        "dev.flutter.pigeon.image_picker_ohos.ImagePickerApi.pickVideos",
        ImagePickerApi.getCodec());
      if (api != null) {
        channel.setMessageHandler({
          onMessage: (message: ESObject, reply: ESObject) => {
            const wrapped: ArrayList<ESObject> = new ArrayList<ESObject>();
            const args: Array<ESObject> = message;
            const sourceArg: SourceSpecification = args[0];
            const optionsArg: VideoSelectionOptions = args[1];
            const generalOptionsArg: GeneralOptions = args[2];
            const resultCallback: Result<ArrayList<string>> = new ResultBuilder((result: ArrayList<string>): void => {
              wrapped.insert(result.convertToArray(), 0);
              reply.reply(wrapped.convertToArray());
            }, (error: Error): void => {
              const wrappedError: ArrayList<ESObject> = Messages.wrapError(error);
              reply.reply(wrappedError.convertToArray());
            })
            api.pickVideos(sourceArg, optionsArg, generalOptionsArg, resultCallback);
          }
        })
      } else {
        channel.setMessageHandler(null);
      }
    }
    {
      const channel: BasicMessageChannel<ESObject> =
      new BasicMessageChannel<ESObject>(
        binaryMessenger,
        "dev.flutter.pigeon.image_picker_ohos.ImagePickerApi.pickMedia",
        ImagePickerApi.getCodec());
      if (api != null) {
        channel.setMessageHandler({
          onMessage: (message: ESObject, reply: ESObject) => {
            const wrapped: ArrayList<ESObject> = new ArrayList<ESObject>();
            const args: Array<ESObject> = message;
            const optionsArg: MediaSelectionOptions = args[0];
            const generalOptionsArg: GeneralOptions = args[1];
            const resultCallback: Result<ArrayList<string>> = new ResultBuilder((result: ArrayList<string>): void => {
              wrapped.insert(result.convertToArray(), 0);
              reply.reply(wrapped.convertToArray());
            }, (error: Error): void => {
              const wrappedError: ArrayList<ESObject> = Messages.wrapError(error);
              reply.reply(wrappedError.convertToArray());
            })
            api.pickMedia(optionsArg, generalOptionsArg, resultCallback);
          }
        })
      } else {
        channel.setMessageHandler(null);
      }
    }
    {
      const channel: BasicMessageChannel<ESObject> =
      new BasicMessageChannel<ESObject>(
        binaryMessenger,
        "dev.flutter.pigeon.image_picker_ohos.ImagePickerApi.retrieveLostResults",
        ImagePickerApi.getCodec());
      if (api != null) {
        channel.setMessageHandler({
          onMessage: async (message: ESObject, reply: ESObject) => {
            let wrapped: ArrayList<ESObject> = new ArrayList<ESObject>();
            try {
              const output: CacheRetrievalResult = await api.retrieveLostResults().then((result) => {
                return result;
              });
              wrapped.insert(output, 0);
            } catch (err) {
              const wrappedError: ArrayList<ESObject> = Messages.wrapError(err);
              wrapped = wrappedError;
            }
            reply.reply(wrapped.convertToArray());
          }
        });
      } else {
        channel.setMessageHandler(null);
      }
    }
  }
}

class ResultBuilder {
  success: (result: ArrayList<string>) => void
  error: (error: Error) => void

  constructor(success: ESObject, error: ESObject) {
    this.success = success
    this.error = error
  }
}