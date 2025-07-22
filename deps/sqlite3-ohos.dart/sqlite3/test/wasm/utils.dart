import 'dart:math';

import 'package:sqlite3/wasm.dart';
import 'package:test/scaffolding.dart';

Future<WasmSqlite3> loadSqlite3([VirtualFileSystem? defaultVfs]) async {
  final channel = spawnHybridUri('/test/wasm/asset_server.dart');
  final port = (await channel.stream.first as double).toInt();

  final sqliteWasm =
      Uri.parse('http://localhost:$port/example/web/sqlite3.wasm');

  final sqlite3 = await WasmSqlite3.loadFromUrl(sqliteWasm);
  sqlite3.registerVirtualFileSystem(
    defaultVfs ??
        InMemoryFileSystem(
          // Not using the default Random.secure() because it's not supported
          // by dart2wasm
          random: Random(),
        ),
    makeDefault: true,
  );
  return sqlite3;
}
