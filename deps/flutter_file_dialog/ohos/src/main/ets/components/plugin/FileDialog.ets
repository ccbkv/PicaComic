// file_dialog.ets

import { hilog } from '@kit.PerformanceAnalysisKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { MethodResult } from '@ohos/flutter_ohos';
import common from '@ohos.app.ability.common';
import picker from '@ohos.file.picker';
import { JSON } from '@kit.ArkTS';

const LOG_TAG = 'FileDialog';
const DOMAIN_NUMBER = 0xFF00;

export class FileDialog {
  private context: common.Context;
  private pendingResult: MethodResult | null = null;
  private fileExtensionsFilter: string[] | null = null;
  private copyPickedFileToCacheDir: boolean = true;
  private sourceFilePath: string | undefined = undefined;
  private isSourceFileTemp: boolean = false;

  constructor(context: common.Context) {
    this.context = context;
  }

  pickDirectory(result: MethodResult): void {

    hilog.info(DOMAIN_NUMBER, LOG_TAG, 'pickDirectory - IN');

    if (!this.setPendingResult(result)) {
      this.finishWithAlreadyActiveError(result);
      return;
    }
    if (canIUse('SystemCapability.FileManagement.UserFileService.FolderSelection')) {

      let documentSelectOptions: picker.DocumentSelectOptions = {
        selectMode: picker.DocumentSelectMode.FOLDER
      }

      const documentViewPicker = new picker.DocumentViewPicker();
      documentViewPicker.select(documentSelectOptions)
        .then((documentSelectResult: string[]) => {
          if (documentSelectResult && documentSelectResult.length > 0) {
            hilog.info(DOMAIN_NUMBER, LOG_TAG, `Picked directory: ${documentSelectResult[0]}`);
            this.finishSuccessfully(documentSelectResult[0]);
          } else {
            hilog.info(DOMAIN_NUMBER, LOG_TAG, 'Cancelled');
            this.finishSuccessfully(null);
          }
        })
        .catch((err: BusinessError) => {
          hilog.error(DOMAIN_NUMBER, LOG_TAG, `Error picking directory: ${err}`);
          this.finishWithError(result, 'pick_directory_failed', 'Failed to pick directory', err.toString());
        });
    }
    hilog.info(DOMAIN_NUMBER, LOG_TAG, 'pickDirectory - OUT');
  }

  async pickFile(
    result: MethodResult,
    fileExtensionsFilter: string[] | null,
    mimeTypesFilter: string[] | undefined,
    localOnly: boolean,
    copyFileToCacheDir: boolean
  ): Promise<void> {
    hilog.info(DOMAIN_NUMBER, LOG_TAG, `pickFile - IN, fileExtensionsFilter=${JSON.stringify(fileExtensionsFilter)}`);

    if (!this.setPendingResult(result)) {
      this.finishWithAlreadyActiveError(result);
      return;
    }

    if (canIUse('SystemCapability.FileManagement.UserFileService.FolderSelection')) {

      this.fileExtensionsFilter = fileExtensionsFilter;
      this.copyPickedFileToCacheDir = copyFileToCacheDir;

      let documentSelectOptions: picker.DocumentSelectOptions = {
        selectMode: picker.DocumentSelectMode.FILE,
        fileSuffixFilters: mimeTypesFilter
      }

      const documentViewPicker = new picker.DocumentViewPicker();
      documentViewPicker.select(documentSelectOptions)
        .then((documentSelectResult: string[]) => {
          if (documentSelectResult && documentSelectResult.length > 0) {
            hilog.info(DOMAIN_NUMBER, LOG_TAG, `Picked file: ${JSON.stringify(documentSelectResult)}`);
            this.handlePickedFile(documentSelectResult[0]);
          } else {
            hilog.info(DOMAIN_NUMBER, LOG_TAG, 'Cancelled');
            this.finishSuccessfully(null);
          }
        })
        .catch((err: BusinessError) => {
          hilog.error(DOMAIN_NUMBER, LOG_TAG, `Error picking directory: ${err}`);
          this.finishWithError(result, 'pick_directory_failed', 'Failed to pick directory', err.toString());
        });
    }
  }

  private async handlePickedFile(uri: string): Promise<void> {
    try {
      const fileInfo = await fs.stat(uri);
      if (fileInfo.isFile()) {
        const fileName = uri.split('/').pop() ?? '';
        if (this.validateFileExtension(fileName)) {
          if (this.copyPickedFileToCacheDir) {
            await this.copyToCacheDir(uri, fileName);
          } else {
            this.finishSuccessfully(uri);
          }
        } else {
          this.finishWithError(this.pendingResult!, 'invalid_extension', 'Invalid file type', null);
        }
      }
    } catch (error) {
      hilog.error(DOMAIN_NUMBER, LOG_TAG, `File handle failed: ${JSON.stringify(error)}`);
    }
  }

