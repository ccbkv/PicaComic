import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart';

import 'core.dart';

@JS('navigator')
external Navigator get _navigator;

StorageManager? get storageManager {
  final navigator = _navigator;

  if (navigator.has('storage')) {
    return navigator.storage;
  }

  return null;
}

extension StorageManagerApi on StorageManager {
  Future<FileSystemDirectoryHandle> get directory => getDirectory().toDart;
}

extension FileSystemSyncAccessHandleApi on FileSystemSyncAccessHandle {
  int readDart(Uint8List buffer, [FileSystemReadWriteOptions? options]) {
    if (options == null) {
      return read(buffer.toJS);
    } else {
      return read(buffer.toJS, options);
    }
  }

  int writeDart(Uint8List buffer, [FileSystemReadWriteOptions? options]) {
    if (options == null) {
      return write(buffer.toJS);
    } else {
      return write(buffer.toJS, options);
    }
  }
}

extension FileSystemHandleApi on FileSystemHandle {
  bool get isFile => kind == 'file';

  bool get isDirectory => kind == 'directory';
}

extension FileSystemDirectoryHandleApi on FileSystemDirectoryHandle {
  Future<FileSystemFileHandle> openFile(String name, {bool create = false}) {
    return getFileHandle(name, FileSystemGetFileOptions(create: create)).toDart;
  }

  Future<FileSystemDirectoryHandle> getDirectory(String name,
      {bool create = false}) {
    return getDirectoryHandle(
            name, FileSystemGetDirectoryOptions(create: create))
        .toDart;
  }

  Future<void> remove(String name, {bool recursive = false}) {
    return removeEntry(name, FileSystemRemoveOptions(recursive: recursive))
        .toDart;
  }

  Stream<FileSystemHandle> list() {
    return AsyncJavaScriptIteratable<JSArray>(this)
        .map((data) => data.toDart[1] as FileSystemHandle);
  }

  Stream<FileSystemHandle> getFilesRecursively() async* {
    await for (final entry in list()) {
      if (entry.isFile) {
        yield entry;
      } else if (entry.isDirectory) {
        yield* (entry as FileSystemDirectoryHandle).getFilesRecursively();
      }
    }
  }
}
