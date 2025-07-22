import 'dart:js_interop';

import 'package:sqlite3/wasm.dart';
import 'package:web/web.dart' hide FileSystem;

import 'types.dart';
import 'client.dart';
import 'worker.dart';

/// A controller responsible for opening databases in the worker.
abstract base class DatabaseController {
  /// Loads a wasm module from the given [uri] with the specified [headers].
  Future<WasmSqlite3> loadWasmModule(Uri uri,
      {Map<String, String>? headers}) async {
    return WasmSqlite3.loadFromUrl(uri, headers: headers);
  }

  /// Opens a database in the pre-configured [sqlite3] instance under the
  /// specified [path] in the given [vfs].
  ///
  /// This should virtually always call `sqlite3.open(path, vfs: vfs)` and wrap
  /// the result in a [WorkerDatabase] subclass.
  Future<WorkerDatabase> openDatabase(
      WasmSqlite3 sqlite3, String path, String vfs);

  /// Handles custom requests from clients that are not bound to a database.
  ///
  /// This is not currently used.
  Future<JSAny?> handleCustomRequest(
      ClientConnection connection, JSAny? request);
}

/// An endpoint that can be used, by any running JavaScript context in the same
/// website, to connect to an existing [Database].
///
/// These endpoints are created by calling [Database.additionalConnection] and
/// consist of a [MessagePort] and a [String] internally identifying the
/// connection. Both objects can be transferred over send ports towards another
/// worker or context. That context can then use [WebSqlite.connectToPort] to
/// connect to the port already opened.
typedef SqliteWebEndpoint = (MessagePort, String);

/// Abstraction over a database either available locally or in a remote worker.
abstract class Database {
  FileSystem get fileSystem;

  /// A relayed stream of [CommonDatabase.updates] from the remote worker.
  ///
  /// Updates are only sent across worker channels while a subscription to this
  /// stream is active.
  Stream<SqliteUpdate> get updates;

  /// A future that resolves when the database is closed.
  ///
  /// Typically, databases are closed because [dispose] is called. For databases
  /// opened with [WebSqlite.connectToPort] however, it's possible that the
  /// original worker hosting the database gets closed without this [Database]
  /// instance being explicitly [dispose]d. In those cases, monitoring [closed]
  /// is useful to react to databases closing.
  Future<void> get closed;

  /// Closes this database and instructs the worker to release associated
  /// resources.
  ///
  /// No methods may be called after a call to [dispose].
  Future<void> dispose();

  /// The rowid for the last insert operation made on this database.
  ///
  /// This calls [CommonDatabase.lastInsertRowId] in the worker.
  Future<int> get lastInsertRowId;

  /// The application-specific user version, mirroring
  /// [CommonDatabase.userVersion] being accessed in the remote worker.
  Future<int> get userVersion;
  Future<void> setUserVersion(int version);

  /// Prepares [sql] and executes it with the given [parameters].
  Future<void> execute(String sql, [List<Object?> parameters = const []]);

  /// Prepares [sql], executes it with the given [parameters] and returns the
  /// [ResultSet].
  Future<ResultSet> select(String sql, [List<Object?> parameters = const []]);

  /// Sends a custom request to the worker database.
  ///
  /// Custom requests are handled by implementing `handleCustomRequest` in your
  /// `WorkerDatabase` subclass.
  Future<JSAny?> customRequest(JSAny? request);

  /// Creates a [MessagePort] (a transferrable object that can be sent to
  /// another JavaScript context like a worker) that can be used with
  /// [WebSqlite.connectToPort] to open another instance of this database
  /// remotely.
  Future<SqliteWebEndpoint> additionalConnection();
}

/// A connection from a client from the perspective of a worker.
abstract class ClientConnection {
  /// The unique id for this connection.
  int get id;

  /// A future that completes when the connection get closed, for instance
  /// because the owning tab is closed.
  Future<void> get closed;

  /// Sends a custom request __towards the client__. This is not currently
  /// implemented.
  Future<JSAny?> customRequest(JSAny? request);
}

/// A [CommonDatabase] wrapped with functionality to handle custom requests.
abstract class WorkerDatabase {
  /// The database made available to the worker.
  CommonDatabase get database;

  /// Handles a custom [request] (encoded as any JS value) from the
  /// [connection].
  ///
  /// The response is sent over the channel and completes a
  /// [Database.customRequest] call for clients.
  Future<JSAny?> handleCustomRequest(
      ClientConnection connection, JSAny? request);
}

/// The result of [WebSqlite.connectToRecommended], containing the opened
/// [database] as well as the [FeatureDetectionResult] leading to that database
/// implementation being chosen.
final class ConnectToRecommendedResult {
  /// The opened [Database] hosted on another worker.
  final Database database;

  /// The missing or available browser features that lead to the current
  /// [storage] and [access] modes being selected.
  final FeatureDetectionResult features;

  /// The [StorageMode] storing contents for [database].
  final StorageMode storage;

  /// The [AccessMode] used to access teh [database] instance.
  final AccessMode access;

  ConnectToRecommendedResult({
    required this.database,
    required this.features,
    required this.storage,
    required this.access,
  });
}

/// Provides asynchronous access to databases hosted in web workers.
///
/// Please see the readme of the `sqlite3_web` package for an overview on how
/// to set up and use this package.
abstract class WebSqlite {
  /// Tries to find features related to storing and accessing databases.
  ///
  /// The [databaseName] can optionally be used to make
  /// [FeatureDetectionResult.existingDatabases] more reliable, as IndexedDB
  /// databases are not found otherwise.
  Future<FeatureDetectionResult> runFeatureDetection({String? databaseName});

  /// Connects to a database identified by its [name] stored under [type] and
  /// accessed via the given [access] mode.
  Future<Database> connect(String name, StorageMode type, AccessMode access);

  /// Starts a feature detection via [runFeatureDetection] and then [connect]s
  /// to the best database available.
  Future<ConnectToRecommendedResult> connectToRecommended(String name);

  /// Entrypoints for workers hosting datbases.
  static void workerEntrypoint({
    required DatabaseController controller,
  }) {
    WorkerRunner(controller).handleRequests();
  }

  /// Opens a [WebSqlite] instance by connecting to the given [worker] and
  /// using the [wasmModule] url to load sqlite3.
  static WebSqlite open({
    required Uri worker,
    required Uri wasmModule,
  }) {
    return DatabaseClient(worker, wasmModule);
  }

  /// Connects to an endpoint previously obtained with [Database.additionalConnection].
  ///
  /// As a [SqliteWebEndpoint] record only consists of fields that are
  /// transferrable in JavaScript, these endpoints can be sent to other workers,
  /// which can then call [connectToPort] to open a database connection
  /// originally established by another JavaScript connection.
  ///
  /// Note that, depending on the access mode, the returned [Database] may only
  /// be valid as long as the original [Database] where [Database.additionalConnection]
  /// was called. This limitation does not exist for databases hosted by shared
  /// workers.
  static Future<Database> connectToPort(SqliteWebEndpoint endpoint) {
    final client = DatabaseClient(Uri.base, Uri.base);
    return client.connectToExisting(endpoint);
  }
}
