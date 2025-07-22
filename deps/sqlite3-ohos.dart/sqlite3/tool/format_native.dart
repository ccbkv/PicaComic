import 'dart:io';

Future<void> main() async {
  final process = await Process.start(
    'clang-format',
    ['--style=google', '-i', 'assets/sqlite3.h'],
    mode: ProcessStartMode.inheritStdio,
  );

  exitCode = await process.exitCode;
}
