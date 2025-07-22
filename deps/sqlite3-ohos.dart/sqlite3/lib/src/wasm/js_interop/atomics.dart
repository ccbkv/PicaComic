import 'dart:typed_data';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('Int32Array')
external JSFunction _int32Array;

@JS('Uint8Array')
external JSFunction _uint8Array;

@JS('DataView')
external JSFunction _dataView;

@JS()
extension type SharedArrayBuffer._(JSObject _) implements JSObject {
  external factory SharedArrayBuffer(int length);

  external int get byteLength;

  Int32List asInt32List() {
    return _int32Array.callAsConstructor<JSInt32Array>(this).toDart;
  }

  ByteData asByteData(int offset, int length) {
    return _dataView
        .callAsConstructor<JSDataView>(this, offset.toJS, length.toJS)
        .toDart;
  }

  Uint8List asUint8List() {
    return _uint8Array.callAsConstructor<JSUint8Array>(this).toDart;
  }

  Uint8List asUint8ListSlice(int offset, int length) {
    return _uint8Array
        .callAsConstructor<JSUint8Array>(this, offset.toJS, length.toJS)
        .toDart;
  }
}

@JS('Atomics')
extension type _Atomics._(JSObject _) implements JSObject {
  @JS('wait')
  external static JSString wait(JSInt32Array typedArray, int index, int value);

  @JS('wait')
  external static JSString waitWithTimeout(
      JSInt32Array typedArray, int index, int value, int timeOutInMillis);

  @JS()
  external static void notify(JSInt32Array typedArray, int index, [num count]);

  @JS()
  external static int store(JSInt32Array typedArray, int index, int value);

  @JS()
  external static int load(JSInt32Array typedArray, int index);
}

class Atomics {
  static const ok = 'ok';
  static const notEqual = 'not-equal';
  static const timedOut = 'timed-out';

  static bool get supported {
    return globalContext.has('Atomics');
  }

  static String wait(Int32List typedArray, int index, int value) {
    return _Atomics.wait(typedArray.toJS, index, value).toDart;
  }

  static String waitWithTimeout(
      Int32List typedArray, int index, int value, int timeOutInMillis) {
    return _Atomics.waitWithTimeout(
            typedArray.toJS, index, value, timeOutInMillis)
        .toDart;
  }

  static void notify(Int32List typedArray, int index,
      [num count = double.infinity]) {
    _Atomics.notify(typedArray.toJS, index, count);
  }

  static int store(Int32List typedArray, int index, int value) {
    return _Atomics.store(typedArray.toJS, index, value);
  }

  static int load(Int32List typedArray, int index) {
    return _Atomics.load(typedArray.toJS, index);
  }
}
