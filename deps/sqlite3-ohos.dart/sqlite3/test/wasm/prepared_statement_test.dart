@Tags(['wasm'])
library;

import 'package:test/scaffolding.dart';

import '../common/prepared_statement.dart';
import 'utils.dart';

void main() {
  testPreparedStatements(loadSqlite3);
}
