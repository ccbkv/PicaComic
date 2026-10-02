import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/utils/extensions.dart';
import 'package:pica_comic/utils/io_tools.dart';
import 'package:pica_comic/utils/translations.dart';
import 'package:webdav_client/webdav_client.dart';

import '../base.dart';

Future<bool> _retryZone(Future<bool> Function() fn) async {
  int time = 1;
  while (time < 1 << 3) {
    var res = await fn();
    if (res) {
      return true;
    }
    await Future.delayed(Duration(seconds: time));
    time *= 2;
  }
  return false;
}

class Webdav {
  static bool _isOperating = false;

  static bool _haveWaitingTask = false;

  /// Human-readable reason for the most recent sync failure, shown to the user.
  static String? lastError;

  /// Sync current data to webdav server. Return true if success.
  static Future<bool> uploadData([String? config]) async {
    if (_haveWaitingTask) {
      return true;
    }
    if (_isOperating) {
      _haveWaitingTask = true;
      while (_isOperating) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    _haveWaitingTask = false;
    _isOperating = true;
    try {
      return await _uploadInternal(config);
    } finally {
      _isOperating = false;
    }
  }

  /// 执行上传（不处理并发锁），供 [uploadData] 和下载后的自动回传复用。
  static Future<bool> _uploadInternal(String? config) async {
    lastError = null;
    appdata.settings[46] =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    appdata.updateSettings(false);
    config ??= appdata.settings[45];
    var configs = _parseConfig(config);
    if (configs == null) {
      // Not configured / disabled: this is not an error.
      return true;
    }
    LogManager.addLog(LogLevel.info, "network", "Uploading Data");
    var client = newClient(
      configs[0],
      user: configs[1],
      password: configs[2],
      debug: false,
    );
    client.setHeaders({'content-type': 'text/plain'});
    client.setConnectTimeout(15000);
    try {
      var files = await client.readDir(configs[3]);
      for (var file in files) {
        var name = file.name;
        if (name != null) {
          var version = name.split(".").first;
          if (version.isNum) {
            var days = int.parse(version) ~/ 86400;
            var currentDays =
                DateTime.now().millisecondsSinceEpoch ~/ 1000 ~/ 86400;
            if (currentDays == days && file.path != null) {
              client.remove(file.path!);
              break;
            }
          }
        }
      }
      await client.writeFromFile(await exportDataToFile(false, "${App.cachePath}/userdata.picadata"),
          "${configs[3]}${appdata.settings[46]}.picadata");
    } catch (e, s) {
      lastError = _describeError(e, stage: "上传");
      LogManager.addLog(LogLevel.error, "Sync",
          "Failed to upload data to webdav server.\n$e\n$s");
      return false;
    }
    return true;
  }

  /// Parse the webdav config string `url;user;password;path`.
  ///
  /// Returns null when sync is not configured / disabled. Also tolerates the
  /// legacy "disabled" form that had a trailing ";0" appended.
  static List<String>? _parseConfig(String config) {
    var configs = config.split(';');
    if (configs.length < 4) return null;
    if (configs.elementAtOrNull(0) == "") return null;
    // Take the first 4 segments, ignoring any trailing marker.
    var result = configs.sublist(0, 4);
    // Normalize: trim whitespace and ensure the path ends with a separator.
    result[0] = result[0].trim();
    result[3] = result[3].trim();
    if (result[3].isEmpty) {
      result[3] = "/";
    }
    if (!result[3].endsWith('/') && !result[3].endsWith('\\')) {
      result[3] += '/';
    }
    return result;
  }

  /// Turn a low-level exception into something a user can act on.
  static String _describeError(Object e, {required String stage}) {
    var s = e.toString();
    if (s.contains('Timeout') || s.contains('timeout')) {
      return "$stage超时：无法连接到 WebDAV 服务器，请确认地址可访问（外网需组网或端口映射）";
    }
    if (s.contains('404')) {
      return "$stage失败：服务器返回 404，储存路径不存在或拼写错误";
    }
    if (s.contains('401') || s.contains('403')) {
      return "$stage失败：认证被拒绝，请检查用户名/密码";
    }
    if (s.contains('SocketException') || s.contains('Connection')) {
      return "$stage失败：无法建立连接，请检查网络与地址";
    }
    return "$stage失败：$s";
  }

  static Future<bool> downloadData([String? config]) async {
    _isOperating = true;
    bool force = config != null;
    lastError = null;
    try {
      config ??= appdata.settings[45];
      var configs = _parseConfig(config);
      if (configs == null) {
        return true;
      }
      LogManager.addLog(LogLevel.info, "network", "Downloading Data");
      var client = newClient(
        configs[0],
        user: configs[1],
        password: configs[2],
        debug: false,
      );
      client.setConnectTimeout(15000);
      try {
        var files = await client.readDir(configs[3]);
        int? maxVersion;
        for (var file in files) {
          var name = file.name;
          if (name != null) {
            var version = name.split(".").first;
            if (version.isNum) {
              maxVersion = max(maxVersion ?? 0, int.parse(version));
            }
          }
        }

        if (maxVersion == null) {
          lastError = "服务器上没有找到任何备份文件，请先在上传端执行一次上传";
          LogManager.addLog(LogLevel.error, "Sync",
              "No backup file found on webdav server.");
          return false;
        }

        // Only skip when this is an automatic (non-forced) sync AND we already
        // have exactly this version. A manual download always proceeds.
        if (!force && maxVersion.toString() == appdata.settings[46]) {
          LogManager.addLog(LogLevel.info, "Sync",
              "No updated version of data.\nStop downloading data.");
          return true;
        }

        final fileName = "$maxVersion.picadata";

        var cachePath = (await getApplicationCacheDirectory()).path;
        await client.read2File(
            "${configs[3]}$fileName", "$cachePath/picadata");
        // Force import: a manual download must never be silently skipped by the
        // internal settings[46] version comparison.
        var res = await importData("$cachePath/picadata", true);
        if (!res) {
          lastError = lastImportError ?? "导入备份数据失败";
          return false;
        }
        // 若本次下载把备份里"本机没有"的收藏合并了进来，说明本机现在是
        // 超集。此时必须把合并结果回传服务器，否则其它设备下次同步时，
        // 会因为服务器上仍是旧备份而再次"看不到"这些收藏。
        if (lastImportMergedSomething) {
          LogManager.addLog(LogLevel.info, "Sync",
              "Merged new data from server, pushing merged result back.");
          try {
            // 注意：downloadData 当前已持有 _isOperating，必须用内部方法，
            // 否则 uploadData 会在锁上等待自己而死锁。
            await _uploadInternal(config);
          } catch (e, s) {
            // 回传失败不影响本次下载结果，仅记录日志。
            LogManager.addLog(LogLevel.error, "Sync",
                "Failed to push merged data back.\n$e\n$s");
          }
        }
        return true;
      } catch (e, s) {
        lastError = _describeError(e, stage: "下载");
        LogManager.addLog(LogLevel.error, "Sync",
            "Failed to download data from webdav server.\n$e\n$s");
        return false;
      }
    } finally {
      _isOperating = false;
    }
  }

  static void syncData() async {
    var configs = _parseConfig(appdata.settings[45]);
    if (configs == null) {
      return;
    }
    var controller = showLoadingDialog(
      App.globalContext!,
      barrierDismissible: false,
      allowCancel: true,
      message: "同步数据中".tl,
      cancelButtonText: "隐藏".tl,
    );
    var res = await _retryZone(Webdav.downloadData);
    await Future.delayed(const Duration(milliseconds: 50));
    controller.close();
    if (!res) {
      // Do NOT corrupt the stored config (old code appended ";" markers which
      // permanently broke sync). Just report and offer a retry.
      showToast(
        message: (lastError ?? "下载数据失败").tl,
        trailing: Button.icon(
          onPressed: () => syncData(),
          icon: const Icon(Icons.refresh),
        ),
      );
    }
  }
}
