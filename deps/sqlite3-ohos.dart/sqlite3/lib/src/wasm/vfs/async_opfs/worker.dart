// https://github.com/dart-lang/sdk/issues/54801
@JS()
library;

import 'dart:js_interop';

import 'package:path/path.dart' as p show url;
import 'package:web/web.dart'
    show
        FileSystemDirectoryHandle,
        FileSystemFileHandle,
        FileSystemSyncAccessHandle,
        FileSystemReadWriteOptions;

import '../../../constants.dart';
import '../../../vfs.dart';
import '../../js_interop.dart';
import 'sync_channel.dart';

const _workerDebugLog =
    bool.fromEnvironment('sqlite3.wasm.worker.debug', defaultValue: false);

void _log(String message) {
  if (_workerDebugLog) print(message);
}

@JS()
@anonymous
extension type WorkerOptions._raw(JSObject _) implements JSObject {
  external int get clientVersion;
  external String get root;
  external SharedArrayBuffer get synchronizationBuffer;
  external SharedArrayBuffer get communicationBuffer;

  external factory WorkerOptions._({
    required int clientVersion,
    required String root,
    required SharedArrayBuffer synchronizationBuffer,
    required SharedArrayBuffer communicationBuffer,
  });

  factory WorkerOptions({
    int clientVersion = protocolVersion,
    required String root,
    required SharedArrayBuffer synchronizationBuffer,
    required SharedArrayBuffer communicationBuffer,
  }) {
    return WorkerOptions._(
      clientVersion: clientVersion,
      root: root,
      synchronizationBuffer: synchronizationBuffer,
      communicationBuffer: communicationBuffer,
    );
  }
}

class _ResolvedPath {
  final String fullPath;

  final FileSystemDirectoryHandle directory;
  final String filename;

  _ResolvedPath(this.fullPath, this.directory, this.filename);

  Future<FileSystemFileHandle> openFile({bool create = false}) {
    return directory.openFile(filename, create: create);
  }
}

class VfsWorker {
  final RequestResponseSynchronizer synchronizer;
  final MessageSerializer messages;

  final FileSystemDirectoryHandle root;

  var _fdCounter = 0;
  var _stopped = false;

  final Map<int, _OpenedFileHandle> _openFiles = {};
  final Set<_OpenedFileHandle> _implicitlyHeldLocks = {};

  VfsWorker._(WorkerOptions options, this.root)
      : synchronizer =
            RequestResponseSynchronizer(options.synchronizationBuffer),
        messages = MessageSerializer(options.communicationBuffer);

  static Future<VfsWorker> create(WorkerOptions options) async {
    var root = await storageManager!.directory;
    final split = p.url.split(options.root);

    for (final directory in split) {
      root = await root.getDirectory(directory, create: true);
    }

    return VfsWorker._(options, root);
  }

  Future<_ResolvedPath> _resolvePath(String absolutePath,
      {bool createDirectories = false}) async {
    final fullPath = p.url.relative(absolutePath, from: '/');
    final [...directories, file] = p.url.split(fullPath);

    var dirHandle = root;
    for (final entry in directories) {
      dirHandle =
          await dirHandle.getDirectory(entry, create: createDirectories);
    }

    return _ResolvedPath(fullPath, dirHandle, file);
  }

  Future<Flags> _xAccess(NameAndInt32Flags flags) async {
    try {
      final resolved = await _resolvePath(flags.name);

      // If we can open the file, it exists. For OPFS, that means that it's both
      // readable and writable.
      await resolved.openFile();
      return Flags(1, 0, 0);
    } catch (e) {
      return Flags(0, 0, 0);
    }
  }

  Future<void> _xDelete(NameAndInt32Flags options) async {
    final resolved = await _resolvePath(options.name);
    try {
      await resolved.directory.remove(resolved.filename);
    } catch (e) {
      _log('Could not delete entry: $e');
      throw const VfsException(SqlExtendedError.SQLITE_IOERR_DELETE);
    }
  }

