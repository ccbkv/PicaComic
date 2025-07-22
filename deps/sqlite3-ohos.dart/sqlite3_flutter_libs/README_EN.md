# sqlite3_flutter_libs

[中文](README.md) | **English**

This package includes SQLite Native Libraries for the following platforms:

- HarmonyOS
- Android
- iOS
- Windows
- MacOS
- Linux

It supports Flutter applications in managing databases through [`sqlite3`](../sqlite3).

After adding this package as your dependency, the native libraries will be included in your application and distributed with your application. As a result, you can use `sqlite3` to manage SQLite databases on these platforms without any additional configurations.

For more information, please refer to the [`sqlite3`](../sqlite3#sqlite3).

## SQLite Compilation

The SQLite native libraries in this package are compiled with [the officially recommended compilation options](https://www.sqlite.org/compile.html#recommended_compile_time_options), and by default include `fts5` and `json1` modules (in recent versions of SQLite, `json1` is added as part of the default build). Other modules are not included.

## Android Platform Notes

### Supported Architectures

This package includes the following architectures for Android SQLite native libraries:

- `arm64-v8a`
- `armeabi-v7a`
- `x86`
- `x86_64`

Since Flutter doesn't support building release versions for `x86` 32-bit devices (see [here](https://docs.flutter.dev/deployment/android#what-are-the-supported-target-architectures)), you can limit the supported architectures in `build.gradle` to reduce the app size:

```gradle
android {
    defaultConfig {
        ndk {
            abiFilters 'armeabi-v7a', 'arm64-v8a', 'x86_64'
        }
    }
}
```

### Loading Native Libraries on Android 6

There seems to be an issue when loading native libraries on Android 6 (see [this issue](https://github.com/simolus3/moor/issues/895#issuecomment-720195005)). If you're seeing those crashes, you can try setting `android.bundle.enableUncompressedNativeLibs=false` in your `gradle.properties` file. This should resolve them but will increase the size of your application when installed.

Alternatively, you can use `applyWorkaroundToOpenSqlite3OnOldAndroidVersions()` in this package. It will try to open SQLite native library in Java, which seems to work more reliably. Once the SQLite library is loaded from Java, we can open it in Dart too.

This method needs to be called before using `sqlite3`, whether directly or indirectly via packages like [`drift`](https://github.com/simolus3/drift).

Since this method calls Android native code through Platform Channel, it may cause issues when called in a background isolate. Therefore, it is recommended to call `await applyWorkaroundToOpenSqlite3OnOldAndroidVersions()` in the main isolate _before_ spawning any background isolates for database management.

### Providing a Temporary Path

If you have complex queries failing with a `SQLITE_IOERR_GETTEMPPATH 6410` error, You could try to explicitly set the temporary path used by `sqlite3`.  [This comment](https://github.com/simolus3/moor/issues/876#issuecomment-710013503) contains a snippet to do just that.