  private async copyToCacheDir(sourceUri: string, fileName: string): Promise<void> {
    const cacheDir = this.context.cacheDir;
    const destPath = `${cacheDir}/${fileName}`;

    try {
      await fs.copy(sourceUri, destPath);
      hilog.info(DOMAIN_NUMBER, LOG_TAG, `File copied to: ${destPath}`);
      this.finishSuccessfully(destPath);
    } catch (error) {
      hilog.error(DOMAIN_NUMBER, LOG_TAG, `Copy failed: ${JSON.stringify(error)}`);
      this.finishWithError(this.pendingResult!, 'copy_failed', 'File copy failed', error.message);
    }
  }

  private validateFileExtension(fileName: string): boolean {
    const ext = fileName.split('.').pop()?.toLowerCase() ?? '';
    return !this.fileExtensionsFilter || this.fileExtensionsFilter.includes(ext);
  }

  saveFile(
    result: MethodResult,
    sourceFilePath: string | undefined,
    data: Uint8Array,
    fileName: string,
    mimeTypesFilter: string[] | undefined,
    localOnly: boolean
  ) {
    hilog.info(DOMAIN_NUMBER, LOG_TAG,
      ` saveFile - IN, sourceFilePath=${sourceFilePath}, ` +
        `data=${data?.byteLength} bytes, fileName=${fileName}, ` +
        `mimeTypesFilter=${mimeTypesFilter}, localOnly=${localOnly}`
    );

    if (!this.setPendingResult(result)) {
      this.finishWithAlreadyActiveError(result);
      return;
    }
    if (sourceFilePath) {
      this.isSourceFileTemp = false;
      this.sourceFilePath = sourceFilePath;
      this.handleSaveFile(fileName, data);
    } else {
      this.isSourceFileTemp = true;
      this.createTempFile(fileName, data);
    }

    hilog.info(DOMAIN_NUMBER, LOG_TAG, `saveFile - OUT`);
  }

  private async createTempFile(fileName: string, data: Uint8Array): Promise<string> {
    const tempDir = this.context.cacheDir + '/temp';
    await fs.mkdtempSync(tempDir);
    const tempPath = `${tempDir}/${fileName}`;
    let file = await fs.open(tempPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
    await fs.write(file.fd, data);
    return tempPath;
  }

  private async handleSaveFile(fileName: string, data: Uint8Array): Promise<void> {
    if (!this.sourceFilePath) {
      return;
    }

    try {
      await fs.mkdir(this.sourceFilePath);
      const filePath = `${this.sourceFilePath}/${fileName}`;
      let file = await fs.open(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
      await fs.write(file.fd, data);
      this.finishSuccessfully(filePath);
    } catch (error) {
      hilog.error(DOMAIN_NUMBER, LOG_TAG, `Save failed: ${JSON.stringify(error)}`);
      this.finishWithError(this.pendingResult!, 'save_failed', 'File save failed', error.message);
    } finally {
      this.cleanupTempFile();
    }
  }

  private async cleanupTempFile(): Promise<void> {
    if (this.isSourceFileTemp && this.sourceFilePath) {
      try {
        await fs.unlink(this.sourceFilePath);
        hilog.info(DOMAIN_NUMBER, LOG_TAG, `Temp file deleted: ${this.sourceFilePath}`);
      } catch (error) {
        hilog.warn(DOMAIN_NUMBER, LOG_TAG, `Temp file delete failed: ${JSON.stringify(error)}`);
      }
    }
  }

  private handleSaveError(error: BusinessError): void {
    hilog.error(DOMAIN_NUMBER, LOG_TAG, `Save error: ${JSON.stringify(error)}`);
    const message = error.code === 13900001 ? 'Permission denied' : error.message;
    this.finishWithError(this.pendingResult!, 'save_error', message, error.code.toString());
  }

  private setPendingResult(result: MethodResult): boolean {
    if (this.pendingResult) {
      return false;
    }
    this.pendingResult = result;
    return true;
  }

  private finishSuccessfully(path: any): void {
    this.pendingResult?.success(path);
    this.pendingResult = null;
  }

  private finishWithError(result: MethodResult, code: string, message: string, details: any): void {
    result.error(code, message, details);
    this.pendingResult = null;
  }

  private finishWithAlreadyActiveError(result: MethodResult): void {
    result.error('busy', 'Operation already in progress', null);
  }
}