import 'dart:js_interop';

import 'package:sqlite3/common.dart';
import 'package:sqlite3/src/wasm/sqlite3.dart';
import 'package:sqlite3_web/sqlite3_web.dart';

final class ExampleController extends DatabaseController {
  final bool isInWorker;

  ExampleController({required this.isInWorker});

  @override
  Future<JSAny?> handleCustomRequest(
      ClientConnection connection, JSAny? request) async {
    return null;
  }

  @override
  Future<WorkerDatabase> openDatabase(
      WasmSqlite3 sqlite3, String path, String vfs) async {
    final raw = sqlite3.open(path, vfs: vfs);
    raw.createFunction(
      functionName: 'database_host',
      function: (args) => isInWorker ? 'worker' : 'document',
      argumentCount: const AllowedArgumentCount(0),
    );
    return ExampleDatabase(database: raw);
  }
}

final class ExampleDatabase extends WorkerDatabase {
  @override
  final CommonDatabase database;

  ExampleDatabase({required this.database});

  @override
  Future<JSAny?> handleCustomRequest(
      ClientConnection connection, JSAny? request) async {
    return null;
  }
}
