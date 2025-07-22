import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:sqlite3/common.dart';
import 'package:sqlite3/wasm.dart' as wasm_vfs;
import 'package:web/web.dart';

import 'types.dart';
import 'channel.dart';

/// Signature of a function allowing structured data to be sent between JS
/// contexts.
typedef PostMessage = void Function(JSAny? msg, JSObject transfer);

enum MessageType<T extends Message> {
  dedicatedCompatibilityCheck<CompatibilityCheck>(),
  sharedCompatibilityCheck<CompatibilityCheck>(),
  dedicatedInSharedCompatibilityCheck<CompatibilityCheck>(),
  custom<CustomRequest>(),
  open<OpenRequest>(),
  runQuery<RunQuery>(),
  fileSystemExists<FileSystemExistsQuery>(),
  fileSystemAccess<FileSystemAccess>(),
  connect<ConnectRequest>(),
  startFileSystemServer<StartFileSystemServer>(),
  updateRequest<UpdateStreamRequest>(),
  simpleSuccessResponse<SimpleSuccessResponse>(),
  rowsResponse<RowsResponse>(),
  errorResponse<ErrorResponse>(),
  endpointResponse<EndpointResponse>(),
  closeDatabase<CloseDatabase>(),
  openAdditionalConnection<OpenAdditonalConnection>(),
  notifyUpdate<UpdateNotification>(),
  ;

  static final Map<String, MessageType> byName = values.asNameMap();
}

/// Field names used when serializing messages to JS objects.
///
/// Since we're using unsafe JS interop here, these can't be mangled by dart2js.
/// Thus, we should keep them short.
class _UniqueFieldNames {
  static const action = 'a';
  static const buffer = 'b';
  static const columnNames = 'c';
  static const databaseId = 'd';
  static const databaseName = 'd'; // no clash, used on different types
  static const errorMessage = 'e';
  static const fileType = 'f';
  static const id = 'i';
  static const updateKind = 'k';
  static const tableNames = 'n';
  static const parameters = 'p';
  static const storageMode = 's';
  static const sql = 's'; // not used in same message
  static const type = 't';
  static const wasmUri = 'u';
  static const updateTableName = 'u';
  static const responseData = 'r';
  static const returnRows = 'r';
  static const updateRowId = 'r';
  static const rows = 'r'; // no clash, used on different message types
}

sealed class Message {
  MessageType get type;

  static Message deserialize(JSObject object) {
    final type = MessageType
        .byName[(object[_UniqueFieldNames.type] as JSString).toDart]!;

    return switch (type) {
      MessageType.dedicatedCompatibilityCheck => CompatibilityCheck.deserialize(
          MessageType.dedicatedCompatibilityCheck, object),
      MessageType.sharedCompatibilityCheck => CompatibilityCheck.deserialize(
          MessageType.sharedCompatibilityCheck, object),
      MessageType.dedicatedInSharedCompatibilityCheck =>
        CompatibilityCheck.deserialize(
            MessageType.dedicatedInSharedCompatibilityCheck, object),
      MessageType.custom => CustomRequest.deserialize(object),
      MessageType.open => OpenRequest.deserialize(object),
      MessageType.startFileSystemServer =>
        StartFileSystemServer.deserialize(object),
      MessageType.runQuery => RunQuery.deserialize(object),
      MessageType.fileSystemExists => FileSystemExistsQuery.deserialize(object),
      MessageType.fileSystemAccess => FileSystemAccess.deserialize(object),
      MessageType.connect => ConnectRequest.deserialize(object),
      MessageType.closeDatabase => CloseDatabase.deserialize(object),
      MessageType.openAdditionalConnection =>
        OpenAdditonalConnection.deserialize(object),
      MessageType.updateRequest => UpdateStreamRequest.deserialize(object),
      MessageType.simpleSuccessResponse =>
        SimpleSuccessResponse.deserialize(object),
      MessageType.endpointResponse => EndpointResponse.deserialize(object),
      MessageType.rowsResponse => RowsResponse.deserialize(object),
      MessageType.errorResponse => ErrorResponse.deserialize(object),
      MessageType.notifyUpdate => UpdateNotification.deserialize(object),
    };
  }

