import '../constants.dart';
import '../result_set.dart';
import '../statement.dart';
import 'bindings.dart';
import 'database.dart';
import 'exception.dart';
import 'finalizer.dart';
import 'utils.dart';

final class FinalizableStatement extends FinalizablePart {
  final RawSqliteStatement statement;

  bool _inResetState = true;
  bool _closed = false;

  FinalizableStatement(this.statement);

  @override
  void dispose() {
    if (!_closed) {
      _closed = true;
      _reset();
      _deallocateArguments();
      statement.sqlite3_finalize();
    }
  }

  void _reset() {
    if (!_inResetState) {
      statement.sqlite3_reset();
      _inResetState = true;
    }
  }

  void _deallocateArguments() {
    statement.deallocateArguments();
  }
}

base class StatementImplementation extends CommonPreparedStatement {
  final RawSqliteStatement statement;
  final DatabaseImplementation database;
  final FinalizableStatement finalizable;

  @override
  final String sql;
  List<Object?>? _latestArguments;

  _ActiveCursorIterator? _currentCursor;

  StatementImplementation(this.sql, this.database, this.statement)
      : finalizable = FinalizableStatement(statement);

  List<String> get _columnNames {
    final columnCount = statement.sqlite3_column_count();

    return [
      for (var i = 0; i < columnCount; i++) statement.sqlite3_column_name(i)
    ];
  }

  List<String?>? get _tableNames {
    if (!statement.supportsReadingTableNameForColumn) {
      return null;
    }

    final columnCount = statement.sqlite3_column_count();
    return List.generate(columnCount, statement.sqlite3_column_table_name);
  }

  void _ensureNotFinalized() {
    if (finalizable._closed) {
      throw StateError('Tried to operate on a released prepared statement');
    }
  }

  void _ensureMatchingParameters(List<Object?>? parameters) {
    final length = parameters?.length ?? 0;
    final count = parameterCount;

    if (length != count) {
      throw ArgumentError.value(
          parameters, 'parameters', 'Expected $count parameters, got $length');
    }
  }

  int _step() => statement.sqlite3_step();

  void _reset({bool invalidateArgs = true}) {
    finalizable._reset();
    if (invalidateArgs) {
      finalizable._deallocateArguments();
    }

    _currentCursor = null;
  }

  void _execute() {
    int result;

    finalizable._inResetState = false;
    // Users should be able to execute statements returning rows, so we should
    // call _step() to skip past rows.
    do {
      result = _step();
    } while (result == SqlError.SQLITE_ROW);

    if (result != SqlError.SQLITE_OK && result != SqlError.SQLITE_DONE) {
      throwException(
        database,
        result,
        operation: 'executing statement',
        previousStatement: sql,
        statementArgs: _latestArguments,
      );
    }
  }

  ResultSet _selectResults() {
    final rows = <List<Object?>>[];
    finalizable._inResetState = false;

    int columnCount = -1;

    int resultCode;
    while ((resultCode = _step()) == SqlError.SQLITE_ROW) {
      // sqlite3_column_count() must be called after _step() because step() can
      // re-compile the statement after schema changes, potentially leading to
      // a different amount of columns.
      if (columnCount == -1) {
        columnCount = statement.sqlite3_column_count();
      }

      assert(columnCount >= 0);
      rows.add(<Object?>[for (var i = 0; i < columnCount; i++) _readValue(i)]);
    }

    if (resultCode != SqlError.SQLITE_OK &&
        resultCode != SqlError.SQLITE_DONE) {
      throwException(
        database,
        resultCode,
        operation: 'selecting from statement',
        previousStatement: sql,
        statementArgs: _latestArguments,
      );
    }

    final names = _columnNames;
    final tableNames = _tableNames;

    return ResultSet(names, tableNames, rows);
  }

  Object? _readValue(int index) {
    final type = statement.sqlite3_column_type(index);
    switch (type) {
      case SqlType.SQLITE_INTEGER:
        const hasNativeInts = !identical(0.0, 0);

        if (hasNativeInts) {
          return statement.sqlite3_column_int64(index);
        } else {
          // Wrap in BigInt if needed
          return statement.sqlite3_column_int64OrBigInt(index);
        }

      case SqlType.SQLITE_FLOAT:
        return statement.sqlite3_column_double(index);
      case SqlType.SQLITE_TEXT:
        return statement.sqlite3_column_text(index);
      case SqlType.SQLITE_BLOB:
        return statement.sqlite3_column_bytes(index);
      case SqlType.SQLITE_NULL:
      default:
        return null;
    }
  }

  void _bindIndexedParams(List<Object?>? params) {
    _ensureMatchingParameters(params);
    if (params == null || params.isEmpty) return;

    // variables in sqlite are 1-indexed
    for (var i = 1; i <= params.length; i++) {
      final Object? param = params[i - 1];

      _bindParam(param, i);
    }

    _latestArguments = params;
  }

  void _bindMapParams(Map<String, Object?> params) {
    final expectedLength = parameterCount;
    final paramsAsList = List<Object?>.filled(expectedLength, null);

    if (params.isEmpty) {
      if (expectedLength != 0) {
        throw ArgumentError.value(params, 'params',
            'Expected $expectedLength parameters, but none were set.');
      }
      return;
    }

    for (final key in params.keys) {
      final Object? param = params[key];
      final i = statement.sqlite3_bind_parameter_index(key);

      // SQL parameters are 1-indexed, so 0 indicates that no parameter with
      // that name was found.
      if (i == 0) {
        throw ArgumentError.value(params, 'params',
            'This statement contains no parameter named `$key`');
      }
      _bindParam(param, i);
      paramsAsList[i - 1] = param;
    }

    // If we reached this point. All parameters from [params] were bound. Check
    // if the statement contains no additional parameters.
    if (expectedLength != params.length) {
      throw ArgumentError.value(
          params, 'params', 'Expected $expectedLength parameters');
    }

    _latestArguments = paramsAsList;
  }

  void _bindParam(Object? param, int i) => switch (param) {
        null => statement.sqlite3_bind_null(i),
        int() => statement.sqlite3_bind_int64(i, param),
        BigInt() => statement.sqlite3_bind_int64BigInt(i, param.checkRange),
        bool() => statement.sqlite3_bind_int64(i, param ? 1 : 0),
        double() => statement.sqlite3_bind_double(i, param),
        String() => statement.sqlite3_bind_text(i, param),
        List<int>() => statement.sqlite3_bind_blob64(i, param),
        CustomStatementParameter() => param.applyTo(this, i),
        _ => throw ArgumentError.value(
            param,
            'params[$i]',
            'Allowed parameters must either be null or bool, int, num, String or '
                'List<int>.',
          )
      };

  void _bindParams(StatementParameters parameters) {
    switch (parameters) {
      case IndexedParameters():
        _bindIndexedParams(parameters.parameters);
      case NamedParameters():
        _bindMapParams(parameters.parameters);
      case CustomParameters():
        parameters.bind(this);
    }
  }

  @override
  void reset() {
    _reset(invalidateArgs: false);
  }

  @override
  void dispose() {
    if (!finalizable._closed) {
      disposeFinalizer.detach(this);
      finalizable.dispose();

      database.handleFinalized(this);
    }
  }

  @override
  ResultSet selectWith(StatementParameters parameters) {
    _ensureNotFinalized();

    _reset();
    _bindParams(parameters);

    return _selectResults();
  }

  @override
  void executeWith(StatementParameters parameters) {
    _ensureNotFinalized();

    _reset();
    _bindParams(parameters);
    _execute();
  }

  @override
  IteratingCursor iterateWith(StatementParameters parameters) {
    _ensureNotFinalized();

    _reset();
    _bindParams(parameters);

    return _currentCursor = _ActiveCursorIterator(this);
  }

  @override
  int get parameterCount => statement.sqlite3_bind_parameter_count();

  @override
  bool get isReadOnly => statement.sqlite3_stmt_readonly() != 0;

  @override
  bool get isExplain => statement.sqlite3_stmt_isexplain() != 0;

  @override
  ResultSet selectMap(Map<String, Object?> parameters) {
    _ensureNotFinalized();

    _reset();
    _bindMapParams(parameters);

    return _selectResults();
  }
}

