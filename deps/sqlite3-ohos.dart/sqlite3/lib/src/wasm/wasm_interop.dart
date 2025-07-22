// ignore_for_file: avoid_dynamic_calls
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import '../../wasm.dart';
import '../implementation/bindings.dart';
import 'bindings.dart';
import 'js_interop.dart';

import 'package:web/web.dart' as web;

// ignore_for_file: non_constant_identifier_names

typedef Pointer = int;

class WasmBindings {
  // We're compiling to 32bit wasm
  static const pointerSize = 4;

  final WasmInstance instance;
  final Memory memory;

  final DartCallbacks callbacks;

  final JSFunction _malloc,
      _free,
      _create_window,
      _create_collation,
      _create_scalar,
      _create_aggregate,
      _register_vfs,
      _unregister_vfs,
      _update_hooks,
      _sqlite3_libversion,
      _sqlite3_sourceid,
      _sqlite3_libversion_number,
      _sqlite3_open_v2,
      _sqlite3_close_v2,
      _sqlite3_extended_errcode,
      _sqlite3_errmsg,
      _sqlite3_errstr,
      _sqlite3_extended_result_codes,
      _sqlite3_exec,
      _sqlite3_free,
      _sqlite3_prepare_v3,
      _sqlite3_bind_parameter_count,
      _sqlite3_column_count,
      _sqlite3_column_name,
      _sqlite3_reset,
      _sqlite3_step,
      _sqlite3_column_type,
      _sqlite3_column_int64,
      _sqlite3_column_double,
      _sqlite3_column_bytes,
      _sqlite3_column_text,
      _sqlite3_column_blob,
      _sqlite3_bind_null,
      _sqlite3_bind_int64,
      _sqlite3_bind_double,
      _sqlite3_bind_text,
      _sqlite3_bind_blob64,
      _sqlite3_bind_parameter_index,
      _sqlite3_finalize,
      _sqlite3_changes,
      _sqlite3_last_insert_rowid,
      _sqlite3_user_data,
      _sqlite3_result_null,
      _sqlite3_result_int64,
      _sqlite3_result_double,
      _sqlite3_result_text,
      _sqlite3_result_blob64,
      _sqlite3_result_error,
      _sqlite3_value_type,
      _sqlite3_value_int64,
      _sqlite3_value_double,
      _sqlite3_value_bytes,
      _sqlite3_value_text,
      _sqlite3_value_blob,
      _sqlite3_aggregate_context,
      _sqlite3_get_autocommit,
      _sqlite3_stmt_readonly,
      _sqlite3_stmt_isexplain;

  final JSFunction? _sqlite3_db_config;

  final Global _sqlite3_temp_directory;

