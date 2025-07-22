@Tags(['ffi'])
library;

import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/scaffolding.dart';

import '../common/database.dart';

void main() {
  final hasColumnMeta =
      open.openSqlite().providesSymbol('sqlite3_column_table_name');

  testDatabase(() => sqlite3, hasColumnMetadata: hasColumnMeta);
}