  void serialize(JSObject object, List<JSObject> transferred) {
    object[_UniqueFieldNames.type] = type.name.toJS;
  }

  void sendTo(PostMessage sender) {
    final serialized = JSObject();
    final transfer = <JSObject>[];
    serialize(serialized, transfer);

    sender(serialized, transfer.toJS);
  }

  void sendToWorker(Worker worker) {
    sendTo((msg, transfer) => worker.postMessage(msg, transfer));
  }

  void sendToPort(MessagePort port) {
    sendTo((msg, transfer) => port.postMessage(msg, transfer));
  }

  void sendToClient(DedicatedWorkerGlobalScope worker) {
    sendTo((msg, transfer) => worker.postMessage(msg, transfer));
  }
}

sealed class Notification extends Message {}

sealed class Request extends Message {
  /// A unique id, incremented by each endpoint when making requests over the
  /// channel.
  int requestId;
  final int? databaseId;

  Request({required this.requestId, this.databaseId});

  @override
  void serialize(JSObject object, List<JSObject> transferred) {
    super.serialize(object, transferred);
    object[_UniqueFieldNames.id] = requestId.toJS;

    if (databaseId case final id?) {
      object[_UniqueFieldNames.databaseId] = id.toJS;
    }
  }

  Future<Response> tryRespond(FutureOr<Response> Function() function) async {
    try {
      return await function();
    } catch (e) {
      return ErrorResponse(message: e.toString(), requestId: requestId);
    }
  }
}

sealed class Response extends Message {
  /// The [Request.requestId] that this is a response of.
  final int requestId;

  Response({required this.requestId});

  @override
  void serialize(JSObject object, List<JSObject> transferred) {
    super.serialize(object, transferred);
    object[_UniqueFieldNames.id] = requestId.toJS;
  }

  RemoteException interpretAsError() {
    return RemoteException(message: 'Did not respond with expected type');
  }
}

enum FileSystemImplementation {
  opfsShared('s'),
  opfsLocks('l'),
  indexedDb('i'),
  inMemory('m');

  final String jsRepresentation;

  const FileSystemImplementation(this.jsRepresentation);

  JSString get toJS => jsRepresentation.toJS;

  static FileSystemImplementation fromJS(JSString js) {
    final toDart = js.toDart;

    for (final entry in values) {
      if (entry.jsRepresentation == toDart) return entry;
    }

    throw ArgumentError('Unknown FS implementation: $toDart');
  }
}

final class OpenRequest extends Request {
  final Uri wasmUri;

  final String databaseName;
  final FileSystemImplementation storageMode;

  OpenRequest({
    required super.requestId,
    required this.wasmUri,
    required this.databaseName,
    required this.storageMode,
  });

  factory OpenRequest.deserialize(JSObject object) {
    return OpenRequest(
      storageMode: FileSystemImplementation.fromJS(
          object[_UniqueFieldNames.storageMode] as JSString),
      databaseName: (object[_UniqueFieldNames.databaseName] as JSString).toDart,
      wasmUri:
          Uri.parse((object[_UniqueFieldNames.wasmUri] as JSString).toDart),
      requestId: object.requestId,
    );
  }

  @override
  MessageType<Message> get type => MessageType.open;

  @override
  void serialize(JSObject object, List<JSObject> transferred) {
    super.serialize(object, transferred);
    object[_UniqueFieldNames.databaseName] = databaseName.toJS;
    object[_UniqueFieldNames.storageMode] = storageMode.toJS;
    object[_UniqueFieldNames.wasmUri] = wasmUri.toString().toJS;
  }
}

/// Requests the receiving end of this message to connect to the channel
/// reachable through [endpoint].
///
/// This message it sent to dedicated and shared workers under their top-level
/// receive handler.
/// This can also be a request as part of an existing communication channel. In
/// that form, the client asks the receiver to forward the connect request to
/// a nested context. In particular, this is used for different tabs to connect
/// to a dedicated worker spawned by a shared worker.
/// As only dedicated workers can use synchronous file system APIs, this allows
/// different tabs to share a dedicated worker hosting a database with OPFS,
/// which is by far the most efficient way access dabases.
final class ConnectRequest extends Request {
  /// The endpoint under which the client is reachable.
  final WebEndpoint endpoint;

