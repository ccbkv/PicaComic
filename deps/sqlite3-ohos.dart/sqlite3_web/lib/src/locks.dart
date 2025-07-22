import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart';

@JS('navigator')
external Navigator get _navigator;

class WebLocks {
  final LockManager _lockManager;

  WebLocks._(this._lockManager);

  Future<HeldLock> request(String name) {
    final gotLock = Completer<HeldLock>.sync();

    JSPromise callback(JSAny lock) {
      final completer = Completer<void>.sync();
      gotLock.complete(HeldLock._(completer));
      return completer.future.toJS;
    }

    _lockManager.request(name, callback.toJS);
    return gotLock.future;
  }

  static WebLocks? instance =
      (_navigator as JSObject).hasProperty('locks'.toJS).toDart
          ? WebLocks._(_navigator.locks)
          : null;
}

class HeldLock {
  final Completer<void> _completer;

  HeldLock._(this._completer);

  void release() => _completer.complete();
}
