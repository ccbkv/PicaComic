// ignore_for_file: constant_identifier_names

/// Common result codes, https://www.sqlite.org/rescode.html
/// Result Codes
///
/// Many SQLite functions return an integer result code from the set shown
/// here in order to indicates success or failure.
///
/// New error codes may be added in future versions of SQLite.
///
/// See also: SQLITE_IOERR_READ | extended result codes,
/// sqlite3_vtab_on_conflictstatic const int ) SQLITE_ROLLBACK | result codes.
final class SqlError {
  /// Successful result
  static const int SQLITE_OK = 0;

  /// Generic error
  static const int SQLITE_ERROR = 1;

  /// Internal logic error in SQLite
  static const int SQLITE_INTERNAL = 2;

  /// Access permission denied
  static const int SQLITE_PERM = 3;

  /// Callback routine requested an abort
  static const int SQLITE_ABORT = 4;

  /// The database file is locked
  static const int SQLITE_BUSY = 5;

  /// A table in the database is locked
  static const int SQLITE_LOCKED = 6;

  /// A mallocstatic const int ) failed
  static const int SQLITE_NOMEM = 7;

  /// Attempt to write a readonly database
  static const int SQLITE_READONLY = 8;

  /// Operation terminated by sqlite3_interruptstatic const int )
  static const int SQLITE_INTERRUPT = 9;

  /// Some kind of disk I/O error occurred
  static const int SQLITE_IOERR = 10;

  /// The database disk image is malformed
  static const int SQLITE_CORRUPT = 11;

  /// Unknown opcode in sqlite3_file_controlstatic const int )
  static const int SQLITE_NOTFOUND = 12;

  /// Insertion failed because database is full
  static const int SQLITE_FULL = 13;

  /// Unable to open the database file
  static const int SQLITE_CANTOPEN = 14;

  /// Database lock protocol error
  static const int SQLITE_PROTOCOL = 15;

  /// Internal use only
  static const int SQLITE_EMPTY = 16;

  /// The database schema changed
  static const int SQLITE_SCHEMA = 17;

  /// String or BLOB exceeds size limit
  static const int SQLITE_TOOBIG = 18;

  /// Abort due to constraint violation
  static const int SQLITE_CONSTRAINT = 19;

  /// Data type mismatch
  static const int SQLITE_MISMATCH = 20;

  /// Library used incorrectly
  static const int SQLITE_MISUSE = 21;

  /// Uses OS features not supported on host
  static const int SQLITE_NOLFS = 22;

  /// Authorization denied
  static const int SQLITE_AUTH = 23;

  /// Not used
  static const int SQLITE_FORMAT = 24;

  /// 2nd parameter to sqlite3_bind out of range
  static const int SQLITE_RANGE = 25;

  /// File opened that is not a database file
  static const int SQLITE_NOTADB = 26;

  /// Notifications from sqlite3_logstatic const int )
  static const int SQLITE_NOTICE = 27;

  /// Warnings from sqlite3_logstatic const int )
  static const int SQLITE_WARNING = 28;

  /// sqlite3_stepstatic const int ) has another row ready
  static const int SQLITE_ROW = 100;

  /// sqlite3_stepstatic const int ) has finished executing
  static const int SQLITE_DONE = 101;
}

/// Extended Result Codes, https://www.sqlite.org/rescode.html
///
/// Result codes are signed 32-bit integers. The least significant 8 bits of the result code define a broad category and are called the "primary result code". More significant bits provide more detailed information about the error and are called the "extended result code"
///
/// Note that the primary result code is always a part of the extended result code. Given a full 32-bit extended result code, the application can always find the corresponding primary result code merely by extracting the least significant 8 bits of the extended result code.
///
/// All extended result codes are also error codes. Hence the terms "extended result code" and "extended error code" are interchangeable.
final class SqlExtendedError {
  /// The sqlite3_load_extension() interface loads an extension into a single database connection.
  ///
  /// The default behavior is for that extension to be automatically unloaded when the database connection closes. However, if the extension entry point returns SQLITE_OK_LOAD_PERMANENTLY instead of SQLITE_OK, then the extension remains loaded into the process address space after the database connection closes. In other words, the xDlClose methods of the sqlite3_vfs object is not called for the extension when the database connection closes.
  ///
  /// The SQLITE_OK_LOAD_PERMANENTLY return code is useful to loadable extensions that register new VFSes, for example.
  static const int SQLITE_OK_LOAD_PERMANENTLY = 256;