  WasmBindings._(this.instance, _InjectedValues values)
      : memory = values.memory,
        callbacks = values.callbacks,
        _malloc = instance.functions['dart_sqlite3_malloc']!,
        _free = instance.functions['dart_sqlite3_free']!,
        _create_scalar =
            instance.functions['dart_sqlite3_create_scalar_function']!,
        _create_aggregate =
            instance.functions['dart_sqlite3_create_aggregate_function']!,
        _create_window =
            instance.functions['dart_sqlite3_create_window_function']!,
        _create_collation =
            instance.functions['dart_sqlite3_create_collation']!,
        _register_vfs = instance.functions['dart_sqlite3_register_vfs']!,
        _unregister_vfs = instance.functions['sqlite3_vfs_unregister']!,
        _update_hooks = instance.functions['dart_sqlite3_updates']!,
        _sqlite3_libversion = instance.functions['sqlite3_libversion']!,
        _sqlite3_sourceid = instance.functions['sqlite3_sourceid']!,
        _sqlite3_libversion_number =
            instance.functions['sqlite3_libversion_number']!,
        _sqlite3_open_v2 = instance.functions['sqlite3_open_v2']!,
        _sqlite3_close_v2 = instance.functions['sqlite3_close_v2']!,
        _sqlite3_extended_errcode =
            instance.functions['sqlite3_extended_errcode']!,
        _sqlite3_errmsg = instance.functions['sqlite3_errmsg']!,
        _sqlite3_errstr = instance.functions['sqlite3_errstr']!,
        _sqlite3_extended_result_codes =
            instance.functions['sqlite3_extended_result_codes']!,
        _sqlite3_exec = instance.functions['sqlite3_exec']!,
        _sqlite3_free = instance.functions['sqlite3_free']!,
        _sqlite3_prepare_v3 = instance.functions['sqlite3_prepare_v3']!,
        _sqlite3_bind_parameter_count =
            instance.functions['sqlite3_bind_parameter_count']!,
        _sqlite3_column_count = instance.functions['sqlite3_column_count']!,
        _sqlite3_column_name = instance.functions['sqlite3_column_name']!,
        _sqlite3_reset = instance.functions['sqlite3_reset']!,
        _sqlite3_step = instance.functions['sqlite3_step']!,
        _sqlite3_finalize = instance.functions['sqlite3_finalize']!,
        _sqlite3_column_type = instance.functions['sqlite3_column_type']!,
        _sqlite3_column_int64 = instance.functions['sqlite3_column_int64']!,
        _sqlite3_column_double = instance.functions['sqlite3_column_double']!,
        _sqlite3_column_bytes = instance.functions['sqlite3_column_bytes']!,
        _sqlite3_column_blob = instance.functions['sqlite3_column_blob']!,
        _sqlite3_column_text = instance.functions['sqlite3_column_text']!,
        _sqlite3_bind_null = instance.functions['sqlite3_bind_null']!,
        _sqlite3_bind_int64 = instance.functions['sqlite3_bind_int64']!,
        _sqlite3_bind_double = instance.functions['sqlite3_bind_double']!,
        _sqlite3_bind_text = instance.functions['sqlite3_bind_text']!,
        _sqlite3_bind_blob64 = instance.functions['sqlite3_bind_blob64']!,
        _sqlite3_bind_parameter_index =
            instance.functions['sqlite3_bind_parameter_index']!,
        _sqlite3_changes = instance.functions['sqlite3_changes']!,
        _sqlite3_last_insert_rowid =
            instance.functions['sqlite3_last_insert_rowid']!,
        _sqlite3_user_data = instance.functions['sqlite3_user_data']!,
        _sqlite3_result_null = instance.functions['sqlite3_result_null']!,
        _sqlite3_result_int64 = instance.functions['sqlite3_result_int64']!,
        _sqlite3_result_double = instance.functions['sqlite3_result_double']!,
        _sqlite3_result_text = instance.functions['sqlite3_result_text']!,
        _sqlite3_result_blob64 = instance.functions['sqlite3_result_blob64']!,
        _sqlite3_result_error = instance.functions['sqlite3_result_error']!,
        _sqlite3_value_type = instance.functions['sqlite3_value_type']!,
        _sqlite3_value_int64 = instance.functions['sqlite3_value_int64']!,
        _sqlite3_value_double = instance.functions['sqlite3_value_double']!,
        _sqlite3_value_bytes = instance.functions['sqlite3_value_bytes']!,
        _sqlite3_value_text = instance.functions['sqlite3_value_text']!,
        _sqlite3_value_blob = instance.functions['sqlite3_value_blob']!,
        _sqlite3_aggregate_context =
            instance.functions['sqlite3_aggregate_context']!,
        _sqlite3_get_autocommit = instance.functions['sqlite3_get_autocommit']!,
        _sqlite3_stmt_isexplain = instance.functions['sqlite3_stmt_isexplain']!,
        _sqlite3_stmt_readonly = instance.functions['sqlite3_stmt_readonly']!,
        _sqlite3_db_config = instance.functions['dart_sqlite3_db_config_int'],
        _sqlite3_temp_directory = instance.globals['sqlite3_temp_directory']!
  // Note when adding new fields: We remove functions from the wasm module that
  // aren't referenced in Dart. We consider a symbol used when it appears in a
  // string literal in an initializer of this constructor (`tool/wasm_dce.dart`).
  // Keep in mind that new symbols can only be tested with release wasm builds
  // after adding them here and re-running the sqlite3 wasm build.
  {
    values.bindings = this;
  }

  static Future<WasmBindings> instantiateAsync(web.Response response) async {
    final injected = _InjectedValues();
    final instance = await WasmInstance.load(response, injected.injectedValues);

    return WasmBindings._(instance, injected);
  }

