import 'dart:collection';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../constants.dart';
import '../functions.dart';
import '../implementation/bindings.dart';
import 'memory.dart';
import 'sqlite3.g.dart';

// ignore_for_file: non_constant_identifier_names

class BindingsWithLibrary {
  // sqlite3_prepare_v3 was added in 3.20.0
  static const int _firstVersionForV3 = 3020000;

  final Bindings bindings;
  final DynamicLibrary library;

  final bool supportsPrepareV3;
  final bool supportsColumnTableName;

  factory BindingsWithLibrary(DynamicLibrary library) {
    final bindings = Bindings(library);
    var hasColumnMetadata = false;

    if (library.providesSymbol('sqlite3_compileoption_get')) {
      var i = 0;
      String? lastOption;
      do {
        final ptr = bindings.sqlite3_compileoption_get(i);

        if (!ptr.isNullPointer) {
          lastOption = ptr.readString();

          if (lastOption == 'ENABLE_COLUMN_METADATA') {
            hasColumnMetadata = true;
            break;
          }
        } else {
          lastOption = null;
        }

        i++;
      } while (lastOption != null);
    }

    return BindingsWithLibrary._(
      bindings,
      library,
      bindings.sqlite3_libversion_number() >= _firstVersionForV3,
      hasColumnMetadata,
    );
  }

  BindingsWithLibrary._(this.bindings, this.library, this.supportsPrepareV3,
      this.supportsColumnTableName);
}

final class FfiBindings extends RawSqliteBindings {
  final BindingsWithLibrary bindings;

  FfiBindings(this.bindings);

  @override
  String? get sqlite3_temp_directory {
    return bindings.bindings.sqlite3_temp_directory.readNullableString();
  }

  @override
  set sqlite3_temp_directory(String? value) {
    if (value == null) {
      bindings.bindings.sqlite3_temp_directory = nullPtr();
    } else {
      bindings.bindings.sqlite3_temp_directory =
          Utf8Utils.allocateZeroTerminated(value);
    }
  }

  @override
  String sqlite3_errstr(int extendedErrorCode) {
    return bindings.bindings.sqlite3_errstr(extendedErrorCode).readString();
  }

  @override
  String sqlite3_libversion() {
    return bindings.bindings.sqlite3_libversion().readString();
  }

  @override
  int sqlite3_libversion_number() {
    return bindings.bindings.sqlite3_libversion_number();
  }

  @override
  SqliteResult<RawSqliteDatabase> sqlite3_open_v2(
      String name, int flags, String? zVfs) {
    final namePtr = Utf8Utils.allocateZeroTerminated(name);
    final outDb = allocate<Pointer<sqlite3>>();
    final vfsPtr = zVfs == null
        ? nullPtr<sqlite3_char>()
        : Utf8Utils.allocateZeroTerminated(zVfs);

    final resultCode =
        bindings.bindings.sqlite3_open_v2(namePtr, outDb, flags, vfsPtr);
    final result = SqliteResult(resultCode, FfiDatabase(bindings, outDb.value));

    namePtr.free();
    outDb.free();
    if (zVfs != null) vfsPtr.free();

    return result;
  }

  @override
  String sqlite3_sourceid() {
    return bindings.bindings.sqlite3_sourceid().readString();
  }
}

final class FfiDatabase extends RawSqliteDatabase {
  final BindingsWithLibrary bindings;
  final Pointer<sqlite3> db;
  NativeCallable<_UpdateHook>? _installedUpdateHook;

  FfiDatabase(this.bindings, this.db);

  @override
  int sqlite3_close_v2() {
    return bindings.bindings.sqlite3_close_v2(db);
  }

  @override
  String sqlite3_errmsg() {
    return bindings.bindings.sqlite3_errmsg(db).readString();
  }

  @override
  int sqlite3_extended_errcode() {
    return bindings.bindings.sqlite3_extended_errcode(db);
  }

  @override
  void sqlite3_extended_result_codes(int onoff) {
    bindings.bindings.sqlite3_extended_result_codes(db, onoff);
  }

