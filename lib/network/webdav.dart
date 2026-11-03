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

  /// Human-readable reason for the most recent sync failure, shown to the user.
  static String? lastError;

  /// Sync current data to webdav server. Return true if success.
  static Future<bool> uploadData([String? config]) async {
    // 已经有一次上传在跑：直接跳过，不排队等待。
    //
    // 旧实现在这种情况会 `while (_isOperating) await ...` 自等 —— 因为
    // _uploadInternal 内部的「上传前预合并」会走 importData → 恢复收藏/
    // 历史 → 触发 saveData() → 回到这里，形成死锁。
    // 同步本身是「最后一次为准」的幂等操作，重入直接返回即可。
    if (_isOperating) {
      return true;
    }
    _isOperating = true;
    try {
      return await _uploadInternal(config);
    } finally {
      _isOperating = false;
    }
  }

  /// 执行上传（不处理并发锁），供 [uploadData] 和下载后的自动回传复用。
  ///
  /// [mergeBeforeUpload] 为 true 时，会先把服务器上的现有备份拉下来与本机
  /// 做并集合并，再写回服务器。这样「A 机上传 → B 机上传」不会把 A 的数据
  /// 整盘覆盖掉，用户也不需要再讲究「谁先上传谁后下载」的顺序。
  static Future<bool> _uploadInternal(String? config,
      {bool mergeBeforeUpload = true}) async {
    lastError = null;
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
      // ── 第一步：先把服务器上的备份拉下来，与本机做并集合并 ──
      //
      // 为什么必须这么做：原来的上传是「把本机全量写上去」，服务器上原有的
      // 内容直接被覆盖。于是 A 机上传完、B 机再上传，A 的东西就没了 ——
      // 用户实测到的「两个都先上传的话，后面的会覆盖新的」正是这个原因。
      //
      // 只有「下载」那条路径会做合并（SyncMerge），上传不做，所以用户被迫
      // 遵守「先上传、再下载」的顺序。这里让上传也先合并一次，两边就对称了。
      if (mergeBeforeUpload) {
        try {
          var existing = await client.readDir(configs[3]);
          int? maxVersion;
          for (var file in existing) {
            var name = file.name;
            if (name == null) continue;
            var version = name.split(".").first;
            if (version.isNum) {
              maxVersion = max(maxVersion ?? 0, int.parse(version));
            }
          }
          if (maxVersion != null) {
            var cachePath = (await getApplicationCacheDirectory()).path;
            await client.read2File(
                "${configs[3]}$maxVersion.picadata", "$cachePath/picadata");
            // force=true  → 跳过版本号检查，一定执行合并
            // mergeSettings=false → **只合并收藏/历史等数据，完全不碰 settings**
            //
            // 后者是关键：此刻本机 settings 才是权威值（用户可能刚改完底栏、
            // 翻页方式，正要点上传）。若允许备份里的设置覆盖本机，用户会遇到
            // 「一上传，刚改的设置就变回服务器的旧值」——正是之前的核心困扰。
            var merged =
                await importData("$cachePath/picadata", true, false);
            if (!merged) {
              LogManager.addLog(LogLevel.error, "Sync",
                  "Pre-upload merge failed, fallback to plain upload.");
            }
          }
        } catch (e) {
          // 服务器上没有备份、或拉取失败 —— 都不是致命错误，继续按普通上传走。
          LogManager.addLog(LogLevel.info, "Sync",
              "Pre-upload merge skipped: $e");
        }
      }
      // 预合并完成后才刷新版本号，作为本次备份的文件名。
      // 顺序不能提前：上面的 importData 会写 settings[46]，
      // 若先取时间戳就会被它覆盖掉。
      appdata.settings[46] =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      appdata.updateSettings(false);
      var files = await client.readDir(configs[3]);
      // 备份文件名是 "<unix秒>.picadata"。清理策略：服务器上**只保留 1 份**备份。
      //
      // 旧实现用 `int.parse(version) ~/ 86400 == now ~/ 86400` 判断"同一天"，
      // 看似合理，实则有个致命 bug：86400 秒切分的是 **UTC 日**，而中国是
      // UTC+8，本地时间每天 08:00 才跨 UTC 日界。于是"今天 07:33 上传的备份"
      // 和"今天 13:07 上传的备份"落在不同的 UTC 日，比较失败 → 旧文件不删，
      // 服务器上就攒下一堆 .picadata。
      //
      // 另一个坑：下载合并后会把结果"回推"服务器（见 downloadData 末尾），
      // 回推会生成一个新时间戳文件，此时服务器上恰好有 **1 个**旧文件。
      // 早期版本写的是 `stale.length > 1 ? stale.sublist(0, stale.length - 1) : []`
      // —— stale 只有 1 个时直接不删，于是"回推"永远留下一对文件。
      // 正确做法：本次要写的版本之外，**其余全部删掉**。
      var newVersion = appdata.settings[46];
      // 收集所有"不是本次要写入版本"的旧备份，稍后新文件写成功再统一清理。
      var stale = <String>[];
      for (var file in files) {
        var name = file.name;
        if (name == null || file.path == null) continue;
        var version = name.split(".").first;
        if (!version.isNum) continue;
        if (version == newVersion) continue;
        stale.add(file.path!);
      }
      // 先写入新版本，成功之后再清理旧文件。
      // 顺序很重要：若先删旧再写新，一旦写入失败（网络中断/配额满）就会
      // 连旧备份也丢掉，服务器上什么都不剩。先写后删则最坏情况只是留下
      // 一对文件（下次上传会再清一次），不会造成数据丢失。
      await client.writeFromFile(await exportDataToFile(false, "${App.cachePath}/userdata.picadata"),
          "${configs[3]}${appdata.settings[46]}.picadata");
      // 新备份落盘成功，现在可以安全删掉所有旧版本，服务器上只留 1 份。
      for (var path in stale) {
        try {
          await client.remove(path);
          LogManager.addLog(LogLevel.info, "Sync", "Removed stale backup: $path");
        } catch (e) {
          // 单个旧文件删不掉不影响本次上传。
          LogManager.addLog(LogLevel.error, "Sync",
              "Failed to remove stale backup $path\n$e");
        }
      }
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

  /// 从服务器下载备份并合并进本机。
  ///
  /// [force] 为 true 时跳过「服务器版本号与本机相同就跳过」的判断，
  /// 一定要执行一次导入。手动点「下载」必须传 true。
  ///
  /// [pullSettings] 决定**这次下载要不要把服务器上的设置也拉过来覆盖本机**：
  ///
  /// - `true` —— 手动「下载数据」按钮。语义就是「以服务器为准」，
  ///   用户在设置页先把某项改成不一样的，再点下载，期望它变回备份里的值。
  /// - `false`（默认）—— **自动同步**（启动时、切回前台每 2 小时一次）。
  ///   这类同步只应该合并收藏/历史等**数据**，绝不能碰 `settings`。
  ///
  /// 为什么自动同步必须传 false：自动同步是无感的、用户根本没点过任何按钮。
  /// 若它顺手把服务器设置覆盖到本机，就会出现「我在这台机器上改好了翻页模式 /
  /// 底栏，什么都没点，只是重开了一下 App，设置就被打回服务器上的旧值」。
  /// 这正是多设备场景下最容易踩的坑 —— 用户在 A 机改了设置但没上传，
  /// B 机一启动就把 A 机的改动冲掉了。
  static Future<bool> downloadData([String? config, bool force = false,
      bool pullSettings = false]) async {
    _isOperating = true;
    // 传了 config 一定意味着是手动（设置页的测试/下载按钮带的配置字符串），
    // 此时无条件强制覆盖；否则由调用方通过 force 显式声明。
    force = force || config != null;
    // 显式传了 config（设置页按钮）同样视为「以服务器为准」。
    if (config != null) {
      pullSettings = true;
    }
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
        //
        // mergeSettings 由 pullSettings 决定：
        //   手动下载 → true，把服务器设置一并拉过来（"以服务器为准"）
        //   自动同步 → false，只合并收藏/历史，本机设置原样保留
        var res = await importData("$cachePath/picadata", true, pullSettings);
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
            //
            // mergeBeforeUpload: false —— 本次刚刚才把服务器备份合并进本机，
            // 本机此刻就是超集，再拉一次没有意义，只会白白多一轮请求。
            await _uploadInternal(config, mergeBeforeUpload: false);
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
    // 自动同步（启动时/定时）走非强制路径：服务器版本与本机一致就跳过，
    // 避免每次启动都重新导入一遍。用户手动点"下载"不走这里。
    var res = await _retryZone(() => Webdav.downloadData(null, false));
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