  ConnectRequest({required super.requestId, required this.endpoint});

  factory ConnectRequest.deserialize(JSObject object) {
    return ConnectRequest(
      requestId: object.requestId,
      endpoint: object[_UniqueFieldNames.responseData] as WebEndpoint,
    );
  }

  @override
  MessageType<Message> get type => MessageType.connect;

  @override
  void serialize(JSObject object, List<JSObject> transferred) {
    super.serialize(object, transferred);
    object[_UniqueFieldNames.responseData] = endpoint;
    transferred.add(endpoint.port);
  }
}

final class StartFileSystemServer extends Message {
  final wasm_vfs.WorkerOptions options;

  StartFileSystemServer({required this.options});

  factory StartFileSystemServer.deserialize(JSObject object) {
    return StartFileSystemServer(
        options:
            object[_UniqueFieldNames.responseData] as wasm_vfs.WorkerOptions);
  }

  @override
  MessageType<Message> get type => MessageType.startFileSystemServer;

  @override
  void serialize(JSObject object, List<JSObject> transferred) {
    super.serialize(object, transferred);
    object[_UniqueFieldNames.responseData] = options;
  }
}

/// Allows users of this package to implement their own RPC calls handled by
/// workers hosting the database.
final class CustomRequest extends Request {
  final JSAny? payload;

  CustomRequest({
    required super.requestId,
    required this.payload,
    super.databaseId,
  });

  factory CustomRequest.deserialize(JSObject object) {
    return CustomRequest(
      requestId: object.requestId,
      payload: object[_UniqueFieldNames.responseData],
      databaseId: object.hasProperty(_UniqueFieldNames.databaseId.toJS).toDart
          ? object.databaseId
          : null,
    );
  }

  @override
  MessageType<Message> get type => MessageType.custom;

  @override
  void serialize(JSObject object, List<JSObject> transferred) {
    super.serialize(object, transferred);
    object[_UniqueFieldNames.responseData] = payload;
  }
}

/// The other side will respond with a [SimpleSuccessResponse] containing a
/// boolean indicating whether the file exists.
final class FileSystemExistsQuery extends Request {
  final FileType fsType;

  @override
  MessageType<Message> get type => MessageType.fileSystemExists;

  FileSystemExistsQuery({
    required this.fsType,
    required super.databaseId,
    required super.requestId,
  });

  factory FileSystemExistsQuery.deserialize(JSObject object) {
    return FileSystemExistsQuery(
      fsType: FileType
          .values[(object[_UniqueFieldNames.fileType] as JSNumber).toDartInt],
      databaseId: object.databaseId,
      requestId: object.requestId,
    );
  }

  @override
  void serialize(JSObject object, List<JSObject> transferred) {
    super.serialize(object, transferred);
    object[_UniqueFieldNames.fileType] = fsType.index.toJS;
  }
}

/// Read or write to files of an opened database.
///
/// For reads, other side will respond with a [SimpleSuccessResponse] containing
/// the transferred buffer, which is cheap in JS because it gets moved.
/// For writes, the other side will respond with a [SimpleSuccessResponse]
/// not containing any value.
final class FileSystemAccess extends Request {
  /// For writes, the contents to write into the file. `null` for reads.
  final JSArrayBuffer? buffer;
  final FileType fsType;

  @override
  MessageType<Message> get type => MessageType.fileSystemAccess;

  FileSystemAccess({
    required super.databaseId,
    required super.requestId,
    required this.buffer,
    required this.fsType,
  });

  factory FileSystemAccess.deserialize(JSObject object) {
    return FileSystemAccess(
      databaseId: object.databaseId,
      requestId: object.requestId,
      buffer: object[_UniqueFieldNames.buffer] as JSArrayBuffer?,
      fsType: FileType
          .values[(object[_UniqueFieldNames.fileType] as JSNumber).toDartInt],
    );
  }

