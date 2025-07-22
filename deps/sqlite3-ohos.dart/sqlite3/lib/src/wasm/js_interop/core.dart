import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('BigInt')
external JSBigInt _bigInt(JSAny? s);

@JS('Number')
external JSNumber _number(JSAny? obj);

extension type WrappedJSAny._(JSAny _) implements JSAny {
  external static JSArray<JSAny?> keys(JSObject o);

  @JS('toString')
  external JSString _toString();
}

@JS('Object')
extension type WrappedJSObject._(JSObject _) implements JSObject {
  external static JSArray<JSAny?> keys(JSObject o);
}

extension type JsBigInt(JSBigInt _jsBigInt) implements JSBigInt {
  factory JsBigInt.parse(String s) => JsBigInt(_bigInt(s.toJS));
  factory JsBigInt.fromInt(int i) => JsBigInt(_bigInt(i.toJS));
  factory JsBigInt.fromBigInt(BigInt i) => JsBigInt.parse(i.toString());

  int get asDartInt => _number(_jsBigInt).toDartInt;

  BigInt get asDartBigInt => BigInt.parse(jsToString());

  JSBigInt get jsObject => _jsBigInt;

  bool get isSafeInteger {
    const maxSafeInteger = 9007199254740992;
    const minSafeInteger = -maxSafeInteger;

    return minSafeInteger.toJS.lessThanOrEqualTo(_jsBigInt).toDart &&
        _jsBigInt.lessThanOrEqualTo(maxSafeInteger.toJS).toDart;
  }

  Object toDart() {
    return isSafeInteger ? asDartInt : asDartBigInt;
  }

  String jsToString() {
    return (_jsBigInt as WrappedJSAny)._toString().toDart;
  }
}

extension type IteratorResult<T extends JSAny?>(JSObject _)
    implements JSObject {
  external JSBoolean? get done;
  external T? get value;
}

extension type AsyncIterator<T extends JSAny?>(JSObject _) implements JSObject {
  external JSPromise<IteratorResult<T>> next();
}

@JS('Symbol.asyncIterator')
external JSSymbol get _asyncIterator;

/// Exposes the async iterable interface as a Dart stream.
///
/// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Iteration_protocols#the_async_iterator_and_async_iterable_protocols
class AsyncJavaScriptIteratable<T extends JSAny?> extends Stream<T> {
  final JSObject _jsObject;

  AsyncJavaScriptIteratable(this._jsObject) {
    if (!_jsObject.hasProperty(_asyncIterator).toDart) {
      throw ArgumentError('Target object does not implement the async iterable '
          'interface');
    }
  }

  @override
  StreamSubscription<T> listen(void Function(T event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    final iterator = _jsObject.callMethod<AsyncIterator<T>>(_asyncIterator);
    final controller = StreamController<T>(sync: true);
    JSPromise<IteratorResult<T>>? currentlyPendingPromise;

    void fetchNext() {
      assert(currentlyPendingPromise == null);
      final promise = currentlyPendingPromise = iterator.next();

      promise.toDart.then(
        (result) {
          final done = result.done?.toDart ?? false;
          final value = result.value;

          if (done) {
            controller.close();

            currentlyPendingPromise = null;
          } else {
            controller.add(value as T);

            currentlyPendingPromise = null;
            if (!controller.isPaused) {
              fetchNext();
            }
          }
        },
        onError: controller.addError,
      );
    }

    void fetchNextIfNecessary() {
      if (currentlyPendingPromise == null && !controller.isPaused) {
        fetchNext();
      }
    }

    controller
      ..onListen = fetchNext
      ..onResume = fetchNextIfNecessary;

    return controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}