  Future<Flags> _xOpen(NameAndInt32Flags req) async {
    final flags = req.flag0;
    final create = (flags & SqlFlag.SQLITE_OPEN_CREATE) != 0;

    _ResolvedPath resolved;

    try {
      resolved = await _resolvePath(req.name, createDirectories: create);
    } catch (e) {
      // Error traversing the path
      throw VfsException(SqlError.SQLITE_NOTFOUND);
    }

    final fileHandle = await resolved.openFile(create: create);
    final readonly = !create && (flags & SqlFlag.SQLITE_OPEN_READONLY) != 0;
    final opened = _OpenedFileHandle(
      fd: _fdCounter++,
      directory: resolved.directory,
      fullPath: resolved.fullPath,
      filename: resolved.filename,
      file: fileHandle,
      deleteOnClose: (flags & SqlFlag.SQLITE_OPEN_DELETEONCLOSE) != 0,
      readonly: readonly,
    );
    _openFiles[opened.fd] = opened;

    var outFlags = 0;
    if (readonly) {
      outFlags |= SqlFlag.SQLITE_OPEN_READONLY;
    }

    // flag0 are the outFlags passed to sqlite, flag1 is the descriptor
    return Flags(outFlags, opened.fd, 0);
  }

  Future<Flags> _xRead(Flags req) async {
    final file = _openFiles[req.flag0]!;
    final offset = req.flag1;
    final bufferLength = req.flag2;
    assert(bufferLength <= MessageSerializer.dataSize);

    final syncHandle = await _openForSynchronousAccess(file);
    final bytesRead = syncHandle.readDart(
        messages.viewByteRange(0, bufferLength),
        FileSystemReadWriteOptions(at: offset));

    return Flags(bytesRead, 0, 0);
  }

  Future<EmptyMessage> _xWrite(Flags req) async {
    final file = _openFiles[req.flag0]!;
    final offset = req.flag1;
    final bufferLength = req.flag2;
    assert(bufferLength <= MessageSerializer.dataSize);

    final syncHandle = await _openForSynchronousAccess(file);
    final bytesWritten = syncHandle.writeDart(
        messages.viewByteRange(0, bufferLength),
        FileSystemReadWriteOptions(at: offset));

    if (bytesWritten != bufferLength) {
      throw const VfsException(SqlExtendedError.SQLITE_IOERR_WRITE);
    }

    return const EmptyMessage();
  }

  Future<void> _xClose(Flags req) async {
    final file = _openFiles.remove(req.flag0);
    _implicitlyHeldLocks.remove(file);

    if (file == null) {
      throw const VfsException(SqlError.SQLITE_NOTFOUND);
    }

    _closeSyncHandle(file);
    if (file.deleteOnClose) {
      await file.directory.remove(file.filename);
    }
  }

  Future<Flags> _xFileSize(Flags req) async {
    final file = _openFiles[req.flag0]!;
    try {
      final syncHandle = await _openForSynchronousAccess(file);
      final size = syncHandle.getSize();

      return Flags(size, 0, 0);
    } finally {
      _releaseImplicitLock(file);
    }
  }

  Future<EmptyMessage> _xTruncate(Flags req) async {
    final file = _openFiles[req.flag0]!;
    file.checkMayWrite();

    try {
      final syncHandle = await _openForSynchronousAccess(file);
      syncHandle.truncate(req.flag1);
    } finally {
      _releaseImplicitLock(file);
    }

    return const EmptyMessage();
  }

  Future<EmptyMessage> _xSync(Flags req) async {
    final file = _openFiles[req.flag0]!;

    // Closing a sync handle will also flush it, so we only need to call flush
    // explicitly if the file is currently opened.
    final syncHandle = file.syncHandle;
    if (!file.readonly && syncHandle != null) {
      syncHandle.flush();
    }

    return const EmptyMessage();
  }

  Future<EmptyMessage> _xLock(Flags req) async {
    final file = _openFiles[req.flag0]!;

    if (file.syncHandle == null) {
      try {
        await _openForSynchronousAccess(file);
        file.explicitlyLocked = true;
      } on Object {
        throw const VfsException(SqlExtendedError.SQLITE_IOERR_LOCK);
      }
    } else {
      // We already have an (implicit) lock on this file, so we just need to
      // make it explicit.
      file.explicitlyLocked = true;
    }

    return const EmptyMessage();
  }

  Future<EmptyMessage> _xUnlock(Flags req) async {
    final file = _openFiles[req.flag0]!;
    final mode = req.flag1;

    final existingHandle = file.syncHandle;
    if (existingHandle != null &&
        mode == SqlFileLockingLevels.SQLITE_LOCK_NONE) {
      _closeSyncHandle(file);
    }

    return const EmptyMessage();
  }

