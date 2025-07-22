@TestOn('browser')
library;

import 'package:sqlite3_web/sqlite3_web.dart';
import 'package:sqlite3_web/src/client.dart';
import 'package:test/test.dart';

void main() {
  test('finds preferrable implementations', () {
    final all = [
      for (final storage in StorageMode.values)
        for (final access in AccessMode.values) (storage, access)
    ];

    all.shuffle();
    all.sort(DatabaseClient.preferrableMode);

    expect(all, [
      (StorageMode.opfs, AccessMode.throughSharedWorker),
      (StorageMode.opfs, AccessMode.throughDedicatedWorker),
      (StorageMode.opfs, AccessMode.inCurrentContext),
      (StorageMode.indexedDb, AccessMode.throughSharedWorker),
      (StorageMode.indexedDb, AccessMode.throughDedicatedWorker),
      (StorageMode.indexedDb, AccessMode.inCurrentContext),
      (StorageMode.inMemory, AccessMode.throughSharedWorker),
      (StorageMode.inMemory, AccessMode.throughDedicatedWorker),
      (StorageMode.inMemory, AccessMode.inCurrentContext),
    ]);
  });
}
