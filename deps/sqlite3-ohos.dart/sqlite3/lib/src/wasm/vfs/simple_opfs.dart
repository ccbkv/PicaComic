import 'dart:js_interop';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:web/web.dart'
    show
        FileSystemDirectoryHandle,
        FileSystemSyncAccessHandle,
        FileSystemReadWriteOptions;

import '../../constants.dart';
import '../../vfs.dart';
import '../js_interop.dart';
import 'memory.dart';

@internal
enum FileType {
  database('/database'),
  journal('/database-journal');

  final String filePath;

  const FileType(this.filePath);

  static final byName = {
    for (final entry in values) entry.filePath: entry,
  };
}

/// A [VirtualFileSystem] for the `sqlite3` wasm library based on the [file system access API].
///
/// By design, this file system can only store two files: `/database` and
/// `/database-journal`. Thus, when this file system is used, the only sqlite3
/// database that will be persisted properly is the one at `/database`.
///
/// The limitation of only being able to store two files comes from the fact
/// that we can't synchronously _open_ files in with the file system access API,
/// only reads and writes are synchronous.
/// By having a known amount of files to store, we can open both files (done in
/// [SimpleOpfsFileSystem.inDirectory] or [SimpleOpfsFileSystem.loadFromStorage]),
/// which is asynchronous too. The actual file system work, which needs to be
/// synchronous for sqlite3 to function, does not need any further wrapper.
///
/// Please note that [SimpleOpfsFileSystem]s are only available in dedicated web workers,
/// not in the JavaScript context for a tab or a shared web worker.
///
/// [file system access API]: https://developer.mozilla.org/en-US/docs/Web/API/File_System_Access_API
final class SimpleOpfsFileSystem extends BaseVirtualFileSystem {
  // The storage idea here is to open sync file handles at the beginning, so
  // that no new async open needs to happen when these callbacks are invoked by
  // sqlite3.
  // We open a sync file for each stored file ([FileType]), plus a meta file
  // file handle that describes whether files exist or not. Handles for stored
  // files just store the raw data directly. The meta file is a 2-byte file
  // storing whether the database or the journal file exists. By storing this
  // information in a secondary file, we avoid the problem of having to query
  // the FileSystem Access API to check whether a file exists, which can only be
  // done asynchronously.

  final FileSystemSyncAccessHandle _metaHandle;
  final Uint8List _existsList = Uint8List(FileType.values.length);

  final Map<FileType, FileSystemSyncAccessHandle> _files;
  final InMemoryFileSystem _memory = InMemoryFileSystem();

  SimpleOpfsFileSystem._(this._metaHandle, this._files,
      {String vfsName = 'simple-opfs'})
      : super(name: vfsName);

  /// Loads an [SimpleOpfsFileSystem] in the desired [path] under the root directory
  /// for OPFS as given by `navigator.storage.getDirectory()` in JavaScript.
  ///
  /// Throws a [VfsException] if OPFS is not available - please note that
  /// this file system implementation requires a recent browser and only works
  /// in dedicated web workers.
  static Future<SimpleOpfsFileSystem> loadFromStorage(String path,
      {String vfsName = 'simple-opfs'}) async {
    final storage = storageManager;
    if (storage == null) {
      throw VfsException(SqlError.SQLITE_ERROR);
    }

    var opfsDirectory = await storage.directory;

    for (final segment in p.split(path)) {
      opfsDirectory = await opfsDirectory.getDirectory(segment, create: true);
    }

    return inDirectory(opfsDirectory, vfsName: vfsName);
  }

  /// Loads an [SimpleOpfsFileSystem] in the desired [root] directory, which must be
  /// a Dart wrapper around a [FileSystemDirectoryHandle].
  ///
  /// [FileSystemDirectoryHandle]: https://developer.mozilla.org/en-US/docs/Web/API/FileSystemDirectoryHandle
  static Future<SimpleOpfsFileSystem> inDirectory(
    FileSystemDirectoryHandle root, {
    String vfsName = 'simple-opfs',
  }) async {
    Future<FileSystemSyncAccessHandle> open(String name) async {
      final handle = await root.openFile(name, create: true);
      return await handle.createSyncAccessHandle().toDart;
    }

    final meta = await open('meta');
    meta.truncate(2);
    final files = {
      for (final type in FileType.values) type: await open(type.name)
    };

    return SimpleOpfsFileSystem._(meta, files, vfsName: vfsName);
  }