  JSFunction _checkForPresence(JSFunction? function, String name) {
    if (function == null) {
      throw UnsupportedError(
          '$name is not supported by WASM sqlite3, try upgrading to '
          'a more recent sqlite3.wasm');
    }

    return function;
  }

  Pointer allocateBytes(List<int> bytes, {int additionalLength = 0}) {
    final ptr = malloc(bytes.length + additionalLength);
    memory.asBytes
      ..setRange(ptr, ptr + bytes.length, bytes)
      ..fillRange(ptr + bytes.length, ptr + bytes.length + additionalLength, 0);

    return ptr;
  }

  Pointer allocateZeroTerminated(String string) {
    return allocateBytes(utf8.encode(string), additionalLength: 1);
  }

  Pointer malloc(int size) {
    return _malloc.callReturningInt(size.toJS);
  }

  void free(Pointer pointer) {
    _free.callReturningVoid(pointer.toJS);
  }

  void sqlite3_free(Pointer ptr) => _sqlite3_free.callReturningVoid(ptr.toJS);

  int create_scalar_function(
      Pointer db, Pointer functionName, int nArg, int eTextRep, int id) {
    return _create_scalar.callReturningInt5(
        db.toJS, functionName.toJS, nArg.toJS, eTextRep.toJS, id.toJS);
  }

  int create_aggregate_function(
      Pointer db, Pointer functionName, int nArg, int eTextRep, int id) {
    return _create_aggregate.callReturningInt5(
        db.toJS, functionName.toJS, nArg.toJS, eTextRep.toJS, id.toJS);
  }

  int create_window_function(
      Pointer db, Pointer functionName, int nArg, int eTextRep, int id) {
    final function = _checkForPresence(_create_window, 'createWindow');
    return function.callReturningInt5(
        db.toJS, functionName.toJS, nArg.toJS, eTextRep.toJS, id.toJS);
  }

  int create_collation(Pointer db, Pointer name, int eTextRep, int id) {
    final function = _checkForPresence(_create_collation, 'createCollation');
    return function.callReturningInt4(
        db.toJS, name.toJS, eTextRep.toJS, id.toJS);
  }

  Pointer dart_sqlite3_register_vfs(Pointer name, int dartId, int makeDefault) {
    return _register_vfs.callReturningInt3(
        name.toJS, dartId.toJS, makeDefault.toJS);
  }

  int sqlite3_vfs_unregister(Pointer vfs) {
    return _unregister_vfs.callReturningInt(vfs.toJS);
  }

  int sqlite3_libversion() => _sqlite3_libversion.callReturningInt0();

  Pointer sqlite3_sourceid() => _sqlite3_sourceid.callReturningInt0();

  int sqlite3_libversion_number() =>
      _sqlite3_libversion_number.callReturningInt0();

  int sqlite3_open_v2(Pointer filename, Pointer ppDb, int flags, Pointer zVfs) {
    return _sqlite3_open_v2.callReturningInt4(
        filename.toJS, ppDb.toJS, flags.toJS, zVfs.toJS);
  }

  int sqlite3_close_v2(Pointer db) =>
      _sqlite3_close_v2.callReturningInt(db.toJS);

  int sqlite3_extended_errcode(Pointer db) =>
      _sqlite3_extended_errcode.callReturningInt(db.toJS);

  Pointer sqlite3_errmsg(Pointer db) =>
      _sqlite3_errmsg.callReturningInt(db.toJS);

  Pointer sqlite3_errstr(int resultCode) =>
      _sqlite3_errstr.callReturningInt(resultCode.toJS);

  int sqlite3_extended_result_codes(Pointer db, int onoff) {
    return _sqlite3_extended_result_codes.callReturningInt2(
        db.toJS, onoff.toJS);
  }

  /// Pass a non-negative [id] to enable update tracking on the db, a negative
  /// one to stop it.
  void dart_sqlite3_updates(Pointer db, int id) {
    _update_hooks.callReturningVoid2(db.toJS, id.toJS);
  }

