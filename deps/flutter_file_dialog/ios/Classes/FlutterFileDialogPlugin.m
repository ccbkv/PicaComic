#import "FlutterFileDialogPlugin.h"
#import <flutter_file_dialog/flutter_file_dialog-Swift.h>

@implementation FlutterFileDialogPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterFileDialogPlugin registerWithRegistrar:registrar];
}
@end
