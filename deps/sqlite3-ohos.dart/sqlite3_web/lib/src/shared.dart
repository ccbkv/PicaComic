/// Functionality shared between workers and client code.

library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart';

/// Checks whether IndexedDB is working in the current browser.
Future<bool> checkIndexedDbSupport() async {
  if (!globalContext.has('indexedDB') ||
      // FileReader needed to read and write blobs efficiently
      !globalContext.has('FileReader')) {
    return false;
  }

  final idb = globalContext['indexedDB'] as IDBFactory;

  try {
    const name = 'drift_mock_db';

    final mockDb = await idb.open(name).completeOpen<IDBDatabase>();
    mockDb.close();
    idb.deleteDatabase(name);
  } catch (error) {
    return false;
  }

  return true;
}

/// Returns whether an drift-wasm database with the given [databaseName] exists.
Future<bool> checkIndexedDbExists(String databaseName) async {
  bool? indexedDbExists;

  try {
    final idb = globalContext['indexedDB'] as IDBFactory;

    final openRequest = idb.open(databaseName, 1);
    openRequest.onupgradeneeded = (IDBVersionChangeEvent event) {
      // If there's an upgrade, we're going from 0 to 1 - the database doesn't
      // exist! Abort the transaction so that we don't create it here.
      openRequest.transaction!.abort();
      indexedDbExists = false;
    }.toJS;
    final database = await openRequest.complete<IDBDatabase>();

    indexedDbExists ??= true;
    database.close();
  } catch (_) {
    // May throw due to us aborting in the upgrade callback.
  }

  return indexedDbExists ?? false;
}

/// Deletes a database from IndexedDb if supported.
Future<void> deleteDatabaseInIndexedDb(String databaseName) async {
  final idb = globalContext['indexedDB'] as IDBFactory;
  await idb.deleteDatabase(databaseName).complete<JSAny?>();
}

/// A single asynchronous lock implemented by future-chaining.
class Lock {
  Future<void>? _last;

  /// Waits for previous [synchronized]-calls on this [Lock] to complete, and
  /// then calls [block] before further [synchronized] calls are allowed.
  Future<T> synchronized<T>(FutureOr<T> Function() block) {
    final previous = _last;
    // This completer may not be sync: It must complete just after
    // callBlockAndComplete completes.
    final blockCompleted = Completer<void>();
    _last = blockCompleted.future;

    Future<T> callBlockAndComplete() {
      return Future.sync(block).whenComplete(blockCompleted.complete);
    }

    if (previous != null) {
      return previous.then((_) => callBlockAndComplete());
    } else {
      return callBlockAndComplete();
    }
  }
}

extension CompleteIdbRequest on IDBRequest {
  Future<T> complete<T extends JSAny?>() {
    final completer = Completer<T>.sync();

    EventStreamProviders.successEvent.forTarget(this).listen((event) {
      completer.complete(result as T);
    });
    EventStreamProviders.errorEvent.forTarget(this).listen((event) {
      completer.completeError(error ?? event);
    });

    return completer.future;
  }
}

extension CompleteOpenIdbRequest on IDBRequest {
  Future<T> completeOpen<T extends JSAny?>() {
    final completer = Completer<T>.sync();

    EventStreamProviders.successEvent.forTarget(this).listen((event) {
      completer.complete(result as T);
    });
    EventStreamProviders.errorEvent.forTarget(this).listen((event) {
      completer.completeError(error ?? event);
    });
    EventStreamProviders.blockedEvent.forTarget(this).listen((event) {
      completer.completeError(error ?? event);
    });

    return completer.future;
  }
}