  int sqlite3_exec(Pointer db, Pointer sql, Pointer callback,
      Pointer callbackArg, Pointer errorOut) {
    return _sqlite3_exec.callReturningInt5(
        db.toJS, sql.toJS, callback.toJS, callbackArg.toJS, errorOut.toJS);
  }

  int sqlite3_prepare_v3(Pointer db, Pointer sql, int length, int prepFlags,
      Pointer ppStmt, Pointer pzTail) {
    return _sqlite3_prepare_v3.callReturningInt6(db.toJS, sql.toJS, length.toJS,
        prepFlags.toJS, ppStmt.toJS, pzTail.toJS);
  }

  int sqlite3_bind_parameter_count(Pointer stmt) {
    return _sqlite3_bind_parameter_count.callReturningInt(stmt.toJS);
  }

  int sqlite3_bind_null(Pointer stmt, int index) {
    return _sqlite3_bind_null.callReturningInt2(stmt.toJS, index.toJS);
  }

  int sqlite3_bind_int64(Pointer stmt, int index, BigInt value) {
    return _sqlite3_bind_int64.callReturningInt3(
        stmt.toJS, index.toJS, JsBigInt.fromBigInt(value).jsObject);
  }

  int sqlite3_bind_int(Pointer stmt, int index, int value) {
    return _sqlite3_bind_int64.callReturningInt3(
        stmt.toJS, index.toJS, JsBigInt.fromInt(value).jsObject);
  }

  int sqlite3_bind_double(Pointer stmt, int index, double value) {
    return _sqlite3_bind_double.callReturningInt3(
        stmt.toJS, index.toJS, value.toJS);
  }

  int sqlite3_bind_text(
      Pointer stmt, int index, Pointer text, int length, Pointer a) {
    return _sqlite3_bind_text.callReturningInt5(
        stmt.toJS, index.toJS, text.toJS, length.toJS, a.toJS);
  }

  int sqlite3_bind_blob64(
      Pointer stmt, int index, Pointer test, int length, Pointer a) {
    return _sqlite3_bind_blob64.callReturningInt5(stmt.toJS, index.toJS,
        test.toJS, JsBigInt.fromInt(length).jsObject, a.toJS);
  }

  int sqlite3_bind_parameter_index(Pointer statement, Pointer key) {
    return _sqlite3_bind_parameter_index.callReturningInt2(
        statement.toJS, key.toJS);
  }

  int sqlite3_column_count(Pointer stmt) {
    return _sqlite3_column_count.callReturningInt(stmt.toJS);
  }

  Pointer sqlite3_column_name(Pointer stmt, int index) {
    return _sqlite3_column_name.callReturningInt2(stmt.toJS, index.toJS);
  }

  int sqlite3_column_type(Pointer stmt, int index) {
    return _sqlite3_column_type.callReturningInt2(stmt.toJS, index.toJS);
  }

  JsBigInt sqlite3_column_int64(Pointer stmt, int index) {
    return JsBigInt(_sqlite3_column_int64.callAsFunction(
        null, stmt.toJS, index.toJS) as JSBigInt);
  }

  double sqlite3_column_double(Pointer stmt, int index) {
    return (_sqlite3_column_double.callAsFunction(null, stmt.toJS, index.toJS)
            as JSNumber)
        .toDartDouble;
  }

  int sqlite3_column_bytes(Pointer stmt, int index) {
    return _sqlite3_column_bytes.callReturningInt2(stmt.toJS, index.toJS);
  }

  Pointer sqlite3_column_text(Pointer stmt, int index) {
    return _sqlite3_column_text.callReturningInt2(stmt.toJS, index.toJS);
  }

  Pointer sqlite3_column_blob(Pointer stmt, int index) {
    return _sqlite3_column_blob.callReturningInt2(stmt.toJS, index.toJS);
  }

  int sqlite3_value_type(Pointer value) {
    return _sqlite3_value_type.callReturningInt(value.toJS);
  }

  JsBigInt sqlite3_value_int64(Pointer value) {
    return JsBigInt(
        _sqlite3_value_int64.callAsFunction(null, value.toJS) as JSBigInt);
  }

  double sqlite3_value_double(Pointer value) {
    return (_sqlite3_value_double.callAsFunction(null, value.toJS) as JSNumber)
        .toDartDouble;
  }