  Future<void> start() async {
    while (!_stopped) {
      final waitResult = synchronizer.waitForRequest();
      if (waitResult == Atomics.timedOut) {
        // No requests for some time, transition to idle
        _releaseImplicitLocks();
        continue;
      }

      int rc;
      WorkerOperation? opcode;
      Object? request;

      try {
        opcode = WorkerOperation.values[synchronizer.takeOpcode()];
        request = opcode.readRequest(messages);

        Message response;

        switch (opcode) {
          case WorkerOperation.xSleep:
            _releaseImplicitLocks();
            await Future<void>.delayed(
                Duration(milliseconds: (request as Flags).flag0));
            response = const EmptyMessage();
            break;
          case WorkerOperation.xAccess:
            response = await _xAccess(request as NameAndInt32Flags);
            break;
          case WorkerOperation.xDelete:
            await _xDelete(request as NameAndInt32Flags);
            response = const EmptyMessage();
            break;
          case WorkerOperation.xOpen:
            response = await _xOpen(request as NameAndInt32Flags);
            break;
          case WorkerOperation.xRead:
            response = await _xRead(request as Flags);
            break;
          case WorkerOperation.xWrite:
            response = await _xWrite(request as Flags);
            break;
          case WorkerOperation.xClose:
            await _xClose(request as Flags);
            response = const EmptyMessage();
            break;
          case WorkerOperation.xFileSize:
            response = await _xFileSize(request as Flags);
            break;
          case WorkerOperation.xTruncate:
            response = await _xTruncate(request as Flags);
            break;
          case WorkerOperation.xSync:
            response = await _xSync(request as Flags);
            break;
          case WorkerOperation.xLock:
            response = await _xLock(request as Flags);
            break;
          case WorkerOperation.xUnlock:
            response = await _xUnlock(request as Flags);
            break;
          case WorkerOperation.stopServer:
            response = const EmptyMessage();
            _stopped = true;
            _releaseImplicitLocks();
            break;
        }

        messages.write(response);
        rc = 0;
      } on VfsException catch (e) {
        _log('Caught $e while handling $opcode($request)');
        rc = e.returnCode;
      } catch (e) {
        _log('Caught $e while handling $opcode($request)');
        rc = 1;
      }

      synchronizer.respond(rc);
    }
  }

  void _releaseImplicitLocks() {
    _implicitlyHeldLocks.toList().forEach(_releaseImplicitLock);
  }

  void _releaseImplicitLock(_OpenedFileHandle handle) {
    if (_implicitlyHeldLocks.remove(handle)) {
      _closeSyncHandleNoThrow(handle);
    }
  }

  Future<FileSystemSyncAccessHandle> _openForSynchronousAccess(
      _OpenedFileHandle file) async {
    final existing = file.syncHandle;
    if (existing != null) {
      return existing;
    }

    var attempt = 1;
    const maxAttempts = 6;

    while (true) {
      try {
        final handle =
            file.syncHandle = await file.file.createSyncAccessHandle().toDart;

        // We've locked the file simply because we've created an (exclusive)
        // synchronous access handle. If there was no explicit lock on this
        // file (through xLock), let's remember that we've locked the file. For
        // most operations (e.g. subsequent reads and writes), we keep a lock
        // across requests.
        if (!file.explicitlyLocked) {
          _implicitlyHeldLocks.add(file);
          _log('Acquired implicit lock for ${file.fullPath}');
        }
        return handle;
      } catch (e) {
        if (attempt == maxAttempts) {
          throw const VfsException(SqlError.SQLITE_IOERR);
        }

        _log('Could not obtain sync handle (attempt $attempt / $maxAttempts)');
        attempt++;
      }
    }
  }

  void _closeSyncHandleNoThrow(_OpenedFileHandle handle) {
    try {
      _closeSyncHandle(handle);
    } catch (e) {
      _log('Ignoring error during close');
    }
  }

  void _closeSyncHandle(_OpenedFileHandle handle) {
    final syncHandle = handle.syncHandle;
    if (syncHandle != null) {
      _log('Closing sync handle for ${handle.fullPath}');
      handle.syncHandle = null;
      _implicitlyHeldLocks.remove(handle);
      handle.explicitlyLocked = false;
      syncHandle.close();
    }
  }
}

class _OpenedFileHandle {
  final int fd;
  final bool readonly;
  final bool deleteOnClose;

  final String fullPath;
  final FileSystemDirectoryHandle directory;
  final String filename;
  final FileSystemFileHandle file;

  bool explicitlyLocked = false;
  FileSystemSyncAccessHandle? syncHandle;

  _OpenedFileHandle({
    required this.fd,
    required this.readonly,
    required this.deleteOnClose,
    required this.fullPath,
    required this.directory,
    required this.filename,
    required this.file,
  });

  void checkMayWrite() {
    if (readonly) {
      throw const VfsException(SqlError.SQLITE_READONLY);
    }
  }
}
