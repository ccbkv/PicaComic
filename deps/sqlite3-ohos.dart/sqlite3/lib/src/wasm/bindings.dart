import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:sqlite3/src/vfs.dart';

import '../constants.dart';
import '../functions.dart';
import '../implementation/bindings.dart';
import 'wasm_interop.dart' as wasm;
import 'wasm_interop.dart';

// ignore_for_file: non_constant_identifier_names

final class WasmSqliteBindings extends RawSqliteBindings {
  final wasm.WasmBindings bindings;

  WasmSqliteBindings(this.bindings);

  @override
  String? get sqlite3_temp_directory {
    final charPtr = bindings.sqlite3_temp_directory;
    if (charPtr == 0) {
      return null;
    } else {
      return bindings.memory.readString(charPtr);
    }
  }

  @override
  set sqlite3_temp_directory(String? value) {
    if (value == null) {
      bindings.sqlite3_temp_directory = 0;
    } else {
      bindings.sqlite3_temp_directory = bindings.allocateZeroTerminated(value);
    }
  }

  @override
  String sqlite3_errstr(int extendedErrorCode) {
    return bindings.memory
        .readString(bindings.sqlite3_errstr(extendedErrorCode));
  }

  @override
  String sqlite3_libversion() {
    return bindings.memory.readString(bindings.sqlite3_libversion());
  }

  @override
  int sqlite3_libversion_number() {
    return bindings.sqlite3_libversion_number();
  }

  @override
  SqliteResult<RawSqliteDatabase> sqlite3_open_v2(
      String name, int flags, String? zVfs) {
    final namePtr = bindings.allocateZeroTerminated(name);
    final outDb = bindings.malloc(wasm.WasmBindings.pointerSize);
    final vfsPtr = zVfs == null ? 0 : bindings.allocateZeroTerminated(zVfs);

    final result = bindings.sqlite3_open_v2(namePtr, outDb, flags, vfsPtr);
    final dbPtr = bindings.memory.int32ValueOfPointer(outDb);

    // Free pointers we allocateed
    bindings
      ..free(namePtr)
      ..free(vfsPtr);
    if (zVfs != null) bindings.free(vfsPtr);

    return SqliteResult(result, WasmDatabase(bindings, dbPtr));
  }

  @override
  String sqlite3_sourceid() {
    return bindings.memory.readString(bindings.sqlite3_sourceid());
  }

  void registerVirtualFileSystem(VirtualFileSystem vfs, int makeDefault) {
    final name = bindings.allocateZeroTerminated(vfs.name);
    final id = bindings.callbacks.registerVfs(vfs);

    final ptr = bindings.dart_sqlite3_register_vfs(name, id, makeDefault);
    DartCallbacks.sqliteVfsPointer[vfs] = ptr;
  }

  void unregisterVirtualFileSystem(VirtualFileSystem vfs) {
    final ptr = DartCallbacks.sqliteVfsPointer[vfs];
    if (ptr == null) {
      throw StateError('vfs has not been registered');
    }

    // zName field is the fifth field, after the (word-sized) iVersion, szOsFile,
    // maxPathname and pNext pointers.
    final zNamePtr = ptr + 4 * 4;
    final pAppDataPtr = zNamePtr + 4;

    bindings.sqlite3_vfs_unregister(ptr);
    bindings.free(zNamePtr);

    final dartId = bindings.memory.int32ValueOfPointer(pAppDataPtr);
    bindings.callbacks.registeredVfs.remove(dartId);
  }
}

final class WasmDatabase extends RawSqliteDatabase {
  final wasm.WasmBindings bindings;
  final wasm.Pointer db;

  WasmDatabase(this.bindings, this.db);

  @override
  int sqlite3_close_v2() {
    return bindings.sqlite3_close_v2(db);
  }

  @override
  String sqlite3_errmsg() {
    return bindings.memory.readString(bindings.sqlite3_errmsg(db));
  }

  @override
  int sqlite3_extended_errcode() {
    return bindings.sqlite3_extended_errcode(db);
  }

  @override
  void sqlite3_extended_result_codes(int onoff) {
    bindings.sqlite3_extended_result_codes(db, onoff);
  }

  @override
  void deallocateAdditionalMemory() {}

