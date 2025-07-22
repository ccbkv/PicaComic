import 'dart:ffi';

import 'package:integration_test/integration_test.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';
import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();

    open.overrideFor(
        OperatingSystem.android, () => DynamicLibrary.open('libsqlcipher.so'));
  });

  test('can open sqlite3', () {
    print(sqlite3.version);
  });

  test('contains sqlite3_key function', () {
    expect(open.openSqlite().lookup('sqlite3_key'),
        isA<Pointer>().having((e) => e.address, 'address', isPositive));
  });
}
