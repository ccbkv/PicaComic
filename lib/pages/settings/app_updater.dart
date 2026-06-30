import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pica_comic/bean/dialog/dialog_helper.dart';
import 'package:pica_comic/request/clients/download_http_client.dart';
import 'package:pica_comic/request/config/api_endpoints.dart';
import 'package:pica_comic/services/logging/logger.dart';
import 'package:pica_comic/base.dart';
import 'package:pica_comic/components/components.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pica_comic/utils/device.dart';
import 'package:pica_comic/utils/date_time.dart';
import 'package:pica_comic/utils/crypto.dart';
import 'package:pica_comic/utils/version.dart';

/// 安装类型枚举
enum InstallationType {
  windowsMsix, // Kazumi_windows_1.7.5.msix
  windowsPortable, // Kazumi_windows_1.7.5.zip
  linuxDeb, // Kazumi_linux_1.7.5_amd64.deb
  linuxTar, // Kazumi_linux_1.7.5_amd64.tar.gz
  macosDmg, // Kazumi_macos_1.7.5.dmg
  androidApk, // Kazumi_android_1.7.5.apk
  ios, // iOS App
  //ohos, // Kazumi_ohos_1.7.5_unsigned.hap
  unknown,
}

/// 更新信息类
class UpdateInfo {
  final String version;
  final String description;
  final String downloadUrl;
  final String releaseNotes;
  final String publishedAt;
  final InstallationType? installationType;
  final List<InstallationType> availableInstallationTypes;
  final List<dynamic> assets;

  UpdateInfo({
    required this.version,
    required this.description,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.publishedAt,
    this.installationType,
    this.availableInstallationTypes = const [],
    this.assets = const [],
  });

  /// 获取默认的安装类型（第一个可用类型）
  InstallationType get recommendedInstallationType {
    if (availableInstallationTypes.isNotEmpty) {
      return availableInstallationTypes.first;
    }
    return installationType ?? InstallationType.unknown;
  }
}

Map<String, dynamic>? getUpdateAssetForType(
    List<dynamic> assets, InstallationType type) {
  Map<String, dynamic>? bestAsset;
  var bestScore = -1;

  for (final rawAsset in assets) {
    if (rawAsset is! Map) {
      continue;
    }

    final asset = Map<String, dynamic>.from(rawAsset);
    final score = getUpdateAssetMatchScore(asset, type);
    if (score > bestScore) {
      bestScore = score;
      bestAsset = asset;
    }
  }

  return bestScore >= 0 ? bestAsset : null;
}

List<Map<String, dynamic>> getUpdateAssetsForType(
    List<dynamic> assets, InstallationType type) {
  final matched = <Map<String, dynamic>>[];

  for (final rawAsset in assets) {
    if (rawAsset is! Map) {
      continue;
    }

    final asset = Map<String, dynamic>.from(rawAsset);
    if (getUpdateAssetMatchScore(asset, type) >= 0) {
      matched.add(asset);
    }
  }

  matched.sort((a, b) =>
      getUpdateAssetMatchScore(b, type).compareTo(getUpdateAssetMatchScore(a, type)));
  return matched;
}

String getUpdateDownloadUrlFromAsset(Map<String, dynamic>? asset) {
  if (asset == null) {
    return '';
  }
  final mirrorUrl = asset['mirror_download_url'] as String? ?? '';
  if (mirrorUrl.isNotEmpty) {
    return mirrorUrl;
  }
  return asset['browser_download_url'] as String? ?? '';
}

String getUpdateFileHashFromAsset(Map<String, dynamic> asset) {
  final digest = asset['digest'] as String? ?? '';
  if (digest.isNotEmpty && digest.startsWith('sha256:')) {
    return digest.substring(7);
  }
  return '';
}