  @override
  void serialize(JSObject object, List<JSObject> transferred) {
    super.serialize(object, transferred);
    object[_UniqueFieldNames.buffer] = buffer;
    object[_UniqueFieldNames.fileType] = fsType.index.toJS;

    // false positive? dart2js seems to emit a null check as it should
    // ignore: pattern_never_matches_value_type
    if (buffer case final buffer?) {
      transferred.add(buffer);
    }
  }
}

final class RunQuery extends Request {
  final String sql;
  final List<Object?> parameters;
  final bool returnRows;

  RunQuery({
    required super.requestId,
    required int super.databaseId,
    required this.sql,
    required this.parameters,
    required this.returnRows,
  });

  factory RunQuery.deserialize(JSObject object) {
    return RunQuery(
      requestId: object.requestId,
      databaseId: object.databaseId,
      sql: (object[_UniqueFieldNames.sql] as JSString).toDart,
      parameters: [
        for (final raw
            in (object[_UniqueFieldNames.parameters] as JSArray).toDart)
          raw.dartify()
      ],
      returnRows: (object[_UniqueFieldNames.returnRows] as JSBoolean).toDart,
    );
  }

  @override
  MessageType<Message> get type => MessageType.runQuery;

  @override
  void serialize(JSObject object, List<JSObject> transferred) {
    super.serialize(object, transferred);
    object[_UniqueFieldNames.sql] = sql.toJS;
    object[_UniqueFieldNames.parameters] =
        <JSAny?>[for (final parameter in parameters) parameter.jsify()].toJS;
    object[_UniqueFieldNames.returnRows] = returnRows.toJS;
  }
}

final class CloseDatabase extends Request {
  CloseDatabase({required super.requestId, required super.databaseId});

  factory CloseDatabase.deserialize(JSObject object) {
    return CloseDatabase(
        requestId: object.requestId, databaseId: object.databaseId);
  }

  @override
  MessageType<Message> get type => MessageType.closeDatabase;
}

final class OpenAdditonalConnection extends Request {
  OpenAdditonalConnection({
    required super.requestId,
    super.databaseId,
  });

  factory OpenAdditonalConnection.deserialize(JSObject object) {
    return OpenAdditonalConnection(
      requestId: object.requestId,
      databaseId: object.databaseId,
    );
  }

  @override
  MessageType<Message> get type => MessageType.openAdditionalConnection;
}

final class SimpleSuccessResponse extends Response {
  final JSAny? response;

  SimpleSuccessResponse({required this.response, required super.requestId});

  factory SimpleSuccessResponse.deserialize(JSObject object) {
    return SimpleSuccessResponse(
      response: object[_UniqueFieldNames.responseData],
      requestId: object.requestId,
    );
  }

  @override
  MessageType<Message> get type => MessageType.simpleSuccessResponse;

  @override
  void serialize(JSObject object, List<JSObject> transferred) {
    super.serialize(object, transferred);
    object[_UniqueFieldNames.responseData] = response;
  }
}

final class EndpointResponse extends Response {
  final WebEndpoint endpoint;

  EndpointResponse({required super.requestId, required this.endpoint});

  factory EndpointResponse.deserialize(JSObject object) {
    return EndpointResponse(
      requestId: object.requestId,
      endpoint: object[_UniqueFieldNames.responseData] as WebEndpoint,
    );
  }

  @override
  MessageType<Message> get type => MessageType.endpointResponse;

  @override
  void serialize(JSObject object, List<JSObject> transferred) {
    super.serialize(object, transferred);
    object[_UniqueFieldNames.responseData] = endpoint;
    transferred.add(endpoint.port);
  }
}

final class RowsResponse extends Response {
  final ResultSet resultSet;

  RowsResponse({required this.resultSet, required super.requestId});

  factory RowsResponse.deserialize(JSObject object) {
    final columnNames = [
      for (final entry
          in (object[_UniqueFieldNames.columnNames] as JSArray).toDart)
        (entry as JSString).toDart
    ];
    final rawTableNames = object[_UniqueFieldNames.tableNames];
    final tableNames = rawTableNames != null
        ? [
            for (final entry in (rawTableNames as JSArray).toDart)
              (entry as JSString).toDart
          ]
        : null;

    final rows = <List<Object?>>[];
    for (final row in (object[_UniqueFieldNames.rows] as JSArray).toDart) {
      final dartRow = <Object?>[];

      for (final column in (row as JSArray).toDart) {
        dartRow.add(column.dartify());
      }

      rows.add(dartRow);
    }

    return RowsResponse(
      resultSet: ResultSet(columnNames, tableNames, rows),
      requestId: object.requestId,
    );
  }

