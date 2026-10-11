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

/// 创建一个 WebDAV 客户端，并**一开始就使用 Basic 认证**。
///
/// 背景（这是本项目 WebDAV 同步屡屡失败的根本原因）：
/// `webdav_client` 的 `newClient()` 会把认证状态初始化为 `AuthType.NoAuth`，
/// 其 `authorize()` 返回 null，因此**第一个请求不带 `authorization` 头**。
/// 服务器只能回 401，客户端收到 401 后才切换成 `BasicAuth` 重试。
///
/// 对大多数 WebDAV 服务这只是多一个来回；但 OpenList / AList 这类服务会按
/// 客户端 IP 统计"认证失败"次数，超过阈值（默认 5 次）就返回 429 并把该 IP
/// 锁定一段时间（默认 5 分钟）。而 `OPTIONS` 以外的每个请求都会先白送一次
/// 401，于是**每同步一次就必然消耗一次失败额度**，同步几次就被锁，表现为
/// "浏览器能打开 WebDAV，App 却报 Too Many Requests"。
///
/// 解法：直接预置 `BasicAuth`，让第一个请求就带认证头，从源头不再产生 401。
/// 唯一风险是服务器只支持 Digest——那种情况下 401 后不会自动降级（库的
/// 自动切换只对 NoAuth 生效）。实践中面向 OpenList/AList/Nextcloud 等，
/// Basic 认证是普遍支持的，因此这里以 Basic 为主。
Client _newAuthedClient(String url, String user, String password) {
  return Client(
    uri: url.endsWith('/') ? url : '$url/',
    c: WdDio(debug: false),
    auth: BasicAuth(user: user, pwd: password),
    debug: false,
  );
}

/// 带指数退避的重试。
///
/// 关键约束：遇到服务器限流（429 Too Many Requests）必须立刻放弃。
/// 原因是限制通常按客户端 IP 计数并会锁定一段时间（OpenList 默认锁 5 分钟），
/// 越重试锁得越久，用户体验只会更差——这一点在真实环境里已被反复验证。
Future<bool> _retryZone(Future<bool> Function() fn) async {
  int time = 1;
  while (time < 1 << 3) {
    var res = await fn();
    if (res) {
      return true;
    }
    if (lastSyncErrorWasRateLimit) {
      // 已经被限流，继续重试只会延长锁定期。
      return false;
    }
    await Future.delayed(Duration(seconds: time));
    time *= 2;
  }
  return false;
}

/// 最近一次同步是否因服务器限流（429）而失败。
/// 由 [Webdav] 在失败时设置，供 [_retryZone] 判断是否值得继续重试。
bool lastSyncErrorWasRateLimit = false;

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
    var client = _newAuthedClient(configs[0], configs[1], configs[2]);
    client.setHeaders({'content-type': 'text/plain'});
    client.setConnectTimeout(15000);
    try {
      var files = await client.readDir(configs[3]);
      // 备份文件名是 "<unix秒>.picadata"。清理策略：
      // 只保留将要写入的新版本，其余旧备份全部删除（保留 1 个）。
      //
      // 旧实现用 `int.parse(version) ~/ 86400 == now ~/ 86400` 判断"同一天"，
      // 看似合理，实则有个致命 bug：86400 秒切分的是 **UTC 日**，而中国是
      // UTC+8，本地时间每天 08:00 才跨 UTC 日界。于是"今天 07:33 上传的备份"
      // 和"今天 13:07 上传的备份"落在不同的 UTC 日，比较失败 → 旧文件不删，
      // 服务器上就攒下一堆 .picadata。多个备份存在时，下载端会取时间戳
      // 最大的那个，虽然能选对，但目录越来越乱，也容易让用户误判。
      var newVersion = appdata.settings[46];
      // 收集所有"不是本次要写入版本"的旧备份。
      var stale = <String>[];
      for (var file in files) {
        var name = file.name;
        if (name == null || file.path == null) continue;
        var version = name.split(".").first;
        if (!version.isNum) continue;
        if (version == newVersion) continue;
        stale.add(file.path!);
      }
      // 只保留最新的一份：把 stale 从旧到新排序后，删掉除最后一个之外的
      // 全部，最后再删掉"倒数第二个"，最终只留下一个最新的备份。
      // 这样即使某次上传中途失败，也不会出现"删了新文件却留着旧文件"。
      stale.sort((a, b) {
        var av = int.tryParse(a.split('/').last.split('.').first) ?? 0;
        var bv = int.tryParse(b.split('/').last.split('.').first) ?? 0;
        return av.compareTo(bv);
      });
      // 留最新的一个不删，其余全删。
      var toRemove = stale.length > 1 ? stale.sublist(0, stale.length - 1) : <String>[];
      for (var path in toRemove) {
        try {
          await client.remove(path);
          LogManager.addLog(LogLevel.info, "Sync", "Removed stale backup: $path");
        } catch (e) {
          // 单个旧文件删不掉不影响本次上传。
          LogManager.addLog(LogLevel.error, "Sync",
              "Failed to remove stale backup $path\n$e");
        }
      }
      await client.writeFromFile(await exportDataToFile(false, "${App.cachePath}/userdata.picadata"),
          "${configs[3]}${appdata.settings[46]}.picadata");
    } catch (e, s) {
      lastSyncErrorWasRateLimit = _isTooManyRequests(e);
      lastError = _describeError(e, stage: "上传");
      LogManager.addLog(LogLevel.error, "Sync",
          "Failed to upload data to webdav server.\n$e\n$s");
      return false;
    }
    lastSyncErrorWasRateLimit = false;
    return true;
  }

  /// OpenList 等服务器会对同一 IP 的连续认证失败做限流：超过阈值后
  /// 返回 429 并锁定 5 分钟。而 webdav_client 首次请求不带认证头
  /// （先匿名试探拿 401，再切 BasicAuth 重试），每次调用都会白送一次
  /// 失败计数。这里识别出 429，避免上层继续重试把锁定期拖长。
  static bool _isTooManyRequests(Object e) {
    var s = e.toString();
    return s.contains('429') || s.contains('Too Many Requests');
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
    if (_isTooManyRequests(e)) {
      return "$stage失败：服务器暂时拒绝了本机（429 请求过多）。"
          "常见原因是密码错误或连续重试触发了服务器的 IP 限流，通常需要等待约 5 分钟再试。"
          "请先确认用户名/密码正确，然后等待几分钟后重试。";
    }
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
      var client = _newAuthedClient(configs[0], configs[1], configs[2]);
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
        lastSyncErrorWasRateLimit = _isTooManyRequests(e);
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
