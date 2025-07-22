import 'dart:html';

import 'package:sqlite3/wasm.dart';

Future<void> main() async {
  final startIndexedDb = document.getElementById('start-idb')!;
  final startOpfs = document.getElementById('start-opfs')!;

  startIndexedDb.onClick.listen((_) async {
    startIndexedDb.remove();

    final sqlite3 =
        await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.debug.wasm'));

    print(sqlite3.version);

    sqlite3.registerVirtualFileSystem(
      await IndexedDbFileSystem.open(dbName: 'sqlite3-example'),
      makeDefault: true,
    );

    sqlite3.open('/database')
      ..execute('pragma user_version = 1')
      ..execute('CREATE TABLE foo (bar INTEGER NOT NULL);')
      ..execute('INSERT INTO foo (bar) VALUES (?)', [3])
      ..dispose();

    final db = sqlite3.open('/database');
    print(db.select('SELECT * FROM foo'));
  });

  startOpfs.onClick.listen((_) async {
    startOpfs.remove();

    final worker = Worker('worker.dart.js');
    worker.postMessage('start');
  });
}