  @override
  MessageType<Message> get type => MessageType.rowsResponse;

  @override
  void serialize(JSObject object, List<JSObject> transferred) {
    super.serialize(object, transferred);
    object[_UniqueFieldNames.rows] = <JSArray>[
      for (final row in resultSet.rows)
        <JSAny?>[
          for (final column in row) column.jsify(),
        ].toJS,
    ].toJS;

    object[_UniqueFieldNames.columnNames] = <JSString>[
      for (final entry in resultSet.columnNames) entry.toJS,
    ].toJS;

    if (resultSet.tableNames case var tableNames?) {
      object[_UniqueFieldNames.tableNames] = <JSString?>[
        for (final entry in tableNames) entry?.toJS,
      ].toJS;
    } else {
      object[_UniqueFieldNames.tableNames] = null;
    }
  }
}

final class ErrorResponse extends Response {
  final String message;

  ErrorResponse({required this.message, required super.requestId});

  factory ErrorResponse.deserialize(JSObject object) {
    return ErrorResponse(
      message: (object[_UniqueFieldNames.errorMessage] as JSString).toDart,
      requestId: object.requestId,
    );
  }

  @override
  MessageType<Message> get type => MessageType.errorResponse;

  @override
  void serialize(JSObject object, List<JSObject> transferred) {
    super.serialize(object, transferred);
    object[_UniqueFieldNames.errorMessage] = message.toJS;
  }

  @override
  RemoteException interpretAsError() {
    return RemoteException(message: message);
  }
}

final class UpdateStreamRequest extends Request {
  /// When true, the client is requesting to be informed about updates happening
  /// on the database identified by this request.
  ///
  /// When false, the client is requesting to no longer be informed about these
  /// updates.
  final bool action;

  UpdateStreamRequest(
      {required this.action,
      required super.requestId,
      required super.databaseId});

  factory UpdateStreamRequest.deserialize(JSObject object) {
    return UpdateStreamRequest(
      action: (object[_UniqueFieldNames.action] as JSBoolean).toDart,
      requestId: object.requestId,
      databaseId: object.databaseId,
    );
  }

  @override
  MessageType<Message> get type => MessageType.updateRequest;

  @override
  void serialize(JSObject object, List<JSObject> transferred) {
    super.serialize(object, transferred);
    object[_UniqueFieldNames.action] = action.toJS;
  }
}

class CompatibilityCheck extends Request {
  @override
  final MessageType<CompatibilityCheck> type;

  final String? databaseName;

  CompatibilityCheck({
    required super.requestId,
    required this.type,
    required this.databaseName,
  });

  factory CompatibilityCheck.deserialize(
      MessageType<CompatibilityCheck> type, JSObject object) {
    return CompatibilityCheck(
      type: type,
      requestId: object.requestId,
      databaseName:
          (object[_UniqueFieldNames.databaseName] as JSString?)?.toDart,
    );
  }

  bool get shouldCheckOpfsCompatibility {
    return type == MessageType.dedicatedCompatibilityCheck ||
        type == MessageType.dedicatedInSharedCompatibilityCheck;
  }

  bool get shouldCheckIndexedDbCompatbility {
    return type == MessageType.dedicatedCompatibilityCheck ||
        type == MessageType.sharedCompatibilityCheck;
  }

  @override
  void serialize(JSObject object, List<JSObject> transferred) {
    super.serialize(object, transferred);
    object[_UniqueFieldNames.databaseName] = databaseName?.toJS;
  }
}

final class CompatibilityResult {
  final List<ExistingDatabase> existingDatabases;

  // Fields set when a shared worker replies.

  /// Whether shared workers are allowed to spawn dedicated workers.
  ///
  /// As far as the web standard goes, they're supposed to. It allows us to
  /// spawn a dedicated worker using OPFS in the context of a shared worker,
  /// which is a very reliable storage implementation. Sadly, only Firefox has
  /// implemented this feature.
  final bool sharedCanSpawnDedicated;