  /// The SQLITE_ERROR_MISSING_COLLSEQ result code means that an SQL statement could not be prepared because a collating sequence named in that SQL statement could not be located.
  ///
  /// Sometimes when this error code is encountered, the sqlite3_prepare_v2static const int ) routine will convert the error into SQLITE_ERROR_RETRY and try again to prepare the SQL statement using a different query plan that does not require the use of the unknown collating sequence.
  static const int SQLITE_ERROR_MISSING_COLLSEQ = 257;

  /// The SQLITE_BUSY_RECOVERY error code is an extended error code for SQLITE_BUSY that indicates that an operation could not continue because another process is busy recovering a WAL mode database file following a crash. The SQLITE_BUSY_RECOVERY error code only occurs on WAL mode databases.
  static const int SQLITE_BUSY_RECOVERY = 261;

  /// The SQLITE_LOCKED_SHAREDCACHE result code indicates that access to an SQLite data record is blocked by another database connection that is using the same record in shared cache mode.
  ///
  /// When two or more database connections share the same cache and one of the connections is in the middle of modifying a record in that cache, then other connections are blocked from accessing that data while the modifications are on-going in order to prevent the readers from seeing a corrupt or partially completed change.
  static const int SQLITE_LOCKED_SHAREDCACHE = 262;

  /// The SQLITE_READONLY_RECOVERY error code is an extended error code for SQLITE_READONLY. The SQLITE_READONLY_RECOVERY error code indicates that a WAL mode database cannot be opened because the database file needs to be recovered and recovery requires write access but only read access is available.
  static const int SQLITE_READONLY_RECOVERY = 264;

  /// The SQLITE_IOERR_READ error code is an extended error code for SQLITE_IOERR indicating an I/O error in the VFS layer while trying to read from a file on disk. This error might result from a hardware malfunction or because a filesystem came unmounted while the file was open.
  static const int SQLITE_IOERR_READ = 266;

  /// The SQLITE_CORRUPT_VTAB error code is an extended error code for SQLITE_CORRUPT used by virtual tables. A virtual table might return SQLITE_CORRUPT_VTAB to indicate that content in the virtual table is corrupt.
  static const int SQLITE_CORRUPT_VTAB = 267;

  /// The SQLITE_CANTOPEN_NOTEMPDIR error code is no longer used.
  static const int SQLITE_CANTOPEN_NOTEMPDIR = 270;

  /// The SQLITE_CONSTRAINT_CHECK error code is an extended error code for SQLITE_CONSTRAINT indicating that a CHECK constraint failed.
  static const int SQLITE_CONSTRAINT_CHECK = 275;

  /// The SQLITE_NOTICE_RECOVER_WAL result code is passed to the callback of sqlite3_logstatic const int ) when a WAL mode database file is recovered.
  static const int SQLITE_NOTICE_RECOVER_WAL = 283;

  /// The SQLITE_WARNING_AUTOINDEX result code is passed to the callback of sqlite3_logstatic const int ) whenever automatic indexing is used. This can serve as a warning to application designers that the database might benefit from additional indexes.
  static const int SQLITE_WARNING_AUTOINDEX = 284;

  /// The SQLITE_ERROR_RETRY is used internally to provoke sqlite3_prepare_v2static const int ) static const int or one of its sibling routines for creating prepared statements) to try again to prepare a statement that failed with an error on the previous attempt.
  static const int SQLITE_ERROR_RETRY = 513;

  /// The SQLITE_ABORT_ROLLBACK error code is an extended error code for SQLITE_ABORT indicating that an SQL statement aborted because the transaction that was active when the SQL statement first started was rolled back. Pending write operations always fail with this error when a rollback occurs. A ROLLBACK will cause a pending read operation to fail only if the schema was changed within the transaction being rolled back.
  static const int SQLITE_ABORT_ROLLBACK = 516;