  int sqlite3_value_bytes(Pointer value) {
    return _sqlite3_value_bytes.callReturningInt(value.toJS);
  }

  Pointer sqlite3_value_text(Pointer value) {
    return _sqlite3_value_text.callReturningInt(value.toJS);
  }

  Pointer sqlite3_value_blob(Pointer value) {
    return _sqlite3_value_blob.callReturningInt(value.toJS);
  }

  void sqlite3_result_null(Pointer context) {
    _sqlite3_result_null.callReturningVoid(context.toJS);
  }

  void sqlite3_result_int64(Pointer context, BigInt value) {
    _sqlite3_result_int64.callReturningVoid2(
        context.toJS, JsBigInt.fromBigInt(value).jsObject);
  }

  void sqlite3_result_double(Pointer context, double value) {
    _sqlite3_result_double.callReturningVoid2(context.toJS, value.toJS);
  }

  void sqlite3_result_text(
      Pointer context, Pointer text, int length, Pointer a) {
    _sqlite3_result_text.callReturningVoid4(
        context.toJS, text.toJS, length.toJS, a.toJS);
  }

  void sqlite3_result_blob64(
      Pointer context, Pointer blob, int length, Pointer a) {
    _sqlite3_result_blob64.callReturningVoid4(
        context.toJS, blob.toJS, JsBigInt.fromInt(length).jsObject, a.toJS);
  }

  void sqlite3_result_error(Pointer context, Pointer text, int length) {
    _sqlite3_result_error.callReturningVoid3(
        context.toJS, text.toJS, length.toJS);
  }

  int sqlite3_user_data(Pointer context) {
    return _sqlite3_user_data.callReturningInt(context.toJS);
  }

  Pointer sqlite3_aggregate_context(Pointer context, int nBytes) {
    return _sqlite3_aggregate_context.callReturningInt2(
        context.toJS, nBytes.toJS);
  }

  int sqlite3_step(Pointer stmt) => _sqlite3_step.callReturningInt(stmt.toJS);

  int sqlite3_reset(Pointer stmt) => _sqlite3_reset.callReturningInt(stmt.toJS);

  int sqlite3_finalize(Pointer stmt) =>
      _sqlite3_finalize.callReturningInt(stmt.toJS);

  int sqlite3_changes(Pointer db) => _sqlite3_changes.callReturningInt(db.toJS);

  int sqlite3_stmt_isexplain(Pointer stmt) =>
      _sqlite3_stmt_isexplain.callReturningInt(stmt.toJS);

  int sqlite3_stmt_readonly(Pointer stmt) =>
      _sqlite3_stmt_readonly.callReturningInt(stmt.toJS);

  int sqlite3_last_insert_rowid(Pointer db) =>
      JsBigInt(_sqlite3_last_insert_rowid.callReturningBigInt(db.toJS))
          .asDartInt;

  int sqlite3_get_autocommit(Pointer db) =>
      _sqlite3_get_autocommit.callReturningInt(db.toJS);

  int sqlite3_db_config(Pointer db, int op, int value) {
    final function = _sqlite3_db_config;
    if (function != null) {
      return function.callReturningInt3(db.toJS, op.toJS, value.toJS);
    } else {
      return 1; // Not supported with this wasm build
    }
  }

  Pointer get sqlite3_temp_directory {
    return _sqlite3_temp_directory.value.toDartInt;
  }

  set sqlite3_temp_directory(Pointer value) {
    _sqlite3_temp_directory.value = value.toJS;
  }
}

int _runVfs(void Function() body) {
  try {
    body();
    return SqlError.SQLITE_OK;
  } on VfsException catch (e) {
    return e.returnCode;
  } on Object {
    return SqlError.SQLITE_ERROR;
  }
}

extension WrappedMemory on Memory {
  ByteBuffer get dartBuffer => buffer.toDart;

  Uint8List get asBytes => buffer.toDart.asUint8List();

  int strlen(int address) {
    assert(address != 0, 'Null pointer dereference');

    final bytes = dartBuffer.asUint8List(address);

    var length = 0;
    while (bytes[length] != 0) {
      length++;
    }

    return length;
  }

