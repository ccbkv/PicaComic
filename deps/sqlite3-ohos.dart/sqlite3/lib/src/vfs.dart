import 'dart:math';
import 'dart:typed_data';

import 'constants.dart';

/// An exception thrown by [VirtualFileSystem] implementations written in Dart
/// to signal that an operation could not be completed.
final class VfsException implements Exception {
  /// The error code to return to sqlite3.
  final int returnCode;

  const VfsException(this.returnCode) : assert(returnCode != 0);

  @override
  String toString() {
    return 'VfsException($returnCode)';
  }
}

/// A filename passed to [VirtualFileSystem.xOpen].
base class Sqlite3Filename {
  final String? path;

  Sqlite3Filename(this.path);
}

/// A [virtual filesystem][vfs] used by sqlite3 to access the current I/O
/// environment.
///
/// Due to a lack of necessity on other platforms, registering instances of
/// virtual file systems is only supported with the web backend of this package.
///
/// Instead of having an integer return code, file system implementations should
/// throw a [VfsException] to signal invalid operations.
/// For details on the individual methods, consult the `sqlite3.h` header file
/// and its documentation.
///
/// For a file system implementation that implements a few methods already,
/// consider extending [BaseVirtualFileSystem].
///
/// [vfs]: https://www.sqlite.org/c3ref/vfs.html
abstract base class VirtualFileSystem {
  /// The name of this virtual file system.
  ///
  /// This can be passed as an URI parameter when opening databases to select
  /// it.
  final String name;

  VirtualFileSystem(this.name);

  /// Opens a file, returning supported flags and a file instance.
  XOpenResult xOpen(
    Sqlite3Filename path,
    int flags,
  );

  /// Delete a file.
  void xDelete(String path, int syncDir);

  /// Check whether a file can be accessed.
  int xAccess(String path, int flags);

  /// Resolves a [path] name supplied by the user into a path that can be used
  /// by the other methods of this VFS.
  String xFullPathName(String path);

  /// Fill the [target] with random bytes.
  ///
  /// __Safety warning__: Target may be a direct view over native memory that
  /// must not be used after this function returns.
  void xRandomness(Uint8List target);

  /// Sleeps for the passed [duration].
  void xSleep(Duration duration);

  /// Returns the current time.
  DateTime xCurrentTime();
}

/// The result of [VirtualFileSystem.xOpen].
typedef XOpenResult = ({int outFlags, VirtualFileSystemFile file});

/// A file implemented by a VFS author and returned by [VirtualFileSystem.xOpen].
///
/// To avoid common pitfalls, consider extending [BaseVfsFile] instead.
abstract interface class VirtualFileSystemFile {
  /// Close this file.
  void xClose();

  /// Fill the [target] with bytes read from [fileOffset].
  ///
  /// If the file is not large enough to fullfill the read, a [VfsException]
  /// with an error code of [SqlExtendedError.SQLITE_IOERR_SHORT_READ] must be
  /// thrown. Additional, the rest of [target] must be filled with zeroes.
  ///
  /// __Safety warning__: Target may be a direct view over native memory that
  /// must not be used after this function returns.
  void xRead(Uint8List target, int fileOffset);

  /// Writes the [buffer] into this file at [fileOffset], overwriting existing
  /// content or appending to it.
  ///
  /// If, for some reason, only a part of the buffer could be written, a
  /// [VfsException] must be thrown.
  ///
  /// __Safety warning__: Target may be a direct view over native memory that
  /// must not be used after this function returns.
  void xWrite(Uint8List buffer, int fileOffset);

  /// Truncates this file to a size of [size].
  void xTruncate(int size);

  /// Synchronizes, or flushes, the contents of this file to the file system.
  void xSync(int flags);

  /// Returns the size of this file.
  int xFileSize();

  /// Moves the lock state of this file to a more exclusive lock state.
  void xLock(int mode);

  /// Moves the lock state of this file to a less exclusive lock state.
  void xUnlock(int mode);

  /// Returns the lock state held by any process on this file.
  int xCheckReservedLock();

  ///
  int get xDeviceCharacteristics;
}

/// A [VirtualFileSystem] implementation that uses a [Random] instance for
/// [xRandomness] and [DateTime.now] for [xCurrentTime].
abstract base class BaseVirtualFileSystem extends VirtualFileSystem {
  final Random random;

  BaseVirtualFileSystem({Random? random, required String name})
      : random = random ?? Random.secure(),
        super(name);

  @override
  void xRandomness(Uint8List target) {
    for (var i = 0; i < target.length; i++) {
      target[i] = random.nextInt(1 << 8);
    }
  }

  @override
  DateTime xCurrentTime() => DateTime.now();
}

/// A [VirtualFileSystemFile] base class that implements [xRead] to zero-fill
/// the buffer in case of short reads.
abstract class BaseVfsFile implements VirtualFileSystemFile {
  /// Reads from the file at [offset] into the [buffer] and returns the amount
  /// of bytes read.
  ///
  /// __Safety warning__: [bufer] may be a direct view over native memory that
  /// must not be used after this function returns.
  int readInto(Uint8List buffer, int offset);

  @override
  int get xDeviceCharacteristics => 0;

  @override
  void xRead(Uint8List target, int fileOffset) {
    final bytesRead = readInto(target, fileOffset);

    if (bytesRead < target.length) {
      // Remaining buffer must be filled with zeroes.
      target.fillRange(bytesRead, target.length, 0);

      // And we need to return a short read error
      throw const VfsException(SqlExtendedError.SQLITE_IOERR_SHORT_READ);
    }
  }
}