  /// The SQLITE_BUSY_SNAPSHOT error code is an extended error code for SQLITE_BUSY that occurs on WAL mode databases when a database connection tries to promote a read transaction into a write transaction but finds that another database connection has already written to the database and thus invalidated prior reads.
  ///
  ///
  /// The following scenario illustrates how an SQLITE_BUSY_SNAPSHOT error might arise:
  ///
  /// Process A starts a read transaction on the database and does one or more SELECT statement. Process A keeps the transaction open.
  ///
  /// Process B updates the database, changing values previous read by process A.
  ///
  /// Process A now tries to write to the database. But process A's view of the database content is now obsolete because process B has modified the database file after process A read from it. Hence process A gets an SQLITE_BUSY_SNAPSHOT error.
  static const int SQLITE_BUSY_SNAPSHOT = 517;

  /// The SQLITE_LOCKED_VTAB result code is not used by the SQLite core, but it is available for use by extensions. Virtual table implementations can return this result code to indicate that they cannot complete the current operation because of locks held by other threads or processes.

  /// The R-Tree extension returns this result code when an attempt is made to update the R-Tree while another prepared statement is actively reading the R-Tree.
  ///
  /// The update cannot proceed because any change to an R-Tree might involve reshuffling and rebalancing of nodes, which would disrupt read cursors, causing some rows to be repeated and other rows to be omitted.
  static const int SQLITE_LOCKED_VTAB = 518;

  /// The SQLITE_READONLY_CANTLOCK error code is an extended error code for SQLITE_READONLY. The SQLITE_READONLY_CANTLOCK error code indicates that SQLite is unable to obtain a read lock on a WAL mode database because the shared-memory file associated with that database is read-only.
  static const int SQLITE_READONLY_CANTLOCK = 520;

  /// The SQLITE_IOERR_SHORT_READ error code is an extended error code for SQLITE_IOERR indicating that a read attempt in the VFS layer was unable to obtain as many bytes as was requested. This might be due to a truncated file.
  static const int SQLITE_IOERR_SHORT_READ = 522;

  /// The SQLITE_CORRUPT_SEQUENCE result code means that the schema of the sqlite_sequence table is corrupt. The sqlite_sequence table is used to help implement the AUTOINCREMENT feature. The sqlite_sequence table should have the following format:
  ///
  /// CREATE TABLE sqlite_sequencestatic const int name,seq);
  ///
  /// If SQLite discovers that the sqlite_sequence table has any other format, it returns the SQLITE_CORRUPT_SEQUENCE error.
  static const int SQLITE_CORRUPT_SEQUENCE = 523;

  /// The SQLITE_CANTOPEN_ISDIR error code is an extended error code for SQLITE_CANTOPEN indicating that a file open operation failed because the file is really a directory.
  static const int SQLITE_CANTOPEN_ISDIR = 526;

  /// The SQLITE_CONSTRAINT_COMMITHOOK error code is an extended error code for SQLITE_CONSTRAINT indicating that a commit hook callback returned non-zero that thus caused the SQL statement to be rolled back.
  static const int SQLITE_CONSTRAINT_COMMITHOOK = 531;

  /// The SQLITE_NOTICE_RECOVER_ROLLBACK result code is passed to the callback of sqlite3_logstatic const int ) when a hot journal is rolled back.
  static const int SQLITE_NOTICE_RECOVER_ROLLBACK = 539;

  /// The SQLITE_ERROR_SNAPSHOT result code might be returned when attempting to start a read transaction on an historical version of the database by using the sqlite3_snapshot_openstatic const int ) interface.
  ///
  ///  If the historical snapshot is no longer available, then the read transaction will fail with the SQLITE_ERROR_SNAPSHOT. This error code is only possible if SQLite is compiled with -DSQLITE_ENABLE_SNAPSHOT.
  static const int SQLITE_ERROR_SNAPSHOT = 769;

  /// The SQLITE_BUSY_TIMEOUT error code indicates that a blocking Posix advisory file lock request in the VFS layer failed due to a timeout. Blocking Posix advisory locks are only available as a proprietary SQLite extension and even then are only supported if SQLite is compiled with the SQLITE_EANBLE_SETLK_TIMEOUT compile-time option.
  static const int SQLITE_BUSY_TIMEOUT = 773;

  /// The SQLITE_READONLY_ROLLBACK error code is an extended error code for SQLITE_READONLY. The SQLITE_READONLY_ROLLBACK error code indicates that a database cannot be opened because it has a hot journal that needs to be rolled back but cannot because the database is readonly.
  static const int SQLITE_READONLY_ROLLBACK = 776;