int getUpdateAssetMatchScore(
    Map<String, dynamic> asset, InstallationType installationType) {
  final name = ((asset['name'] as String?) ?? '').toLowerCase();
  final contentType = ((asset['content_type'] as String?) ?? '').toLowerCase();

  switch (installationType) {
    case InstallationType.windowsMsix:
      if (!name.endsWith('.msix')) {
        return -1;
      }
      return name.contains('windows') ? 120 : 100;
    case InstallationType.windowsPortable:
      if (!name.endsWith('.zip')) {
        return -1;
      }
      if (name.contains('windows')) {
        return 120;
      }
      return name.contains('portable') ? 110 : -1;
    case InstallationType.macosDmg:
      if (name.contains('macos') && name.endsWith('.dmg')) {
        return 130;
      }
      if (name.contains('macos') && name.endsWith('.zip')) {
        return 120;
      }
      return -1;
    case InstallationType.androidApk:
      final isApk = name.endsWith('.apk') ||
          contentType.contains('android.package-archive');
      if (!isApk) {
        return -1;
      }

      var score = 100;
      if (name.contains('arm64') || name.contains('arm64-v8a')) {
        score += 35;
      }
      if (!name.contains('arm64') &&
          !name.contains('arm64-v8a') &&
          !name.contains('x86_64') &&
          !name.contains('armeabi') &&
          !name.contains('universal') &&
          name.contains('_sign.apk')) {
        score += 20;
      }
      if (name.contains('universal')) {
        score += 10;
      }
      if (name.contains('sign')) {
        score += 5;
      }
      return score;
    case InstallationType.linuxDeb:
    case InstallationType.linuxTar:
    case InstallationType.ios:
    case InstallationType.unknown:
      return -1;
  }
}

enum AndroidApkVariant {
  universal,
  arm64,
  x86_64,
  armeabi,
  other,
}

AndroidApkVariant getAndroidApkVariant(Map<String, dynamic> asset) {
  final name = ((asset['name'] as String?) ?? '').toLowerCase();

  if (name.contains('x86_64')) {
    return AndroidApkVariant.x86_64;
  }
  if (name.contains('arm64') || name.contains('arm64-v8a')) {
    return AndroidApkVariant.arm64;
  }
  if (name.contains('armeabi')) {
    return AndroidApkVariant.armeabi;
  }
  if (name.contains('universal') || name.endsWith('_sign.apk')) {
    return AndroidApkVariant.universal;
  }
  return AndroidApkVariant.other;
}

String getAndroidApkVariantLabel(AndroidApkVariant variant) {
  switch (variant) {
    case AndroidApkVariant.universal:
      return '通用包';
    case AndroidApkVariant.arm64:
      return 'arm64';
    case AndroidApkVariant.x86_64:
      return 'x86_64';
    case AndroidApkVariant.armeabi:
      return 'armeabi-v7a';
    case AndroidApkVariant.other:
      return '其他 APK';
  }
}

String getAndroidApkVariantDescription(Map<String, dynamic> asset) {
  switch (getAndroidApkVariant(asset)) {
    case AndroidApkVariant.universal:
      return '兼容大多数 Android 设备';
    case AndroidApkVariant.arm64:
      return '适用于大多数 64 位 ARM 手机';
    case AndroidApkVariant.x86_64:
      return '适用于 x86_64 模拟器或少数设备';
    case AndroidApkVariant.armeabi:
      return '适用于部分 32 位 ARM 设备';
    case AndroidApkVariant.other:
      return (asset['name'] as String?) ?? '未知 APK';
  }
}

List<Map<String, dynamic>> getPreferredAndroidApkAssets(List<dynamic> assets) {
  final candidates = getUpdateAssetsForType(assets, InstallationType.androidApk);
  final grouped = <AndroidApkVariant, Map<String, dynamic>>{};

  for (final asset in candidates) {
    final variant = getAndroidApkVariant(asset);
    final current = grouped[variant];
    if (current == null ||
        getUpdateAssetMatchScore(asset, InstallationType.androidApk) >
            getUpdateAssetMatchScore(current, InstallationType.androidApk)) {
      grouped[variant] = asset;
    }
  }

  const order = [
    AndroidApkVariant.arm64,
    AndroidApkVariant.universal,
    AndroidApkVariant.x86_64,
    AndroidApkVariant.armeabi,
    AndroidApkVariant.other,
  ];

  return [
    for (final variant in order)
      if (grouped[variant] != null) grouped[variant]!,
  ];
}

