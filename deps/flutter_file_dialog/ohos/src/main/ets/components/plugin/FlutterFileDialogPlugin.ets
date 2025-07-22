import {
  BinaryMessenger,
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult
} from "@ohos/flutter_ohos";
import { FileDialog } from "./FileDialog";
import { common } from "@kit.AbilityKit";
import { hilog } from "@kit.PerformanceAnalysisKit";
import { fileIo as fs } from '@kit.CoreFileKit';

const LOG_TAG = 'FlutterFileDialogPlugin';
const DOMAIN_NUMBER = 0xFF00;

export const FlutterFileDialogPlugin = class implements FlutterPlugin, MethodCallHandler {
  getUniqueClassName(): string {
    throw new Error('FlutterFileDialogPlugin');
  }

  private context: common.Context | null = null;
  private fileDialog: FileDialog | null = null;
  private pluginBinding: FlutterPluginBinding | null = null;
  private methodChannel: MethodChannel | null = null;
  static LOG_TAG = "FlutterFileDialogPlugin";

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    console.log(`${FlutterFileDialogPlugin.LOG_TAG} - onAttachedToEngine - IN`);

    if (this.pluginBinding) {
      console.warn(`${FlutterFileDialogPlugin.LOG_TAG} - onAttachedToEngine - already attached`);
    }

    this.pluginBinding = binding;

    const messenger = this.pluginBinding.getBinaryMessenger();
    this.doOnAttachedToEngine(messenger);
    this.context = this.pluginBinding.getApplicationContext();

    console.log(`${FlutterFileDialogPlugin.LOG_TAG} - onAttachedToEngine - OUT`);
  }

  onDetachedFromEngine(): void {
    console.log(`${FlutterFileDialogPlugin.LOG_TAG} - onDetachedFromEngine`);
    this.doOnDetachedFromEngine();
  }


  private doOnAttachedToEngine(messenger: BinaryMessenger): void {
    console.log(`${FlutterFileDialogPlugin.LOG_TAG} - doOnAttachedToEngine - IN`);

    this.methodChannel = new MethodChannel(messenger, "flutter_file_dialog");
    this.methodChannel.setMethodCallHandler(this);

    console.log(`${FlutterFileDialogPlugin.LOG_TAG} - doOnAttachedToEngine - OUT`);
  }

  private doOnDetachedFromEngine(): void {
    console.log(`${FlutterFileDialogPlugin.LOG_TAG} - doOnDetachedFromEngine - IN`);

    if (!this.pluginBinding) {
      console.warn(`${FlutterFileDialogPlugin.LOG_TAG} - doOnDetachedFromEngine - already detached`);
    }
    this.pluginBinding = null;

    this.methodChannel?.setMethodCallHandler(null);
    this.methodChannel = null;

    console.log(`${FlutterFileDialogPlugin.LOG_TAG} - doOnDetachedFromEngine - OUT`);
  }

  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    console.log(`${FlutterFileDialogPlugin.LOG_TAG} - onMethodCall - IN , method=${call.method}`);
    if (!this.fileDialog) {
      if (!this.createFileDialog()) {
        result.error("init_failed", "Not attached", null);
        return;
      }
    }

    switch (call.method) {
      case "pickDirectory":
        await this.fileDialog!.pickDirectory(result);
        break;
      case "isPickDirectorySupported":
        //todo
        break;
      case "saveFileToDirectory":
        await this.saveFileToDirectory(
          result,
          call.argument("mimeType"),
          call.argument("fileName"),
          call.argument("directory"),
          call.argument("data")
        );
        break;
      case "pickFile":
        await this.fileDialog!.pickFile(
          result,
          call.argument("fileExtensionsFilter"),
          call.argument("mimeTypesFilter"),
          call.argument("localOnly"),
          call.argument("copyFileToCacheDir")
        );
        break;
      case "saveFile":
        await this.fileDialog!.saveFile(
          result,
          call.argument("sourceFilePath"),
          call.argument("data"),
          call.argument("fileName"),
          call.argument("mimeTypesFilter"),
          call.argument("localOnly")
        );
        break;
      default:
        result.notImplemented();
    }
  }

  private async saveFileToDirectory(
    result: MethodResult,
    mimeType: string | null,
    fileName: string | null,
    directory: string | null,
    data: Uint8Array | null
  ): Promise<void> {
    if (!data || !fileName || !mimeType || !directory) {
      result.error("invalid_arguments", "Missing required arguments", null);
      return;
    }

    if (!this.context) {
      result.error("context_bound", "context not bound", null);
      return;
    }

    try {
      await this.writeFile(data, directory, fileName);
      result.success(`${directory}/${fileName}`);
    } catch (e) {
      result.error("error_saving_file", e.message, null);
    }
  }

  private async writeFile(data: Uint8Array, destinationFileUri: string, fileName: string): Promise<void> {
    try {
      await fs.mkdir(destinationFileUri);
      const filePath = `${destinationFileUri}/${fileName}`;
      let file = await fs.open(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      await fs.write(file.fd, data);
      hilog.error(DOMAIN_NUMBER, LOG_TAG, `Save file to : ${destinationFileUri}`);
    } catch (error) {
      hilog.error(DOMAIN_NUMBER, LOG_TAG, `Save failed: ${JSON.stringify(error)}`);
    }
  }

  private createFileDialog(): boolean {
    console.log(`${FlutterFileDialogPlugin.LOG_TAG} - createFileDialog - IN`);
    if (this.context) {
      this.fileDialog = new FileDialog(this.context);
    }

    console.log(`${FlutterFileDialogPlugin.LOG_TAG} - createFileDialog - OUT`);
    return !!this.fileDialog;
  }

  private parseMethodCallArrayArgument(call: MethodCall, arg: string): string[] | null {
    return call.argument(arg) || null;
  }
}