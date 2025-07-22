import 'package:sqlite3_web/sqlite3_web.dart';

import 'controller.dart';

void main() {
  WebSqlite.workerEntrypoint(controller: ExampleController(isInWorker: true));
}
