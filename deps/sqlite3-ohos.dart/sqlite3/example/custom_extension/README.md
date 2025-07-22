# uuid.c example

This example shows how to load SQLite extensions into Flutter apps using `sqlite3_flutter_libs`.
As an example, it uses the [uuid.c](https://github.com/sqlite/sqlite/blob/master/ext/misc/uuid.c)
extension, but other extensions can be adapted similarly.

To build the extension:

1. A `CMakeLists.txt` (in `src/`) is written for Android, Linux and Windows.
2. On Android, the NDK is set up to point at the CMake builds in `android/build.gradle`.
3. For macOS and iOS (which don't use CMake as a build tool), the `uuid.c` file is added
   to `macos|ios/Classes` instead.
4. Note that this example does not currently support WebAssembly. Loadable extensions don't
   work on the web, but you can compile a custom `sqlite3.wasm` bundle with the desired extensions
   included. The `../custom_wasm_build` example has an example for that setup.

This build setup includes a shared library with the extension in your app. To use it, load the
`DynamicLibrary` and then load it into sqlite3 like this:

```dart
  sqlite3.ensureExtensionLoaded(
    SqliteExtension.inLibrary(uuid.lib, 'sqlite3_uuid_init'),
  );
```
