import 'dart:async';
import 'dart:typed_data';

import 'package:sqlite3/common.dart';
import 'package:test/test.dart';

import 'utils.dart';

void testDatabase(
  FutureOr<CommonSqlite3> Function() loadSqlite, {
  bool hasColumnMetadata = false,
}) {
  late CommonSqlite3 sqlite3;
  late CommonDatabase database;

  setUpAll(() async => sqlite3 = await loadSqlite());
  setUp(() => database = sqlite3.openInMemory());
  tearDown(() => database.dispose());

  test('user version', () {
    expect(database.userVersion, 0);
    database.userVersion = 1;
    expect(database.userVersion, 1);
  });

  test("database can't be used after dispose", () {
    database.dispose();

    expect(() => database.execute('SELECT 1;'), throwsStateError);
  });

  test('disposing multiple times works', () {
    database.dispose();
    database.dispose(); // shouldn't throw or crash
  });

  test('updated rows', () {
    database
      ..execute('CREATE TABLE foo (bar INT);')
      ..execute('INSERT INTO foo VALUES (3), (4);');

    expect(database.updatedRows, 2);
    // ignore: deprecated_member_use_from_same_package
    expect(database.getUpdatedRows(), 2);
  });

  test('last insert id', () {
    database.execute('CREATE TABLE tbl(a INTEGER PRIMARY KEY AUTOINCREMENT)');

    for (var i = 0; i < 5; i++) {
      database.execute('INSERT INTO tbl DEFAULT VALUES');
      expect(database.lastInsertRowId, i + 1);
    }
  });

  group('execute', () {
    test('can run multiple statements at once', () {
      database.execute('CREATE TABLE foo (a); CREATE TABLE bar (b);');

      final result = database
          .select('SELECT name FROM sqlite_master')
          .map((row) => row['name'] as String);
      expect(result, containsAll(<String>['foo', 'bar']));
    });

    test('can use parameters', () {
      database.execute('CREATE TABLE foo (a);');
      database.execute('INSERT INTO foo VALUES (?)', [123]);

      final result = database.select('SELECT * FROM foo');
      expect(result, hasLength(1));
      expect(result.single['a'], 123);
    });

    test('does not allow multiple statements with parameters', () {
      database.execute('CREATE TABLE foo (a);');

      expect(
          () => database.execute(
              'INSERT INTO foo VALUES (?); INSERT INTO foo VALUES (?);', [123]),
          throwsArgumentError);
    });

    test('inner join with toTableColumnMap and computed column', () {
      database.execute('''
      CREATE TABLE foo (
        a INT
      );
      CREATE TABLE bar (
        b TEXT,
        a_ref INT,
        FOREIGN KEY (a_ref) REFERENCES foo (a)
      );
      ''');
      database.execute('INSERT INTO foo(a) VALUES (1), (2), (3);');
      database.execute(
          "INSERT INTO bar(b, a_ref) VALUES ('1', NULL), ('2', 2), ('3', 3);");

      final result = database.select(
        'SELECT *, foo.a > 2 is_greater_than_2 FROM foo'
        ' INNER JOIN bar bar_alias ON bar_alias.a_ref = foo.a;',
      );

      expect(result, [
        {'a': 2, 'b': '2', 'a_ref': 2, 'is_greater_than_2': 0},
        {'a': 3, 'b': '3', 'a_ref': 3, 'is_greater_than_2': 1},
      ]);

      expect(result.map((row) => row.toTableColumnMap()), [
        {
          null: {'is_greater_than_2': 0},
          'foo': {'a': 2},
          'bar': {'b': '2', 'a_ref': 2},
        },
        {
          null: {'is_greater_than_2': 1},
          'foo': {'a': 3},
          'bar': {'b': '3', 'a_ref': 3},
        },
      ]);
    },
        skip: hasColumnMetadata
            ? null
            : 'sqlite3 was compiled without column metadata');
  });

  group('throws', () {
    test('when executing an invalid statement', () {
      database.execute('CREATE TABLE foo (bar INTEGER CHECK (bar > 10));');

      expect(
        () => database.execute('INSERT INTO foo VALUES (3);'),
        throwsA(const TypeMatcher<SqliteException>().having(
            (e) => e.message, 'message', contains('CHECK constraint failed'))),
      );
    });

    test('when preparing an invalid statement', () {
      expect(
        () => database.prepare('INSERT INTO foo VALUES (3);'),
        throwsA(const TypeMatcher<SqliteException>()
            .having((e) => e.operation, 'operation', 'preparing statement')
            .having((e) => e.message, 'message', contains('no such table'))),
      );
    });

    group('with statement and args', () {
      setUp(() {
        database.createFunction(
          functionName: 'throw_if_3',
          argumentCount: const AllowedArgumentCount(1),
          function: (args) {
            if (args[0] == 3) {
              throw Exception('intended exception');
            }
            return null;
          },
        );
      });

      Matcher sqlite3Exception(dynamic operation, dynamic causingStatement,
          dynamic parameters, dynamic toString) {
        return isA<SqliteException>()
            .having((e) => e.operation, 'operation', operation)
            .having(
                (e) => e.causingStatement, 'causingStatement', causingStatement)
            .having((e) => e.parametersToStatement, 'parametersToStatement',
                parameters)
            .having((e) => e.toString(), 'toString()', toString);
      }

      test('for execute', () {
        expect(
          () => database.execute('SELECT throw_if_3(?)', [3]),
          throwsA(
            sqlite3Exception(
              'executing statement',
              'SELECT throw_if_3(?)',
              [3],
              contains(
                'Causing statement: SELECT throw_if_3(?), parameters: 3',
              ),
            ),
          ),
        );
      });

      test('for reading prepared statements', () {
        final stmt = database.prepare('SELECT throw_if_3(?)');

        expect(
          () => stmt.select([3]),
          throwsA(
            sqlite3Exception(
              'selecting from statement',
              'SELECT throw_if_3(?)',
              [3],
              contains(
                'Causing statement: SELECT throw_if_3(?), parameters: 3',
              ),
            ),
          ),
        );
      });

      test('for writing prepared statements', () {
        database.execute('CREATE TABLE foo (bar INTEGER);');

        final stmt = database.prepare('INSERT INTO foo VALUES (throw_if_3(?))');
        expect(
          () => stmt.execute([3]),
          throwsA(
            sqlite3Exception(
              'executing statement',
              'INSERT INTO foo VALUES (throw_if_3(?))',
              [3],
              contains(
                'Causing statement: INSERT INTO foo VALUES (throw_if_3(?)), parameters: 3',
              ),
            ),
          ),
        );
      });

      test('for prepared statements with map', () {
        final stmt = database.prepare('SELECT :a, throw_if_3(:b)');
        final expectation = throwsA(
          sqlite3Exception(
            'selecting from statement',
            'SELECT :a, throw_if_3(:b)',
            [1, 3],
            contains(
              'Causing statement: SELECT :a, throw_if_3(:b), parameters: 1, 3',
            ),
          ),
        );

        expect(
          // ignore: deprecated_member_use_from_same_package
          () => stmt.selectMap({':a': 1, ':b': 3}),
          expectation,
        );

        expect(
          () => stmt.selectWith(StatementParameters.named({':a': 1, ':b': 3})),
          expectation,
        );
      });

      test('for prepared statements with cursor', () {
        const sql = 'SELECT throw_if_3(column1) FROM (VALUES (?), (?))';
        final stmt = database.prepare(sql);
        final cursor = stmt.selectCursor([1, 3]);

        expect(cursor.moveNext(), isTrue);
        expect(
            () => cursor.moveNext(),
            throwsA(
              sqlite3Exception(
                'iterating through statement',
                sql,
                [1, 3],
                contains(
                  'Causing statement: $sql, parameters: 1, 3',
                ),
              ),
            ));
      });
    });
  });

  test('violating constraint throws exception with extended error code', () {
    database.execute('CREATE TABLE tbl(a INTEGER NOT NULL)');

    final statement = database.prepare('INSERT INTO tbl DEFAULT VALUES');

    expect(
      statement.execute,
      throwsA(
        isA<SqliteException>().having(
            (e) => e.explanation, 'explanation', endsWith(' (code 1299)')),
      ),
    );
  });

  test('open shared in-memory instances', () {
    final db1 = sqlite3.open('file:test?mode=memory&cache=shared', uri: true);
    final db2 = sqlite3.open('file:test?mode=memory&cache=shared', uri: true);
    addTearDown(() {
      db1.dispose();
      db2.dispose();
    });

    db1
      ..execute('CREATE TABLE tbl (a INTEGER NOT NULL);')
      ..execute('INSERT INTO tbl VALUES (1), (2), (3);');

    final result = db2.select('SELECT * FROM tbl');
    expect(result, hasLength(3));
  });

  test('locked exceptions', () {
    final db1 = sqlite3.open('file:busy?mode=memory&cache=shared', uri: true);
    final db2 = sqlite3.open('file:busy?mode=memory&cache=shared', uri: true);
    addTearDown(() {
      db1.dispose();
      db2.dispose();
    });

    db1.execute('BEGIN EXCLUSIVE TRANSACTION');
    expect(() => db2.execute('BEGIN EXCLUSIVE TRANSACTION'),
        throwsSqlError(SqlError.SQLITE_LOCKED, 262));
  });

  test('result sets are lists', () {
    final result = database.select('SELECT 1, 2 UNION ALL SELECT 3, 4;');
    expect(result, isA<List<Row>>());

    expect(result[0], {'1': 1, '2': 2});
    expect(result[1], {'1': 3, '2': 4});

    // ignore: collection_methods_unrelated_type
    expect(result[0][0], 1);
    expect(result[0]['1'], 1);
    // ignore: collection_methods_unrelated_type
    expect(result[0][1], 2);
    expect(result[0]['2'], 2);
  });

  group(
    'user-defined functions',
    () {
      test('can read arguments of user defined functions', () {
        late List<Object?> readArguments;

        database.createFunction(
          functionName: 'test_fun',
          argumentCount: const AllowedArgumentCount(6),
          function: (args) {
            // copy since the args become invalid as soon as this function
            // finishes.
            readArguments = List.of(args);
            return null;
          },
        );

        database.execute(
            r'''SELECT test_fun(1, 2.5, 'hello world', X'ff00ff', X'', NULL)''');

        expect(readArguments, <dynamic>[
          1,
          2.5,
          'hello world',
          Uint8List.fromList([255, 0, 255]),
          Uint8List(0),
          null,
        ]);
      });

      test('throws when using a long function name', () {
        expect(
          () => database.createFunction(
              functionName: 'foo' * 100, function: (args) => null),
          throwsArgumentError,
        );
      });

      group('scalar return', () {
        test('null', () {
          database.createFunction(
            functionName: 'test_null',
            function: (args) => null,
            argumentCount: const AllowedArgumentCount(0),
          );
          final stmt = database.prepare('SELECT test_null() AS result');

          expect(stmt.select(), [
            {'result': null}
          ]);
        });

        test('integers', () {
          database.createFunction(
            functionName: 'test_int',
            function: (args) => 420,
            argumentCount: const AllowedArgumentCount(0),
          );
          final stmt = database.prepare('SELECT test_int() AS result');

          expect(stmt.select(), [
            {'result': 420}
          ]);
        });

        test('big int', () {
          database.createFunction(
            functionName: 'test_int',
            function: (args) => BigInt.from(12),
            argumentCount: const AllowedArgumentCount(0),
          );
          final stmt = database.prepare('SELECT test_int() AS result');

          expect(stmt.select(), [
            {'result': 12}
          ]);
        });

        test('doubles', () {
          database.createFunction(
            functionName: 'test_double',
            function: (args) => 133.7,
            argumentCount: const AllowedArgumentCount(0),
          );
          final stmt = database.prepare('SELECT test_double() AS result');

          expect(stmt.select(), [
            {'result': 133.7}
          ]);
        });

        test('bytes', () {
          database.createFunction(
            functionName: 'test_blob',
            function: (args) => [1, 2, 3],
            argumentCount: const AllowedArgumentCount(0),
          );
          final stmt = database.prepare('SELECT test_blob() AS result');

          expect(stmt.select(), [
            {
              'result': [1, 2, 3]
            }
          ]);
        });

        test('text', () {
          database.createFunction(
            functionName: 'test_text',
            function: (args) => 'hello from Dart',
            argumentCount: const AllowedArgumentCount(0),
          );
          final stmt = database.prepare('SELECT test_text() AS result');

          expect(stmt.select(), [
            {'result': 'hello from Dart'}
          ]);
        });
      });

      test('aggregate functions', () {
        database
          ..execute('CREATE TABLE test (a INT, b TEXT);')
          ..execute('INSERT INTO test VALUES '
              "(1, 'hello world'), "
              "(2, 'foo'), "
              "(1, 'another'), "
              "(2, 'bar');");

        database.createAggregateFunction(
          functionName: 'sum_lengths',
          function: const _SummedStringLength(),
          argumentCount: const AllowedArgumentCount(1),
        );

        expect(
          database.select('SELECT a, sum_lengths(b) AS l FROM test GROUP BY a '
              'ORDER BY 2;'),
          [
            {'a': 2, 'l': 6 /* foo + bar */},
            {'a': 1, 'l': 18 /* hello world + another */},
          ],
        );
      });

      test('window functions', () {
        // Dart port of https://www.sqlite.org/windowfunctions.html#udfwinfunc
        database
          ..execute('CREATE TABLE t3 (x, y);')
          ..execute('INSERT INTO t3 VALUES '
              "('a', 4), "
              "('b', 5), "
              "('c', 3), "
              "('d', 8), "
              "('e', 1)");

        database.createAggregateFunction(
          functionName: 'sumint',
          function: _SumInt(),
          argumentCount: const AllowedArgumentCount(1),
        );

        expect(
          database.select('SELECT x, sumint(y) OVER ('
              '  ORDER BY x ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING'
              ') AS sum_y FROM t3 ORDER BY x'),
          [
            {'x': 'a', 'sum_y': 9},
            {'x': 'b', 'sum_y': 12},
            {'x': 'c', 'sum_y': 16},
            {'x': 'd', 'sum_y': 12},
            {'x': 'e', 'sum_y': 9},
          ],
        );
      });
    },
  );

  test('createCollation', () {
    database
      ..execute('CREATE TABLE foo2 (bar)')
      ..execute(
          "INSERT INTO foo2 VALUES ('AaAaaaAA'), ('BBBbBb'),('cCCCcc    '), ('  dD   ')")
      ..createCollation(
        name: "RTRIMNOCASE",
        function: (String? a, String? b) {
          final compareA = a?.toLowerCase().trimRight();
          final compareB = b?.toLowerCase().trimRight();

          if (compareA == null && compareB == null) {
            return 0;
          } else if (compareA == null) {
            // a < b
            return -1;
          } else if (compareB == null) {
            // a > b
            return 1;
          } else {
            return compareA.compareTo(compareB);
          }
        },
      );

    expect(
      database.select(
          "SELECT * FROM foo2 WHERE bar = 'aaaaAaAa   ' COLLATE RTRIMNOCASE"),
      [
        {'bar': 'AaAaaaAA'},
      ],
    );

    expect(
      database.select(
          "SELECT * FROM foo2 WHERE bar = 'bbbbbb' COLLATE RTRIMNOCASE"),
      [
        {'bar': 'BBBbBb'},
      ],
    );

    expect(
      database.select(
          "SELECT * FROM foo2 WHERE bar = 'cCcccC' COLLATE RTRIMNOCASE"),
      [
        {'bar': 'cCCCcc    '},
      ],
    );

    expect(
      database
          .select("SELECT * FROM foo2 WHERE bar = 'dd' COLLATE RTRIMNOCASE"),
      isEmpty,
    );
  });

  test('prepare does not throw for multiple statements by default', () {
    final stmt = database.prepare('SELECT 1; SELECT 2');
    expect(stmt.sql, 'SELECT 1;');
  });

  test('prepare throws with checkNoTail', () {
    expect(() => database.prepare('SELECT 1; SELECT 2', checkNoTail: true),
        throwsArgumentError);
  });

  group('prepareMultiple', () {
    test('can prepare multiple statements', () {
      final statements = database.prepareMultiple('SELECT 1; SELECT 2;');
      expect(statements, [_statement('SELECT 1;'), _statement(' SELECT 2;')]);
    });

    test('fails for trailing syntax error', () {
      expect(() => database.prepareMultiple('SELECT 1; error here '),
          throwsA(isA<SqliteException>()));
    });

    test('fails for syntax error in the middle', () {
      expect(() => database.prepareMultiple('SELECT 1; error here; SELECT 2;'),
          throwsA(isA<SqliteException>()));
    });

    group('edge-cases', () {
      test('empty string', () {
        expect(() => database.prepare(''), throwsArgumentError);
        expect(database.prepareMultiple(''), isEmpty);
      });

      test('whitespace only', () {
        expect(() => database.prepare('  '), throwsArgumentError);
        expect(() => database.prepare('/* oh hi */'), throwsArgumentError);

        expect(database.prepareMultiple('  '), isEmpty);
        expect(database.prepareMultiple('/* oh hi */'), isEmpty);
      });

      test('leading whitespace', () {
        final stmt =
            database.prepare('  /*wait for it*/ SELECT 1;', checkNoTail: true);
        expect(stmt.sql, '  /*wait for it*/ SELECT 1;');
      });

      test('trailing comment', () {
        final stmt =
            database.prepare('SELECT 1; /* done! */', checkNoTail: true);
        expect(stmt.sql, 'SELECT 1;');
      });

      test('whitespace between statements', () {
        final stmts = database.prepareMultiple('SELECT 1; /* and */ SELECT 2;');
        expect(stmts, hasLength(2));

        expect(stmts[0].sql, 'SELECT 1;');
        expect(stmts[1].sql, ' /* and */ SELECT 2;');
      });

      test('BigInt bounds', () {
        database.execute('CREATE TABLE foo (a INTEGER);');

        database.execute('INSERT INTO foo VALUES (?)',
            [BigInt.parse('-9223372036854775808')]);
        database.execute('INSERT INTO foo VALUES (?)',
            [BigInt.parse('9223372036854775807')]);

        final result = database.select('SELECT * FROM foo');
        expect(result, hasLength(2));
        expect(result.rows[0][0].toString(), '-9223372036854775808');
        expect(result.rows[1][0].toString(), '9223372036854775807');

        expect(
          () => database.execute('INSERT INTO foo VALUES (?)',
              [BigInt.parse('-9223372036854775809')]),
          throwsA(const TypeMatcher<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('BigInt value exceeds the range of 64 bits'))),
        );

        expect(
          () => database.execute('INSERT INTO foo VALUES (?)',
              [BigInt.parse('9223372036854775808')]),
          throwsA(const TypeMatcher<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('BigInt value exceeds the range of 64 bits'))),
        );
      });
    });
  });

  group('update stream', () {
    setUp(() {
      database.execute('CREATE TABLE tbl (a TEXT, b INT);');
    });

    test('emits event after insert', () {
      expect(database.updates,
          emits(_update(SqliteUpdate(SqliteUpdateKind.insert, 'tbl', 1))));

      database.execute("INSERT INTO tbl VALUES ('', 1);");
    });

    test('emits event after update', () {
      database.execute("INSERT INTO tbl VALUES ('', 1);");

      expect(database.updates,
          emits(_update(SqliteUpdate(SqliteUpdateKind.update, 'tbl', 1))));

      database.execute("UPDATE tbl SET b = b + 1;");
    });

    test('emits event after delete', () {
      database.execute("INSERT INTO tbl VALUES ('', 1);");

      expect(database.updates,
          emits(_update(SqliteUpdate(SqliteUpdateKind.delete, 'tbl', 1))));

      database.execute("DELETE FROM tbl WHERE b = 1;");
    });

    test('removes callback when no listener exists', () async {
      database.execute("INSERT INTO tbl VALUES ('', 1);");

      final subscription =
          database.updates.listen(expectAsync1((data) {}, count: 0));

      // Pause the subscription, cause an update and resume. As no listener
      // exists, no event should have been received and buffered.
      subscription.pause();
      database.execute("DELETE FROM tbl WHERE b = 1;");
      subscription.resume();
      await pumpEventQueue();

      await subscription.cancel();
    });

    test('closes when disposing the database', () {
      expect(database.updates.listen(null).asFuture(null), completes);
      database.dispose();
    });
  });

  group('unicode handling', () {
    test('accents in statements', () {
      final table = 'télé'; // with accent
      final column = 'mycolumn';

      database
        ..execute('''
    CREATE TABLE $table (
      $column INTEGER
    )''')
        ..execute('INSERT INTO $table($column) VALUES(1)');

      final statement = database.prepare('SELECT * FROM $table;');
      final cursor = statement.selectCursor();
      expect(cursor.moveNext(), isTrue);

      database.dispose();
    });

    test('return value of function', () {
      database.createFunction(functionName: 'test', function: (args) => 'télé');

      expect(database.select('SELECT test() AS r'), [
        {'r': 'télé'}
      ]);
    });

    test('parameter', () {
      expect(database.select('SELECT ? AS r', ['télé']), [
        {'r': 'télé'}
      ]);
    });
  });

  group('double quotes as literals', () {
    const query = 'SELECT "foo" AS double, \'bar\' AS single';

    test('enable', () {
      database.config.doubleQuotedStringLiterals = true;

      expect(database.select(query), [
        {
          'double': 'foo',
          'single': 'bar',
        }
      ]);
    });

    test('disable', () {
      database.config.doubleQuotedStringLiterals = false;

      expect(
        () => database.select(query),
        throwsSqlError(SqlError.SQLITE_ERROR, 1),
      );
    });
  });

  test('autocommit', () {
    expect(database.autocommit, equals(true));
    database.execute('BEGIN');
    expect(database.autocommit, equals(false));
    database.execute('ROLLBACK');
    expect(database.autocommit, equals(true));
  });
}

