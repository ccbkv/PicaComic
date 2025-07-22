import '../exception.dart';
import 'bindings.dart';
import 'database.dart';

SqliteException createExceptionRaw(
  RawSqliteBindings bindings,
  RawSqliteDatabase db,
  int returnCode, {
  String? operation,
  String? previousStatement,
  List<Object?>? statementArgs,
}) {
  // Getting hold of more explanatory error code as SQLITE_IOERR error group has
  // an extensive list of extended error codes
  final extendedCode = db.sqlite3_extended_errcode();
  return createExceptionFromExtendedCode(
    bindings,
    db,
    returnCode,
    extendedCode,
    operation: operation,
    previousStatement: previousStatement,
    statementArgs: statementArgs,
  );
}

SqliteException createExceptionFromExtendedCode(
  RawSqliteBindings bindings,
  RawSqliteDatabase db,
  int returnCode,
  int extendedErrorCode, {
  String? operation,
  String? previousStatement,
  List<Object?>? statementArgs,
}) {
  // We don't need to free the pointer returned by sqlite3_errmsg: "Memory to
  // hold the error message string is managed internally. The application does
  // not need to worry about freeing the result."
  // https://www.sqlite.org/c3ref/errcode.html
  final dbMessage = db.sqlite3_errmsg();
  final errStr = bindings.sqlite3_errstr(extendedErrorCode);
  final explanation = '$errStr (code $extendedErrorCode)';

  return SqliteException(
    returnCode,
    dbMessage,
    explanation,
    previousStatement,
    statementArgs,
    operation,
  );
}

SqliteException createException(
  DatabaseImplementation db,
  int returnCode, {
  String? operation,
  String? previousStatement,
  List<Object?>? statementArgs,
}) {
  return createExceptionRaw(
    db.bindings,
    db.database,
    returnCode,
    operation: operation,
    previousStatement: previousStatement,
    statementArgs: statementArgs,
  );
}

Never throwException(DatabaseImplementation db, int returnCode,
    {String? operation,
    String? previousStatement,
    List<Object?>? statementArgs}) {
  throw createException(
    db,
    returnCode,
    operation: operation,
    previousStatement: previousStatement,
    statementArgs: statementArgs,
  );
}
