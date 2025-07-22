import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart'
    show getApplicationDocumentsDirectory;
import 'package:sqlite3/common.dart' show CommonDatabase;
import 'package:sqlite3/sqlite3.dart' show sqlite3;

Future<CommonDatabase> openSqliteDb() async {
  final docsDir = await getApplicationDocumentsDirectory();
  final filename = path.join(docsDir.path, 'my_app.db');
  return sqlite3.open(filename);
}
