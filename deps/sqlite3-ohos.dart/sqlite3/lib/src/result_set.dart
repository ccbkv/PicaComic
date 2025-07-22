import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Base class for result sets.
///
/// Result sets are either completely materialized ([ResultSet] with all rows
/// being directly available), or executed row-by-row ([IteratingCursor]).
sealed class Cursor {
  List<String> _columnNames;

  /// The column names of this query, as returned by `sqlite3`.
  List<String> get columnNames => _columnNames;

  @protected
  set columnNames(List<String> names) {
    _columnNames = names;
    _calculateIndexes();
  }

  /// The table names of this query, as returned by `sqlite3`.
  ///
  /// A table name is null when the column is not directly associated
  /// with a table, such as a computed column.
  /// The list is null if the sqlite library was not compiled with the SQLITE_ENABLE_COLUMN_METADATA
  /// C-preprocessor symbol.
  /// More information in https://www.sqlite.org/c3ref/column_database_name.html.
  final List<String?>? tableNames;

  // a result set can have multiple columns with the same name, but that's rare
  // and users usually use a name as index. So we cache that for O(1) lookups
  Map<String, int> _calculatedIndexes = const {};

  Cursor(this._columnNames, this.tableNames) {
    _calculateIndexes();
  }

  void _calculateIndexes() {
    _calculatedIndexes = {
      for (var column in _columnNames) column: _columnNames.lastIndexOf(column),
    };
  }
}

/// A [Cursor] that can only be read once, obtaining rows from the database "on
/// the fly" as [moveNext] is called.
///
/// This class provides [columnNames] and [tableNames]. Since sqlite3 statements
/// are dynamically re-compiled by sqlite3 in response to schema changes, column
/// names might change in the first call to [moveNext]. So, these getters are
/// only reliable after [moveNext] was called once (regardless of its return
/// value).
abstract class IteratingCursor extends Cursor implements Iterator<Row> {
  IteratingCursor(super._columnNames, super.tableNames);
}

/// Stores the full result of a select statement.
final class ResultSet extends Cursor
    with
        ListMixin<Row>,
        NonGrowableListMixin<Row> // ignore: prefer_mixin
    implements
        Iterable<Row> {
  /// The raw row data.
  final List<List<Object?>> rows;

  ResultSet(super._columnNames, super.tableNames, this.rows);

  @override
  Iterator<Row> get iterator => _ResultIterator(this);

  @override
  Row operator [](int index) => Row(this, rows[index]);

  @override
  void operator []=(int index, Row value) {
    throw UnsupportedError("Can't change rows from a result set");
  }

  @override
  int get length => rows.length;
}

/// A single row in the result of a select statement.
///
/// This class implements the [Map] interface, which can be used to look up the
/// value of a column by its name.
/// The [columnAt] method may be used to obtain the value of a column by its
/// index.
final class Row
    with
        // ignore: prefer_mixin
        UnmodifiableMapMixin<String, dynamic>,
        MapMixin<String, dynamic>
    implements
        Map<String, dynamic> {
  final Cursor _result;
  final List<Object?> _data;

  Row(this._result, List<Object?> data) : _data = List.unmodifiable(data);

  /// Returns the value stored in the [i]-th column in this row (zero-indexed).
  dynamic columnAt(int i) {
    return _data[i];
  }

  @override
  dynamic operator [](Object? key) {
    if (key is! String) {
      if (key is int) {
        return _data[key];
      }
      return null;
    }

    final index = _result._calculatedIndexes[key];
    if (index == null) return null;

    return columnAt(index);
  }

  @override
  List<String> get keys => _result.columnNames;

  @override
  List<Object?> get values => _data;

  /// Returns a two-level map that on the first level contains the resolved
  /// non-aliased table name, and on the second level the column name (or its alias).
  ///
  /// A table name (first level map key) is null when the column is not directly associated
  /// with a table, such as a computed column.
  /// The map is null if the sqlite3 library was not compiled with the SQLITE_ENABLE_COLUMN_METADATA
  /// C-preprocessor symbol.
  /// More information in https://www.sqlite.org/c3ref/column_database_name.html.
  Map<String?, Map<String, dynamic>>? toTableColumnMap() {
    if (_result.tableNames == null) {
      return null;
    }
    final Map<String?, Map<String, dynamic>> map = {};
    for (int i = 0; i < _data.length; i++) {
      final tableName = _result.tableNames![i];
      final columnName = _result.columnNames[i];
      final value = _data[i];

      final columnsMap = map.putIfAbsent(tableName, () => <String, dynamic>{});
      columnsMap[columnName] = value;
    }
    return map;
  }
}

final class _ResultIterator implements Iterator<Row> {
  final ResultSet result;
  int index = -1;

  _ResultIterator(this.result);

  @override
  Row get current => Row(result, result.rows[index]);

  @override
  bool moveNext() {
    index++;
    return index < result.rows.length;
  }
}
