import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../implementation/sqlite3.dart';
import '../vfs.dart';
import 'bindings.dart';
import 'js_interop.dart';
import 'wasm_interop.dart';

/// A WebAssembly version of the [CommmonSqlite3] interface.
///
/// This implementation supports the same API as the native version based on
/// `dart:ffi`, but runs in the web.
final class WasmSqlite3 extends Sqlite3Implementation {
  /// Loads a web version of the sqlite3 libraries.
  ///
  /// [source] must be a byte buffer of a `sqlite.wasm` file prepared for this
  /// package. This file can be obtained at the [releases][pgk release] for this
  /// package.
  ///
  /// The [environment] can optionally be set to use a custom virtual file
  /// system. By default, all databases opened are stored in memory only (this
  /// includes databases opened with a path in [open]).
  ///
  /// When the [source] is obtained through a HTTP request, consider directly
  /// using [loadFromUrl] as that method is more efficient.
  ///
  /// [pgk release]: https://github.com/simolus3/sqlite3.dart/releases
  static Future<WasmSqlite3> load(Uint8List source) {
    final headers = JSObject()..['content-type'] = 'application/wasm'.toJS;

    final fakeResponse = web.Response(
      source.toJS,
      web.ResponseInit(headers: headers),
    );

    return _load(fakeResponse);
  }

  /// Loads a web version of the sqlite3 libraries.
  ///
  /// The native wasm library for sqlite3 is loaded from the [uri] with the
  /// desired [headers] through a `fetch` request.
  ///
  /// The [environment] can optionally be set to use a custom virtual file
  /// system. By default, all databases opened are stored in memory only (this
  /// includes databases opened with a path in [open]).
  ///
  /// [pgk release]: https://github.com/simolus3/sqlite3.dart/releases
  static Future<WasmSqlite3> loadFromUrl(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    web.RequestInit? options;

    if (headers != null) {
      final headersJs = JSObject();
      headers.forEach((key, value) {
        headersJs[key] = value.toJS;
      });

      options = web.RequestInit(headers: headersJs);
    }

    final jsUri = uri.isAbsolute
        ? web.URL(uri.toString())
        : web.URL(uri.toString(), Uri.base.toString());
    final response = await fetch(jsUri, options).toDart;
    return _load(response);
  }

  static Future<WasmSqlite3> _load(web.Response fetchResponse) async {
    final bindings = await WasmBindings.instantiateAsync(fetchResponse);
    return WasmSqlite3._(bindings);
  }

  WasmSqlite3._(WasmBindings bindings) : super(WasmSqliteBindings(bindings));

  /// Registers a custom virtual file system used by this sqlite3 instance to
  /// emulate I/O functionality that is not supported through WASM directly.
  ///
  /// Implementing a suitable [VirtualFileSystem] is a complex task. Users of
  /// this package on the web should consider using a package that calls this
  /// method for them (like `drift` or `sqflite_common_ffi_web`).
  /// For more information on how to implement this, see the readme of the
  /// `sqlite3` package for details.
  void registerVirtualFileSystem(VirtualFileSystem vfs,
      {bool makeDefault = false}) {
    (bindings as WasmSqliteBindings)
        .registerVirtualFileSystem(vfs, makeDefault ? 1 : 0);
  }

  /// Unregisters a virtual file system implementation that has been registered
  /// with [registerVirtualFileSystem].
  ///
  /// sqlite3 is not clear about what happens when this method is called with
  /// the file system being in used. Thus, this method should be used with care.
  void unregisterVirtualFileSystem(VirtualFileSystem vfs) {
    (bindings as WasmSqliteBindings).unregisterVirtualFileSystem(vfs);
  }
}
