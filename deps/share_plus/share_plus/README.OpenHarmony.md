> Template version: v0.0.1

<p align="center">
  <h1 align="center"> <code>share_plus</code> </h1>
</p>

This project is based on [share_plus](https://pub.dev/packages/share_plus).

## 1. Installation and Usage

### 1.1 Installation

Go to the project directory and add the following dependencies in pubspec.yaml

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

Execute Command

```bash
flutter pub get
```

<!-- tabs:end -->

### 1.2 Usage

For use cases [example](example/lib/main.dart)

## 2. Constraints

### 2.1 Compatibility

This document is verified based on the following versions:

1. Flutter: 3.22.1-ohos-1.0.1; SDK: 5.0.0(12); IDE: DevEco Studio: 5.0.13.200; ROM: 5.1.0.120 SP3;


## 3. API

> [!TIP] If the value of **ohos Support** is **yes**, it means that the ohos platform supports this property; **no** means the opposite; **partially** means some capabilities of this property are supported. The usage method is the same on different platforms and the effect is the same as that of iOS or Android.

### Share API 
| Name                | Description                         | Type     | Input | Output  | ohos Support |
|---------------------|-------------------------------------|----------|-------|---------|--------------|
| shareUri            | Shares a URI using platform share sheet | function | (Uri uri, {Rect? sharePositionOrigin}) | Future<ShareResult> | yes |
| share               | Shares text with optional subject/position | function | (String text, {String? subject, Rect? sharePositionOrigin}) | Future<ShareResult> | yes |
| shareXFiles         | Shares multiple files with MIME type handling | function | (List<XFile> files, {String? subject, String? text, Rect? sharePositionOrigin, List<String>? fileNameOverrides}) | Future<ShareResult> | yes |

---

## 4. Properties

> [!TIP] If the value of **ohos Support** is **yes**, it means that the ohos platform supports this property; **no** means the opposite; **partially** means some capabilities of this property are supported. The usage method is the same on different platforms and the effect is the same as that of iOS or Android.

### ShareResult Filters 
| Name                | Description                         | Type     | Input | Output  | ohos Support |
|---------------------|-------------------------------------|----------|-------|---------|--------------|
| raw                 | Raw platform return value (empty=dismissed, special value=unavailable) | String | / | / | yes |
| status              | Enum indicating user action (success/dismissed/unavailable) | ShareResultStatus | / | / | yes |

---

### ShareResultStatus Filters 
| Name                | Description                         | Type     | Input | Output  | ohos Support |
|---------------------|-------------------------------------|----------|-------|---------|--------------|
| success             | User selected an action             | enum | / | / | yes |
| dismissed           | User dismissed the share sheet      | enum | / | / | yes |
| unavailable         | Status determination not supported  | enum | / | / | yes |

---

## 5. Known Issues

## 6. Others

## 7. License

This project is licensed under [The BSD-3-Clause (license)](LICENSE).