class _ActiveCursorIterator extends IteratingCursor {
  final StatementImplementation statement;
  int columnCount = -1;

  @override
  late Row current;

  /// We can only reliably know the columns of a statement after step() has been
  /// called once.
  ///
  /// However, that also consumes a row which must happen in [moveNext]. This
  /// interface unfortunately exposes the column names directly - the information
  /// is potentially incorrect at the beginning but correct at the first row.
  /// This design issue is documented on [IteratingCursor].
  bool _hasReliableColumnNames = false;

  _ActiveCursorIterator(
    this.statement,
  ) : super(statement._columnNames, statement._tableNames) {
    statement.finalizable._inResetState = false;
  }

  @override
  bool moveNext() {
    if (statement.finalizable._closed || statement._currentCursor != this) {
      return false;
    }

    final result = statement._step();

    if (result == SqlError.SQLITE_ROW) {
      if (!_hasReliableColumnNames) {
        columnCount = statement.statement.sqlite3_column_count();
        columnNames = statement._columnNames;
        _hasReliableColumnNames = true;
      }

      assert(columnCount >= 0);
      final rowData = <Object?>[
        for (var i = 0; i < columnCount; i++) statement._readValue(i)
      ];

      current = Row(this, rowData);
      return true;
    }

    // We're at the end of the result set or encountered an exception here.
    statement._currentCursor = null;

    if (result != SqlError.SQLITE_OK && result != SqlError.SQLITE_DONE) {
      throwException(
        statement.database,
        result,
        operation: 'iterating through statement',
        previousStatement: statement.sql,
        statementArgs: statement._latestArguments,
      );
    }

    return false;
  }
}
