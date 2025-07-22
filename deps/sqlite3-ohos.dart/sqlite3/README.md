# sqlite3

**中文** | [English](README_EN.md)

通过 `dart:ffi` 提供对 [SQLite](https://www.sqlite.org/index.html) 的 Dart 绑定。

本库是 [sqlite.dart](https://github.com/simolus3/sqlite3.dart) 的分支版本之一，在原版支持 Android, iOS, Windows, MacOS, Linux, Web 的基础上，**新增了对 HarmonyOS 平台的支持**。

HarmonyOS 适配基于 **[鸿蒙突击队 / Flutter 3.22.0](https://gitee.com/harmonycommando_flutter/flutter/tree/oh-3.22.0)** 实现，目前已在 Mac Arm HarmonyOS 模拟器 通过测试。

## 目录

- [快速开始](#快速开始)
  - [添加 `sqlite3`](#添加-sqlite3)
  - [添加 `sqlite3_flutter_libs` (可选)](#添加-sqlite3_flutter_libs-可选)
  - [通过 `sqlite3` 管理数据库](#通过-sqlite3-管理数据库)
  - [自行提供 SQLite 原生库](#自行提供-sqlite-原生库)
    - [获取](#获取)
    - [覆盖](#覆盖)
  - [为依赖于 `sqlite3`、`sqlite3_flutter_libs` 的库添加 HarmonyOS 支持](#为依赖于-sqlite3sqlite3_flutter_libs-的库添加-harmonyos-支持)
- [补充说明](#补充说明)

## 快速开始

### 添加 `sqlite3`

```yaml
dependencies:
  sqlite3:
    git:
      url: https://github.com/SageMik/sqlite3-ohos.dart
      path: sqlite3
      ref: sqlite3-2.4.7-ohos
```

### 添加 `sqlite3_flutter_libs` (可选)

```yaml
dependencies:
  sqlite3_flutter_libs:
    git:
      url: https://github.com/SageMik/sqlite3-ohos.dart
      path: sqlite3_flutter_libs
      ref: sqlite3_flutter_libs-0.5.25-ohos
```

为了支持 `sqlite3` 管理数据库，您需要确保您的环境中存在可访问的 SQLite3 原生库。

例如，对于 Android 和 HarmonyOS 平台，需要根据实际情况提供 `arm64-v8a`, `x86_64` 等架构的 `libsqlite3.so` ；对于 Windows 平台，则需要提供 `x64` 架构的 `sqlite3.dll` 。

这也意味着，您能够在任何可以通过 `DynamicLibrary` 加载原生库获取到 SQLite3 符号的平台上使用 `sqlite3` 。

**如果您是 Flutter 开发者，推荐直接添加 `sqlite3_flutter_libs` 依赖** ，该库包含了如下平台的 SQLite 原生库：

- HarmonyOS
- Android
- iOS
- Windows
- MacOS
- Linux

添加依赖后，原生库会被包含在应用中并随应用分发。因此**您无需进行任何额外的配置，即可通过 `sqlite3` 在上述平台管理 SQLite 数据库。**

若非如此，或者您希望自行编译提供 SQLite 原生库，请参考下文 [自行提供 SQLite 原生库](#自行提供-SQLite-原生库) 。

此外，不同平台 SQLite 原生库的提供情况还有一部分差异，也请参阅 [自行提供 SQLite 原生库](#自行提供-SQLite-原生库) 。

### 通过 `sqlite3` 管理数据库

1. 导入 `package:sqlite3/sqlite3.dart` 。
2. 使用 `final db = sqlite3.open()` 打开数据库文件，或使用 `sqlite3.openInMemory()` 打开一个临时的内存数据库。
3. 使用 `db.execute()` 执行语句，`db.prepare()` 预编译语句。
4. 使用完毕，通过 `dispose()` 关闭数据库或已编译的语句。

更多示例请参考 [`example`](example) 。

### 自行提供 SQLite 原生库

#### 获取

除了**通过 `sqlite3_flutter_libs` 引入 SQLite 原生库**，您还可以在不同平台上通过不同的方式获取 SQLite 原生库，例如：

- **Android**：可以引入 [sqlite-android](https://github.com/requery/sqlite-android) 提供的 `libsqlite3x.so` 原生库。
- **iOS**：在不引入其他 SQLite 原生库的情况下，默认使用系统内置的 SQLite 。
- **MacOS**：同上。

（有关 `sqlite3` 查找原生库的默认方式请参考 [`lib/src/ffi/load_library.dart`](lib/src/ffi/load_library.dart) ）

如果您希望自行编译 SQLite 原生库，通过调整不同的编译选项自定义您的原生库，请参考 [SQLite 官方编译指南](https://sqlite.org/howtocompile.html)，或参考 [`sqlite3_flutter_libs` 的在不同平台的编译实现](../sqlite3_flutter_libs)，例如：

- **Android**：[sqlite-native-libraries](https://github.com/simolus3/sqlite-native-libraries) 中 [`sqlite3-native-library/cpp/CMakeLists.txt`](https://github.com/simolus3/sqlite-native-libraries/blob/master/sqlite3-native-library/cpp/CMakeLists.txt) 。
- **HarmonyOS**：[sqlite3.ArkTS](https://github.com/SageMik/sqlite3.ArkTS) 中 [`sqlite3_native_library/src/main/cpp/CMakeLists.txt`](https://github.com/SageMik/sqlite3.ArkTS/blob/main/sqlite3_native_library/src/main/cpp/CMakeLists.txt)（与 Android 实现保持一致）。

#### 覆盖

在获取 SQLite 原生库后，您需要覆盖 `sqlite3` 查找 SQLite 原生库的方式。假定您获取了 Linux 平台下的 `sqlite3.so`，您可以通过如下代码使用指定的原生库：

```dart
import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  open.overrideFor(OperatingSystem.linux, _openOnLinux);

  final db = sqlite3.openInMemory();
  
  // 执行数据库操作

  db.dispose();
}

DynamicLibrary _openOnLinux() {
  final scriptDir = File(Platform.script.toFilePath()).parent;
  final libraryNextToScript = File(join(scriptDir.path, 'sqlite3.so'));
  return DynamicLibrary.open(libraryNextToScript.path);
}
```

### 为依赖于 `sqlite3`、`sqlite3_flutter_libs` 的库添加 HarmonyOS 支持

理论上，在 `pubspec.yaml` 中将其他依赖中的 `sqlite3`、`sqlite3_flutter_libs` 覆盖为本分支版本，即支持这些库在 HarmonyOS 上管理 SQLite ，如 [`drift`](https://github.com/simolus3/drift)、[`sqflite_common_ffi`](https://github.com/tekartik/sqflite/tree/master/sqflite_common_ffi) 等：

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

这一结论待补充具体示例。

## 补充说明

未尽事宜，请参阅原仓库 [sqlite.dart](https://github.com/simolus3/sqlite3.dart) 文档。
