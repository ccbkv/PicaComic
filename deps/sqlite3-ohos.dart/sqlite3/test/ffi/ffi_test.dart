@Tags(['ffi'])
library;

import 'dart:ffi';

import 'package:sqlite3/src/ffi/memory.dart';
import 'package:test/test.dart';

void main() {
  test('isNullPointer', () {
    expect(Pointer.fromAddress(1).isNullPointer, isFalse);
    expect(Pointer.fromAddress(0).isNullPointer, isTrue);
  });
}