  @override
  int sqlite3_changes() => bindings.bindings.sqlite3_changes(db);

  @override
  int sqlite3_exec(String sql) {
    final sqlPtr = Utf8Utils.allocateZeroTerminated(sql);

    final result = bindings.bindings
        .sqlite3_exec(db, sqlPtr, nullPtr(), nullPtr(), nullPtr());
    sqlPtr.free();
    return result;
  }

  @override
  int sqlite3_last_insert_rowid() {
    return bindings.bindings.sqlite3_last_insert_rowid(db);
  }

  @override
  void deallocateAdditionalMemory() {}

  @override
  int sqlite3_create_collation_v2({
    required Uint8List collationName,
    required int eTextRep,
    required RawCollation collation,
  }) {
    final name = allocateBytes(collationName, additionalLength: 1);
    final bindings = this.bindings.bindings;
    final compare = collation.toNative(bindings);

    final result = bindings.sqlite3_create_collation_v2(
      db,
      name.cast(),
      eTextRep,
      nullPtr(),
      compare.nativeFunction,
      _xDestroy([compare]),
    );
    name.free();

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
    final functionNamePtr = allocateBytes(functionName, additionalLength: 1);

    final bindings = this.bindings.bindings;
    final step = xStep.toNative(bindings);
    final $final = xFinal.toNative(bindings, true);
    final value = xValue.toNative(bindings, false);
    final inverse = xInverse.toNative(bindings);

    final result = bindings.sqlite3_create_window_function(
      db,
      functionNamePtr.cast(),
      nArg,
      eTextRep,
      nullPtr(),
      step.nativeFunction,
      $final.nativeFunction,
      value.nativeFunction,
      inverse.nativeFunction,
      _xDestroy([step, $final, value, inverse]),
    );
    functionNamePtr.free();
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
    final functionNamePtr = allocateBytes(functionName, additionalLength: 1);

    final bindings = this.bindings.bindings;
    final func = xFunc?.toNative(bindings);
    final step = xStep?.toNative(bindings);
    final $final = xFinal?.toNative(bindings, true);

    final result = bindings.sqlite3_create_function_v2(
      db,
      functionNamePtr.cast(),
      nArg,
      eTextRep,
      nullPtr(),
      func?.nativeFunction ?? nullPtr(),
      step?.nativeFunction ?? nullPtr(),
      $final?.nativeFunction ?? nullPtr(),
      _xDestroy([
        if (func != null) func,
        if (step != null) step,
        if ($final != null) $final,
      ]),
    );
    functionNamePtr.free();
    return result;
  }

  @override
  void sqlite3_update_hook(RawUpdateHook? hook) {
    final previous = _installedUpdateHook;

    if (hook == null) {
      bindings.bindings.sqlite3_update_hook(db, nullPtr(), nullPtr());
    } else {
      final native = _installedUpdateHook = hook.toNative();
      bindings.bindings
          .sqlite3_update_hook(db, native.nativeFunction, nullPtr());
    }

    previous?.close();
  }

  @override
  int sqlite3_db_config(int op, int value) {
    final result = bindings.bindings.sqlite3_db_config(
      db,
      op,
      value,
      nullPtr(),
    );
    return result;
  }

  @override
  int sqlite3_get_autocommit() {
    return bindings.bindings.sqlite3_get_autocommit(db);
  }

  @override
  RawStatementCompiler newCompiler(List<int> utf8EncodedSql) {
    return FfiStatementCompiler(this, allocateBytes(utf8EncodedSql));
  }

  static Pointer<NativeFunction<Void Function(Pointer<Void>)>> _xDestroy(
      List<NativeCallable> callables) {
    int destroy(Pointer<Void> _) {
      for (final callable in callables) {
        callable.close();
      }

      // TODO: Remove and change to void after Dart 3.5 or https://github.com/dart-lang/sdk/issues/56064
      return 0;
    }

    final callable =
        NativeCallable<Void Function(Pointer<Void>)>.isolateLocal(destroy)
          ..keepIsolateAlive = false;
    callables.add(callable);

    return callable.nativeFunction;
  }
}

