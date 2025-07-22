/// Very regrettably, `package:drift` imports this exact file and because it
/// used to define FileSystem Access API bindings before we've migrated these to
/// `package:web`.
///
/// To avoid breaking drift, we're exporting the subset of APIs used by drift
/// to keep that working. This file is not used anywhere in this package and
/// will be removed in the next major release.
@Deprecated('Do not import this at all')
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;
import 'core.dart';
import 'new_file_system_access.dart' as fixed;

typedef FileSystemDirectoryHandle = LegacyDirectoryHandle;
typedef FileSystemFileHandle = LegacyFileHandle;
typedef FileSystemSyncAccessHandle = LegacySyncFileHandle;

LegacyStorageManager? get storageManager {
  final raw = fixed.storageManager;
  return raw != null ? LegacyStorageManager(raw) : null;
}

extension type LegacyStorageManager(web.StorageManager inner) {
  Future<FileSystemDirectoryHandle> get directory async =>
      FileSystemDirectoryHandle(await inner.directory);
}

extension type LegacyHandle(web.FileSystemHandle inner) {
  bool get isDirectory => inner.isDirectory;

  String get name => inner.name;
}

extension type LegacyDirectoryHandle(web.FileSystemDirectoryHandle inner) {
  Future<LegacyFileHandle> openFile(String name, {bool create = false}) async {
    return LegacyFileHandle(await inner.openFile(name, create: create));
  }

  Future<void> removeEntry(String name, {bool recursive = false}) async {
    await fixed.FileSystemDirectoryHandleApi(inner)
        .remove(name, recursive: recursive);
  }

  Future<LegacyDirectoryHandle> getDirectory(String name) async {
    return LegacyDirectoryHandle(await inner.getDirectory(name));
  }

  Stream<LegacyHandle> list() {
    return AsyncJavaScriptIteratable<JSArray>(inner)
        .map((data) => LegacyHandle(data.toDart[1] as web.FileSystemHandle));
  }
}

extension type LegacyFileHandle(web.FileSystemFileHandle inner) {
  Future<LegacySyncFileHandle> createSyncAccessHandle() async {
    final raw = await inner.createSyncAccessHandle().toDart;
    return LegacySyncFileHandle(raw);
  }
}

extension type LegacySyncFileHandle(web.FileSystemSyncAccessHandle inner) {
  void close() {
    inner.close();
  }
}