  @override
  RawStatementCompiler newCompiler(List<int> utf8EncodedSql) {
    final ptr = bindings.allocateBytes(utf8EncodedSql);

    return WasmStatementCompiler(this, ptr);
  }

  @override
  int sqlite3_changes() => bindings.sqlite3_changes(db);

  @override
  int sqlite3_create_collation_v2({
    required Uint8List collationName,
    required int eTextRep,
    required RawCollation collation,
  }) {
    final ptr = bindings.allocateBytes(collationName, additionalLength: 1);
    final result = bindings.create_collation(
        db,
        ptr,
        eTextRep,
        bindings.callbacks.register(RegisteredFunctionSet(
          collation: collation,
        )));

    bindings.free(ptr);
    return result;
  }

  @override
  int sqlite3_create_function_v2({
    required Uint8List functionName,
    required int nArg,
    required int eTextRep,
    RawXFunc? xFunc,
    RawXStep? xStep,
    RawXFinal? xFinal,
  }) {
    final ptr = bindings.allocateBytes(functionName, additionalLength: 1);

    final int result;
    if (xFunc != null) {
      // Scalar function
      result = bindings.create_scalar_function(
        db,
        ptr,
        nArg,
        eTextRep,
        bindings.callbacks.register(RegisteredFunctionSet(xFunc: xFunc)),
      );
    } else {
      // Aggregate function
      result = bindings.create_aggregate_function(
        db,
        ptr,
        nArg,
        eTextRep,
        bindings.callbacks.register(
          RegisteredFunctionSet(xStep: xStep, xFinal: xFinal),
        ),
      );
    }

    bindings.free(ptr);
    return result;
  }

  @override
  int sqlite3_create_window_function({
    required Uint8List functionName,
    required int nArg,
    required int eTextRep,
    required RawXStep xStep,
    required RawXFinal xFinal,
    required RawXFinal xValue,
    required RawXStep xInverse,
  }) {
    final ptr = bindings.allocateBytes(functionName, additionalLength: 1);
    final result = bindings.create_window_function(
        db,
        ptr,
        nArg,
        eTextRep,
        bindings.callbacks.register(RegisteredFunctionSet(
          xStep: xStep,
          xFinal: xFinal,
          xValue: xValue,
          xInverse: xInverse,
        )));

    bindings.free(ptr);
    return result;
  }

  @override
  int sqlite3_exec(String sql) {
    final stmt = bindings.allocateZeroTerminated(sql);
    final result = bindings.sqlite3_exec(db, stmt, 0, 0, 0);
    bindings.free(stmt);
    return result;
  }

  @override
  int sqlite3_last_insert_rowid() {
    return bindings.sqlite3_last_insert_rowid(db);
  }

  @override
  void sqlite3_update_hook(RawUpdateHook? hook) {
    bindings.callbacks.installedUpdateHook = hook;

    bindings.dart_sqlite3_updates(db, hook != null ? 1 : -1);
  }

  @override
  int sqlite3_get_autocommit() {
    return bindings.sqlite3_get_autocommit(db);
  }

  @override
  int sqlite3_db_config(int op, int value) {
    return bindings.sqlite3_db_config(db, op, value);
  }
}

final class WasmStatementCompiler extends RawStatementCompiler {
  final WasmDatabase database;
  final Pointer sql;
  final Pointer stmtOut;
  final Pointer pzTail;

  WasmStatementCompiler(this.database, this.sql)
      : stmtOut = database.bindings.malloc(WasmBindings.pointerSize),
        pzTail = database.bindings.malloc(WasmBindings.pointerSize);

  @override
  void close() {
    database.bindings
      ..free(sql)
      ..free(stmtOut)
      ..free(pzTail);
  }

  @override
  int get endOffset {
    final bindings = database.bindings;
    return bindings.memory.int32ValueOfPointer(pzTail) - sql;
  }

  @override
  SqliteResult<RawSqliteStatement?> sqlite3_prepare(
      int byteOffset, int length, int prepFlag) {
    final result = database.bindings.sqlite3_prepare_v3(
      database.db,
      sql + byteOffset,
      length,
      prepFlag,
      stmtOut,
      pzTail,
    );

    final stmt = database.bindings.memory.int32ValueOfPointer(stmtOut);
    final libraryStatement = stmt == 0 ? null : WasmStatement(database, stmt);

    return SqliteResult(result, libraryStatement);
  }
}

