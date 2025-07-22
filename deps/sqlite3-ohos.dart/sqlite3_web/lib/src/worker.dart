import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:sqlite3/wasm.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web/web.dart'
    show
        DedicatedWorkerGlobalScope,
        SharedWorkerGlobalScope,
        EventStreamProviders,
        MessagePort,
        MessageEvent,
        FileSystemDirectoryHandle,
        FileSystemFileHandle,
        FileSystemSyncAccessHandle,
        Worker;
// ignore: implementation_imports
import 'package:sqlite3/src/wasm/js_interop/new_file_system_access.dart';

import 'database.dart';
import 'channel.dart';
import 'protocol.dart';
import 'shared.dart';

sealed class WorkerEnvironment {
  WorkerEnvironment._();

  factory WorkerEnvironment() {
    final context = globalContext;
    if (context.instanceOfString('DedicatedWorkerGlobalScope')) {
      return Dedicated();
    } else {
      return Shared();
    }
  }

  /// Messages outside of a connection being posted to the worker or a connect
  /// port of a shared worker.
  ///
  /// We're not using them for actual channels, but instead have clients
  /// setup message ports which are then forwarded to workers using these
  /// top-level requests.
  Stream<Message> get topLevelRequests;
}

final class Dedicated extends WorkerEnvironment {
  final DedicatedWorkerGlobalScope scope;

  Dedicated()
      : scope = globalContext as DedicatedWorkerGlobalScope,
        super._();

  @override
  Stream<Message> get topLevelRequests {
    return EventStreamProviders.messageEvent.forTarget(scope).map((event) {
      return Message.deserialize(event.data as JSObject);
    });
  }
}

final class Shared extends WorkerEnvironment {
  final SharedWorkerGlobalScope scope;

  Shared()
      : scope = globalContext as SharedWorkerGlobalScope,
        super._();

  @override
  Stream<Message> get topLevelRequests {
    // Listen for connect events, then watch each connected port to send a a
    // connect message.
    // Tabs will only use one message port to this worker, but may use multiple
    // connections for different databases. So we're not using the connect port
    // for the actual connection and instead wait for clients to send message
    // ports through the connect port.
    return Stream.multi((listener) {
      final connectPorts = <MessagePort>[];
      final subscriptions = <StreamSubscription>[];

      void handlePort(MessagePort port) {
        connectPorts.add(port);
        port.start();

        subscriptions.add(
            EventStreamProviders.messageEvent.forTarget(port).listen((event) {
          listener.addSync(Message.deserialize(event.data as JSObject));
        }));
      }

      subscriptions.add(
          EventStreamProviders.connectEvent.forTarget(scope).listen((event) {
        for (final port in (event as MessageEvent).ports.toDart) {
          handlePort(port);
        }
      }));

      listener.onCancel = () {
        for (final subscription in subscriptions) {
          subscription.cancel();
        }
      };
    });
  }
}

/// A database opened by a client.
final class _ConnectionDatabase {
  final DatabaseState database;
  final int id;

  StreamSubscription<SqliteUpdate>? updates;

  _ConnectionDatabase(this.database, [int? id]) : id = id ?? database.id;

  Future<void> close() async {
    updates?.cancel();
    updates = null;

    await database.decrementRefCount();
  }
}