  /// The SQLITE_IOERR_WRITE error code is an extended error code for SQLITE_IOERR indicating an I/O error in the VFS layer while trying to write into a file on disk.
  ///
  /// This error might result from a hardware malfunction or because a filesystem came unmounted while the file was open. This error should not occur if the filesystem is full as there is a separate error code static const int SQLITE_FULL) for that purpose.
  static const int SQLITE_IOERR_WRITE = 778;

  /// The SQLITE_CORRUPT_INDEX result code means that SQLite detected an entry is or was missing from an index. This is a special case of the SQLITE_CORRUPT error code that suggests that the problem might be resolved by running the REINDEX command, assuming no other problems exist elsewhere in the database file.
  static const int SQLITE_CORRUPT_INDEX = 779;

  /// The SQLITE_CANTOPEN_FULLPATH error code is an extended error code for SQLITE_CANTOPEN indicating that a file open operation failed because the operating system was unable to convert the filename into a full pathname.
  static const int SQLITE_CANTOPEN_FULLPATH = 782;

  /// The SQLITE_CONSTRAINT_FOREIGNKEY error code is an extended error code for SQLITE_CONSTRAINT indicating that a foreign key constraint failed.
  static const int SQLITE_CONSTRAINT_FOREIGNKEY = 787;

  /// The SQLITE_READONLY_DBMOVED error code is an extended error code for SQLITE_READONLY.
  ///
  /// The SQLITE_READONLY_DBMOVED error code indicates that a database cannot be modified because the database file has been moved since it was opened, and so any attempt to modify the database might result in database corruption if the processes crashes because the rollback journal would not be correctly named.
  static const int SQLITE_READONLY_DBMOVED = 1032;

  /// The SQLITE_IOERR_FSYNC error code is an extended error code for SQLITE_IOERR indicating an I/O error in the VFS layer while trying to flush previously written content out of OS and/or disk-control buffers and into persistent storage.
  ///
  ///  In other words, this code indicates a problem with the fsyncstatic const int ) system call in unix or the FlushFileBuffersstatic const int ) system call in windows.
  static const int SQLITE_IOERR_FSYNC = 1034;

  /// The SQLITE_CANTOPEN_CONVPATH error code is an extended error code for SQLITE_CANTOPEN used only by Cygwin VFS and indicating that the cygwin_conv_pathstatic const int ) system call failed while trying to open a file. See also: SQLITE_IOERR_CONVPATH
  static const int SQLITE_CANTOPEN_CONVPATH = 1038;

  /// The SQLITE_CONSTRAINT_FUNCTION error code is not currently used by the SQLite core. However, this error code is available for use by extension functions.
  static const int SQLITE_CONSTRAINT_FUNCTION = 1043;

  /// The SQLITE_READONLY_CANTINIT result code originates in the xShmMap method of a VFS to indicate that the shared memory region used by WAL mode exists buts its content is unreliable and unusable by the current process since the current process does not have write permission on the shared memory region.
  ///
  /// static const int The shared memory region for WAL mode is normally a file with a "-wal" suffix that is mmapped into the process space. If the current process does not have write permission on that file, then it cannot write into shared memory.)
  ///
  /// Higher level logic within SQLite will normally intercept the error code and create a temporary in-memory shared memory region so that the current process can at least read the content of the database. This result code should not reach the application interface layer.
  static const int SQLITE_READONLY_CANTINIT = 1288;

  /// The SQLITE_IOERR_DIR_FSYNC error code is an extended error code for SQLITE_IOERR indicating an I/O error in the VFS layer while trying to invoke fsyncstatic const int ) on a directory.
  ///
  ///  The unix VFS attempts to fsyncstatic const int ) directories after creating or deleting certain files to ensure that those files will still appear in the filesystem following a power loss or system crash.
  ///
  /// This error code indicates a problem attempting to perform that fsyncstatic const int ).
  static const int SQLITE_IOERR_DIR_FSYNC = 1290;

  /// The SQLITE_CANTOPEN_DIRTYWAL result code is not used at this time.
  static const int SQLITE_CANTOPEN_DIRTYWAL = 1294;

  /// The SQLITE_CONSTRAINT_NOTNULL error code is an extended error code for SQLITE_CONSTRAINT indicating that a NOT NULL constraint failed.
  static const int SQLITE_CONSTRAINT_NOTNULL = 1299;

