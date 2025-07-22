@Tags(['wasm'])
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:sqlite3/wasm.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import 'utils.dart';

void main() {
  for (final throughFetch in [false, true]) {
    group(throughFetch ? 'with fetch' : 'manually', () {
      late WasmSqlite3 sqlite3;

      setUpAll(() async {
        if (throughFetch) {
          sqlite3 = await loadSqlite3();
        } else {
          final channel = spawnHybridUri('/test/wasm/asset_server.dart');
          final port = (await channel.stream.first as double).toInt();

          final sqliteWasm =
              Uri.parse('http://localhost:$port/example/web/sqlite3.wasm');

          final response = await http.get(sqliteWasm);
          if (response.statusCode != 200) {
            throw StateError(
                'Could not load module (${response.statusCode} ${response.body})');
          }

          sqlite3 = await WasmSqlite3.load(response.bodyBytes);
          sqlite3.registerVirtualFileSystem(
            // Not using the default Random.secure() because it's not supported
            // by dart2wasm
            InMemoryFileSystem(random: Random()),
            makeDefault: true,
          );
        }
      });

      test('get version', () {
        final version = sqlite3.version;
        expect(
          version,
          isA<Version>()
              .having((e) => e.libVersion, 'libVersion', startsWith('3.46')),
        );
      });

      test('can use current date', () {
        final db = sqlite3.openInMemory();
        addTearDown(db.dispose);

        final results =
            db.select("SELECT strftime('%s', CURRENT_TIMESTAMP) AS r");
        final row = results.single['r'] as String;

        expect(int.parse(row),
            closeTo(DateTime.now().millisecondsSinceEpoch ~/ 1000, 5));
      });
    });
  }

  group(
    'can be used in workers',
    () {
      late String workerUri;
      late String wasmUri;

      setUpAll(() async {
        final channel = spawnHybridUri('/test/wasm/worker_server.dart');
        final port = (await channel.stream.first as double).toInt();

        final uri = 'http://localhost:$port/worker.dart.js';
        wasmUri = 'http://localhost:$port/sqlite3.wasm';
        final blob = web.Blob(['importScripts("$uri");'.toJS].toJS,
            web.BlobPropertyBag(type: 'application/javascript'));

        workerUri = web.URL.createObjectURL(blob);
      });

      // See worker.dart for the supported backends
      for (final backend in ['memory', 'opfs-simple', 'opfs', 'indexeddb']) {
        final requiresSab = backend == 'opfs';
        final missingSab =
            requiresSab && globalContext.has('SharedArrayBuffer');

        test(
          backend,
          () async {
            final worker = web.Worker(workerUri.toJS);

            web.EventStreamProviders.errorEvent
                .forTarget(worker)
                .listen((error) {
              if (error.instanceOfString('ErrorEvent')) {
                final event = error as web.ErrorEvent;
                fail('Error ${event.message} - ${event.error}');
              } else {
                fail(error.toString());
              }
            });

            // Inform the worker about the test we want to run
            worker.postMessage([backend.toJS, wasmUri.toJS].toJS);

            final response = (await web.EventStreamProviders.messageEvent
                    .forTarget(worker)
                    .first)
                .data as JSArray;
            final status = response.toDart[0] as JSBoolean;

            if (!status.toDart) {
              throw 'Exception in worker: $response';
            }
          },
          skip: missingSab
              ? 'This test requires SharedArrayBuffers that cannot be enabled '
                  'on this platform with a simple `dart test` setup.'
              : null,
          onPlatform: {
            if (backend == 'opfs')
              'chrome || edge':
                  Skip('todo: Always times out in GitHub actions'),
            if (backend == 'opfs')
              'firefox': Skip('todo: Currently broken in firefox'),
          },
        );
      }
    },
  );
}