final class _ClientConnection extends ProtocolChannel
    implements ClientConnection {
  final WorkerRunner _runner;
  final List<_ConnectionDatabase> _openedDatabases = [];

  @override
  final int id;

  _ClientConnection(
      {required WorkerRunner runner,
      required StreamChannel<Message> channel,
      required this.id})
      : _runner = runner,
        super(channel) {
    closed.whenComplete(() async {
      for (final id in _openedDatabases) {
        await id.close();
      }
      _openedDatabases.clear();
    });
  }

  @override
  Future<Response> handleRequest(Request request) async {
    final database = _databaseFor(request);

    switch (request) {
      case CompatibilityCheck():
        return SimpleSuccessResponse(
          response: (await _runner.checkCompatibility(request)).toJS,
          requestId: request.requestId,
        );
      case ConnectRequest():
        final inner = _runner.useOrSpawnInnerWorker();
        ConnectRequest(endpoint: request.endpoint, requestId: 0)
            .sendToWorker(inner);

        return SimpleSuccessResponse(
            response: null, requestId: request.requestId);
      case CustomRequest():
        JSAny? response;

        if (database != null) {
          response = await (await database.database.opened)
              .handleCustomRequest(this, request.payload);
        } else {
          response = await _runner._controller
              .handleCustomRequest(this, request.payload);
        }

        return SimpleSuccessResponse(
            requestId: request.requestId, response: response);
      case OpenRequest():
        await _runner.loadWasmModule(request.wasmUri);
        DatabaseState? database;
        _ConnectionDatabase? connectionDatabase;

        try {
          database =
              _runner.findDatabase(request.databaseName, request.storageMode);
          await database.opened;
          connectionDatabase = _ConnectionDatabase(database);
          _openedDatabases.add(connectionDatabase);
          return SimpleSuccessResponse(
              response: database.id.toJS, requestId: request.requestId);
        } catch (e) {
          if (database != null) {
            _openedDatabases.remove(connectionDatabase);
            await database.decrementRefCount();
          }

          rethrow;
        }
      case RunQuery():
        final openedDatabase = await database!.database.opened;

        if (request.returnRows) {
          return RowsResponse(
            resultSet:
                openedDatabase.database.select(request.sql, request.parameters),
            requestId: request.requestId,
          );
        } else {
          openedDatabase.database.execute(request.sql, request.parameters);
          return SimpleSuccessResponse(
              response: null, requestId: request.requestId);
        }
      case UpdateStreamRequest(action: true):
        if (database!.updates == null) {
          final rawDatabase = await database.database.opened;
          database.updates ??= rawDatabase.database.updates.listen((event) {
            sendNotification(UpdateNotification(
                update: event, databaseId: database.database.id));
          });
        }
        return SimpleSuccessResponse(
            response: null, requestId: request.requestId);
      case UpdateStreamRequest(action: false):
        if (database!.updates != null) {
          database.updates?.cancel();
          database.updates = null;
        }
        return SimpleSuccessResponse(
            response: null, requestId: request.requestId);
      case OpenAdditonalConnection():
        final database = _databaseFor(request)!.database;
        database.refCount++;
        final (endpoint, channel) = await createChannel();

        final client = _runner._accept(channel);
        client._openedDatabases.add(_ConnectionDatabase(database, 0));

        return EndpointResponse(
            requestId: request.requestId, endpoint: endpoint);
      case CloseDatabase():
        _openedDatabases.remove(database!);
        await database.close();
        return SimpleSuccessResponse(
            response: null, requestId: request.requestId);
      case FileSystemExistsQuery():
        throw UnimplementedError();
      case FileSystemAccess():
        throw UnimplementedError();
    }
  }

  @override
  void handleNotification(Notification notification) {
    // There aren't supposed to be any notifications from the client.
  }

  @override
  Future<JSAny?> customRequest(JSAny? request) async {
    final response = await sendRequest(
        CustomRequest(requestId: 0, payload: request),
        MessageType.simpleSuccessResponse);
    return response.response;
  }

  _ConnectionDatabase? _databaseFor(Request request) {
    if (request.databaseId case final id?) {
      return _openedDatabases.firstWhere((e) => e.id == id);
    } else {
      return null;
    }
  }
}

final class DatabaseState {
  final WorkerRunner runner;
  final int id;
  final String name;
  final FileSystemImplementation mode;
  int refCount = 1;

  Future<WorkerDatabase>? _database;

  /// Runs additional async work, such as flushing the VFS to IndexedDB when
  /// the database is closed.
  FutureOr<void> Function()? closeHandler;
  VirtualFileSystem? vfs;

  DatabaseState(
      {required this.id,
      required this.runner,
      required this.name,
      required this.mode});

