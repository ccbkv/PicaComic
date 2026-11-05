import 'dart:async';
import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

Database openSqliteDatabase(
  String path, {
  OpenMode mode = OpenMode.readWriteCreate,
}) {
  final db = sqlite3.open(path, mode: mode);
  try {
    if (mode != OpenMode.readOnly) {
      db.execute('PRAGMA foreign_keys = ON;');
      db.execute('PRAGMA journal_mode = WAL;');
      db.execute('PRAGMA wal_autocheckpoint = 200;');
      db.execute('PRAGMA synchronous = NORMAL;');
      db.execute('PRAGMA busy_timeout = 5000;');
    }
  } catch (_) {
    db.dispose();
    rethrow;
  }
  return db;
}

Future<T> withDatabase<T>(
  String path,
  FutureOr<T> Function(Database db) op, {
  OpenMode mode = OpenMode.readWriteCreate,
}) async {
  final db = openSqliteDatabase(path, mode: mode);
  try {
    return await op(db);
  } finally {
    db.dispose();
  }
}

class DatabaseGateway {
  DatabaseGateway._();

  static final DatabaseGateway instance = DatabaseGateway._();

  Future<void> _tail = Future.value();

  Future<T> isolateOp<T>(
    String path,
    FutureOr<T> Function(Database db) op, {
    OpenMode mode = OpenMode.readWriteCreate,
  }) {
    return guardedRead(
      () => Isolate.run(() => withDatabase(path, op, mode: mode)),
    );
  }

  Future<T> guardedRead<T>(Future<T> Function() op) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    return previous.then((_) => op()).whenComplete(done.complete);
  }

  Future<T> runExclusive<T>(Future<T> Function() op) async {
    final previous = _tail;
    final gate = Completer<void>();
    _tail = gate.future;
    await previous;
    try {
      return await op();
    } finally {
      gate.complete();
    }
  }
}
