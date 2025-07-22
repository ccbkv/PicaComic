import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../constants.dart';
import '../database.dart';
import '../exception.dart';
import '../functions.dart';
import '../result_set.dart';
import '../statement.dart';
import 'bindings.dart';
import 'exception.dart';
import 'finalizer.dart';
import 'statement.dart';
import 'utils.dart';

/// Contains the state of a database needed for finalization.
///
/// This is extracted into separate object so that it can be used as a
/// finalization token. It will get disposed when the main database is no longer
/// reachable without being closed.
final class FinalizableDatabase extends FinalizablePart {
  final RawSqliteBindings bindings;
  final RawSqliteDatabase database;

  final List<FinalizableStatement> _statements = [];

  FinalizableDatabase(this.bindings, this.database);

  @override
  void dispose() {
    for (final stmt in _statements) {
      stmt.dispose();
    }

    final code = database.sqlite3_close_v2();
    SqliteException? exception;
    if (code != SqlError.SQLITE_OK) {
      exception = createExceptionRaw(bindings, database, code,
          operation: 'closing database');
    }

    database.deallocateAdditionalMemory();

    if (exception != null) {
      throw exception;
    }
  }
}

base class DatabaseImplementation implements CommonDatabase {
  final RawSqliteBindings bindings;
  final RawSqliteDatabase database;

  final FinalizableDatabase finalizable;

  final List<MultiStreamController<SqliteUpdate>> _updateListeners = [];

  var _isClosed = false;

  @override
  DatabaseConfig get config => DatabaseConfigImplementation(this);

  @override
  int get userVersion {
    final stmt = prepare('PRAGMA user_version;');
    try {
      final result = stmt.select();

      final version = result.first.columnAt(0) as int;
      return version;
    } finally {
      stmt.dispose();
    }
  }

  @override
  set userVersion(int value) {
    execute('PRAGMA user_version = $value;');
  }

  DatabaseImplementation(this.bindings, this.database)
      : finalizable = FinalizableDatabase(bindings, database) {
    disposeFinalizer.attach(this, finalizable, detach: this);
  }

  @visibleForOverriding
  StatementImplementation wrapStatement(String sql, RawSqliteStatement stmt) {
    return StatementImplementation(sql, this, stmt);
  }

  void handleFinalized(StatementImplementation stmt) {
    if (!_isClosed) {
      finalizable._statements.remove(stmt.finalizable);
    }
  }

  void _ensureOpen() {
    if (_isClosed) {
      throw StateError('This database has already been closed');
    }
  }

  Uint8List _validateAndEncodeFunctionName(String functionName) {
    final functionNameBytes = utf8.encode(functionName);

    if (functionNameBytes.length > 255) {
      throw ArgumentError.value(functionName, 'functionName',
          'Must not exceed 255 bytes when utf-8 encoded');
    }

    return Uint8List.fromList(functionNameBytes);
  }

  @override
  void createAggregateFunction<V>({
    required String functionName,
    required AggregateFunction<V> function,
    AllowedArgumentCount argumentCount = const AllowedArgumentCount.any(),
    bool deterministic = false,
    bool directOnly = true,
  }) {
    final name = _validateAndEncodeFunctionName(functionName);
    final textRep = eTextRep(deterministic, directOnly);
    int result;

    AggregateContext<V> readOrCreateContext(RawSqliteContext raw) {
      var dartContext = raw.dartAggregateContext as AggregateContext<V>?;
      return dartContext ??=
          raw.dartAggregateContext = function.createContext();
    }

    void step(RawSqliteContext context, List<RawSqliteValue> args) {
      final dartContext = readOrCreateContext(context);
      context.runWithArgsAndSetResult(
          (args) => function.step(args, dartContext), args);
    }

    void finalize(RawSqliteContext context) {
      context.runAndSetResult(() {
        final existingContext =
            context.dartAggregateContext as AggregateContext<V>?;

        return function.finalize(existingContext ?? function.createContext());
      });
    }

    if (function is WindowFunction<V>) {
      result = database.sqlite3_create_window_function(
        functionName: name,
        nArg: argumentCount.allowedArgs,
        eTextRep: textRep,
        xStep: step,
        xFinal: finalize,
        xValue: (context) {
          context.runAndSetResult(() {
            return function.value(readOrCreateContext(context));
          });
        },
        xInverse: (context, args) {
          final dartContext = readOrCreateContext(context);
          context.runWithArgsAndSetResult(
              (args) => function.inverse(args, dartContext), args);
        },
      );
    } else {
      result = database.sqlite3_create_function_v2(
        functionName: name,
        nArg: argumentCount.allowedArgs,
        eTextRep: textRep,
        xStep: step,
        xFinal: finalize,
      );
    }

    if (result != SqlError.SQLITE_OK) {
      throwException(this, result);
    }
  }

  @override
  void createFunction({
    required String functionName,
    required ScalarFunction function,
    AllowedArgumentCount argumentCount = const AllowedArgumentCount.any(),
    bool deterministic = false,
    bool directOnly = true,
  }) {
    final returnCode = database.sqlite3_create_function_v2(
      functionName: _validateAndEncodeFunctionName(functionName),
      nArg: argumentCount.allowedArgs,
      eTextRep: eTextRep(deterministic, directOnly),
      xFunc: (context, args) {
        context.runWithArgsAndSetResult(function, args);
      },
    );

    if (returnCode != SqlError.SQLITE_OK) {
      throwException(this, returnCode);
    }
  }

  @override
  void createCollation(
      {required String name, required CollatingFunction function}) {
    final result = database.sqlite3_create_collation_v2(
      collationName: _validateAndEncodeFunctionName(name),
      eTextRep: eTextRep(false, false),
      collation: function,
    );

    if (result != SqlError.SQLITE_OK) {
      throwException(this, result);
    }
  }

  @override
  void dispose() {
    if (_isClosed) return;

    disposeFinalizer.detach(this);
    _isClosed = true;

    for (final listener in _updateListeners) {
      listener.close();
    }
    database.sqlite3_update_hook(null);

    finalizable.dispose();
  }

  @override
  void execute(String sql, [List<Object?> parameters = const []]) {
    if (parameters.isEmpty) {
      // No parameters? Use sqlite3_exec since that can run multiple statements
      // at once.
      _ensureOpen();

      final result = database.sqlite3_exec(sql);
      if (result != SqlError.SQLITE_OK) {
        throwException(
          this,
          result,
          operation: 'executing',
          previousStatement: sql,
          statementArgs: parameters,
        );
      }
    } else {
      final stmt = prepare(sql, checkNoTail: true);
      try {
        stmt.execute(parameters);
      } finally {
        stmt.dispose();
      }
    }
  }

  @override
  int get updatedRows => database.sqlite3_changes();

  @override
  int getUpdatedRows() => updatedRows;

  @override
  int get lastInsertRowId => database.sqlite3_last_insert_rowid();

  @override
  bool get autocommit {
    return database.sqlite3_get_autocommit() != 0;
  }

  List<StatementImplementation> _prepareInternal(String sql,
      {bool persistent = false,
      bool vtab = true,
      int? maxStatements,
      bool checkNoTail = false}) {
    _ensureOpen();

    final bytes = utf8.encode(sql);
    final compiler = database.newCompiler(bytes);

    var prepFlags = 0;
    if (persistent) {
      prepFlags |= SqlPrepareFlag.SQLITE_PREPARE_PERSISTENT;
    }
    if (!vtab) {
      prepFlags |= SqlPrepareFlag.SQLITE_PREPARE_NO_VTAB;
    }

    final createdStatements = <StatementImplementation>[];
    var offset = 0;

    void freeIntermediateResults() {
      compiler.close();

      for (final stmt in createdStatements) {
        stmt.dispose();
      }
    }

    while (offset < bytes.length) {
      final result =
          compiler.sqlite3_prepare(offset, bytes.length - offset, prepFlags);

      if (result.resultCode != SqlError.SQLITE_OK) {
        freeIntermediateResults();
        throwException(this, result.resultCode,
            operation: 'preparing statement', previousStatement: sql);
      }

      final endOffset = compiler.endOffset;

      // prepare can return a null pointer with SQLITE_OK if only whitespace
      // or comments were parsed. That's fine, just skip over it then.
      final stmt = result.result;
      if (stmt != null) {
        final stmtSql = utf8.decoder.convert(bytes, offset, endOffset);

        createdStatements.add(wrapStatement(stmtSql, stmt));
      }

      offset = endOffset;

      if (createdStatements.length == maxStatements) {
        break;
      }
    }

    if (checkNoTail) {
      // Issue another prepare call at the current offset to account for
      // potential whitespace.
      while (offset < bytes.length) {
        final result =
            compiler.sqlite3_prepare(offset, bytes.length - offset, prepFlags);
        offset = compiler.endOffset;

        final stmt = result.result;

        if (stmt != null) {
          // Had an unexpected trailing statement -> throw!
          createdStatements.add(wrapStatement('', stmt));
          freeIntermediateResults();
          throw ArgumentError.value(
              sql, 'sql', 'Had an unexpected trailing statement.');
        } else if (result.resultCode != SqlError.SQLITE_OK) {
          // Invalid content that's not just a whitespace or a comment.
          freeIntermediateResults();
          throw ArgumentError.value(
              sql, 'sql', 'Has trailing data after the first sql statement:');
        }
      }
    }

    compiler.close();

    for (final created in createdStatements) {
      finalizable._statements.add(created.finalizable);
    }

    return createdStatements;
  }

  @override
  CommonPreparedStatement prepare(String sql,
      {bool persistent = false, bool vtab = true, bool checkNoTail = false}) {
    final stmts = _prepareInternal(
      sql,
      persistent: persistent,
      vtab: vtab,
      maxStatements: 1,
      checkNoTail: checkNoTail,
    );

    if (stmts.isEmpty) {
      // Can happen without a syntax error if we're only given whitespace or
      // comments.
      throw ArgumentError.value(sql, 'sql', 'Must contain an SQL statement.');
    }

    return stmts.first;
  }

  @override
  List<CommonPreparedStatement> prepareMultiple(String sql,
      {bool persistent = false, bool vtab = true}) {
    return _prepareInternal(sql, persistent: persistent, vtab: vtab);
  }

  @override
  ResultSet select(String sql, [List<Object?> parameters = const []]) {
    final stmt = prepare(sql);
    try {
      return stmt.select(parameters);
    } finally {
      stmt.dispose();
    }
  }

  @override
  Stream<SqliteUpdate> get updates {
    return Stream.multi(
      (newListener) {
        if (_isClosed) {
          newListener.closeSync();
          return;
        }

        void addUpdateListener() {
          final isFirstListener = _updateListeners.isEmpty;
          _updateListeners.add(newListener);

          if (isFirstListener) {
            // Add native update hook
            database.sqlite3_update_hook((kind, tableName, rowId) {
              SqliteUpdateKind updateKind;

              switch (kind) {
                case SQLITE_INSERT:
                  updateKind = SqliteUpdateKind.insert;
                  break;
                case SQLITE_UPDATE:
                  updateKind = SqliteUpdateKind.update;
                  break;
                case SQLITE_DELETE:
                  updateKind = SqliteUpdateKind.delete;
                  break;
                default:
                  return;
              }

              final update = SqliteUpdate(updateKind, tableName, rowId);
              for (final listener in _updateListeners) {
                listener.add(update);
              }
            });
          }
        }

        void removeUpdateListener() {
          _updateListeners.remove(newListener);

          if (_updateListeners.isEmpty && !_isClosed) {
            database.sqlite3_update_hook(null); // Remove native hook
          }
        }

        newListener
          ..onPause = removeUpdateListener
          ..onCancel = removeUpdateListener
          ..onResume = addUpdateListener;

        // Since this is a onListen callback, add listener now
        addUpdateListener();
      },
      isBroadcast: true,
    );
  }
}