class AutoUpdater {
  static final AutoUpdater _instance = AutoUpdater._internal();
  static const Duration _autoReminderInterval = Duration(hours: 12);

  factory AutoUpdater() => _instance;

  AutoUpdater._internal();

  final DownloadHttpClient _downloadClient = DownloadHttpClient.instance;

  /// 检测所有可能的安装类型
  Future<List<InstallationType>> _detectAvailableInstallationTypes() async {
    List<InstallationType> availableTypes = [];

    try {
      if (Platform.isWindows) {
        // Windows 平台支持 MSIX 和 ZIP 便携版
        availableTypes.add(InstallationType.windowsMsix);
        availableTypes.add(InstallationType.windowsPortable);
      } else if (Platform.isLinux) {
        // Linux 平台支持 DEB 和 TAR.GZ
        availableTypes.add(InstallationType.linuxDeb);
        availableTypes.add(InstallationType.linuxTar);
      } else if (Platform.isMacOS) {
        // macOS 平台支持 DMG
        availableTypes.add(InstallationType.macosDmg);
      } else if (Platform.isIOS) {
        // iOS 平台通过 Github
        availableTypes.add(InstallationType.ios);
      } else if (Platform.isAndroid) {
        // Android 平台支持 APK
        availableTypes.add(InstallationType.androidApk);
      //} else if (Platform.isOhos) {
        //// ohos 平台支持 hap
        //availableTypes.add(InstallationType.ohos);
      }
    } catch (e) {
      KazumiLogger().w('Update: detect installation types failed', error: e);
    }

    if (availableTypes.isEmpty) {
      availableTypes.add(InstallationType.unknown);
    }

    return availableTypes;
  }