  /// The SQLITE_READONLY_DIRECTORY result code indicates that the database is read-only because process does not have permission to create a journal file in the same directory as the database and the creation of a journal file is a prerequisite for writing.
  static const int SQLITE_READONLY_DIRECTORY = 1544;

  /// The SQLITE_IOERR_TRUNCATE error code is an extended error code for SQLITE_IOERR indicating an I/O error in the VFS layer while trying to truncate a file to a smaller size.
  static const int SQLITE_IOERR_TRUNCATE = 1546;

  /// The SQLITE_CANTOPEN_SYMLINK result code is returned by the sqlite3_openstatic const int ) interface and its siblings when the SQLITE_OPEN_NOFOLLOW flag is used and the database file is a symbolic link.
  static const int SQLITE_CANTOPEN_SYMLINK = 1550;

  /// The SQLITE_CONSTRAINT_PRIMARYKEY error code is an extended error code for SQLITE_CONSTRAINT indicating that a PRIMARY KEY constraint failed.
  static const int SQLITE_CONSTRAINT_PRIMARYKEY = 1555;

  /// The SQLITE_IOERR_FSTAT error code is an extended error code for SQLITE_IOERR indicating an I/O error in the VFS layer while trying to invoke fstatstatic const int ) static const int or the equivalent) on a file in order to determine information such as the file size or access permissions.
  static const int SQLITE_IOERR_FSTAT = 1802;

  /// The SQLITE_CONSTRAINT_TRIGGER error code is an extended error code for SQLITE_CONSTRAINT indicating that a RAISE function within a trigger fired, causing the SQL statement to abort.
  static const int SQLITE_CONSTRAINT_TRIGGER = 1811;

  /// The SQLITE_IOERR_UNLOCK error code is an extended error code for SQLITE_IOERR indicating an I/O error within xUnlock method on the sqlite3_io_methods object.
  static const int SQLITE_IOERR_UNLOCK = 2058;

  /// The SQLITE_CONSTRAINT_UNIQUE error code is an extended error code for SQLITE_CONSTRAINT indicating that a UNIQUE constraint failed.
  static const int SQLITE_CONSTRAINT_UNIQUE = 2067;

  /// The SQLITE_IOERR_UNLOCK error code is an extended error code for SQLITE_IOERR indicating an I/O error within xLock method on the sqlite3_io_methods object while trying to obtain a read lock.
  static const int SQLITE_IOERR_RDLOCK = 2314;

  /// The SQLITE_CONSTRAINT_VTAB error code is not currently used by the SQLite core. However, this error code is available for use by application-defined virtual tables.
  static const int SQLITE_CONSTRAINT_VTAB = 2323;

  /// The SQLITE_IOERR_UNLOCK error code is an extended error code for SQLITE_IOERR indicating an I/O error within xDelete method on the sqlite3_vfs object.
  static const int SQLITE_IOERR_DELETE = 2570;

  /// The SQLITE_CONSTRAINT_ROWID error code is an extended error code for SQLITE_CONSTRAINT indicating that a rowid is not unique.
  static const int SQLITE_CONSTRAINT_ROWID = 2579;

  /// The SQLITE_IOERR_BLOCKED error code is no longer used.
  static const int SQLITE_IOERR_BLOCKED = 2826;

  /// The SQLITE_CONSTRAINT_PINNED error code is an extended error code for SQLITE_CONSTRAINT indicating that an UPDATE trigger attempted do delete the row that was being updated in the middle of the update.
  static const int SQLITE_CONSTRAINT_PINNED = 2835;

  /// The SQLITE_IOERR_NOMEM error code is sometimes returned by the VFS layer to indicate that an operation could not be completed due to the inability to allocate sufficient memory. This error code is normally converted into SQLITE_NOMEM by the higher layers of SQLite before being returned to the application.
  static const int SQLITE_IOERR_NOMEM = 3082;

  /// The SQLITE_IOERR_ACCESS error code is an extended error code for SQLITE_IOERR indicating an I/O error within the xAccess method on the sqlite3_vfs object.
  static const int SQLITE_IOERR_ACCESS = 3338;