extension on RawSqliteContext {
  void runWithArgsAndSetResult(
      Object? Function(List<Object?>) function, List<RawSqliteValue> args) {
    final dartArgs = ValueList(args);
    try {
      setResult(function(dartArgs));
    } on Object catch (e) {
      sqlite3_result_error(Error.safeToString(e));
    } finally {
      dartArgs.isValid = false;
    }
  }

  void runAndSetResult(Object? Function() function) {
    try {
      setResult(function());
    } on Object catch (e) {
      sqlite3_result_error(Error.safeToString(e));
    }
  }

  void setResult(Object? result) => switch (result) {
        null => sqlite3_result_null(),
        int() => sqlite3_result_int64(result),
        BigInt() => sqlite3_result_int64BigInt(result.checkRange),
        double() => sqlite3_result_double(result),
        bool() => sqlite3_result_int64(result ? 1 : 0),
        String() => sqlite3_result_text(result),
        List<int>() => sqlite3_result_blob64(result),
        _ => throw ArgumentError.value(result, 'result', 'Unsupported type')
      };
}

/// An unmodifiable Dart list backed by native sqlite3 values.
class ValueList extends ListBase<Object?> {
  final List<RawSqliteValue> rawValues;
  final List<Object?> _cachedCopies;

  bool isValid = true;

