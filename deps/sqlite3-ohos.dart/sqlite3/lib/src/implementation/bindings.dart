@internal
library sqlite3.implementation.bindings;

import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../functions.dart';

// ignore_for_file: non_constant_identifier_names

/// Defines a lightweight abstraction layer around sqlite3 that can be accessed
/// without platform-specific APIs (`dart:ffi` or `dart:js`).
///
/// The implementation for the user-visible API exposed by this package will
/// wrap these raw bindings to provide the more convenient to use Dart API.
/// By only requiring platform-specific code for the lowest layer, we can
/// advance the overal API with less maintenance overhead, as changes don't
/// need to be implemented for both the FFI and the WASM backend.
///
/// Methods defined here mirror the corresponding sqlite3 functions where
/// applicable. These functions don't do much more than transforming types
/// (e.g. a `String` to `sqlite3_char *`).
/// Other methods and special considerations are documented separately.
///
/// All of the classes and methods defined here are internal and can be changed
/// as needed.
abstract base class RawSqliteBindings {
  String sqlite3_libversion();
  String sqlite3_sourceid();
  int sqlite3_libversion_number();

  String? sqlite3_temp_directory;

  SqliteResult<RawSqliteDatabase> sqlite3_open_v2(
      String name, int flags, String? zVfs);

  String sqlite3_errstr(int extendedErrorCode);
}

/// Combines a sqlite result code and the result object.
final class SqliteResult<T> {
  final int resultCode;

  /// The result of the operation, which is assumed to be valid if [resultCode]
  /// is zero.
  final T result;

  SqliteResult(this.resultCode, this.result);
}

typedef RawXFunc = void Function(RawSqliteContext, List<RawSqliteValue>);
typedef RawXStep = void Function(RawSqliteContext, List<RawSqliteValue>);
typedef RawXFinal = void Function(RawSqliteContext);
typedef RawUpdateHook = void Function(int kind, String tableName, int rowId);
typedef RawCollation = int Function(String? a, String? b);

abstract base class RawSqliteDatabase {
  int sqlite3_changes();
  int sqlite3_last_insert_rowid();

  int sqlite3_exec(String sql);

  int sqlite3_extended_errcode();
  void sqlite3_extended_result_codes(int onoff);
  int sqlite3_close_v2();
  String sqlite3_errmsg();

  /// Deallocate additional memory that the raw implementation may had to use
  /// for some type conversions for previous method invocations.
  ///
  /// This is called by the higher-level implementation when a database is
  /// closed.
  void deallocateAdditionalMemory();

  void sqlite3_update_hook(RawUpdateHook? hook);

  /// Returns a compiler able to create prepared statements from the utf8-
  /// encoded SQL string passed as its argument.
  RawStatementCompiler newCompiler(List<int> utf8EncodedSql);

  int sqlite3_create_collation_v2({
    required Uint8List collationName,
    required int eTextRep,
    required RawCollation collation,
  });

  int sqlite3_create_function_v2({
    required Uint8List functionName,
    required int nArg,
    required int eTextRep,
    RawXFunc? xFunc,
    RawXStep? xStep,
    RawXFinal? xFinal,
  });

  int sqlite3_create_window_function({
    required Uint8List functionName,
    required int nArg,
    required int eTextRep,
    required RawXStep xStep,
    required RawXFinal xFinal,
    required RawXFinal xValue,
    required RawXStep xInverse,
  });

  int sqlite3_db_config(int op, int value);
  int sqlite3_get_autocommit();
}

/// A stateful wrapper around multiple `sqlite3_prepare` invocations.
abstract base class RawStatementCompiler {
  /// The current byte-offset in the SQL statement passed to
  /// [RawSqliteDatabase.newCompiler].
  ///
  /// After calling [sqlite3_prepare], this value should advance to the end of
  /// that statement.
  ///
  /// The behavior of invoking this getter before the first
  /// [sqlite3_prepare] is undefined.
  int get endOffset;

  /// Compile a statement from the substring at [byteOffset] with a maximum
  /// length of [length].
  SqliteResult<RawSqliteStatement?> sqlite3_prepare(
      int byteOffset, int length, int prepFlag);

  /// Releases resources used by this compiler interface.
  void close();
}

abstract base class RawSqliteStatement {
  void sqlite3_reset();
  int sqlite3_step();
  void sqlite3_finalize();

  /// Deallocates memory used using `sqlite3_bind` calls to hold argument
  /// values.
  void deallocateArguments();

  int sqlite3_bind_parameter_index(String name);

  void sqlite3_bind_null(int index);
  void sqlite3_bind_int64(int index, int value);
  void sqlite3_bind_int64BigInt(int index, BigInt value);
  void sqlite3_bind_double(int index, double value);
  void sqlite3_bind_text(int index, String value);
  void sqlite3_bind_blob64(int index, List<int> value);

  int sqlite3_column_count();
  String sqlite3_column_name(int index);
  bool get supportsReadingTableNameForColumn;
  String? sqlite3_column_table_name(int index);

  int sqlite3_column_type(int index);
  int sqlite3_column_int64(int index);

  /// (Only used on the web): Like [sqlite3_column_int64], but wrapping the
  /// result in a [BigInt] if it's too large to be represented in a JavaScript
  /// [int] implementation.
  Object sqlite3_column_int64OrBigInt(int index);
  double sqlite3_column_double(int index);
  String sqlite3_column_text(int index);
  Uint8List sqlite3_column_bytes(int index);

  int sqlite3_bind_parameter_count();
  int sqlite3_stmt_readonly();
  int sqlite3_stmt_isexplain();
}

abstract base class RawSqliteContext {
  AggregateContext<Object?>? dartAggregateContext;

  void sqlite3_result_null();
  void sqlite3_result_int64(int value);
  void sqlite3_result_int64BigInt(BigInt value);
  void sqlite3_result_double(double value);
  void sqlite3_result_text(String text);
  void sqlite3_result_blob64(List<int> blob);
  void sqlite3_result_error(String message);
}

abstract base class RawSqliteValue {
  int sqlite3_value_type();
  int sqlite3_value_int64();
  double sqlite3_value_double();
  String sqlite3_value_text();
  Uint8List sqlite3_value_blob();
}
