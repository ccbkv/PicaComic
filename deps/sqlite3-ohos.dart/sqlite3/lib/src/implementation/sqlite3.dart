import 'package:meta/meta.dart';

import '../constants.dart';
import '../database.dart';
import '../sqlite3.dart';
import 'bindings.dart';
import 'database.dart';
import 'exception.dart';

base class Sqlite3Implementation implements CommonSqlite3 {
  final RawSqliteBindings bindings;

  Sqlite3Implementation(this.bindings);

  @visibleForOverriding
  CommonDatabase wrapDatabase(RawSqliteDatabase rawDb) {
    return DatabaseImplementation(bindings, rawDb);
  }

  @override
  String? get tempDirectory => bindings.sqlite3_temp_directory;

  @override
  set tempDirectory(String? value) => bindings.sqlite3_temp_directory = value;

  @override
  CommonDatabase open(String filename,
      {String? vfs,
      OpenMode mode = OpenMode.readWriteCreate,
      bool uri = false,
      bool? mutex}) {
    int flags;
    switch (mode) {
      case OpenMode.readOnly:
        flags = SqlFlag.SQLITE_OPEN_READONLY;
        break;
      case OpenMode.readWrite:
        flags = SqlFlag.SQLITE_OPEN_READWRITE;
        break;
      case OpenMode.readWriteCreate:
        flags = SqlFlag.SQLITE_OPEN_READWRITE | SqlFlag.SQLITE_OPEN_CREATE;
        break;
    }

    if (uri) {
      flags |= SqlFlag.SQLITE_OPEN_URI;
    }

    if (mutex != null) {
      flags |=
          mutex ? SqlFlag.SQLITE_OPEN_FULLMUTEX : SqlFlag.SQLITE_OPEN_NOMUTEX;
    }

    final result = bindings.sqlite3_open_v2(filename, flags, vfs);
    if (result.resultCode != SqlError.SQLITE_OK) {
      final exception = createExceptionRaw(
          bindings, result.result, result.resultCode,
          operation: 'opening the database');
      // Close the database after creating the exception, which needs to read
      // the extended error from the database.
      result.result.sqlite3_close_v2();
      throw exception;
    }

    return wrapDatabase(result.result..sqlite3_extended_result_codes(1));
  }

  @override
  CommonDatabase openInMemory() {
    return open(':memory:');
  }

  @override
  Version get version {
    return Version(
      bindings.sqlite3_libversion(),
      bindings.sqlite3_sourceid(),
      bindings.sqlite3_libversion_number(),
    );
  }
}
