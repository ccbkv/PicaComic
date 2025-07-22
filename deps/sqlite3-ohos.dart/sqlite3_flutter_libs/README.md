# sqlite3_flutter_libs

**中文** | [English](README_EN.md)

本库包含了如下平台的 SQLite 原生库 (Native Library)：

- HarmonyOS
- Android
- iOS
- Windows
- MacOS
- Linux

用于支持 Flutter 应用通过 [`sqlite3`](../sqlite3) 管理数据库。

添加对本库的依赖后，原生库会被包含在应用中并随应用分发。因此**您无需进行任何额外的配置，即可通过 `sqlite3` 在上述平台管理 SQLite 数据库。**

更多相关信息，请参阅 [`sqlite3` 的说明](../sqlite3/README.md) 。

## SQLite 编译说明

本库的 SQLite 原生库使用了 [官方推荐的编译选项](https://www.sqlite.org/compile.html#recommended_compile_time_options) 进行编译，并默认包含了 `fts5` 和 `json1`（在最近的 SQLite 版本中，`json1` 被添加为默认构建的一部分）模块，其它模块则未被包含。

## Android 平台注意事项

### 原生库支持的架构

本库包含如下架构的 Android SQLite 原生库：

- `arm64-v8a`
- `armeabi-v7a`
- `x86`
- `x86_64`

由于 Flutter 不支持构建正式发布版本的 `x86` 32 位设备应用（详见 [此处](https://docs.flutter.cn/deployment/android#what-are-the-supported-target-architectures) ），您可以在 `build.gradle` 通过 [`abiFilters`](https://developer.android.google.cn/ndk/guides/abis?hl=zh-cn#gc) 限制支持的架构以缩减应用大小：

```gradle
android {
    defaultConfig {
        ndk {
            abiFilters 'armeabi-v7a', 'arm64-v8a', 'x86_64'
        }
    }
}
```

### Android 6 加载原生库问题

在 Android 6 上加载原生库时似乎存在问题（参见 [此问题](https://github.com/simolus3/moor/issues/895#issuecomment-720195005) ） 。如果您也遇到此类崩溃，可以尝试在 `gradle.properties` 中配置 `android.bundle.enableUncompressedNativeLibs=false` 。这应该能解决此类崩溃，但会增加应用的安装大小。

此外，您也可以调用本库的 `applyWorkaroundToOpenSqlite3OnOldAndroidVersions()` 方法。它会尝试在 Java 中加载 SQLite 原生库，应该是更可靠的方法。待 Java 中的 SQLite 就绪后，我们也就能够在 Dart 中打开它。

该方法需要在使用 `sqlite3` 之前（无论是直接使用，还是通过 [`drift`](https://github.com/simolus3/drift) 等间接使用）调用。

由于通过平台通道（Platform Channel）调用了 Android 原生代码，在后台隔离（Background Isolate）中调用该方法可能会存在问题，因此推荐在主隔离（Main Isolate）中，并在生成用于数据库的后台隔离**之前**，通过 `await applyWorkaroundToOpenSqlite3OnOldAndroidVersions()` 的方式调用。

### 提供临时路径

如果您使用了较为复杂的查询，可能会遇到 `SQLITE_IOERR_GETTEMPPATH 6410` 错误。此时可以通过显式设置 `sqlite3` 使用的临时路径尝试解决，详见 [此评论](https://github.com/simolus3/moor/issues/876#issuecomment-710013503) 。