  int int32ValueOfPointer(Pointer pointer) {
    assert(pointer != 0, 'Null pointer dereference');
    return dartBuffer.asInt32List()[pointer >> 2];
  }

  void setInt32Value(Pointer pointer, int value) {
    assert(pointer != 0, 'Null pointer dereference');
    dartBuffer.asInt32List()[pointer >> 2] = value;
  }

  void setInt64Value(Pointer pointer, JsBigInt value) {
    assert(pointer != 0, 'Null pointer dereference');
    dartBuffer.asByteData().setBigInt64(pointer, value, true);
  }

  String readString(int address, [int? length]) {
    assert(address != 0, 'Null pointer dereference');
    return utf8
        .decode(dartBuffer.asUint8List(address, length ?? strlen(address)));
  }

  String? readNullableString(int address, [int? length]) {
    if (address == 0) return null;

    return utf8
        .decode(dartBuffer.asUint8List(address, length ?? strlen(address)));
  }

  Uint8List copyRange(Pointer pointer, int length) {
    final list = Uint8List(length);
    list.setAll(0, dartBuffer.asUint8List(pointer, length));
    return list;
  }
}

class _InjectedValues {
  late WasmBindings bindings;
  late Map<String, Map<String, JSObject>> injectedValues;

  late Memory memory;

  final DartCallbacks callbacks = DartCallbacks();