  /// The SQLITE_IOERR_CHECKRESERVEDLOCK error code is an extended error code for SQLITE_IOERR indicating an I/O error within the xCheckReservedLock method on the sqlite3_io_methods object.
  static const int SQLITE_IOERR_CHECKRESERVEDLOCK = 3594;

  /// The SQLITE_IOERR_LOCK error code is an extended error code for SQLITE_IOERR indicating an I/O error in the advisory file locking logic. Usually an SQLITE_IOERR_LOCK error indicates a problem obtaining a PENDING lock. However it can also indicate miscellaneous locking errors on some of the specialized VFSes used on Macs.
  static const int SQLITE_IOERR_LOCK = 3850;

  /// The SQLITE_IOERR_ACCESS error code is an extended error code for SQLITE_IOERR indicating an I/O error within the xClose method on the sqlite3_io_methods object.
  static const int SQLITE_IOERR_CLOSE = 4106;

  /// The SQLITE_IOERR_DIR_CLOSE error code is no longer used.
  static const int SQLITE_IOERR_DIR_CLOSE = 4362;

  /// The SQLITE_IOERR_SHMOPEN error code is an extended error code for SQLITE_IOERR indicating an I/O error within the xShmMap method on the sqlite3_io_methods object while trying to open a new shared memory segment.
  static const int SQLITE_IOERR_SHMOPEN = 4618;

  /// The SQLITE_IOERR_SHMSIZE error code is an extended error code for SQLITE_IOERR indicating an I/O error within the xShmMap method on the sqlite3_io_methods object while trying to enlarge a "shm" file as part of WAL mode transaction processing. This error may indicate that the underlying filesystem volume is out of space.
  static const int SQLITE_IOERR_SHMSIZE = 4874;

  /// The SQLITE_IOERR_SHMLOCK error code is no longer used.
  static const int SQLITE_IOERR_SHMLOCK = 5310;

  /// The SQLITE_IOERR_SHMMAP error code is an extended error code for SQLITE_IOERR indicating an I/O error within the xShmMap method on the sqlite3_io_methods object while trying to map a shared memory segment into the process address space.
  static const int SQLITE_IOERR_SHMMAP = 5386;

  /// The SQLITE_IOERR_SEEK error code is an extended error code for SQLITE_IOERR indicating an I/O error within the xRead or xWrite methods on the sqlite3_io_methods object while trying to seek a file descriptor to the beginning point of the file where the read or write is to occur.
  static const int SQLITE_IOERR_SEEK = 5642;

  /// The SQLITE_IOERR_DELETE_NOENT error code is an extended error code for SQLITE_IOERR indicating that the xDelete method on the sqlite3_vfs object failed because the file being deleted does not exist.
  static const int SQLITE_IOERR_DELETE_NOENT = 5898;

  /// The SQLITE_IOERR_MMAP error code is an extended error code for SQLITE_IOERR indicating an I/O error within the xFetch or xUnfetch methods on the sqlite3_io_methods object while trying to map or unmap part of the database file into the process address space.
  static const int SQLITE_IOERR_MMAP = 6154;

  /// The SQLITE_IOERR_GETTEMPPATH error code is an extended error code for SQLITE_IOERR indicating that the VFS is unable to determine a suitable directory in which to place temporary files.
  static const int SQLITE_IOERR_GETTEMPPATH = 6410;

  /// The SQLITE_IOERR_CONVPATH error code is an extended error code for SQLITE_IOERR used only by Cygwin VFS and indicating that the cygwin_conv_pathstatic const int ) system call failed. See also: SQLITE_CANTOPEN_CONVPATH
  static const int SQLITE_IOERR_CONVPATH = 6666;

  /// The SQLITE_IOERR_VNODE error code is a code reserved for use by extensions. It is not used by the SQLite core.
  static const int SQLITE_IOERR_VNODE = 6922;

  /// The SQLITE_IOERR_AUTH error code is a code reserved for use by extensions. It is not used by the SQLite core.
  static const int SQLITE_IOERR_AUTH = 7178;

  /// The SQLITE_IOERR_BEGIN_ATOMIC error code indicates that the underlying operating system reported and error on the SQLITE_FCNTL_BEGIN_ATOMIC_WRITE file-control. This only comes up when SQLITE_ENABLE_ATOMIC_WRITE is enabled and the database is hosted on a filesystem that supports atomic writes.
  static const int SQLITE_IOERR_BEGIN_ATOMIC = 7434;

