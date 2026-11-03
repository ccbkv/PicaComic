import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pica_comic/utils/extensions.dart';

void log(String content,
    [String title = "debug", LogLevel level = LogLevel.info]) {
  LogManager.addLog(level, title, content);
}

class LogManager {
  static final List<Log> _logs = <Log>[];

  static List<Log> get logs => _logs;

  static const maxLogLength = 3000;

  static const maxLogNumber = 500;

  static bool ignoreLimitation = false;

  static void printWarning(String text) {
    print('\x1B[33m$text\x1B[0m');
  }

  static void printError(String text) {
    print('\x1B[31m$text\x1B[0m');
  }

  static void addLog(LogLevel level, String title, String content) {
    if (!ignoreLimitation && content.length > maxLogLength) {
      content = "${content.substring(0, maxLogLength)}...";
    }

    if (kDebugMode) {
      switch (level) {
        case LogLevel.error:
          printError("$title: $content");
        case LogLevel.warning:
          printWarning("$title: $content");
        case LogLevel.info:
          print("$title: $content");
      }
    }

    var newLog = Log(level, title, content);

    if (newLog == _logs.lastOrNull) {
      return;
    }

    _logs.add(newLog);
    writeLog(level, title, content);
    if (_logs.length > maxLogNumber) {
      var res = _logs.remove(
          _logs.firstWhereOrNull((element) => element.level == LogLevel.info));
      if (!res) {
        _logs.removeAt(0);
      }
    }
  }

  static void clear() => _logs.clear();

  @override
  String toString() {
    var res = "Logs\n\n";
    for (var log in _logs) {
      res += log.toString();
    }
    return res;
  }

  static File? logFile;
  static final List<String> _buffer = <String>[];
  static Timer? _flushTimer;

  /// 是否处于「隔离区同步写盘」模式，见 [attachIsolateLogFile]。
  static bool _syncWrite = false;

  /// 让 compute() 隔离区也能落日志。
  ///
  /// `compute()` 起的是一个**新 isolate**，而 [logFile] 是静态变量 ——
  /// 主 isolate 里赋过值，隔离区里那份**仍然是 null**，
  /// [writeLog] 开头 `if (logFile == null) return;` 会把隔离区里的每一条
  /// 日志**静默丢弃**。
  ///
  /// 麻烦在于同步合并（`SyncMerge.mergeFavoriteDb`）恰好整个跑在隔离区里，
  /// 于是「收藏合并到底做了什么」在日志里完全看不见，出问题只能靠 UI 现象猜。
  ///
  /// 隔离区里调用它把日志文件指过去，同时切到**同步写盘**：
  /// 隔离区随 compute 回调结束就被销毁，500ms 的定时 flush 根本等不到。
  static void attachIsolateLogFile(String? path) {
    if (path == null || path.isEmpty) return;
    try {
      logFile = File(path);
      _syncWrite = true;
    } catch (_) {
      // 指不过去就算了：日志丢了也不该影响同步本身。
    }
  }

  static void writeLog(LogLevel level, String title, String content) {
    if (logFile == null) return;
    final line =
        "${DateTime.now().toIso8601String()} ${level.name}\n$title: $content\n\n";
    if (_syncWrite) {
      // 隔离区：随时可能被销毁，必须立刻落盘（定时器等不到）。
      try {
        logFile!.writeAsStringSync(line, mode: FileMode.append);
      } catch (_) {}
      return;
    }
    _buffer.add(line);
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(milliseconds: 500), () {
      if (_buffer.isEmpty || logFile == null) return;
      final data = _buffer.join();
      _buffer.clear();
      logFile!.writeAsString(data, mode: FileMode.append);
    });
  }
}

class Log {
  final LogLevel level;
  final String title;
  final String content;
  final DateTime time = DateTime.now();

  @override
  toString() => "${level.name} $title $time \n$content\n\n";

  Log(this.level, this.title, this.content);

  static void info(String title, String message) {
    LogManager.addLog(LogLevel.info, title, message);
  }

  static void warning(String title, String message) {
    LogManager.addLog(LogLevel.warning, title, message);
  }

  static void error(String title, String message) {
    LogManager.addLog(LogLevel.error, title, message);
  }

  @override
  bool operator ==(Object other) {
    if (other is! Log) return false;
    return other.level == level &&
        other.title == title &&
        other.content == content;
  }

  @override
  int get hashCode => level.hashCode ^ title.hashCode ^ content.hashCode;
}

enum LogLevel { error, warning, info }
