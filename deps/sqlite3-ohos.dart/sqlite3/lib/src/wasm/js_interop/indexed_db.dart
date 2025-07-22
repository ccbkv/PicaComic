import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart'
    show
        IDBFactory,
        IDBDatabaseInfo,
        IDBRequest,
        IDBCursor,
        EventStreamProviders;

extension RequestExt on IDBRequest {
  /// A [StreamIterator] to asynchronously iterate over a [Cursor].
  ///
  /// Dart provides a streaming view over cursors, but the confusing pause
  /// behavior of `await for` loops and IndexedDB's behavior of closing
  /// transactions that are not immediately used after an event leads to code
  /// that is hard to reason about.
  ///
  /// An explicit pull-based model makes it easy to iterate over values in a
  /// cursor while also being clearer about asynchronous suspensions one might
  /// want to avoid.
  StreamIterator<T> cursorIterator<T extends IDBCursor>() {
    return _CursorReader(this);
  }
}

class _CursorReader<T extends IDBCursor> implements StreamIterator<T> {
  T? _cursor;
  StreamSubscription<void>? _onSuccess, _onError;

  final IDBRequest _cursorRequest;

  _CursorReader(this._cursorRequest);

  @override
  Future<void> cancel() async {
    unawaited(_onSuccess?.cancel());
    unawaited(_onError?.cancel());

    _onSuccess = null;
    _onError = null;
  }

  @override
  T get current => _cursor ?? (throw StateError('Await moveNext() first'));

  @override
  Future<bool> moveNext() {
    assert(_onSuccess == null && _onError == null, 'moveNext() called twice');
    _cursor?.continue_();

    final completer = Completer<bool>.sync();
    _onSuccess = EventStreamProviders.successEvent
        .forTarget(_cursorRequest)
        .listen((event) {
      cancel();

      _cursor = _cursorRequest.result as T?;
      completer.complete(_cursor != null);
    });

    _onError = EventStreamProviders.errorEvent
        .forTarget(_cursorRequest)
        .listen((event) {
      cancel();
      completer.completeError(_cursorRequest.error ?? event);
    });

    return completer.future;
  }
}

@JS()
external IDBFactory? get indexedDB;

extension IdbFactoryExt on IDBFactory {
  Future<List<IDBDatabaseInfo>?> listDatabases() async {
    if (!has('databases')) {
      return null;
    }

    return (await databases().toDart).toDart;
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
  Future<T> completeOrBlocked<T extends JSAny?>() {
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