final class WasmStatement extends RawSqliteStatement {
  final WasmDatabase database;
  final Pointer stmt;
  final WasmBindings bindings;

  final List<Pointer> _allocatedArguments = [];

  WasmStatement(this.database, this.stmt) : bindings = database.bindings;

  @override
  void deallocateArguments() {
    for (final arg in _allocatedArguments) {
      bindings.free(arg);
    }
    _allocatedArguments.clear();
  }

  @override
  void sqlite3_bind_blob64(int index, List<int> value) {
    final ptr = bindings.allocateBytes(value);
    _allocatedArguments.add(ptr);

    bindings.sqlite3_bind_blob64(stmt, index, ptr, value.length, 0);
  }

  @override
  void sqlite3_bind_double(int index, double value) {
    bindings.sqlite3_bind_double(stmt, index, value);
  }

  @override
  void sqlite3_bind_int64(int index, int value) {
    bindings.sqlite3_bind_int(stmt, index, value);
  }

  @override
  void sqlite3_bind_int64BigInt(int index, BigInt value) {
    bindings.sqlite3_bind_int64(stmt, index, value);
  }

  @override
  void sqlite3_bind_null(int index) {
    bindings.sqlite3_bind_null(stmt, index);
  }

  @override
  int sqlite3_bind_parameter_count() {
    return bindings.sqlite3_bind_parameter_count(stmt);
  }

  @override
  int sqlite3_stmt_isexplain() {
    return bindings.sqlite3_stmt_isexplain(stmt);
  }

  @override
  int sqlite3_stmt_readonly() {
    return bindings.sqlite3_stmt_readonly(stmt);
  }

  @override
  int sqlite3_bind_parameter_index(String name) {
    final namePtr = bindings.allocateZeroTerminated(name);

    final result = bindings.sqlite3_bind_parameter_index(stmt, namePtr);
    bindings.free(namePtr);

    return result;
  }

  @override
  void sqlite3_bind_text(int index, String value) {
    final encoded = utf8.encode(value);
    final ptr = bindings.allocateBytes(encoded);
    _allocatedArguments.add(ptr);

    bindings.sqlite3_bind_text(stmt, index, ptr, encoded.length, 0);
  }

  @override
  Uint8List sqlite3_column_bytes(int index) {
    final length = bindings.sqlite3_column_bytes(stmt, index);
    final ptr = bindings.sqlite3_column_blob(stmt, index);

    return bindings.memory.copyRange(ptr, length);
  }

  @override
  int sqlite3_column_count() {
    return bindings.sqlite3_column_count(stmt);
  }

  @override
  double sqlite3_column_double(int index) {
    return bindings.sqlite3_column_double(stmt, index);
  }

  @override
  int sqlite3_column_int64(int index) {
    final jsBigInt = bindings.sqlite3_column_int64(stmt, index);
    return jsBigInt.asDartInt;
  }

  @override
  Object sqlite3_column_int64OrBigInt(int index) {
    final jsBigInt = bindings.sqlite3_column_int64(stmt, index);
    return jsBigInt.toDart();
  }

  @override
  String sqlite3_column_name(int index) {
    final namePtr = bindings.sqlite3_column_name(stmt, index);
    return bindings.memory.readString(namePtr);
  }

  @override
  String? sqlite3_column_table_name(int index) {
    return null;
  }

  @override
  String sqlite3_column_text(int index) {
    final ptr = bindings.sqlite3_column_text(stmt, index);
    return bindings.memory.readString(ptr);
  }

  @override
  int sqlite3_column_type(int index) {
    return bindings.sqlite3_column_type(stmt, index);
  }

  @override
  void sqlite3_finalize() {
    bindings.sqlite3_finalize(stmt);
  }

  @override
  void sqlite3_reset() {
    bindings.sqlite3_reset(stmt);
  }

  @override
  int sqlite3_step() {
    return bindings.sqlite3_step(stmt);
  }

  @override
  bool get supportsReadingTableNameForColumn => false;
}