  _InjectedValues() {
    final memory = this.memory = Memory(MemoryDescriptor(initial: 16.toJS));

    injectedValues = {
      'env': {'memory': memory},
      'dart': {
        // See assets/wasm/bridge.h
        'error_log': ((Pointer ptr) {
          print('[sqlite3] ${memory.readString(ptr)}');
        }).toJS,
        'xOpen': ((int vfsId, Pointer zName, Pointer dartFdPtr, int flags,
            Pointer pOutFlags) {
          final vfs = callbacks.registeredVfs[vfsId]!;
          final path = Sqlite3Filename(memory.readNullableString(zName));

          return _runVfs(() {
            final result = vfs.xOpen(path, flags);
            final fd = callbacks.registerFile(result.file);

            memory.setInt32Value(dartFdPtr, fd);
            if (pOutFlags != 0) {
              memory.setInt32Value(pOutFlags, result.outFlags);
            }
          });
        }).toJS,
        'xDelete': ((int vfsId, Pointer zName, int syncDir) {
          final vfs = callbacks.registeredVfs[vfsId]!;
          final path = memory.readString(zName);

          return _runVfs(() => vfs.xDelete(path, syncDir));
        }).toJS,
        'xAccess': ((int vfsId, Pointer zName, int flags, Pointer pResOut) {
          final vfs = callbacks.registeredVfs[vfsId]!;
          final path = memory.readString(zName);

          return _runVfs(() {
            final res = vfs.xAccess(path, flags);
            memory.setInt32Value(pResOut, res);
          });
        }).toJS,
        'xFullPathname': ((int vfsId, Pointer zName, int nOut, Pointer zOut) {
          final vfs = callbacks.registeredVfs[vfsId]!;
          final path = memory.readString(zName);

          return _runVfs(() {
            final fullPath = vfs.xFullPathName(path);
            final encoded = utf8.encode(fullPath);

            if (encoded.length > nOut) {
              throw VfsException(SqlError.SQLITE_CANTOPEN);
            }

            memory.asBytes
              ..setAll(zOut, encoded)
              ..[zOut + encoded.length] = 0;
          });
        }).toJS,
        'xRandomness': ((int vfsId, int nByte, Pointer zOut) {
          final vfs = callbacks.registeredVfs[vfsId]!;

          return _runVfs(() {
            vfs.xRandomness(memory.buffer.toDart.asUint8List(zOut, nByte));
          });
        }).toJS,
        'xSleep': ((int vfsId, int micros) {
          final vfs = callbacks.registeredVfs[vfsId]!;

          return _runVfs(() {
            vfs.xSleep(Duration(microseconds: micros));
          });
        }).toJS,
        'xCurrentTimeInt64': ((int vfsId, Pointer target) {
          final vfs = callbacks.registeredVfs[vfsId]!;
          final time = vfs.xCurrentTime();

          // dartvfs_currentTimeInt64 will turn this into the right value, it's
          // annoying to do in JS due to the lack of proper ints.
          memory.setInt64Value(
              target, JsBigInt.fromInt(time.millisecondsSinceEpoch));
        }).toJS,
        'xDeviceCharacteristics': ((int fd) {
          final file = callbacks.openedFiles[fd]!;
          return file.xDeviceCharacteristics;
        }).toJS,
        'xClose': ((int fd) {
          final file = callbacks.openedFiles[fd]!;
          return _runVfs(() {
            file.xClose();
            callbacks.openedFiles.remove(fd);
          });
        }).toJS,
        'xRead': ((int fd, Pointer target, int amount, JSBigInt offset) {
          final file = callbacks.openedFiles[fd]!;
          return _runVfs(() {
            file.xRead(memory.buffer.toDart.asUint8List(target, amount),
                JsBigInt(offset).asDartInt);
          });
        }).toJS,
        'xWrite': ((int fd, Pointer source, int amount, JSBigInt offset) {
          final file = callbacks.openedFiles[fd]!;
          return _runVfs(() {
            file.xWrite(memory.buffer.toDart.asUint8List(source, amount),
                JsBigInt(offset).asDartInt);
          });
        }).toJS,
        'xTruncate': ((int fd, JSBigInt size) {
          final file = callbacks.openedFiles[fd]!;
          return _runVfs(() => file.xTruncate(JsBigInt(size).asDartInt));
        }).toJS,
        'xSync': ((int fd, int flags) {
          final file = callbacks.openedFiles[fd]!;
          return _runVfs(() => file.xSync(flags));
        }).toJS,
        'xFileSize': ((int fd, Pointer sizePtr) {
          final file = callbacks.openedFiles[fd]!;
          return _runVfs(() {
            final size = file.xFileSize();
            memory.setInt32Value(sizePtr, size);
          });
        }).toJS,
        'xLock': ((int fd, int flags) {
          final file = callbacks.openedFiles[fd]!;
          return _runVfs(() => file.xLock(flags));
        }).toJS,
        'xUnlock': ((int fd, int flags) {
          final file = callbacks.openedFiles[fd]!;
          return _runVfs(() => file.xUnlock(flags));
        }).toJS,
        'xCheckReservedLock': ((int fd, Pointer pResOut) {
          final file = callbacks.openedFiles[fd]!;
          return _runVfs(() {
            final status = file.xCheckReservedLock();
            memory.setInt32Value(pResOut, status);
          });
        }).toJS,
        'function_xFunc': ((Pointer ctx, int args, Pointer value) {
          final id = bindings.sqlite3_user_data(ctx);
          callbacks.functions[id]!.xFunc!(
            WasmContext(bindings, ctx, callbacks),
            WasmValueList(bindings, args, value),
          );
        }).toJS,
        'function_xStep': ((Pointer ctx, int args, Pointer value) {
          final id = bindings.sqlite3_user_data(ctx);
          callbacks.functions[id]!.xStep!(
            WasmContext(bindings, ctx, callbacks),
            WasmValueList(bindings, args, value),
          );
        }).toJS,
        'function_xInverse': ((Pointer ctx, int args, Pointer value) {
          final id = bindings.sqlite3_user_data(ctx);
          callbacks.functions[id]!.xInverse!(
            WasmContext(bindings, ctx, callbacks),
            WasmValueList(bindings, args, value),
          );
        }).toJS,
        'function_xFinal': ((Pointer ctx) {
          final id = bindings.sqlite3_user_data(ctx);
          callbacks
              .functions[id]!.xFinal!(WasmContext(bindings, ctx, callbacks));
        }).toJS,
        'function_xValue': ((Pointer ctx) {
          final id = bindings.sqlite3_user_data(ctx);
          callbacks
              .functions[id]!.xValue!(WasmContext(bindings, ctx, callbacks));
        }).toJS,
        'function_forget': ((Pointer ctx) {
          callbacks.forget(ctx);
        }).toJS,
        'function_compare':
            ((Pointer ctx, int lengthA, Pointer a, int lengthB, int b) {
          final aStr = memory.readNullableString(a, lengthA);
          final bStr = memory.readNullableString(b, lengthB);

          return callbacks.functions[ctx]!.collation!(aStr, bStr);
        }).toJS,
        'function_hook':
            ((int id, int kind, Pointer _, Pointer table, JSBigInt rowId) {
          final tableName = memory.readString(table);

          callbacks.installedUpdateHook
              ?.call(kind, tableName, JsBigInt(rowId).asDartInt);
        }).toJS,
      }
    };
  }
}

