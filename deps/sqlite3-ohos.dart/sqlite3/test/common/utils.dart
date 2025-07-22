import 'package:sqlite3/common.dart';
import 'package:test/test.dart';

Matcher throwsSqlError(int resultCode, int extendedResultCode) {
  return throwsA(isA<SqliteException>()
      .having(
          (e) => e.extendedResultCode, 'extendedResultCode', extendedResultCode)
      .having((e) => e.resultCode, 'resultCode', resultCode));
}