final class WasmContext extends RawSqliteContext {
  final WasmBindings bindings;
  final Pointer context;
  final DartCallbacks callbacks;

  WasmContext(this.bindings, this.context, this.callbacks);

  Pointer get _rawAggregateContext {
    final agCtxPtr = bindings.sqlite3_aggregate_context(context, 4);

    if (agCtxPtr == 0) {
      // We can't run without our 4 bytes! This indicates an out-of-memory error
      throw StateError(
          'Internal error while allocating sqlite3 aggregate context (OOM?)');
    }

    return agCtxPtr;
  }

  @override
  AggregateContext<Object?>? get dartAggregateContext {
    final agCtxPtr = _rawAggregateContext;
    final value = bindings.memory.int32ValueOfPointer(agCtxPtr);

    // Ok, we have a pointer (that sqlite3 zeroes out for us). Our state counter
    // starts at one, so if it's still zero we don't have a Dart context yet.
    if (value == 0) {
      return null;
    } else {
      return callbacks.aggregateContexts[value];
    }
  }

  @override
  set dartAggregateContext(AggregateContext<Object?>? value) {
    final ptr = _rawAggregateContext;
    final id = callbacks.aggregateContextId++;
    callbacks.aggregateContexts[id] = ArgumentError.checkNotNull(value);

    bindings.memory.setInt32Value(ptr, id);
  }

  @override
  void sqlite3_result_blob64(List<int> blob) {
    final ptr = bindings.allocateBytes(blob);

    bindings.sqlite3_result_blob64(
        context, ptr, blob.length, SqlSpecialDestructor.SQLITE_TRANSIENT);
    bindings.free(ptr);
  }

  @override
  void sqlite3_result_double(double value) {
    return bindings.sqlite3_result_double(context, value);
  }

  @override
  void sqlite3_result_error(String message) {
    final encoded = utf8.encode(message);
    final ptr = bindings.allocateBytes(encoded);

    bindings.sqlite3_result_error(context, ptr, encoded.length);
    bindings.free(ptr);
  }

  @override
  void sqlite3_result_int64(int value) {
    bindings.sqlite3_result_int64(context, BigInt.from(value));
  }

  @override
  void sqlite3_result_int64BigInt(BigInt value) {
    bindings.sqlite3_result_int64(context, value);
  }

  @override
  void sqlite3_result_null() {
    return bindings.sqlite3_result_null(context);
  }

  @override
  void sqlite3_result_text(String text) {
    final encoded = utf8.encode(text);
    final ptr = bindings.allocateBytes(encoded);

    bindings.sqlite3_result_text(
        context, ptr, encoded.length, SqlSpecialDestructor.SQLITE_TRANSIENT);
    bindings.free(ptr);
  }
}

final class WasmValue extends RawSqliteValue {
  final WasmBindings bindings;
  final Pointer value;

  WasmValue(this.bindings, this.value);

  @override
  Uint8List sqlite3_value_blob() {
    final length = bindings.sqlite3_value_bytes(value);
    return bindings.memory
        .copyRange(bindings.sqlite3_value_blob(value), length);
  }

  @override
  double sqlite3_value_double() {
    return bindings.sqlite3_value_double(value);
  }

  @override
  int sqlite3_value_int64() {
    return bindings.sqlite3_value_int64(value).asDartInt;
  }

  @override
  String sqlite3_value_text() {
    final length = bindings.sqlite3_value_bytes(value);
    return bindings.memory
        .readString(bindings.sqlite3_value_text(value), length);
  }

  @override
  int sqlite3_value_type() {
    return bindings.sqlite3_value_type(value);
  }
}

class WasmValueList extends ListBase<WasmValue> {
  final WasmBindings bindings;
  @override
  final int length;
  final Pointer value;

  WasmValueList(this.bindings, this.length, this.value);

  @override
  set length(int value) {
    throw UnsupportedError('Setting length in WasmValueList');
  }

  @override
  WasmValue operator [](int index) {
    final valuePtr = bindings.memory
        .int32ValueOfPointer(value + index * WasmBindings.pointerSize);
    return WasmValue(bindings, valuePtr);
  }

  @override
  void operator []=(int index, WasmValue value) {
    throw UnsupportedError('Setting element in WasmValueList');
  }
}
