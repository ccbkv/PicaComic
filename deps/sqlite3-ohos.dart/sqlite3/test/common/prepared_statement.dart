import 'dart:async';
import 'dart:typed_data';

import 'package:sqlite3/common.dart';
import 'package:sqlite3/src/implementation/statement.dart';
import 'package:test/test.dart';

import 'utils.dart';

void testPreparedStatements(
  FutureOr<CommonSqlite3> Function() loadSqlite, {
  bool supportsReturning = true,
}) {
  late CommonSqlite3 sqlite3;

  setUpAll(() async => sqlite3 = await loadSqlite());

  test('report used SQL', () {
    final db = sqlite3.openInMemory()
      ..execute('CREATE TABLE foo (a INTEGER);')
      ..execute('CREATE TABLE télé (a INTEGER);');
    addTearDown(db.dispose);

    final stmts = db.prepareMultiple('SELECT * FROM foo;SELECT * FROM télé;');

    expect(stmts[0].sql, 'SELECT * FROM foo;');
    expect(stmts[1].sql, 'SELECT * FROM télé;');
  });

  test('prepared statements can be used multiple times', () {
    final opened = sqlite3.openInMemory();
    opened.execute('CREATE TABLE tbl (a TEXT);');

    final stmt = opened.prepare('INSERT INTO tbl(a) VALUES(?)');
    stmt.execute(<String>['a']);
    stmt.execute(<String>['b']);
    stmt.dispose();

    final select = opened.prepare('SELECT * FROM tbl ORDER BY a');
    final result = select.select();

    expect(result, hasLength(2));
    expect(result.map((row) => row['a'] as String), ['a', 'b']);

    select.dispose();

    opened.dispose();
  });

  test('prepared statements without parameters can be used multiple times', () {
    final opened = sqlite3.openInMemory();
    addTearDown(opened.dispose);
    opened
      ..execute('CREATE TABLE tbl (a TEXT);')
      ..execute('INSERT INTO tbl DEFAULT VALUES;');

    final stmt = opened.prepare('SELECT * FROM tbl');
    expect(stmt.select(), hasLength(1));
    expect(stmt.select(), hasLength(1));
  });

  test('prepared statements cannot be used after close', () {
    final opened = sqlite3.openInMemory();

    final stmt = opened.prepare('SELECT ?');
    stmt.dispose();

    expect(stmt.select, throwsStateError);
    opened.dispose();
  });

  test('prepared statements cannot be used after db is closed', () {
    final opened = sqlite3.openInMemory();
    final stmt = opened.prepare('SELECT 1');
    opened.dispose();

    expect(stmt.select, throwsStateError);
  });

  test('parameterCount', () {
    final opened = sqlite3.openInMemory();
    addTearDown(opened.dispose);

    expect(opened.prepare('SELECT 1').parameterCount, 0);
    expect(opened.prepare('SELECT 1, ?2 AS r').parameterCount, 2);
  });

  test('isReadOnly', () {
    final opened = sqlite3.openInMemory()
      ..execute('CREATE TABLE tbl (a TEXT);');
    addTearDown(opened.dispose);

    expect(opened.prepare('SELECT 1').isReadOnly, isTrue);
    expect(opened.prepare('UPDATE tbl SET a = a || ?').isReadOnly, isFalse);
  });

  test('isExplain', () {
    final opened = sqlite3.openInMemory()
      ..execute('CREATE TABLE tbl (a TEXT);');
    addTearDown(opened.dispose);

    expect(opened.prepare('SELECT 1').isExplain, isFalse);
    expect(opened.prepare('EXPLAIN SELECT 1').isExplain, isTrue);
  });

  Uint8List? insertBlob(Uint8List? value) {
    final opened = sqlite3.openInMemory();
    opened.execute('CREATE TABLE tbl (x BLOB);');

    final insert = opened.prepare('INSERT INTO tbl VALUES (?)');
    insert.execute(<dynamic>[value]);
    insert.dispose();

    final select = opened.prepare('SELECT * FROM tbl');
    final result = select.select().single;

    opened.dispose();
    return result['x'] as Uint8List?;
  }

  test('can bind empty blob in prepared statements', () {
    expect(insertBlob(Uint8List(0)), isEmpty);
  });

  test('can bind null blob in prepared statements', () {
    expect(insertBlob(null), isNull);
  });

  test('can bind and read non-empty blob', () {
    const bytes = [1, 2, 3];
    expect(insertBlob(Uint8List.fromList(bytes)), bytes);
  });

  test('throws when sql statement has an error', () {
    final db = sqlite3.openInMemory();
    db.execute('CREATE TABLE foo (id INTEGER CHECK (id > 10));');

    final stmt = db.prepare('INSERT INTO foo VALUES (9)');

    expect(
      stmt.execute,
      throwsA(isA<SqliteException>()
          .having((e) => e.message, 'message', contains('constraint failed'))),
    );

    db.dispose();
  });

  test(
    'throws an exception when iterating over result rows',
    () {
      final db = sqlite3.openInMemory()
        ..createFunction(
          functionName: 'raise_if_two',
          function: (args) {
            if (args.first == 2) {
              // ignore: only_throw_errors
              throw 'parameter was two';
            } else {
              return null;
            }
          },
        );

      db.execute(
          'CREATE TABLE tbl (a INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT)');
      // insert with a = 1..3
      for (var i = 0; i < 3; i++) {
        db.execute('INSERT INTO tbl DEFAULT VALUES');
      }

      final statement =
          db.prepare('SELECT raise_if_two(a) FROM tbl ORDER BY a');

      expect(
        statement.select,
        throwsA(isA<SqliteException>()
            .having((e) => e.message, 'message', contains('was two'))),
      );
    },
  );

  test('can bind booleans', () {
    final db = sqlite3.openInMemory();
    final stmt = db.prepare('SELECT ?');
    final result = stmt.select([false]).single;

    expect(result.values.single, isZero);
    db.dispose();
  });

  test('can bind named parameters', () {
    final db = sqlite3.openInMemory();
    final stmt = db.prepare('SELECT ?1, :a, @b');
    final result = stmt
        .selectWith(StatementParameters.named({
          '?1': 'first',
          ':a': 'second',
          '@b': 'third',
        }))
        .single;

    expect(result.values, ['first', 'second', 'third']);
  });

  test('can bind custom values', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.dispose);

    final stmt = db.prepare('SELECT :a AS a, :b AS b');
    final result = stmt.selectWith(StatementParameters.named(
        {':a': 'normal parameter', ':b': _CustomValue()}));

    expect(result, [
      {'a': 'normal parameter', 'b': 42}
    ]);
  });

  group('checks that the amount of parameters are correct', () {
    late CommonDatabase db;

    setUp(() => db = sqlite3.openInMemory());
    tearDown(() => db.dispose());

    test('when no parameters are set', () {
      final stmt = db.prepare('SELECT ?');
      expect(stmt.select, throwsArgumentError);
    });

    test('when the wrong amount of parameters are set', () {
      final stmt = db.prepare('SELECT ?, ?');
      expect(() => stmt.select(<int>[1]), throwsArgumentError);
    });

    test('when not all names are covered', () {
      final stmt = db.prepare('SELECT :a, @b');
      expect(() => stmt.executeWith(StatementParameters.named({':a': 'a'})),
          throwsArgumentError);
    });

    test('when an invalid name is passed', () {
      final stmt = db.prepare('SELECT :a, @b');
      expect(
          () => stmt.executeWith(
              StatementParameters.named({':a': 'a', '@b': 'b', ':c': 'c'})),
          throwsArgumentError);
    });

    test('when named parameters are empty', () {
      final stmt = db.prepare('SELECT :a, @b');
      expect(() => stmt.executeWith(const StatementParameters.named({})),
          throwsArgumentError);
    });
  });

  test('select statements return expected value', () {
    final opened = sqlite3.openInMemory();

    final prepared = opened.prepare('SELECT ?');

    final result1 = prepared.select(<int>[1]);
    expect(result1.columnNames, ['?']);
    expect(result1.single.columnAt(0), 1);

    final result2 = prepared.select(<int>[2]);
    expect(result2.columnNames, ['?']);
    expect(result2.single.columnAt(0), 2);

    final result3 = prepared.select(<String>['']);
    expect(result3.columnNames, ['?']);
    expect(result3.single.columnAt(0), '');

    opened.dispose();
  });

  test('does not validate custom parameters', () {
    final opened = sqlite3.openInMemory();
    addTearDown(opened.dispose);

    final stmt = opened.prepare('SELECT ? AS r');
    expect(stmt.selectWith(StatementParameters.bindCustom((stmt) {})), [
      {'r': null}
    ]);
  });

  test('handles recompilations', () {
    final opened = sqlite3.openInMemory()
      ..execute('create table t (c1)')
      ..execute('insert into t values (1)');
    addTearDown(opened.dispose);

    final stmt = opened.prepare('select * from t');
    expect(stmt.select(), [
      {'c1': 1}
    ]);

    opened.execute('alter table t add column c2 default 2');

    expect(stmt.select(), [
      {'c1': 1, 'c2': 2}
    ]);
  });

  test('reset', () {
    final opened = sqlite3.openInMemory()
      ..execute('create table t (c1)')
      ..execute('begin;');

    final stmt = opened.prepare('insert into t values (1), (2) returning c1');
    final cursor = stmt.selectCursor();
    expect(cursor.moveNext(), isTrue);

    // This fails due to the pending write of the active statement
    expect(() => opened.execute('commit'), throwsSqlError(5, 5));

    stmt.reset();
    expect(cursor.moveNext(), isFalse);

    opened.execute('commit');
    opened.dispose();
  },
      skip: supportsReturning
          ? null
          : 'RETURNING not supported by current sqlite3 version');

  group('cursors', () {
    late CommonDatabase database;

    setUp(() => database = sqlite3.openInMemory());

    tearDown(() => database.dispose());

    test('report correct values', () {
      final stmt = database.prepare('VALUES (1), (2), (3);');

      expect(
        _TestIterable(stmt.selectCursor()).toList(),
        [
          {'column1': 1},
          {'column1': 2},
          {'column1': 3}
        ],
      );
    });

    test('bind variables', () {
      final stmt = database.prepare('VALUES (?), (?), (?);');

      expect(
        _TestIterable(stmt.selectCursor([2, 3, 5])).toList(),
        [
          {'column1': 2},
          {'column1': 3},
          {'column1': 5}
        ],
      );
    });

    test('throw exceptions', () {
      database
        ..execute('CREATE TABLE foo (a);')
        ..execute('INSERT INTO foo VALUES (1), (2), (3);')
        ..createFunction(
          functionName: 'throw_if',
          function: (args) {
            if (args[0] == args[1]) throw Exception('boom!');

            return args[0];
          },
          argumentCount: const AllowedArgumentCount(2),
        );

      final stmt = database.prepare(
          'WITH seq(a) AS (VALUES (1), (2), (3)) SELECT throw_if(a, 3) AS r FROM seq;');
      final cursor = stmt.selectCursor();

      expect(cursor.columnNames, ['r']);

      expect(cursor.moveNext(), isTrue);
      expect(cursor.current, {'r': 1});

      expect(cursor.moveNext(), isTrue);
      expect(cursor.current, {'r': 2});

      expect(cursor.moveNext, throwsA(isA<SqliteException>()));
      expect(cursor.moveNext(), isFalse);
    });

    test('handle recompilations while not running', () {
      final opened = sqlite3.openInMemory()
        ..execute('create table t (c1)')
        ..execute('insert into t values (1)');
      addTearDown(opened.dispose);

      final stmt = opened.prepare('select * from t');
      var cursor = stmt.selectCursor();

      expect(cursor.moveNext(), isTrue);
      expect(cursor.current, {'c1': 1});
      expect(cursor.moveNext(), isFalse);

      opened.execute('alter table t add column c2 default 2');
      cursor = stmt.selectCursor();
      expect(cursor.columnNames, ['c1']);

      expect(cursor.moveNext(), isTrue);
      expect(cursor.columnNames, ['c1', 'c2']);
      expect(cursor.current, {'c1': 1, 'c2': 2});
      expect(cursor.moveNext(), isFalse);
    });

    test('handles recompilations while running', () {
      final opened = sqlite3.openInMemory()
        ..execute('create table t (c1)')
        ..execute('insert into t values (1)')
        ..execute('insert into t values (2)');
      addTearDown(opened.dispose);

      final stmt = opened.prepare('select * from t');
      final cursor = stmt.selectCursor();

      expect(cursor.moveNext(), isTrue);
      expect(cursor.current, {'c1': 1});

      opened.execute('alter table t add column c2 default 2');

      // alter statements while the cursor is iterating don't seem to be causing
      // a recompile
      expect(cursor.moveNext(), isTrue);
      expect(cursor.current, {'c1': 2});
    });

    group('are closed', () {
      test('by closing the prepared statement', () {
        final stmt = database.prepare('VALUES (1), (2), (3);');
        final cursor = stmt.selectCursor();
        expect(cursor.moveNext(), isTrue);

        stmt.dispose();
        expect(cursor.moveNext(), isFalse);
      });

      test('by resetting the prepared statement', () {
        final stmt = database.prepare('VALUES (1), (2), (3);');
        final cursor = stmt.selectCursor();
        expect(cursor.moveNext(), isTrue);

        stmt.reset();
        expect(cursor.moveNext(), isFalse);
        stmt.dispose();
      });

      test('by invoking select', () {
        final stmt = database.prepare('VALUES (1), (2), (3);');
        final cursor = stmt.selectCursor();
        expect(cursor.moveNext(), isTrue);

        stmt.select();
        expect(cursor.moveNext(), isFalse);
      });

      test('by invoking execute', () {
        final stmt = database.prepare('VALUES (1), (2), (3);');
        final cursor = stmt.selectCursor();
        expect(cursor.moveNext(), isTrue);

        stmt.execute();
        expect(cursor.moveNext(), isFalse);
      });

      test('by invoking selectCursor', () {
        final stmt = database.prepare('VALUES (1), (2), (3);');
        final cursor = stmt.selectCursor();
        expect(cursor.moveNext(), isTrue);

        stmt.selectCursor();
        expect(cursor.moveNext(), isFalse);
      });
    });
  });

  group('returning', () {
    late CommonDatabase database;
    late CommonPreparedStatement statement;

    setUp(() {
      database = sqlite3.openInMemory()
        ..execute('CREATE TABLE tbl (foo TEXT);');
      statement =
          database.prepare('INSERT INTO tbl DEFAULT VALUES RETURNING *');
    });

    tearDown(() {
      statement.dispose();
      database.dispose();
    });

    test('can be used with execute', () {
      statement.execute();
    });

    test('can get returned rows', () {
      final result = statement.select();
      expect(result, hasLength(1));

      final row = result.single;
      expect(row, {'foo': null});
    });
  },
      skip: supportsReturning
          ? null
          : 'RETURNING not supported by current sqlite3 version');

  group('errors', () {
    late CommonDatabase db;

    setUp(() => db = sqlite3.openInMemory());
    tearDown(() => db.dispose());

    test('for syntax', () {
      final throwsSyntaxError = throwsSqlError(1, 1);

      expect(() => db.execute('DUMMY'), throwsSyntaxError);
      expect(() => db.prepare('DUMMY'), throwsSyntaxError);
    });

    test('for missing table', () {
      expect(() => db.execute('SELECT * FROM missing_table'),
          throwsSqlError(1, 1));
    });

    test('for violated primary key constraint', () {
      db
        ..execute('CREATE TABLE Test (name TEXT PRIMARY KEY)')
        ..execute("INSERT INTO Test(name) VALUES('test1')");

      expect(
        () => db.execute("INSERT INTO Test(name) VALUES('test1')"),
        // SQLITE_CONSTRAINT_PRIMARYKEY (1555)
        throwsSqlError(19, 1555),
      );

      expect(
        () => db.prepare('INSERT INTO Test(name) VALUES(?)').execute(['test1']),
        // SQLITE_CONSTRAINT_PRIMARYKEY (1555)
        throwsSqlError(19, 1555),
      );
    });

    test('for violated unique constraint', () {
      db
        ..execute('CREATE TABLE Test (id INT PRIMARY KEY, name TEXT UNIQUE)')
        ..execute("INSERT INTO Test(name) VALUES('test')");

      expect(
        () => db.execute("INSERT INTO Test(name) VALUES('test')"),
        // SQLITE_CONSTRAINT_UNIQUE (2067)
        throwsSqlError(19, 2067),
      );

      expect(
        () => db.prepare('INSERT INTO Test(name) VALUES(?)').execute(['test']),
        // SQLITE_CONSTRAINT_UNIQUE (2067)
        throwsSqlError(19, 2067),
      );
    });
  });
}

class _TestIterable<T> extends Iterable<T> {
  @override
  final Iterator<T> iterator;

  _TestIterable(this.iterator);
}

class _CustomValue implements CustomStatementParameter {
  @override
  void applyTo(CommonPreparedStatement statement, int index) {
    final stmt = statement as StatementImplementation;
    stmt.statement.sqlite3_bind_int64(index, 42);
  }
}
