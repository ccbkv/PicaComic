package eu.simonbinder.sqlite3_flutter_libs;

import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/** Sqlite3FlutterLibsPlugin */
public class Sqlite3FlutterLibsPlugin implements FlutterPlugin {

  private static final String CHANNEL = "sqlcipher_flutter_libs";

  private MethodChannel channel;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    // Ideally, we shouldn't have to do anything, as the only purpose of this plugin is to provide
    // sqlite native libraries to DynamicLibrary.open() in Dart. However, the loader of Android
    // 6.0.1 is so broken that we can only dlopen stuff after loading it through System.openLibrary.
    // So, we provide a platform method for that.
    channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);

    channel.setMethodCallHandler(new MethodChannel.MethodCallHandler() {
      @Override
      public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        try {
          System.loadLibrary("sqlcipher");
          result.success(null);
        } catch (Throwable e) {
          result.error(e.toString(), null, null);
        }
      }
    });
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    if (channel != null) {
      channel.setMethodCallHandler(null);
      channel = null;
    }
  }

}