  /// Whether dedicated workers can use OPFS.
  ///
  /// The file system API is only available in dedicated workers, so if they
  /// can't use it, the browser just likely doesn't support that API.
  final bool canUseOpfs;

  /// Whether IndexedDB is available to shared workers.
  ///
  /// On some browsers, IndexedDB is not available in private/incognito tabs.
  final bool canUseIndexedDb;

  /// Whether dedicated workers can use shared array buffers and the atomics
  /// API.
  ///
  /// This is required for the synchronous channel used to host an OPFS
  /// filesystem between threads. However, it is only available when the page is
  /// served with special headers for security purposes.
  final bool supportsSharedArrayBuffers;

  /// Whether dedicated workers can spawn their own dedicated workers.
  ///
  /// We need two dedicated workers with a synchronous channel between them to
  /// host an OPFS filesystem.
  final bool dedicatedWorkersCanNest;

  CompatibilityResult({
    required this.existingDatabases,
    required this.sharedCanSpawnDedicated,
    required this.canUseOpfs,
    required this.canUseIndexedDb,
    required this.supportsSharedArrayBuffers,
    required this.dedicatedWorkersCanNest,
  });

  factory CompatibilityResult.fromJS(JSObject result) {
    final existing = <ExistingDatabase>[];

    final encodedExisting = (result['a'] as JSArray<JSString>).toDart;
    for (var i = 0; i < encodedExisting.length / 2; i++) {
      final mode = StorageMode.values.byName(encodedExisting[i * 2].toDart);
      final name = encodedExisting[i * 2 + 1].toDart;

      existing.add((mode, name));
    }

    return CompatibilityResult(
      existingDatabases: existing,
      sharedCanSpawnDedicated: (result['b'] as JSBoolean).toDart,
      canUseOpfs: (result['c'] as JSBoolean).toDart,
      canUseIndexedDb: (result['d'] as JSBoolean).toDart,
      supportsSharedArrayBuffers: (result['e'] as JSBoolean).toDart,
      dedicatedWorkersCanNest: (result['f'] as JSBoolean).toDart,
    );
  }

  JSObject get toJS {
    final encodedDatabases = <JSString>[
      for (final existing in existingDatabases) ...[
        existing.$1.name.toJS,
        existing.$2.toJS
      ],
    ];

    return JSObject()
      ..['a'] = encodedDatabases.toJS
      ..['b'] = sharedCanSpawnDedicated.toJS
      ..['c'] = canUseOpfs.toJS
      ..['d'] = canUseIndexedDb.toJS
      ..['e'] = supportsSharedArrayBuffers.toJS
      ..['f'] = dedicatedWorkersCanNest.toJS;
  }
}

final class UpdateNotification extends Notification {
  final SqliteUpdate update;
  final int databaseId;

  UpdateNotification({required this.update, required this.databaseId});

  factory UpdateNotification.deserialize(JSObject object) {
    return UpdateNotification(
      update: SqliteUpdate(
        SqliteUpdateKind.values[
            (object[_UniqueFieldNames.updateKind] as JSNumber).toDartInt],
        (object[_UniqueFieldNames.updateTableName] as JSString).toDart,
        (object[_UniqueFieldNames.updateRowId] as JSNumber).toDartInt,
      ),
      databaseId: object.databaseId,
    );
  }

  @override
  MessageType<Message> get type => MessageType.notifyUpdate;

  @override
  void serialize(JSObject object, List<JSObject> transferred) {
    super.serialize(object, transferred);
    object[_UniqueFieldNames.databaseId] = databaseId.toJS;
    object[_UniqueFieldNames.updateKind] = update.kind.index.toJS;
    object[_UniqueFieldNames.updateTableName] = update.tableName.toJS;
    object[_UniqueFieldNames.updateRowId] = update.rowId.toJS;
  }
}

extension on JSObject {
  int get requestId {
    return (this[_UniqueFieldNames.id] as JSNumber).toDartInt;
  }

  int get databaseId {
    return (this[_UniqueFieldNames.databaseId] as JSNumber).toDartInt;
  }
}
