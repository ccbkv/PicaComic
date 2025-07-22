> 模板版本: v0.0.1

<p align="center">
  <h1 align="center"> <code>share_plus</code> </h1>
</p>

本项目基于 [share_plus](https://pub.dev/packages/share_plus) 开发。

## 1. 安装与使用

### 1.1 安装方式

进入到工程目录并在 pubspec.yaml 中添加以下依赖：

<!-- tabs:start -->

#### pubspec.yaml

```yaml
...

dependencies:
  share_plus:
    git: 
      url: https://gitcode.com/openharmony-sig/flutter_plus_plugins.git
      path: packages/share_plus/share_plus
      ref: br_share_plus-v10.1.1_ohos

...
```

执行命令

```bash
flutter pub get
```

<!-- tabs:end -->

### 1.2 使用案例

使用案例详见 [example](example/lib/main.dart)

## 2. 约束与限制

### 2.1 兼容性

在以下版本中已测试通过

1. Flutter: 3.22.1-ohos-1.0.1; SDK: 5.0.0(12); IDE: DevEco Studio: 5.0.13.200; ROM: 5.1.0.120 SP3;


## 3. API

> [!TIP] "ohos Support"列为 yes 表示 ohos 平台支持该属性；no 则表示不支持；partially 表示部分支持。使用方法跨平台一致，效果对标 iOS 或 Android 的效果。

### Share API 
| Name                | Description                         | Type     | Input | Output  | ohos Support |
|---------------------|-------------------------------------|----------|-------|---------|--------------|
| shareUri            | 调用平台分享面板以分享URI | function | (Uri uri, {Rect? sharePositionOrigin}) | Future<ShareResult> | yes |
| share               | 调用平台分享面板以分享文本（可选主题/位置） | function | (String text, {String? subject, Rect? sharePositionOrigin}) | Future<ShareResult> | yes |
| shareXFiles         | 支持MIME类型处理分享多个文件 | function | (List<XFile> files, {String? subject, String? text, Rect? sharePositionOrigin, List<String>? fileNameOverrides}) | Future<ShareResult> | yes |

---

## 4. 属性

> [!TIP] "ohos Support"列为 yes 表示 ohos 平台支持该属性；no 则表示不支持；partially 表示部分支持。使用方法跨平台一致，效果对标 iOS 或 Android 的效果。

### ShareResult Filters 
| Name                | Description                         | Type     | Input | Output  | ohos Support |
|---------------------|-------------------------------------|----------|-------|---------|--------------|
| raw                 | 原始平台返回值（空字符串=用户取消分享，特殊值=功能不可用） | String | / | / | yes |
| status              | 枚举指示用户操作（成功/取消/不可用） | ShareResultStatus | / | / | yes |

---

### ShareResultStatus Filters 
| Name                | Description                         | Type     | Input | Output  | ohos Support |
|---------------------|-------------------------------------|----------|-------|---------|--------------|
| success             | 用户选择了某个分享动作 | enum | / | / | yes |
| dismissed           | 用户取消了分享操作 | enum | / | / | yes |
| unavailable         | 状态无法确定（平台不支持） | enum | / | / | yes |

---

## 5. 遗留问题

## 6. 其他

## 7. 开源协议

本项目基于 [The BSD-3-Clause (license)](LICENSE) ，请自由地享受和参与开源。
