# sqlite3

[中文](README.md) | **English**

Provides Dart bindings to [SQLite](https://www.sqlite.org/index.html) via `dart:ffi`.

This library is one of forked versions of [sqlite.dart](https://github.com/simolus3/sqlite3.dart). Derived from the original support for Android, iOS, Windows, MacOS, Linux, and Web, **this library provides additional support for HarmonyOS**.

HarmonyOS support is based on **[鸿蒙突击队 / Flutter 3.22.0](https://gitee.com/harmonycommando_flutter/flutter/tree/oh-3.22.0)** and has been tested on Mac Arm HarmonyOS Simulator.

## Contents

- [Quick Start](#quick-start)
  - [Add `sqlite3`](#add-sqlite3)
  - [Add `sqlite3_flutter_libs` (Optional)](#add-sqlite3_flutter_libs-optional)
  - [Manage Databases via `sqlite3`](#manage-databases-via-sqlite3)
  - [Provide SQLite Native Libraries Manually](#provide-sqlite-native-libraries-manually)
    - [Obtain](#obtain)
    - [Override](#override)
  - [Add HarmonyOS Support for Packages that Depend on `sqlite3` and `sqlite3_flutter_libs`](#add-harmonyos-support-for-packages-that-depend-on-sqlite3-and-sqlite3_flutter_libs)
- [Addition](#addition)

## Quick Start

### Add `sqlite3`

```yaml
dependencies:
  sqlite3:
    git:
      url: https://github.com/SageMik/sqlite3-ohos.dart
      path: sqlite3
      ref: sqlite3-2.4.7-ohos
```

### Add `sqlite3_flutter_libs` (Optional)

```yaml
dependencies:
  sqlite3_flutter_libs:
    git:
      url: https://github.com/SageMik/sqlite3-ohos.dart
      path: sqlite3_flutter_libs
      ref: sqlite3_flutter_libs-0.5.25-ohos
```

To support `sqlite3` in accessing databases, you need to ensure that SQLite native libraries are accessible in your environment.

For example, For Android and HarmonyOS, you may provide `libsqlite3.so` for architectures such as `arm64-v8a`, `x86_64` and so on. For Windows, `sqlite3.dll` for `x64` is what you need.

This also means that you can use `sqlite3` on any platform that can load native libraries and obtain SQLite3 symbols via `DynamicLibrary`.

If you are a Flutter developer, it is recommended to add `sqlite3_flutter_libs` as your dependency directly, which includes native SQLite libraries for the following platforms:

- HarmonyOS
- Android
- iOS
- Windows
- MacOS
- Linux

After adding it, the native libraries will be included in your application and distributed with your application. As a result, you can use `sqlite3` to manage SQLite databases on these platforms without any additional configurations.

If not, or if you prefer to compile SQLite native libraries by yourself, please refer to [Provide SQLite Native Libraries Manually](#Provide-SQLite-Native-Libraries-Manually).

In addition, there are some differences in the availability of SQLite native libraries on different platforms. Please also refer to [Provide SQLite Native Libraries Manually](#Provide-SQLite-Native-Libraries-Manually) for more information.

### Manage Databases via `sqlite3`

1. Import `package:sqlite3/sqlite3.dart`.
2. Use `final db = sqlite3.open()` to open a database file , or use `sqlite3.openInMemory()` to open a temporary in-memory database.
3. Use `db.execute()` to execute statements or use `db.prepare()` to precompile them first.
4. When finished, use `dispose()` to close the database or compiled statements.

### Provide SQLite Native Libraries Manually

#### Obtain

Apart from **including SQLite native libraries via `sqlite3_flutter_libs`**, you can also obtain SQLite native libraries in different ways on various platforms, for example:

- **Android**: You can get `libsqlite3x.so` provided by [sqlite-android](https://github.com/requery/sqlite-android).
- **iOS**: Without other SQLite native libraries, the system's built-in SQLite is used by default.
- **MacOS**: Same as iOS.

(For the default way `sqlite3` searches native libraries, please refer to [`lib/src/ffi/load_library.dart`](lib/src/ffi/load_library.dart) )

If you want to customize your native libraries with different compilation options and compile them yourself, please refer to the official guide [How To Compile SQLite](https://sqlite.org/howtocompile.html) or the implementations of [`sqlite3_flutter_libs` on different platforms](../sqlite3_flutter_libs) for different platforms, for example:

- **Android**: [`sqlite3-native-library/cpp/CMakeLists.txt`](https://github.com/simolus3/sqlite-native-libraries/blob/master/sqlite3-native-library/cpp/CMakeLists.txt) in [sqlite-native-libraries](https://github.com/simolus3/sqlite-native-libraries).
- **HarmonyOS**: [`sqlite3_native_library/src/main/cpp/CMakeLists.txt`](https://github.com/SageMik/sqlite3.ArkTS/blob/main/sqlite3_native_library/src/main/cpp/CMakeLists.txt) in [sqlite3.ArkTS](https://github.com/SageMik/sqlite3.ArkTS) (keep consistent with the Android).

#### Override

After obtaining SQLite native libraries, you need to override the way `sqlite3` searches them. For example, if you have got `sqlite3.so` for Linux platform, you can use your native library as follows:

```dart
import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  open.overrideFor(OperatingSystem.linux, _openOnLinux);

  final db = sqlite3.openInMemory();
  
  // DO SOME DATABASE OPERATIONS

  db.dispose();
}

DynamicLibrary _openOnLinux() {
  final scriptDir = File(Platform.script.toFilePath()).parent;
  final libraryNextToScript = File(join(scriptDir.path, 'sqlite3.so'));
  return DynamicLibrary.open(libraryNextToScript.path);
}
```

### Add HarmonyOS Support for Packages that Depend on `sqlite3` and `sqlite3_flutter_libs`

In theory, by overriding `sqlite3` and `sqlite3_flutter_libs` with this forked version packages depended on them are supposed to manage SQLite on HarmonyOS, such as [`drift`](https://github.com/simolus3/drift), [`sqflite_common_ffi`](https://github.com/tekartik/sqflite/tree/master/sqflite_common_ffi) and so on.

```yaml
dependency_overrides:
  
  sqlite3:
    git:
      url: https://github.com/SageMik/sqlite3-ohos.dart
      path: sqlite3
      ref: sqlite3-2.4.7-ohos
  
  sqlite3_flutter_libs:
    git:
      url: https://github.com/SageMik/sqlite3-ohos.dart
      path: sqlite3_flutter_libs
      ref: sqlite3_flutter_libs-0.5.25-ohos
```

This conclusion is waiting for further examples.

## Addition

For any matters not covered herein, please refer to the original repository [sqlite.dart](https://github.com/simolus3/sqlite3.dart).