  Future<WorkerDatabase> get opened async {
    final database = _database ??= Future.sync(() async {
      final sqlite3 = await runner._sqlite3!;
      final vfsName = 'vfs-web-$id';

      switch (mode) {
        case FileSystemImplementation.opfsLocks:
          final options = WasmVfs.createOptions(root: pathForOpfs(name));
          final worker = Worker(Uri.base.toString().toJS);

          StartFileSystemServer(options: options).sendToWorker(worker);

          // Wait for the server worker to report that it's ready
          await EventStreamProviders.messageEvent.forTarget(worker).first;

          final wasmVfs =
              vfs = WasmVfs(workerOptions: options, vfsName: vfsName);
          closeHandler = wasmVfs.close;
        case FileSystemImplementation.opfsShared:
          final simple = vfs = await SimpleOpfsFileSystem.loadFromStorage(
              pathForOpfs(name),
              vfsName: vfsName);
          closeHandler = simple.close;
        case FileSystemImplementation.indexedDb:
          final idb = vfs =
              await IndexedDbFileSystem.open(dbName: name, vfsName: vfsName);
          closeHandler = idb.close;
        case FileSystemImplementation.inMemory:
          vfs = InMemoryFileSystem(name: vfsName);
      }

      sqlite3.registerVirtualFileSystem(vfs!);
      return await runner._controller.openDatabase(
        sqlite3,
        // We're currently using /database as the in-VFS path. This is because
        // we need to pre-open persistent files in SimpleOpfsFileSystem, and
        // that VFS only stores `/database` and `/database-journal`.
        // We still provide support for multiple databases by keeping multiple
        // VFS instances around.
        '/database',
        vfsName,
      );
    });

    return await database;
  }

  Future<void> decrementRefCount() async {
    if (--refCount == 0) {
      await close();
    }
  }

  Future<void> close() async {
    final sqlite3 = await runner._sqlite3!;
    final database = await _database!;

    database.database.dispose();
    if (vfs case final vfs?) {
      sqlite3.unregisterVirtualFileSystem(vfs);
    }

    await closeHandler?.call();
  }
}

final class WorkerRunner {
  final WorkerEnvironment _environment;
  final DatabaseController _controller;

  final List<_ClientConnection> _connections = [];
  var _nextConnectionId = 0;

  final Map<int, DatabaseState> openedDatabases = {};
  var _nextDatabaseId = 0;

  Future<WasmSqlite3>? _sqlite3;
  Uri? _wasmUri;

  final Lock _compatibilityCheckLock = Lock();
  CompatibilityResult? _compatibilityResult;

  /// For shared workers, a dedicated inner worker allowing tabs to connect to
  /// a shared context that can use synchronous JS APIs.
  Worker? _innerWorker;

  WorkerRunner(this._controller) : _environment = WorkerEnvironment();

  void handleRequests() async {
    await for (final message in _environment.topLevelRequests) {
      if (message is ConnectRequest) {
        final channel = message.endpoint.connect();
        _accept(channel);
      } else if (message is StartFileSystemServer) {
        final worker = await VfsWorker.create(message.options);
        // Inform the requester that the VFS is ready
        (_environment as Dedicated).scope.postMessage(true.toJS);
        await worker.start();
      } else if (message is CompatibilityCheck) {
        // A compatibility check message is sent to dedicated workers inside of
        // shared workers, we respond through the top-level port.
        final result = await checkCompatibility(message);
        (_environment as Dedicated).scope.postMessage(result.toJS);
      }
    }
  }

  _ClientConnection _accept(StreamChannel<Message> channel) {
    final connection = _ClientConnection(
        runner: this, channel: channel, id: _nextConnectionId++);
    _connections.add(connection);
    connection.closed.whenComplete(() => _connections.remove(connection));

    return connection;
  }

  Future<CompatibilityResult> checkCompatibility(CompatibilityCheck check) {
    return _compatibilityCheckLock.synchronized(() async {
      if (_compatibilityResult != null) {
        // todo: We may have to update information about existing databases
        // as they come and go
        return _compatibilityResult!;
      }

      var supportsOpfs =
          check.shouldCheckOpfsCompatibility ? await checkOpfsSupport() : false;
      final supportsIndexedDb = check.shouldCheckIndexedDbCompatbility
          ? await checkIndexedDbSupport()
          : false;

      var sharedCanSpawnDedicated = false;

      if (check.type == MessageType.sharedCompatibilityCheck) {
        if (globalContext.has('Worker')) {
          sharedCanSpawnDedicated = true;

          final worker = useOrSpawnInnerWorker();
          CompatibilityCheck(
            databaseName: check.databaseName,
            type: MessageType.dedicatedInSharedCompatibilityCheck,
            requestId: 0,
          ).sendToWorker(worker);

          final response =
              await EventStreamProviders.messageEvent.forTarget(worker).first;
          final result = CompatibilityResult.fromJS(response.data as JSObject);

          supportsOpfs = result.canUseOpfs;
        }
      }

      return CompatibilityResult(
        existingDatabases: const [], // todo
        sharedCanSpawnDedicated: sharedCanSpawnDedicated,
        canUseOpfs: supportsOpfs,
        canUseIndexedDb: supportsIndexedDb,
        supportsSharedArrayBuffers: globalContext.has('SharedArrayBuffer'),
        dedicatedWorkersCanNest: globalContext.has('Worker'),
      );
    });
  }

