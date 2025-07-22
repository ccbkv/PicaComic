import 'database.dart';

/// Provides access to `sqlite3` functions, such as opening new databases.
abstract interface class CommonSqlite3 {
  /// The version of the sqlite3 library in used.
  Version get version;

  /// Opens a database file.
  ///
  /// The [vfs] option can be used to set the appropriate virtual file system
  /// implementation. When null, the default file system will be used.
  ///
  /// If [uri] is enabled (defaults to `false`), the [filename] will be
  /// interpreted as an uri as according to https://www.sqlite.org/uri.html.
  ///
  /// If the [mutex] parameter is set to true, the `SQLITE_OPEN_FULLMUTEX` flag
  /// will be set. If it's set to false, `SQLITE_OPEN_NOMUTEX` will be enabled.
  /// By default, neither parameter will be set.
  CommonDatabase open(
    String filename, {
    String? vfs,
    OpenMode mode = OpenMode.readWriteCreate,
    bool uri = false,
    bool? mutex,
  });

  /// Opens an in-memory database.
  CommonDatabase openInMemory();

  /// Accesses the `sqlite3_temp_directory` variable.
  ///
  /// Note that this operation might not be safe if a database connection is
  /// being used at the same time in different isolates.
  ///
  /// See also: https://www.sqlite.org/c3ref/temp_directory.html
  String? tempDirectory;
}

/// Version information about the sqlite3 library in use.
final class Version {
  /// A textual description of this sqlite version, such as '3.32.2'.
  final String libVersion;

  /// Detailed information about the source code of this sqlite build, which
  /// contains the Date of the latest change and a commit hash.
  final String sourceId;

  /// A numerical representation of [libVersion], such as `3032002`.
  final int versionNumber;

  /// Construct a version from the individual components.
  Version(this.libVersion, this.sourceId, this.versionNumber);

  @override
  String toString() {
    return 'Version(libVersion: $libVersion, sourceId: $sourceId, '
        'number: $versionNumber)';
  }
}

/// Controls how databases should be opened by sqlite
enum OpenMode {
  /// The database is opened in read-only mode. If the database does not already
  /// exist, an error is returned.
  readOnly,

  /// The database is opened for reading and writing if possible, or reading
  /// only if the file is write protected by the operating system. In either
  /// case the database must already exist, otherwise an error is returned.
  readWrite,

  /// The database is opened for reading and writing, and is created if it does
  /// not already exist
  readWriteCreate,
}
