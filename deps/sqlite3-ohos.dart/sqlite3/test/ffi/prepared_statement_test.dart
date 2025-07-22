@Tags(['ffi'])
library;

import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3/src/ffi/implementation.dart';
import 'package:test/test.dart';

import '../common/prepared_statement.dart';

void main() {
  final version = sqlite3.version;
  final hasReturning = version.versionNumber > 3035000;

  testPreparedStatements(() => sqlite3, supportsReturning: hasReturning);

  group('deallocates statement arguments', () {
    late Database database;

    setUp(() => database = sqlite3.openInMemory());
    tearDown(() => database.dispose());

    test('after binding different args', () {
      final stmt = database.prepare('SELECT ?;');
      stmt.execute(['this needs to be allocated and copied into ffi buffer']);
      expect(
          (stmt as FfiStatementImplementation).ffiStatement.allocatedArguments,
          isNotEmpty);

      stmt.execute([3]);
      expect(stmt.ffiStatement.allocatedArguments, isEmpty);
    });

    test('after disposing statement', () {
      final stmt = database.prepare('SELECT ?;');
      stmt.execute(['this needs to be allocated and copied into ffi buffer']);
      expect(
          (stmt as FfiStatementImplementation).ffiStatement.allocatedArguments,
          isNotEmpty);

      stmt.dispose();
      expect(stmt.ffiStatement.allocatedArguments, isEmpty);
    });
  });
}