final class FfiStatementCompiler extends RawStatementCompiler {
  final FfiDatabase database;
  final Pointer<Uint8> sql;
  final Pointer<Pointer<sqlite3_stmt>> stmtOut = allocate();
  final Pointer<Pointer<sqlite3_char>> pzTail = allocate();

  FfiStatementCompiler(this.database, this.sql);

  @override
  void close() {
    sql.free();
    stmtOut.free();
    pzTail.free();
  }

  @override
  int get endOffset => pzTail.value.address - sql.address;

  @override
  SqliteResult<RawSqliteStatement?> sqlite3_prepare(
      int byteOffset, int length, int prepFlag) {
    final int result;

    if (database.bindings.supportsPrepareV3) {
      result = database.bindings.bindings.sqlite3_prepare_v3(
        database.db,
        (sql + byteOffset).cast(),
        length,
        prepFlag,
        stmtOut,
        pzTail,
      );
    } else {
      assert(
        prepFlag == 0,
        'Used custom preparation flags, but the loaded sqlite library does '
        'not support prepare_v3',
      );

      result = database.bindings.bindings.sqlite3_prepare_v2(
        database.db,
        (sql + byteOffset).cast(),
        length,
        stmtOut,
        pzTail,
      );
    }

    final stmt = stmtOut.value;
    final libraryStatement =
        stmt.isNullPointer ? null : FfiStatement(database, stmt);

    return SqliteResult(result, libraryStatement);
  }
}

final class FfiStatement extends RawSqliteStatement {
  final FfiDatabase database;
  final Bindings bindings;
  final Pointer<sqlite3_stmt> stmt;

  final List<Pointer> _allocatedArguments = [];

  FfiStatement(this.database, this.stmt)
      : bindings = database.bindings.bindings;

  @visibleForTesting
  List<Pointer> get allocatedArguments => _allocatedArguments;

  @override
  void deallocateArguments() {
    for (final arg in _allocatedArguments) {
      arg.free();
    }
    _allocatedArguments.clear();
  }

  @override
  void sqlite3_bind_blob64(int index, List<int> value) {
    final ptr = allocateBytes(value);
    _allocatedArguments.add(ptr);

    bindings.sqlite3_bind_blob64(
        stmt, index, ptr.cast(), value.length, nullPtr());
  }

  @override
  void sqlite3_bind_double(int index, double value) {
    bindings.sqlite3_bind_double(stmt, index, value);
  }

  @override
  void sqlite3_bind_int64(int index, int value) {
    bindings.sqlite3_bind_int64(stmt, index, value);
  }

  @override
  void sqlite3_bind_int64BigInt(int index, BigInt value) {
    bindings.sqlite3_bind_int64(stmt, index, value.toInt());
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
    final ptr = Utf8Utils.allocateZeroTerminated(name);
    try {
      return bindings.sqlite3_bind_parameter_index(stmt, ptr);
    } finally {
      ptr.free();
    }
  }

  @override
  void sqlite3_bind_text(int index, String value) {
    final bytes = utf8.encode(value);
    final ptr = allocateBytes(bytes);
    _allocatedArguments.add(ptr);

    bindings.sqlite3_bind_text(
        stmt, index, ptr.cast(), bytes.length, nullPtr());
  }

  @override
  Uint8List sqlite3_column_bytes(int index) {
    final length = bindings.sqlite3_column_bytes(stmt, index);
    if (length == 0) {
      // sqlite3_column_blob returns a null pointer for non-null blobs with
      // a length of 0. Note that we can distinguish this from a proper null
      // by checking the type (which isn't SQLITE_NULL)
      return Uint8List(0);
    }
    return bindings.sqlite3_column_blob(stmt, index).copyRange(length);
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
    return bindings.sqlite3_column_int64(stmt, index);
  }