/// Aggregate function that counts the length of all string parameters it
/// receives.
class _SummedStringLength implements AggregateFunction<int> {
  const _SummedStringLength();

  @override
  AggregateContext<int> createContext() {
    return AggregateContext(0);
  }

  @override
  void step(List<Object?> arguments, AggregateContext<int> context) {
    if (arguments.length != 1) return;

    final arg = arguments.single;
    if (arg is String) {
      context.value += arg.length;
    }
  }

  @override
  Object finalize(AggregateContext<int> context) => context.value;
}

class _SumInt implements WindowFunction<int> {
  @override
  AggregateContext<int> createContext() => AggregateContext(0);

  @override
  Object? finalize(AggregateContext<int> context) {
    // There's nothing to finalize
    return value(context);
  }

  int _argument(List<Object?> arguments) {
    return arguments.single! as int;
  }

  @override
  void inverse(List<Object?> arguments, AggregateContext<int> context) {
    context.value -= _argument(arguments);
  }

  @override
  void step(List<Object?> arguments, AggregateContext<int> context) {
    context.value += _argument(arguments);
  }

  @override
  Object? value(AggregateContext<int> context) => context.value;
}

Matcher _statement(String sql) {
  return isA<CommonPreparedStatement>().having((e) => e.sql, 'sql', sql);
}

Matcher _update(SqliteUpdate update) {
  return isA<SqliteUpdate>()
      .having((e) => e.kind, 'kind', update.kind)
      .having((e) => e.tableName, 'tableName', update.tableName)
      .having((e) => e.rowId, 'rowId', update.rowId);
}