  /// The SQLITE_IOERR_COMMIT_ATOMIC error code indicates that the underlying operating system reported and error on the SQLITE_FCNTL_COMMIT_ATOMIC_WRITE file-control. This only comes up when SQLITE_ENABLE_ATOMIC_WRITE is enabled and the database is hosted on a filesystem that supports atomic writes.
  static const int SQLITE_IOERR_COMMIT_ATOMIC = 7690;

  /// The SQLITE_IOERR_ROLLBACK_ATOMIC error code indicates that the underlying operating system reported and error on the SQLITE_FCNTL_ROLLBACK_ATOMIC_WRITE file-control. This only comes up when SQLITE_ENABLE_ATOMIC_WRITE is enabled and the database is hosted on a filesystem that supports atomic writes.
  static const int SQLITE_IOERR_ROLLBACK_ATOMIC = 7946;

  /// The SQLITE_IOERR_DATA error code is an extended error code for SQLITE_IOERR used only by checksum VFS shim to indicate that the checksum on a page of the database file is incorrect.
  static const int SQLITE_IOERR_DATA = 8202;
}

/// Flags for file open operations, https://www.sqlite.org/c3ref/c_open_autoproxy.html
/// Flags For File Open Operations
///
/// These bit values are intended for use in the
/// 3rd parameter to the [sqlite3_open_v2static const int )] interface and
/// in the 4th parameter to the `xopen` method.
final class SqlFlag {
  /// Ok for sqlite3_open_v2static const int )
  static const int SQLITE_OPEN_READONLY = 0x00000001;

  /// Ok for sqlite3_open_v2static const int )
  static const int SQLITE_OPEN_READWRITE = 0x00000002;

  /// Ok for sqlite3_open_v2static const int )
  static const int SQLITE_OPEN_CREATE = 0x00000004;

  /// VFS only
  static const int SQLITE_OPEN_DELETEONCLOSE = 0x00000008;

  /// VFS only
  static const int SQLITE_OPEN_EXCLUSIVE = 0x00000010;

  /// VFS only
  static const int SQLITE_OPEN_AUTOPROXY = 0x00000020;

  /// Ok for sqlite3_open_v2static const int )
  static const int SQLITE_OPEN_URI = 0x00000040;

  /// Ok for sqlite3_open_v2static const int )
  static const int SQLITE_OPEN_MEMORY = 0x00000080;

  /// VFS only
  static const int SQLITE_OPEN_MAIN_DB = 0x00000100;

  /// VFS only
  static const int SQLITE_OPEN_TEMP_DB = 0x00000200;

  /// VFS only
  static const int SQLITE_OPEN_TRANSIENT_DB = 0x00000400;

  /// VFS only
  static const int SQLITE_OPEN_MAIN_JOURNAL = 0x00000800;

  /// VFS only
  static const int SQLITE_OPEN_TEMP_JOURNAL = 0x00001000;

  /// VFS only
  static const int SQLITE_OPEN_SUBJOURNAL = 0x00002000;

  /// VFS only
  static const int SQLITE_OPEN_MASTER_JOURNAL = 0x00004000;

  /// Ok for sqlite3_open_v2static const int )
  static const int SQLITE_OPEN_NOMUTEX = 0x00008000;

  /// Ok for sqlite3_open_v2static const int )
  static const int SQLITE_OPEN_FULLMUTEX = 0x00010000;

  /// Ok for sqlite3_open_v2static const int )
  static const int SQLITE_OPEN_SHAREDCACHE = 0x00020000;

  /// Ok for sqlite3_open_v2static const int )
  static const int SQLITE_OPEN_PRIVATECACHE = 0x00040000;

  /// VFS only
  static const int SQLITE_OPEN_WAL = 0x00080000;
}

// Prepare flags, https://www.sqlite.org/c3ref/c_prepare_normalize.html
final class SqlPrepareFlag {
  ///The SQLITE_PREPARE_PERSISTENT flag is a hint to the query planner that the prepared statement will be retained for a long time and probably reused many times.
  /// Without this flag, sqlite3_prepare_v3static const int ) and sqlite3_prepare16_v3static const int ) assume that the prepared statement will be used just once or at most a few times and then destroyed using sqlite3_finalizestatic const int ) relatively soon.
  ///  The current implementation acts on this hint by avoiding the use of lookaside memory so as not to deplete the limited store of lookaside memory.
  ///Future versions of SQLite may act on this hint differently.
  static const int SQLITE_PREPARE_PERSISTENT = 0x01;

