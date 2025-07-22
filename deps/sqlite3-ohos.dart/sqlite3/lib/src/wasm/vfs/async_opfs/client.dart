import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../constants.dart';
import '../../../vfs.dart';
import '../../js_interop.dart';
import '../utils.dart';
import 'sync_channel.dart';
import 'worker.dart';

final class WasmVfs extends BaseVirtualFileSystem {
  final RequestResponseSynchronizer synchronizer;
  final MessageSerializer serializer;

  final String chroot;
  final p.Context pathContext;

  WasmVfs({
    super.random,
    required WorkerOptions workerOptions,
    this.chroot = '/',
    String vfsName = 'dart-sqlite3-vfs',
  })  : synchronizer =
            RequestResponseSynchronizer(workerOptions.synchronizationBuffer),
        serializer = MessageSerializer(workerOptions.communicationBuffer),
        pathContext = p.Context(style: p.Style.url, current: chroot),
        super(name: vfsName);

  Res _runInWorker<Req extends Message, Res extends Message>(
      WorkerOperation<Req, Res> operation, Req requestData) {
    serializer.write(requestData);

    final rc = synchronizer.requestAndWaitForResponse(operation.index);
    if (rc != 0) {
      throw VfsException(rc);
    }

    return operation.readResponse(serializer);
  }

  @override
  int xAccess(String path, int flags) {
    final res = _runInWorker(
        WorkerOperation.xAccess, NameAndInt32Flags(path, flags, 0, 0));
    return res.flag0;
  }

  @override
  void xDelete(String path, int syncDir) {
    _runInWorker(
        WorkerOperation.xDelete, NameAndInt32Flags(path, syncDir, 0, 0));
  }

  @override
  String xFullPathName(String path) {
    final resolved = pathContext.absolute(path);
    if (!p.isWithin(chroot, resolved)) {
      throw const VfsException(SqlError.SQLITE_CANTOPEN);
    }

    return resolved;
  }

  @override
  XOpenResult xOpen(Sqlite3Filename path, int flags) {
    final filePath = path.path ?? random.randomFileName(prefix: chroot);
    final result = _runInWorker(
        WorkerOperation.xOpen, NameAndInt32Flags(filePath, flags, 0, 0));

    final outFlags = result.flag0;
    final fd = result.flag1;
    return (outFlags: outFlags, file: WasmFile(this, fd));
  }

  @override
  void xSleep(Duration duration) {
    _runInWorker(WorkerOperation.xSleep, Flags(duration.inMilliseconds, 0, 0));
  }

  void close() {
    _runInWorker(WorkerOperation.stopServer, const EmptyMessage());
  }

  static bool get supportsAtomicsAndSharedMemory {
    return Atomics.supported && globalContext.has('SharedArrayBuffer');
  }

  static WorkerOptions createOptions({String root = 'pkg_sqlite3_db/'}) {
    return WorkerOptions(
      synchronizationBuffer: RequestResponseSynchronizer.createBuffer(),
      communicationBuffer: SharedArrayBuffer(MessageSerializer.totalSize),
      root: root,
    );
  }
}

class WasmFile extends BaseVfsFile {
  final WasmVfs vfs;
  final int fd;

  int lockStatus = SqlFileLockingLevels.SQLITE_LOCK_NONE;

  WasmFile(this.vfs, this.fd);

  @override
  int get xDeviceCharacteristics {
    return SqlDeviceCharacteristics.SQLITE_IOCAP_UNDELETABLE_WHEN_OPEN;
  }

  @override
  int readInto(Uint8List buffer, int offset) {
    var remainingBytes = buffer.length;
    var totalBytesRead = 0;

    while (remainingBytes > 0) {
      // There's a limit on the length of byte data we can transmit with one
      // worker call. A single read call is unlikely to exceed this, but we run
      // this in a loop to be safe.
      final bytesToRead = min(MessageSerializer.dataSize, remainingBytes);
      remainingBytes -= bytesToRead;

      final result = vfs._runInWorker(WorkerOperation.xRead,
          Flags(fd, offset + totalBytesRead, bytesToRead));
      final bytesRead = result.flag0;

      // Copy read bytes into result buffer.
      buffer.set(vfs.serializer.viewByteRange(0, bytesRead), totalBytesRead);

      totalBytesRead += bytesRead;
      if (bytesRead < bytesToRead) {
        // short read! No point in reading further as the end of the file has
        // been reached.
        break;
      }
    }

    return totalBytesRead;
  }

  @override
  int xCheckReservedLock() {
    // Copying the approach from sqlite3's implementation here: We can't check
    // whether another tab has a lock on this file without racing. So, we just
    // reprot whether _we_ have a lock...
    return lockStatus != SqlFileLockingLevels.SQLITE_LOCK_NONE ? 1 : 0;
  }

  @override
  void xClose() {
    vfs._runInWorker(WorkerOperation.xClose, Flags(fd, 0, 0));
  }

  @override
  int xFileSize() {
    final response =
        vfs._runInWorker(WorkerOperation.xFileSize, Flags(fd, 0, 0));
    return response.flag0;
  }

  @override
  void xLock(int mode) {
    // In our implementation, all locks are exclusive. So we only need to lock
    // if this file is not currently locked.
    if (lockStatus == SqlFileLockingLevels.SQLITE_LOCK_NONE) {
      vfs._runInWorker(WorkerOperation.xLock, Flags(fd, mode, 0));
    }

    lockStatus = mode;
  }

  @override
  void xSync(int flags) {
    vfs._runInWorker(WorkerOperation.xSync, Flags(fd, 0, 0));
  }

  @override
  void xTruncate(int size) {
    vfs._runInWorker(WorkerOperation.xTruncate, Flags(fd, size, 0));
  }

  @override
  void xUnlock(int mode) {
    // As we only have exlusive locks in OPFS, this only needs to do something
    // when sqlite3 requests to clear the lock entirely.
    if (lockStatus != SqlFileLockingLevels.SQLITE_LOCK_NONE &&
        mode == SqlFileLockingLevels.SQLITE_LOCK_NONE) {
      vfs._runInWorker(WorkerOperation.xUnlock, Flags(fd, mode, 0));
    }
  }

  @override
  void xWrite(Uint8List buffer, int fileOffset) {
    var remainingBytes = buffer.length;
    var totalBytesWritten = 0;

    while (remainingBytes > 0) {
      // Again, we may have to split this into multiple write calls if the
      // buffer would otherwise overflow.
      final bytesToWrite = min(MessageSerializer.dataSize, remainingBytes);

      final subBuffer = bytesToWrite == remainingBytes
          ? buffer
          : buffer.buffer.asUint8List(buffer.offsetInBytes, bytesToWrite);
      vfs.serializer.byteView.set(subBuffer, 0);

      vfs._runInWorker(WorkerOperation.xWrite,
          Flags(fd, fileOffset + totalBytesWritten, bytesToWrite));

      totalBytesWritten += bytesToWrite;
      remainingBytes -= bytesToWrite;
    }
  }
}