  @override
  BigInt sqlite3_column_int64OrBigInt(int index) {
    return BigInt.from(bindings.sqlite3_column_int64(stmt, index));
  }

  @override
  String sqlite3_column_name(int index) {
    return bindings.sqlite3_column_name(stmt, index).readString();
  }

  @override
  String? sqlite3_column_table_name(int index) {
    return bindings.sqlite3_column_table_name(stmt, index).readNullableString();
  }

  @override
  String sqlite3_column_text(int index) {
    final length = bindings.sqlite3_column_bytes(stmt, index);
    return bindings.sqlite3_column_text(stmt, index).readString(length);
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
  bool get supportsReadingTableNameForColumn =>
      database.bindings.supportsColumnTableName;
}

final class FfiValue extends RawSqliteValue {
  final Bindings bindings;
  final Pointer<sqlite3_value> value;

  FfiValue(this.bindings, this.value);

  @override
  Uint8List sqlite3_value_blob() {
    final byteLength = bindings.sqlite3_value_bytes(value);
    return bindings.sqlite3_value_blob(value).copyRange(byteLength);
  }

  @override
  double sqlite3_value_double() {
    return bindings.sqlite3_value_double(value);
  }

  @override
  int sqlite3_value_int64() {
    return bindings.sqlite3_value_int64(value);
  }

  @override
  String sqlite3_value_text() {
    final byteLength = bindings.sqlite3_value_bytes(value);
    return utf8
        .decode(bindings.sqlite3_value_text(value).copyRange(byteLength));
  }

  @override
  int sqlite3_value_type() {
    return bindings.sqlite3_value_type(value);
  }
}

final class FfiContext extends RawSqliteContext {
  static int _aggregateContextId = 1;
  static final Map<int, AggregateContext<Object?>> _contexts = {};

  final Bindings bindings;
  final Pointer<sqlite3_context> context;

  FfiContext(this.bindings, this.context);

  Pointer<Int64> get _rawAggregateContext {
    final agCtxPtr = bindings
        .sqlite3_aggregate_context(context, sizeOf<Int64>())
        .cast<Int64>();

    if (agCtxPtr.isNullPointer) {
      // We can't run without our 8 bytes! This indicates an out-of-memory error
      throw StateError(
          'Internal error while allocating sqlite3 aggregate context (OOM?)');
    }

    return agCtxPtr;
  }

  @override
  AggregateContext<Object?>? get dartAggregateContext {
    final agCtxPtr = _rawAggregateContext;
    final value = agCtxPtr.value;

    // Ok, we have a pointer (that sqlite3 zeroes out for us). Our state counter
    // starts at one, so if it's still zero we don't have a Dart context yet.
    if (value == 0) {
      return null;
    } else {
      return _contexts[value];
    }
  }

  @override
  set dartAggregateContext(AggregateContext<Object?>? value) {
    final ptr = _rawAggregateContext;

    final id = _aggregateContextId++;
    _contexts[id] = ArgumentError.checkNotNull(value);
    ptr.value = id;
  }

  @override
  void sqlite3_result_blob64(List<int> blob) {
    final ptr = allocateBytes(blob);

    bindings.sqlite3_result_blob64(context, ptr.cast(), blob.length,
        Pointer.fromAddress(SqlSpecialDestructor.SQLITE_TRANSIENT));
    ptr.free();
  }

  @override
  void sqlite3_result_double(double value) {
    bindings.sqlite3_result_double(context, value);
  }

  @override
  void sqlite3_result_error(String message) {
    final ptr = allocateBytes(utf8.encode(message));

    bindings.sqlite3_result_error(context, ptr.cast(), message.length);
    ptr.free();
  }

  @override
  void sqlite3_result_int64(int value) {
    bindings.sqlite3_result_int64(context, value);
  }

  @override
  void sqlite3_result_int64BigInt(BigInt value) {
    bindings.sqlite3_result_int64(context, value.toInt());
  }

