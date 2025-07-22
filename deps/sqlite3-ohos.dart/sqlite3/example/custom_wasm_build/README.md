## custom wasm modules

This example demonstrates how to build a custom `sqlite3.wasm` module than can be
used with `package:sqlite3`.
Using custom wasm modules is useful to include additional extensions in sqlite3, or to
use different compile-time options.

This example uses existing C source files also used by the default configuration:

- `sqlite3.c` for the actual SQLite library.
- [`helpers.c`](https://github.com/simolus3/sqlite3.dart/blob/main/sqlite3/assets/wasm/helpers.c) from this repository, which defines a VFS wrapper for virtual filesystem implementations provided from Dart.
- Our `os_web.c` file is _not_ included. It contains the implementation for
  `sqlite3_os_init` and `sqlite3_os_end`, which are implemented in this custom
  extension instead. `sqlite3_os_init` is a suitable hook to load your sqlite3
  extensions.

In this example, the extension is a simple Rust library printing a hello message
to the web console when the module is loaded.

## Setup

We're currently using the libc from [WASI](https://wasi.dev/) to compile sqlite3,
so the easiest approach is to compile your custom extensions with that as well:

```
rustup target add wasm32-wasi
```

Additionally, you need to download WASI compiler builtins and the associated libc
as described in the [build instructions](https://github.com/simolus3/sqlite3.dart/tree/main/sqlite3#compiling).

## Building

The `build.rs` file from this example is responsible for compiling sqlite3 to
WebAssembly object files. We're not using a static library because that seems to
break the `--export-dynamic` option used in the final linking step to expose the
relevant functions.

To download and compile sqlite3 as well as the patched `sqlite3_os_init` function
for this example, run

```
WASI_SYSROOT=/path/to/wasi/ CC=/path/to/clang cargo build --target wasm32-wasi
```

Or, to compile a release build optimized for size:

```
WASI_SYSROOT=/path/to/wasi/ CC=/path/to/clang cargo build --target wasm32-wasi --release
```

Cargo compiles sqlite3 to WASM object files, the Rust part is compiled into a static
library.
A Dart script (`link.dart`) can be used to link them together into a `sqlite3.wasm`
file loadable by the `sqlite3` package:

```
CC=/path/to/clang dart run link.dart target/wasm32-wasi/debug
CC=/path/to/clang dart run link.dart target/wasm32-wasi/release
```

As an additional transformation step, running `wasm-opt -O4` on the resulting
WASM file may optimize it further.
Similarly, running `dart run tool/wasm_dce.dart <input.wasm> <output.wasm>` in
the `sqlite3` source directory will remove functions not directly or indirectly
used by the Dart package, reduzing bundle size.
