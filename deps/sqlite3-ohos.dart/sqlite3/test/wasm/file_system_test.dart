@Tags(['wasm'])
library;

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:sqlite3/wasm.dart';
import 'package:test/test.dart';

import 'utils.dart';

const _fsRoot = '/test';

Future<void> main() async {
  // dart2wasm does not currently support Random.secure(), so we have to use
  // this as a fallback.
  final random = Random();

  group('in memory', () {
    _testWith(() => InMemoryFileSystem(random: random));
  });

  group('indexed db', () {
    _testWith(
        () => IndexedDbFileSystem.open(dbName: _randomName(), random: random));

    test('example with frequent writes', () async {
      final fileSystem =
          await IndexedDbFileSystem.open(dbName: 'test', random: random);
      final sqlite3 = await loadSqlite3(fileSystem);
      final database = sqlite3.open('test');
      expect(database.userVersion, 0);
      database.userVersion = 1;
      expect(database.userVersion, 1);

      database.execute('CREATE TABLE IF NOT EXISTS users ( '
          'id INTEGER NOT NULL, '
          'name TEXT NOT NULL, '
          'email TEXT NOT NULL UNIQUE, '
          'user_id INTEGER NOT NULL, '
          'PRIMARY KEY (id));');

      final prepared = database.prepare('INSERT INTO users '
          '(id, name, email, user_id) VALUES (?, ?, ?, ?)');

      for (var i = 0; i < 200; i++) {
        prepared.execute(
          [
            BigInt.from(i),
            'name',
            'email${BigInt.from(i)}',
            BigInt.from(i),
          ],
        );
      }

      expect(database.select('SELECT * FROM users'), hasLength(200));

      database.dispose();

      // file-system should save reasonably quickly
      await fileSystem.close().timeout(const Duration(seconds: 1));

      final fileSystem2 =
          await IndexedDbFileSystem.open(dbName: 'test', random: random);
      final sqlite32 = await loadSqlite3(fileSystem2);
      final database2 = sqlite32.open('test');
      expect(database2.userVersion, 1);
      expect(database2.select('SELECT * FROM users'), hasLength(200));
    }, onPlatform: {'wasm': Skip('Broken on dart2wasm')});
  });
}

final _random = Random(DateTime.now().millisecond);
String _randomName() => _random.nextInt(0x7fffffff).toString();

Future<void> _disposeFileSystem(VirtualFileSystem fs, [String? name]) async {
  if (fs is IndexedDbFileSystem) {
    await fs.close();
    if (name != null) await IndexedDbFileSystem.deleteDatabase(name);
  }
}

Future<void> _testWith(FutureOr<VirtualFileSystem> Function() open) async {
  late VirtualFileSystem fs;

  setUp(() async {
    fs = await open();
  });

  tearDown(() => _disposeFileSystem(fs));

  test('can create files', () {
    expect(fs.exists('$_fsRoot/foo.txt'), isFalse);
    fs.createFile('$_fsRoot/foo.txt');
    expect(fs.exists('$_fsRoot/foo.txt'), isTrue);
    fs.xDelete('$_fsRoot/foo.txt', 0);
    expect(fs.exists('$_fsRoot/foo.txt'), isFalse);
  });

  test('can create and delete multiple files', () {
    final paths = <String>[];

    for (var i = 1; i <= 10; i++) {
      final path = '$_fsRoot/foo$i.txt';
      paths.add(path);

      fs.createFile(path);
      expect(fs.exists(path), isTrue);
    }

    for (final path in paths) {
      fs.xDelete(path, 0);
      expect(fs.exists(path), isFalse);
    }
  });

  test('reads and writes', () {
    expect(fs.exists('$_fsRoot/foo.txt'), isFalse);

    final file = fs
        .xOpen(Sqlite3Filename('$_fsRoot/foo.txt'), SqlFlag.SQLITE_OPEN_CREATE)
        .file;

    fs.createFile('$_fsRoot/foo.txt');
    addTearDown(() {
      file.xClose();
      fs.xDelete('$_fsRoot/foo.txt', 0);
    });

    expect(file.xFileSize(), isZero);

    file.xTruncate(1024);
    expect(file.xFileSize(), 1024);

    file.xTruncate(600);
    expect(file.xFileSize(), 600);

    file.xTruncate(0);
    expect(file.xFileSize(), 0);

    file.xWrite(Uint8List.fromList([1, 2, 3]), 0);
    expect(file.xFileSize(), 3);

    final target = Uint8List(3);
    file.xRead(target, 0);
    expect(target, [1, 2, 3]);
  });
}

extension on VirtualFileSystem {
  bool exists(String file) => xAccess(file, 0) != 0;

  void createFile(String path) {
    final open = xOpen(Sqlite3Filename(path), SqlFlag.SQLITE_OPEN_CREATE);
    open.file.xClose();
  }
}