  ///The SQLITE_PREPARE_NORMALIZE flag is a no-op. This flag used to be required for any prepared statement that wanted to use the sqlite3_normalized_sqlstatic const int ) interface.
  /// However, the sqlite3_normalized_sqlstatic const int ) interface is now available to all prepared statements, regardless of whether or not they use this flag.
  static const int SQLITE_PREPARE_NORMALIZE = 0x02;

  ///the SQL compiler to return an error static const int error code SQLITE_ERROR) if the statement uses any virtual tables
  static const int SQLITE_PREPARE_NO_VTAB = 0x04;
}

/// Datatypes, https://sqlite.org/c3ref/c_blob.html
final class SqlType {
  static const int SQLITE_INTEGER = 1;
  static const int SQLITE_FLOAT = 2;
  static const int SQLITE_TEXT = 3;
  static const int SQLITE_BLOB = 4;
  static const int SQLITE_NULL = 5;
}

/// Text Encodings, https://www.sqlite.org/c3ref/c_any.html
/// These constant define integer codes that represent the various text encodings supported by SQLite.
final class SqlTextEncoding {
  ///IMP: R-37514-35566
  static const int SQLITE_UTF8 = 1;

  ///IMP: R-03371-37637
  static const int SQLITE_UTF16LE = 2;

  ///IMP: R-51971-34154
  static const int SQLITE_UTF16BE = 3;

  ///Use native byte order
  static const int SQLITE_UTF16 = 4;

  ///Deprecated
  static const int SQLITE_ANY = 5;

  ///qlite3_create_collation only
  static const int SQLITE_UTF16_ALIGNED = 8;
}

/// File lock levels, https://www.sqlite.org/c3ref/c_lock_exclusive.html
final class SqlFileLockingLevels {
  static const SQLITE_LOCK_NONE = 0;
  static const SQLITE_LOCK_SHARED = 1;
  static const SQLITE_LOCK_RESERVED = 2;
  static const SQLITE_LOCK_PENDING = 3;
  static const SQLITE_LOCK_EXCLUSIVE = 4;
}

/// Special destructors, https://www.sqlite.org/c3ref/c_static.html
final class SqlSpecialDestructor {
  /// it means that the content pointer is constant and will never change, It does not need to be destroyed
  static const SQLITE_STATIC = 0;

  ///The SQLITE_TRANSIENT value means that the content will likely change in the near future
  /// and that SQLite should make its own private copy of the content before returning.
  static const SQLITE_TRANSIENT = -1;
}

/// Function flags, https://www.sqlite.org/c3ref/c_deterministic.html
final class SqlFunctionFlag {
  /// The SQLITE_DETERMINISTIC flag means that the new function always gives the same output when the input parameters are the same
  static const SQLITE_DETERMINISTIC = 0x000000800;

  ///he SQLITE_DIRECTONLY flags is a security feature which is recommended for all application-defined SQL functions,
  /// and especially for functions that have side-effects or that could potentially leak sensitive information.
  static const SQLITE_DIRECTONLY = 0x000080000;

  ///The SQLITE_SUBTYPE flag indicates to SQLite that a function may call sqlite3_value_subtypestatic const int ) to inspect the sub-types of its arguments.
  static const SQLITE_SUBTYPE = 0x000100000;

  ///The SQLITE_INNOCUOUS flag means that the function is unlikely to cause problems even if misused.
  static const SQLITE_INNOCUOUS = 0x000200000;
}

final class SqlDeviceCharacteristics {
  static const SQLITE_IOCAP_UNDELETABLE_WHEN_OPEN = 0x00000800;
}

const SQLITE_DELETE = 9;
const SQLITE_INSERT = 18;
const SQLITE_UPDATE = 23;

final bigIntMinValue64 = BigInt.parse('-9223372036854775808');
final bigIntMaxValue64 = BigInt.parse('9223372036854775807');

// Connection config options https://www.sqlite.org/c3ref/c_dbconfig_defensive.html
const SQLITE_DBCONFIG_DQS_DML = 1013;
const SQLITE_DBCONFIG_DQS_DDL = 1014;