class DartCallbacks {
  int _id = 0;
  final Map<int, RegisteredFunctionSet> functions = {};

  int aggregateContextId = 1;
  final Map<int, AggregateContext<Object?>> aggregateContexts = {};

  final Map<int, VirtualFileSystem> registeredVfs = {};
  final Map<int, VirtualFileSystemFile> openedFiles = {};

  RawUpdateHook? installedUpdateHook;

  int register(RegisteredFunctionSet set) {
    final id = _id++;
    functions[id] = set;
    return id;
  }

  int registerVfs(VirtualFileSystem vfs) {
    final id = registeredVfs.length;
    registeredVfs[id] = vfs;
    return id;
  }

  int registerFile(VirtualFileSystemFile file) {
    final id = openedFiles.length;
    openedFiles[id] = file;
    return id;
  }

  void forget(int id) => functions.remove(id);

  static final sqliteVfsPointer = Expando<int>();
}

class RegisteredFunctionSet {
  final RawXFunc? xFunc;
  final RawXStep? xStep;
  final RawXFinal? xFinal;

  final RawXFinal? xValue;
  final RawXStep? xInverse;

  final RawCollation? collation;

  RegisteredFunctionSet({
    this.xFunc,
    this.xStep,
    this.xFinal,
    this.xValue,
    this.xInverse,
    this.collation,
  });
}

extension on JSFunction {
  @JS('call')
  external JSNumber _call5(
      JSAny? r, JSAny? a0, JSAny? a1, JSAny? a2, JSAny? a3, JSAny? a4);

  @JS('call')
  external JSNumber _call6(JSAny? r, JSAny? a0, JSAny? a1, JSAny? a2, JSAny? a3,
      JSAny? a4, JSAny? a5);

  int callReturningInt0() {
    return (callAsFunction(null) as JSNumber).toDartInt;
  }

  int callReturningInt(JSAny? arg) {
    return (callAsFunction(null, arg) as JSNumber).toDartInt;
  }

  int callReturningInt2(JSAny? arg0, JSAny? arg1) {
    return (callAsFunction(null, arg0, arg1) as JSNumber).toDartInt;
  }

  int callReturningInt3(JSAny? arg0, JSAny? arg1, JSAny? arg2) {
    return (callAsFunction(null, arg0, arg1, arg2) as JSNumber).toDartInt;
  }

  int callReturningInt4(JSAny? arg0, JSAny? arg1, JSAny? arg2, JSAny? arg3) {
    return (callAsFunction(null, arg0, arg1, arg2, arg3) as JSNumber).toDartInt;
  }

  int callReturningInt5(
      JSAny? arg0, JSAny? arg1, JSAny? arg2, JSAny? arg3, JSAny? arg4) {
    return _call5(null, arg0, arg1, arg2, arg3, arg4).toDartInt;
  }

  int callReturningInt6(JSAny? arg0, JSAny? arg1, JSAny? arg2, JSAny? arg3,
      JSAny? arg4, JSAny? arg5) {
    return _call6(null, arg0, arg1, arg2, arg3, arg4, arg5).toDartInt;
  }

  JSBigInt callReturningBigInt([JSAny? arg]) {
    return callAsFunction(null, arg) as JSBigInt;
  }

  void callReturningVoid([JSAny? arg]) {
    callAsFunction(null, arg);
  }

  void callReturningVoid2(JSAny? arg0, JSAny? arg1) {
    callAsFunction(null, arg0, arg1);
  }

  void callReturningVoid3(JSAny? arg0, JSAny? arg1, JSAny? arg2) {
    callAsFunction(null, arg0, arg1, arg2);
  }

  void callReturningVoid4(JSAny? arg0, JSAny? arg1, JSAny? arg2, JSAny? arg3) {
    callAsFunction(null, arg0, arg1, arg2, arg3);
  }
}
