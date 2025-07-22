/// This library contains a workaround neccessary to open dynamic libraries on
/// old Android versions (6.0.1).
///
/// The purpose of the `sqlite3_flutter_libs` package is to provide `sqlite3`
/// native libraries when building Flutter apps for Android and iOS.
library sqlite3_flutter_libs;

import 'dart:ffi';
import 'dart:io';

import 'package:flutter/services.dart';

const _platform = MethodChannel('sqlite3_flutter_libs');

/// Workaround to open sqlite3 on old Android versions.
///
/// On old Android versions, this method can help if you're having issues
/// opening sqlite3 (e.g. if you're seeing crashes about `libsqlite3.so` not
/// being available). To be safe, call this method before using apis from
/// `package:sqlite3` or `package:moor/ffi.dart`.
///
/// Big thanks to [@knaeckeKami](https://github.com/knaeckeKami) for finding
/// this workaround!!
Future<void> applyWorkaroundToOpenSqlite3OnOldAndroidVersions() async {
  if (!Platform.isAndroid) return;

  try {
    DynamicLibrary.open('libsqlite3.so');
  } on ArgumentError {
    // Ok, the regular approach failed. Try to open sqlite3 in Java, which seems
    // to fix the problem.
    await _platform.invokeMethod('doesnt_matter');

    // Try again. If it still fails we're out of luck.
    DynamicLibrary.open('libsqlite3.so');
  }
}
