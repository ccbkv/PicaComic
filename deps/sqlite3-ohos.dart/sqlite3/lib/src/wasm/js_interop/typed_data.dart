import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'core.dart';

extension NativeUint8List on Uint8List {
  /// A native version of [setRange] that takes another typed array directly.
  /// This avoids the type checks part of [setRange] in compiled JavaScript
  /// code.
  void set(Uint8List from, int offset) {
    toJS.callMethod('set'.toJS, from.toJS, offset.toJS);
  }
}

extension NativeDataView on ByteData {
  void setBigInt64(int offset, JsBigInt value, bool littleEndian) {
    toJS.callMethod(
        'setBigInt64'.toJS, offset.toJS, value.jsObject, littleEndian.toJS);
  }
}
