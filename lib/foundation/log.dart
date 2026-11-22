import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pica_comic/utils/extensions.dart';

void log(String content,
    [String title = "debug", LogLevel level = LogLevel.info]) {
  LogManager.addLog(level, title, content);
}

class LogManager {
  static final List<Log> _logs = <Log>[];

  static List<Log> get logs => _logs;

  static final changes = ValueNotifier<int>(0);

  static const maxLogLength = 3000;

  static const maxLogNumber = 500;

  static bool ignoreLimitation = false;

  static bool verboseNetwork = false;

  static void syncVerboseNetwork(bool value) => verboseNetwork = value;

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
    writeLog(newLog);
    if (_logs.length > maxLogNumber) {
      var res = _logs.remove(
          _logs.firstWhereOrNull((element) => element.level == LogLevel.info));
      if (!res) {
        _logs.removeAt(0);
      }
    }
    changes.value++;
  }

  static void clear() {
    flush();
    _logs.clear();
    changes.value++;
  }

  @override
  String toString() {
    var res = "Logs\n\n";
    for (var log in _logs) {
      res += log.toString();
    }
    return res;
  }

  static File? logFile;
  static File? previousLogFile;
  static final List<String> _buffer = <String>[];
  static Timer? _flushTimer;

  static void rotateLogFile(File? file) {
    flush();
    logFile = file;
    previousLogFile = null;
    if (file == null) return;
    final previous = File('${file.path}.previous');
    try {
      if (previous.existsSync()) previous.deleteSync();
      if (file.existsSync()) {
        file.renameSync(previous.path);
        previousLogFile = previous;
      }
    } catch (e) {
      debugPrint('Failed to keep previous logs: $e');
    }
  }

  static void writeLog(Log log) {
    if (logFile == null) return;
    _buffer.add(log.toString());
    if (log.level == LogLevel.error || _buffer.length >= 64) {
      flush();
      return;
    }
    _flushTimer ??= Timer(const Duration(milliseconds: 500), flush);
  }

  static void flush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_buffer.isEmpty || logFile == null) return;
    final data = _buffer.join();
    _buffer.clear();
    try {
      logFile!.writeAsString(data, mode: FileMode.append);
    } catch (e) {
      debugPrint('Failed to write logs: $e');
    }
  }

  static const _previousTailBytes = 1 << 20;

  static Future<List<Log>> loadPreviousSession() async {
    final file = previousLogFile;
    if (file == null || !await file.exists()) return const [];
    final raf = await file.open();
    Uint8List bytes;
    try {
      final length = await raf.length();
      final start =
          length > _previousTailBytes ? length - _previousTailBytes : 0;
      await raf.setPosition(start);
      bytes = await raf.read(length - start);
    } finally {
      await raf.close();
    }
    return compute(_parseBytes, bytes);
  }

  static List<Log> _parseBytes(Uint8List bytes) =>
      parse(utf8.decode(bytes, allowMalformed: true));

  static final _header = RegExp(
    r'^(error|warning|info) (.*) (\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+) $',
    multiLine: true,
  );

  static List<Log> parse(String text) {
    final matches = _header.allMatches(text).toList();
    final items = <Log>[];
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final end = i + 1 < matches.length ? matches[i + 1].start : text.length;
      final start = match.end < end ? match.end + 1 : end;
      final content = text.substring(start, end);
      var trimmed = content.length;
      while (trimmed > 0 && content.codeUnitAt(trimmed - 1) == 0x0A) {
        trimmed--;
      }
      items.add(Log(
        LogLevel.values.byName(match[1]!),
        match[2]!,
        content.substring(0, trimmed),
        DateTime.tryParse(match[3]!),
      ));
    }
    return items;
  }

  static String exportText(Iterable<Log> items, {String title = 'Logs'}) {
    final buffer = StringBuffer()
      ..writeln(title)
      ..writeln(
        'Platform: ${Platform.operatingSystem} '
        '${Platform.operatingSystemVersion}',
      )
      ..writeln('Exported at: ${DateTime.now()}')
      ..writeln();
    for (final item in items) {
      buffer.write(item);
    }
    return buffer.toString();
  }

  static String exportFileName([DateTime? time]) {
    final value = time ?? DateTime.now();
    String two(int number) => number.toString().padLeft(2, '0');
    return 'logs-${value.year}${two(value.month)}${two(value.day)}'
        '-${two(value.hour)}${two(value.minute)}${two(value.second)}.txt';
  }
}

class Log {
  final LogLevel level;
  final String title;
  final String content;
  final DateTime time;

  @override
  toString() => "${level.name} $title $time \n$content\n\n";

  Log(this.level, this.title, this.content, [DateTime? time])
      : time = time ?? DateTime.now();

  static void info(String title, String message) {
    LogManager.addLog(LogLevel.info, title, message);
  }

  static void warning(String title, String message) {
    LogManager.addLog(LogLevel.warning, title, message);
  }

  static void error(String title, Object message, [Object? stackTrace]) {
    var content = message.toString();
    if (stackTrace != null) content += '\n$stackTrace';
    LogManager.addLog(LogLevel.error, title, content);
  }

  static List<Log> get logs => LogManager.logs;

  static ValueNotifier<int> get changes => LogManager.changes;

  static bool get ignoreLimitation => LogManager.ignoreLimitation;

  static set ignoreLimitation(bool value) =>
      LogManager.ignoreLimitation = value;

  static bool get verboseNetwork => LogManager.verboseNetwork;

  static void syncVerboseNetwork(bool value) =>
      LogManager.syncVerboseNetwork(value);

  static void flush() => LogManager.flush();

  static void clear() => LogManager.clear();

  static Future<List<Log>> loadPreviousSession() =>
      LogManager.loadPreviousSession();

  static String exportText(Iterable<Log> items, {String title = 'Logs'}) =>
      LogManager.exportText(items, title: title);

  static String exportFileName() => LogManager.exportFileName();

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

typedef LogItem = Log;

enum LogLevel { error, warning, info }