  /// 检查是否有新版本可用
  Future<UpdateInfo?> checkForUpdates() async {
    try {
      final data = await _latestRelease();

      if (!data.containsKey('tag_name')) {
        throw Exception('无效的响应数据');
      }

      final remoteVersion = data['tag_name'] as String;
      final currentVersion = appVersion;

      if (needUpdate(currentVersion, remoteVersion)) {
        final availableTypes = await _detectAvailableInstallationTypes();

        return UpdateInfo(
          version: remoteVersion,
          description: data['body'] ?? '发现新版本',
          downloadUrl: '',
          // 将在用户选择安装类型后填充
          releaseNotes: data['html_url'] ?? '',
          publishedAt: data['published_at'] ?? '',
          installationType: availableTypes.first,
          // 保持兼容性
          availableInstallationTypes: availableTypes,
          assets: data['assets'] ?? [],
        );
      }

      return null;
    } catch (e) {
      KazumiLogger().e('Update: check for updates failed', error: e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _latestRelease() async {
    final res = await _downloadClient.getPlain(ApiEndpoints.latestAppMirror);
    if (res.error) {
      throw Exception(res.errorMessageWithoutNull);
    }
    final data = json.decode(res.data);
    if (data is! Map) {
      throw Exception('Invalid update response');
    }
    return Map<String, dynamic>.from(data);
  }

  /// 自动检查更新（仅在启用自动更新时）
  Future<void> autoCheckForUpdates() async {
    if (appdata.settings[2] != "1") return;

    try {
      final lastReminder = await appdata.readLastCheckUpdate();
      if (lastReminder != null) {
        final elapsed = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(lastReminder),
        );
        if (elapsed < _autoReminderInterval) {
          return;
        }
      }

      final updateInfo = await checkForUpdates();
      if (updateInfo != null) {
        _showUpdateDialog(updateInfo, isAutoCheck: true);
      }
    } catch (e) {
      // 自动检查失败时不显示错误
      KazumiLogger().w('Update: auto check for updates failed', error: e);
    }
  }

  /// 手动检查更新
  Future<void> manualCheckForUpdates() async {
    try {
      final updateInfo = await checkForUpdates();
      if (updateInfo != null) {
        _showUpdateDialog(updateInfo, isAutoCheck: false);
      } else {
        KazumiDialog.showToast(message: '当前已经是最新版本！');
      }
    } catch (e) {
      KazumiDialog.showToast(message: '检查更新失败');
    }
  }

  /// 下载指定版本的安装包或打开对应发布页
  Future<void> downloadRelease(
      UpdateInfo updateInfo, InstallationType selectedType) async {
    await _downloadUpdateWithType(updateInfo, selectedType);
  }

  /// 显示更新对话框
  void _showUpdateDialog(UpdateInfo updateInfo, {bool isAutoCheck = false}) {
    KazumiDialog.show(
      builder: (context) {
        final dialogActions = <Widget>[
          if (isAutoCheck)
            TextButton(
              onPressed: () {
                appdata.settings[2] = "0";
                appdata.updateSettings();
                KazumiDialog.dismiss();
                KazumiDialog.showToast(message: '已关闭自动更新');
              },
              child: Text(
                '关闭自动更新',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
          TextButton(
            onPressed: () {
              appdata.writeLastCheckUpdate(
                DateTime.now().millisecondsSinceEpoch,
              );
              KazumiDialog.dismiss();
            },
            child: Text(
              '稍后提醒',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          if (updateInfo.releaseNotes.isNotEmpty)
            TextButton(
              onPressed: () {
                launchUrl(Uri.parse(updateInfo.releaseNotes),
                    mode: LaunchMode.externalApplication);
              },
              child: const Text('查看详情'),
            ),
          TextButton(
            onPressed: () {
              KazumiDialog.dismiss();
              // 直接使用第一个可用的安装类型
              if (updateInfo.availableInstallationTypes.isNotEmpty) {
                _downloadUpdateWithType(
                    updateInfo, updateInfo.availableInstallationTypes.first);
              }
            },
            child: const Text('立即更新'),
          ),
        ];

        return AlertDialog(
          title: Text('发现新版本 ${updateInfo.version}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(updateInfo.description),
                if (updateInfo.publishedAt.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '发布时间: ${formatDate(updateInfo.publishedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 8),
                if (!Platform.isLinux && !Platform.isIOS) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '选择安装类型:',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 8),
                        ...updateInfo.availableInstallationTypes.map((type) {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(4),
                                onTap: () {
                                  KazumiDialog.dismiss();
                                  _downloadUpdateWithType(updateInfo, type);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline
                                          .withValues(alpha: 0.3),
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.download,
                                        size: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _getInstallationTypeDescription(type),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < dialogActions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      dialogActions[i],
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 获取安装类型的描述
  String _getInstallationTypeDescription(InstallationType type) {
    switch (type) {
      case InstallationType.windowsMsix:
        return 'Windows MSIX 包';
      case InstallationType.windowsPortable:
        return 'Windows 便携版 (ZIP)';
      case InstallationType.linuxDeb:
        return 'Linux DEB 包';
      case InstallationType.linuxTar:
        return 'Linux TAR 包';
      case InstallationType.macosDmg:
        return 'macOS DMG 镜像';
      case InstallationType.androidApk:
        return 'Android APK';
      case InstallationType.ios:
        return 'iOS ipa';
      //case InstallationType.ohos:
        //return 'ohos hap';
      case InstallationType.unknown:
        return '未知安装类型';
    }
  }

  Future<Map<String, dynamic>?> _selectAndroidApkAsset(
      List<dynamic> assets) async {
    final apkAssets = getPreferredAndroidApkAssets(assets);
    if (apkAssets.isEmpty) {
      return null;
    }
    if (apkAssets.length == 1) {
      return apkAssets.first;
    }

    return KazumiDialog.show<Map<String, dynamic>>(
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('选择 Android APK'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '请选择要下载的安装包:',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                ...apkAssets.map((asset) {
                  final variant = getAndroidApkVariant(asset);
                  final isRecommended = variant == AndroidApkVariant.arm64;
                  final fileName = (asset['name'] as String?) ?? '';
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () {
                          KazumiDialog.dismiss(popWith: asset);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.outline
                                  .withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.android,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          getAndroidApkVariantLabel(variant),
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                        if (isRecommended) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            '推荐',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      getAndroidApkVariantDescription(asset),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    if (fileName.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        fileName,
                                        style: theme.textTheme.labelSmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 12,
                                color: theme.colorScheme.outline,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => KazumiDialog.dismiss(),
              child: Text(
                '取消',
                style: TextStyle(color: theme.colorScheme.outline),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 根据选择的类型下载更新
  Future<void> _downloadUpdateWithType(
      UpdateInfo updateInfo, InstallationType selectedType) async {
    try {
      // iOS 和 Linux 直接跳转到 Release 页面
      if (selectedType == InstallationType.ios ||
          selectedType == InstallationType.linuxDeb ||
          selectedType == InstallationType.linuxTar) {
        String releaseUrl = updateInfo.releaseNotes;
        if (releaseUrl.isEmpty) {
          releaseUrl = ApiEndpoints.latestApp;
        }
        launchUrl(Uri.parse(releaseUrl), mode: LaunchMode.externalApplication);
        return;
      }

      final asset = selectedType == InstallationType.androidApk
          ? await _selectAndroidApkAsset(updateInfo.assets)
          : getUpdateAssetForType(updateInfo.assets, selectedType);
      if (selectedType == InstallationType.androidApk && asset == null) {
        return;
      }
      final downloadUrl = getUpdateDownloadUrlFromAsset(asset);
      if (asset == null || downloadUrl.isEmpty) {
        KazumiDialog.showToast(
            message:
                '没有找到 ${_getInstallationTypeDescription(selectedType)} 的下载链接');
        return;
      }

      final expectedHash = getUpdateFileHashFromAsset(asset);

      // 创建一个临时的 UpdateInfo 对象用于下载
      final downloadInfo = UpdateInfo(
        version: updateInfo.version,
        description: updateInfo.description,
        downloadUrl: downloadUrl,
        releaseNotes: updateInfo.releaseNotes,
        publishedAt: updateInfo.publishedAt,
        installationType: selectedType,
        availableInstallationTypes: [selectedType],
        assets: updateInfo.assets,
      );

      _downloadUpdate(downloadInfo, expectedHash);
    } catch (e) {
      KazumiDialog.showToast(message: '下载失败: ${e.toString()}');
      KazumiLogger().e('Update: download update failed', error: e);
    }
  }

  /// 下载更新
  Future<void> _downloadUpdate(
      UpdateInfo updateInfo, String expectedHash) async {
    if (updateInfo.downloadUrl.isEmpty) {
      KazumiDialog.showToast(message: '没有找到合适的下载链接');
      return;
    }

    // 显示下载进度对话框
    KazumiDialog.show(
      clickMaskDismiss: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('正在下载更新'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<double>(
                valueListenable: _downloadProgress,
                builder: (context, value, child) {
                  return Column(
                    children: [
                      LinearProgressIndicator(value: value),
                      const SizedBox(height: 8),
                      Text('${(value * 100).toStringAsFixed(1)}%'),
                    ],
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _cancelDownload();
                KazumiDialog.dismiss();
              },
              child: const Text('取消'),
            ),
          ],
        );
      },
    );

    try {
      final downloadPath = await _downloadFile(
          updateInfo.downloadUrl, updateInfo.version, expectedHash);

      // 不自动关闭对话框，而是显示下载完成状态
      _showDownloadCompleteDialog(downloadPath, updateInfo);
    } catch (e) {
      KazumiDialog.dismiss();

      // 显示详细的错误信息
      String errorMessage = '下载失败';
      if (e.toString().contains('Permission denied') ||
          e.toString().contains('Operation not permitted')) {
        errorMessage = '权限不足，文件已保存到应用临时目录';
      } else if (e.toString().contains('No space left')) {
        errorMessage = '磁盘空间不足';
      } else if (e.toString().contains('Network')) {
        errorMessage = '网络连接错误';
      } else if (e.toString().contains('文件完整性验证失败')) {
        errorMessage = '文件完整性验证失败，可能是网络传输错误';
      }

      KazumiDialog.show(
        builder: (context) {
          return AlertDialog(
            title: const Text('下载失败'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorMessage),
                const SizedBox(height: 8),
                Text(
                  '错误详情: ${e.toString()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => KazumiDialog.dismiss(),
                child: const Text('确定'),
              ),
              TextButton(
                onPressed: () {
                  KazumiDialog.dismiss();
                  // 重新尝试下载
                  _downloadUpdate(updateInfo, expectedHash);
                },
                child: const Text('重试'),
              ),
            ],
          );
        },
      );

      KazumiLogger().e('Update: download update failed', error: e);
    }
  }

  final ValueNotifier<double> _downloadProgress = ValueNotifier(0.0);
  CancelToken? _cancelToken;

  void _cancelDownload() {
    _cancelToken?.cancel();
  }

  /// 显示下载完成对话框
  void _showDownloadCompleteDialog(String filePath, UpdateInfo updateInfo) {
    // 替换当前的下载进度对话框内容
    KazumiDialog.dismiss();

    KazumiDialog.show(
      builder: (context) {
        return AlertDialog(
          title: const Text('下载完成'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('新版本 ${updateInfo.version} 已下载完成'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '安装过程中应用将会退出',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '文件位置:',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 4),
                    NonScrollableSelectableText(
                      filePath,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => KazumiDialog.dismiss(),
              child: Text(
                '稍后安装',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            if (isDesktop())
              TextButton(
                onPressed: () {
                  // 在文件管理器中显示文件
                  _revealInFileManager(filePath);
                },
                child: const Text('打开文件夹'),
              ),
            TextButton(
              onPressed: () {
                KazumiDialog.dismiss();
                _installUpdate(
                    filePath, updateInfo.recommendedInstallationType);
              },
              child: const Text('立即安装'),
            ),
          ],
        );
      },
    );
  }

  /// 下载文件
  Future<String> _downloadFile(
      String url, String version, String expectedHash) async {
    final fileName = _getFileNameFromUrl(url, version);

    // 统一使用临时目录
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/$fileName';
    final file = File(filePath);

    // 检查文件是否已存在
    if (await file.exists()) {
      try {
        //使用哈希验证文件完整性
        final localHash = await calculateFileHash(file);
        if (localHash == expectedHash) {
          // 文件已存在且哈希匹配，直接返回
          KazumiLogger().i(
              'Update: file already exists and hash verified, skipping download: $filePath');
          _downloadProgress.value = 1.0;
          return filePath;
        } else {
          // 文件存在但哈希不匹配，删除后重新下载
          KazumiLogger().i(
              'Update: file hash mismatch detected (local: $localHash, expected: $expectedHash), deleting and re-downloading');
          await file.delete();
        }
      } catch (e) {
        // 验证过程中出错，删除文件重新下载
        KazumiLogger().w(
            'Update: file verification failed, deleting and re-downloading',
            error: e);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }

    _cancelToken = CancelToken();

    final downloadRes = await _downloadClient.download(
      url,
      filePath,
      cancelToken: _cancelToken,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          _downloadProgress.value = received / total;
        }
      },
    );
    if (downloadRes.error) {
      throw Exception(downloadRes.errorMessageWithoutNull);
    }

    // 下载完成后验证文件哈希
    final downloadedHash = await calculateFileHash(file);
    if (downloadedHash != expectedHash) {
      // 哈希不匹配，删除文件并抛出异常
      await file.delete();
      throw Exception('文件完整性验证失败: 期望 $expectedHash，实际 $downloadedHash');
    }
    KazumiLogger().i('Update: file downloaded and hash verified: $filePath');

    return filePath;
  }

  /// 安装更新
  void _installUpdate(
      String filePath, InstallationType installationType) async {
    try {
      // 显示准备退出的提示
      KazumiDialog.showToast(message: '准备安装更新，应用即将退出...');

      await Future.delayed(const Duration(seconds: 2));

      if (Platform.isWindows) {
        if (installationType == InstallationType.windowsMsix) {
          final Uri fileUri = Uri.file(filePath);
          if (await canLaunchUrl(fileUri)) {
            await launchUrl(fileUri);
          } else {
            throw 'Could not launch $fileUri';
          }
        } else {
          await Process.start('explorer.exe', [filePath], runInShell: true);
        }
        await Future.delayed(const Duration(seconds: 1));
        exit(0);
      } else if (Platform.isMacOS) {
        if (filePath.endsWith('.dmg')) {
          await Process.start('open', [filePath]);
          exit(0);
        }
      } else if (Platform.isAndroid) {
        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done) {
          KazumiDialog.showToast(message: '无法打开安装文件: ${result.message}');
          return;
      //  }
      //} else if (Platform.isOhos) {
       // const platform = MethodChannel('com.predidit.kazumi/intent');
       // try {
          //await platform.invokeMethod(
             // 'openWithInstaller', <String, String>{'path': filePath});
      //  } on PlatformException catch (e) {
         // KazumiDialog.showToast(message: '无法打开安装文件: ${e.message}');
        }
      }
    } catch (e) {
      KazumiDialog.showToast(message: '启动安装程序失败: ${e.toString()}');
      KazumiLogger().e('Update: launch installer failed', error: e);
    }
  }

  /// 在文件管理器中显示文件
  void _revealInFileManager(String filePath) async {
    try {
      final type = await FileSystemEntity.type(filePath);
      String targetDirOrFile;

      // 如果传入的本来就是目录则打开这个目录
      // 如果是文件则打开包含它的目录
      if (type == FileSystemEntityType.notFound) {
        KazumiDialog.showToast(message: '文件或目录不存在');
        return;
      } else if (type == FileSystemEntityType.directory) {
        targetDirOrFile = filePath;
      } else {
        targetDirOrFile = File(filePath).parent.path;
      }

      if (Platform.isWindows) {
        if (type == FileSystemEntityType.file) {
          final arg = '/select,${filePath.replaceAll('/', r'\')}';
          await Process.start('explorer.exe', [arg], runInShell: true);
        } else {
          await Process.start(
              'explorer.exe', [targetDirOrFile.replaceAll('/', r'\')],
              runInShell: true);
        }
      } else if (Platform.isMacOS) {
        if (type == FileSystemEntityType.file) {
          await Process.start('open', ['-R', filePath]);
        } else {
          await Process.start('open', [targetDirOrFile]);
        }
      } else if (Platform.isLinux) {
        // 尝试打开包含文件的文件夹
        await Process.start('xdg-open', [targetDirOrFile]);
      } else {
        KazumiDialog.showToast(message: '此平台不支持通过此方法打开文件管理器');
      }
    } catch (e) {
      KazumiDialog.showToast(message: '无法打开文件管理器');
      KazumiLogger().w('Update: reveal in file manager failed', error: e);
    } finally {
      try {
        // 确保对话框被关闭
        KazumiDialog.dismiss();
      } catch (_) {}
    }
  }

  /// 从URL获取文件名
  String _getFileNameFromUrl(String url, String version) {
    final uri = Uri.parse(url);
    final fileName = uri.pathSegments.last;

    if (fileName.isNotEmpty) {
      return fileName;
    }

    // 回退方案
    String extension = '';
    if (Platform.isWindows) {
      extension = '.msix';
    } else if (Platform.isMacOS) {
      extension = '.dmg';
    } else if (Platform.isLinux) {
      extension = '.deb';
    } else if (Platform.isAndroid) {
      extension = '.apk';
    //} else if (Platform.isOhos) {
      //extension = '.hap';
    }
    return 'Kazumi-$version$extension';
  }
}