  ValueList(this.rawValues)
      : _cachedCopies = List.filled(rawValues.length, null);

  @override
  int get length => rawValues.length;

  @override
  set length(int newLength) {
    throw UnsupportedError('Changing the length of sql arguments in Dart');
  }

  @override
  Object? operator [](int index) {
    assert(
      isValid,
      'Invalid arguments. This commonly happens when an application-defined '
      'sql function leaks its arguments after it finishes running. '
      'Please use List.of(arguments) in the function to create a copy of '
      'the argument instead.',
    );
    RangeError.checkValidIndex(index, this, 'index', length);

    final cached = _cachedCopies[index];
    if (cached != null) {
      return cached;
    }

    final result = rawValues[index];
    final type = result.sqlite3_value_type();

    switch (type) {
      case SqlType.SQLITE_INTEGER:
        return result.sqlite3_value_int64();
      case SqlType.SQLITE_FLOAT:
        return result.sqlite3_value_double();
      case SqlType.SQLITE_TEXT:
        return result.sqlite3_value_text();
      case SqlType.SQLITE_BLOB:
        return result.sqlite3_value_blob();
      case SqlType.SQLITE_NULL:
      default:
        return null;
    }
  }

  @override
  void operator []=(int index, Object? value) {
    throw ArgumentError('The argument list is unmodifiable');
  }
}

final class DatabaseConfigImplementation extends DatabaseConfig {
  final DatabaseImplementation database;

  DatabaseConfigImplementation(this.database);

  @override
  void setIntConfig(int key, int configValue) {
    final resultDML = database.database.sqlite3_db_config(key, configValue);
    if (resultDML != SqlError.SQLITE_OK) {
      throwException(database, resultDML);
    }
  }
}
