import 'dart:typed_data';

/// A [StorageMode], name pair representing an existing database already stored
/// by the current browsing context.
typedef ExistingDatabase = (StorageMode, String);

/// Types of files persisted for databases by virtual file system
/// implementations.
enum FileType {
  /// The main database file.
  database,

  /// A journal file used to synchronize changes toe database file.
  journal,
}

/// Available locations to store database content in browsers.
enum StorageMode {
  // Note: Indices in this enum are used in the protocol, changing them is a
  // backwards-incompatible change.
  /// A origin-private folder provided by the file system access API.
  ///
  /// This is generally considered to be the most reliable way to store large
  /// data efficiently.
  opfs,

  /// A virtual file system implemented by splitting files into chunks which are
  /// then stored in IndexedDB.
  ///
  /// As sqlite3 expects a synchronous file system and IndexedDB is
  /// asynchronous, we maintain the illusion if synchronous access by keeping
  /// the entire database cached in memory and then flushing changes
  /// asynchronously.
  /// This technically looses durability, but is reasonably reliable in
  /// practice.
  indexedDb,

  /// Don't persist databases, instead keeping them in memory only.
  inMemory,
}

/// In addition to the [StorageMode] describing which browser API is used to
/// store content, this enum describes how databases are accessed.
enum AccessMode {
  /// Access databases by spawning a shared worker shared across tabs.
  ///
  /// This is more efficient as it avoids synchronization conflicts between tabs
  /// which may slow things down.
  throughSharedWorker,

  /// Access databases by spawning a dedicated worker for this tab.
  throughDedicatedWorker,

  /// Access databases without any shared or dedicated worker.
  inCurrentContext,
}

/// An exception thrown when a operation fails on the remote worker.
///
/// As the worker and the main tab have been compiled independently and don't
/// share a class hierarchy or object representations, it is impossible to send
/// typed exception objects. Instead, this exception wraps every error or
/// exception thrown by the remote worker and contains the [toString]
/// representation in [message].
final class RemoteException implements Exception {
  /// The [Object.toString] representation of the original exception.
  final String message;

  /// Creates a remote exception from the [message] thrown.
  RemoteException({required this.message});

  @override
  String toString() {
    return 'Remote error: $message';
  }
}

abstract class FileSystem {
  StorageMode get storage;
  String get databaseName;

  Future<bool> exists(FileType type);
  Future<Uint8List> readFile(FileType type);
  Future<void> writeFile(FileType type, Uint8List content);
}

/// An enumeration of features not supported by the current browsers.
///
/// While this information may not be useful to end users, it can be used to
/// understand why a particular file system implementation is unavailable.
enum MissingBrowserFeature {
  /// The browser is missing support for [shared workers].
  ///
  /// [shared workers]: https://developer.mozilla.org/en-US/docs/Web/API/SharedWorker
  sharedWorkers,

  /// The browser is missing support for [web workers] in general.
  ///
  /// [web workers]: https://developer.mozilla.org/en-US/docs/Web/API/Worker
  dedicatedWorkers,

  /// The browser doesn't allow shared workers to spawn dedicated workers in
  /// their context.
  ///
  /// While the specification for web workers explicitly allows this, this
  /// feature is only implemented by Firefox at the time of writing.
  dedicatedWorkersInSharedWorkers,

  /// The browser doesn't allow dedicated workers to spawn their own dedicated
  /// workers.
  dedicatedWorkersCanNest,

  /// The browser does not support a synchronous version of the [File System API]
  ///
  /// [File System API]: https://developer.mozilla.org/en-US/docs/Web/API/File_System_Access_API
  fileSystemAccess,

  /// The browser does not support IndexedDB.
  indexedDb,

  /// The browser does not support shared array buffers and `Atomics.wait`.
  ///
  /// To enable this feature in most browsers, you need to serve your app with
  /// two [special headers](https://web.dev/coop-coep/).
  sharedArrayBuffers,
}

/// The result of [WebSqlite.runFeatureDetection], describing which browsers
/// and databases are available in the current browser.
final class FeatureDetectionResult {
  /// A list of features that were probed and found to be unsupported in the
  /// current browser.
  final List<MissingBrowserFeature> missingFeatures;

  /// All existing databases that have been found.
  ///
  /// Databases are only found reliably when a database name is passed to
  /// [WebSqlite.runFeatureDetection].
  final List<ExistingDatabase> existingDatabases;

  /// All available [StorageMode], [AccessMode] pairs describing the databases
  /// supported by this browser.
  final List<(StorageMode, AccessMode)> availableImplementations;

  FeatureDetectionResult({
    required this.missingFeatures,
    required this.existingDatabases,
    required this.availableImplementations,
  });

  @override
  String toString() {
    return 'Existing: $existingDatabases, available: '
        '$availableImplementations, missing: $missingFeatures';
  }
}