  Future<void> loadWasmModule(Uri uri) async {
    if (_sqlite3 != null) {
      if (_wasmUri != uri) {
        throw StateError(
            'Workers only support a single sqlite3 wasm module, provided '
            'different URI (has $_wasmUri, got $uri)');
      }

      await _sqlite3;
    } else {
      final future = _sqlite3 =
          _controller.loadWasmModule(uri).onError((error, stackTrace) {
        _sqlite3 = null;
        throw error!;
      });
      await future;
      _wasmUri = uri;
    }
  }

  DatabaseState findDatabase(String name, FileSystemImplementation mode) {
    for (final existing in openedDatabases.values) {
      if (existing.refCount != 0 &&
          existing.name == name &&
          existing.mode == mode) {
        existing.refCount++;
        return existing;
      }
    }

    final id = _nextDatabaseId++;
    return openedDatabases[id] = DatabaseState(
      id: id,
      runner: this,
      name: name,
      mode: mode,
    );
  }

  Worker useOrSpawnInnerWorker() {
    return _innerWorker ??= Worker(Uri.base.toString().toJS);
  }
}

/// Checks whether the OPFS API is likely to be correctly implemented in the
/// current browser.
///
/// Since OPFS uses the synchronous file system access API, this method can only
/// return true when called in a dedicated worker.
Future<bool> checkOpfsSupport() async {
  final storage = storageManager;
  if (storage == null) return false;

  const testFileName = '_drift_feature_detection';

  FileSystemDirectoryHandle? opfsRoot;
  FileSystemFileHandle? fileHandle;
  JSObject? openedFile;

  try {
    opfsRoot = await storage.directory;

    fileHandle = await opfsRoot.openFile(testFileName, create: true);
    openedFile = await fileHandle.createSyncAccessHandle().toDart;

    // In earlier versions of the OPFS standard, some methods like `getSize()`
    // on a sync file handle have actually been asynchronous. We don't support
    // Browsers that implement the outdated spec.
    final getSizeResult = openedFile.callMethod('getSize'.toJS);
    if (getSizeResult.typeofEquals('object')) {
      // Returned a promise, that's no good.
      await (getSizeResult as JSPromise).toDart;
      return false;
    }

    return true;
  } on Object {
    return false;
  } finally {
    if (openedFile != null) {
      (openedFile as FileSystemSyncAccessHandle).close();
    }

    if (opfsRoot != null && fileHandle != null) {
      await opfsRoot.remove(testFileName);
    }
  }
}

/// Collects all drift OPFS databases.
Future<List<String>> opfsDatabases() async {
  final storage = storageManager;
  if (storage == null) return const [];

  var directory = await storage.directory;
  try {
    directory = await directory.getDirectory('drift_db');
  } on Object {
    // The drift_db folder doesn't exist, so there aren't any databases.
    return const [];
  }

  return [
    await for (final entry in directory.list())
      if (entry.isDirectory) entry.name,
  ];
}

/// Constructs the path used by drift to store a database in the origin-private
/// section of the agent's file system.
String pathForOpfs(String databaseName) {
  return 'drift_db/$databaseName';
}

/// Deletes the OPFS folder storing a database with the given [databaseName] if
/// such folder exists.
Future<void> deleteDatabaseInOpfs(String databaseName) async {
  final storage = storageManager;
  if (storage == null) return;

  var directory = await storage.directory;
  try {
    directory = await directory.getDirectory('drift_db');
    await directory.remove(databaseName, recursive: true);
  } on Object {
    // fine, an error probably means that the database didn't exist in the first
    // place.
  }
}