  void _markExists(FileType type, bool exists) {
    _existsList[type.index] = exists ? 1 : 0;
    _metaHandle.writeDart(_existsList, FileSystemReadWriteOptions(at: 0));
  }

  FileType? _recognizeType(String path) {
    return FileType.byName[path];
  }

  @override
  int xAccess(String path, int flags) {
    final type = _recognizeType(path);
    if (type == null) {
      return _memory.xAccess(path, flags);
    } else {
      _metaHandle.readDart(_existsList, FileSystemReadWriteOptions(at: 0));
      return _existsList[type.index];
    }
  }

  @override
  void xDelete(String path, int syncDir) {
    final type = _recognizeType(path);
    if (type == null) {
      return _memory.xDelete(path, syncDir);
    } else {
      _markExists(type, false);
    }
  }

  @override
  String xFullPathName(String path) {
    return p.url.normalize('/$path');
  }

  @override
  XOpenResult xOpen(Sqlite3Filename path, int flags) {
    final pathStr = path.path;
    if (pathStr == null) return _memory.xOpen(path, flags);

    final recognized = _recognizeType(pathStr);
    if (recognized == null) return _memory.xOpen(path, flags);

    final create = (flags & SqlFlag.SQLITE_OPEN_CREATE) != 0;
    final deleteOnClose = (flags & SqlFlag.SQLITE_OPEN_DELETEONCLOSE) != 0;

    _metaHandle.readDart(_existsList, FileSystemReadWriteOptions(at: 0));
    final existsAlready = _existsList[recognized.index] != 0;

    final syncHandle = _files[recognized]!;

    if (!existsAlready) {
      if (create) {
        syncHandle.truncate(0);
        _markExists(recognized, true);
      } else {
        throw const VfsException(SqlError.SQLITE_CANTOPEN);
      }
    }

    return (
      outFlags: 0,
      file: _SimpleOpfsFile(this, recognized, syncHandle, deleteOnClose),
    );
  }

  @override
  void xSleep(Duration duration) {}

  /// Closes the synchronous access handles kept open while this file system is
  /// active.
  void close() {
    _metaHandle.close();
    for (final file in _files.values) {
      file.close();
    }
  }
}

class _SimpleOpfsFile extends BaseVfsFile {
  final SimpleOpfsFileSystem vfs;
  final FileType type;
  final FileSystemSyncAccessHandle syncHandle;
  final bool deleteOnClose;

  var _lockMode = SqlFileLockingLevels.SQLITE_LOCK_NONE;

  _SimpleOpfsFile(this.vfs, this.type, this.syncHandle, this.deleteOnClose);

  @override
  int readInto(Uint8List buffer, int offset) {
    return syncHandle.readDart(buffer, FileSystemReadWriteOptions(at: offset));
  }

  @override
  int xCheckReservedLock() {
    return _lockMode >= SqlFileLockingLevels.SQLITE_LOCK_RESERVED ? 1 : 0;
  }

  @override
  void xClose() {
    syncHandle.flush();

    if (deleteOnClose) {
      vfs._markExists(type, false);
    }
  }

  @override
  int xFileSize() {
    return syncHandle.getSize();
  }

  @override
  void xLock(int mode) {
    _lockMode = mode;
  }

  @override
  void xSync(int flags) {
    syncHandle.flush();
  }

  @override
  void xTruncate(int size) {
    syncHandle.truncate(size);
  }

  @override
  void xUnlock(int mode) {
    _lockMode = mode;
  }

  @override
  void xWrite(Uint8List buffer, int fileOffset) {
    final bytesWritten = syncHandle.writeDart(
        buffer, FileSystemReadWriteOptions(at: fileOffset));

    if (bytesWritten < buffer.length) {
      throw const VfsException(SqlExtendedError.SQLITE_IOERR_WRITE);
    }
  }
}
