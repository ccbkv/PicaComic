import 'package:sqlite3/common.dart' show CommonDatabase;
import 'sqlite3/sqlite3.dart' show openSqliteDb;

late CommonDatabase sqliteDb;

Future<void> openDb() async {
  sqliteDb = await openSqliteDb();

  final dbVersion =
      sqliteDb.select('PRAGMA user_version').first['user_version'];

  print('DB version: $dbVersion');

  if (dbVersion == 0) {
    sqliteDb.execute('''
      BEGIN;
      -- TODO
      PRAGMA user_version = 1;
      COMMIT;
    ''');
  }
}