  @override
  void sqlite3_result_null() {
    bindings.sqlite3_result_null(context);
  }

  @override
  void sqlite3_result_text(String text) {
    final bytes = utf8.encode(text);
    final ptr = allocateBytes(bytes);

    bindings.sqlite3_result_text(context, ptr.cast(), bytes.length,
        Pointer.fromAddress(SqlSpecialDestructor.SQLITE_TRANSIENT));
    ptr.free();
  }

  void freeContext() {
    final ctxId = _rawAggregateContext.value;
    _contexts.remove(ctxId);
  }
}

class RegisteredFunctionSet {
  final RawXFunc? xFunc;
  final RawXStep? xStep;
  final RawXFinal? xFinal;

  final RawXFinal? xValue;
  final RawXStep? xInverse;

  final RawCollation? collation;

  RegisteredFunctionSet({
    this.xFunc,
    this.xStep,
    this.xFinal,
    this.xValue,
    this.xInverse,
    this.collation,
  });
}

class _ValueList extends ListBase<FfiValue> {
  @override
  int length;
  final Pointer<Pointer<sqlite3_value>> args;
  final Bindings bindings;

  _ValueList(this.length, this.args, this.bindings);

  @override
  FfiValue operator [](int index) {
    return FfiValue(bindings, args[index]);
  }

  @override
  void operator []=(int index, FfiValue value) {}
}

typedef _XFunc = Void Function(
    Pointer<sqlite3_context>, Int, Pointer<Pointer<sqlite3_value>>);
typedef _XFinal = Void Function(Pointer<sqlite3_context>);
typedef _XCompare = Int Function(
    Pointer<Void>, Int, Pointer<Void>, Int, Pointer<Void>);
typedef _UpdateHook = Void Function(
    Pointer<Void>, Int, Pointer<sqlite3_char>, Pointer<sqlite3_char>, Int64);

extension on RawXFunc {
  NativeCallable<_XFunc> toNative(Bindings bindings) {
    return NativeCallable.isolateLocal((Pointer<sqlite3_context> ctx, int nArgs,
        Pointer<Pointer<sqlite3_value>> args) {
      this(FfiContext(bindings, ctx), _ValueList(nArgs, args, bindings));
      // TODO: Remove and change to void after Dart 3.5 or https://github.com/dart-lang/sdk/issues/56064
      return 0;
    })
      ..keepIsolateAlive = false;
  }
}

extension on RawXFinal {
  NativeCallable<_XFinal> toNative(Bindings bindings, bool clean) {
    return NativeCallable.isolateLocal((Pointer<sqlite3_context> ctx) {
      final context = FfiContext(bindings, ctx);
      this(context);
      if (clean) context.freeContext();
      // TODO: Remove and change to void after Dart 3.5 or https://github.com/dart-lang/sdk/issues/56064
      return 0;
    })
      ..keepIsolateAlive = false;
  }
}

extension on RawCollation {
  NativeCallable<_XCompare> toNative(Bindings bindings) {
    return NativeCallable.isolateLocal(
      (
        Pointer<Void> _,
        int lengthA,
        Pointer<Void> a,
        int lengthB,
        Pointer<Void> b,
      ) {
        final dartA = a.cast<sqlite3_char>().readNullableString(lengthA);
        final dartB = b.cast<sqlite3_char>().readNullableString(lengthB);

        return this(dartA, dartB);
      },
      exceptionalReturn: 0,
    )..keepIsolateAlive = false;
  }
}

extension on RawUpdateHook {
  NativeCallable<_UpdateHook> toNative() {
    return NativeCallable.isolateLocal(
      (Pointer<Void> _, int kind, Pointer<sqlite3_char> db,
          Pointer<sqlite3_char> table, int rowid) {
        final tableName = table.readString();
        this(kind, tableName, rowid);

        // TODO: Remove and change to void after Dart 3.5 or https://github.com/dart-lang/sdk/issues/56064
        return 0;
      },
    )..keepIsolateAlive = false;
  }
}
