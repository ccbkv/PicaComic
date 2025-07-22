import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart' as ffi;

import 'sqlite3.g.dart';

const allocate = ffi.malloc;

/// Loads a null-pointer with a specified type.
///
/// The [nullptr] getter from `dart:ffi` can be slow due to being a
/// `Pointer<Null>` on which the VM has to perform runtime type checks. See also
/// https://github.com/dart-lang/sdk/issues/39488
@pragma('vm:prefer-inline')
Pointer<T> nullPtr<T extends NativeType>() => nullptr.cast<T>();

Pointer<Void> _freeImpl(Pointer<Void> ptr) {
  ptr.free();
  return nullPtr();
}

/// Pointer to a function that frees memory we allocated.
///
/// This corresponds to `void(*)(void*)` arguments found in sqlite.
final Pointer<NativeFunction<Pointer<Void> Function(Pointer<Void>)>>
    freeFunctionPtr = Pointer.fromFunction(_freeImpl);

extension FreePointerExtension on Pointer {
  void free() => allocate.free(this);
}

Pointer<Uint8> allocateBytes(List<int> bytes, {int additionalLength = 0}) {
  final ptr = allocate.allocate<Uint8>(bytes.length + additionalLength);

  ptr.asTypedList(bytes.length + additionalLength)
    ..setAll(0, bytes)
    ..fillRange(bytes.length, bytes.length + additionalLength, 0);

  return ptr;
}

extension Utf8Utils on Pointer<sqlite3_char> {
  int get _length {
    final asBytes = cast<Uint8>();
    var length = 0;

    for (; asBytes[length] != 0; length++) {}
    return length;
  }

  String? readNullableString([int? length]) {
    return isNullPointer ? null : readString(length);
  }

  String readString([int? length]) {
    final resolvedLength = length ??= _length;

    return utf8.decode(cast<Uint8>().asTypedList(resolvedLength));
  }

  static Pointer<sqlite3_char> allocateZeroTerminated(String string) {
    return allocateBytes(utf8.encode(string), additionalLength: 1).cast();
  }
}

extension PointerUtils on Pointer<NativeType> {
  bool get isNullPointer => address == 0;

  Uint8List copyRange(int length) {
    final list = Uint8List(length);
    list.setAll(0, cast<Uint8>().asTypedList(length));
    return list;
  }
}
