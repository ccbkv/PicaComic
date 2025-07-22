import 'dart:js_interop';

import 'package:sqlite3/wasm.dart';
import 'package:web/web.dart' as web;

@JS()
external bool get crossOriginIsolated;

void main() {
  print('worker main');
  final self = (globalContext as web.DedicatedWorkerGlobalScope);

  if (!WasmVfs.supportsAtomicsAndSharedMemory) {
    throw UnsupportedError(
        'Missing support for Atomics or SharedArrayBuffer! Isolated: $crossOriginIsolated');
  }

  Future<void> handleEvent(web.MessageEvent event) async {
    final data = event.data;

    if (data.equals('start'.toJS).toDart) {
      final options = WasmVfs.createOptions();
      final worker = web.Worker(''.toJS); // Clone this worker
      worker.postMessage(options);

      // Now, wait for the worker to report that it has been initialized.
      await web.EventStreamProviders.messageEvent.forTarget(worker).first;

      final sqlite3 =
          await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.debug.wasm'));
      sqlite3.registerVirtualFileSystem(
          await SimpleOpfsFileSystem.loadFromStorage('worker-test'),
          makeDefault: true);

      sqlite3.open('/database')
        ..execute('pragma user_version = 1')
        ..execute('CREATE TABLE foo (bar INTEGER NOT NULL);')
        ..execute('INSERT INTO foo (bar) VALUES (?)', [3])
        ..dispose();

      final db = sqlite3.open('/database');
      print(db.select('SELECT * FROM foo'));
    } else {
      final message = data as WorkerOptions;

      final worker = await VfsWorker.create(message);

      self.postMessage(true.toJS);
      await worker.start();
    }
  }

  self.onmessage = (web.MessageEvent event) {
    handleEvent(event);
  }.toJS;
}
