Support for building libraries enabling access to `sqlite3` on the web.

## What does this do?

`package:sqlite3` provides all the foundations necessary to access sqlite3 on
the web.
As the APIs exposed by that package are direct wrappers around the `sqlite3` C
library compiled to WebAssembly, some limitations remain.
In particular, the most reliable way to access databases on the web involves
workers, which are required to use the filesystem access API.

When workers are involved however, the database is no longer running in the
JavaScript context for your app. To access the database in these setups, you
instead have to use asynchronous communication channels between the worker and
your app. The synchronous API provided by the `sqlite3` package is unsuitable
for this.
Further, different browsers support different persistence APIs and you need to
check what's available beforehand to use the best storage engine available.

And that is what this package can do for you:

1. It provides an API enabling you to write database workers in Dart.
2. It can then use these workers for an asynchronous interface to sqlite3
   databases.
3. It automatically detects available storage implementations, and can pick the
   best one available.

## Getting started

Note: While this package can be used by end applications, it is meant as a
building block for database packages like `sqlite3_async` or `drift`. Using
these packages helps avoid some setup work.

Workers are responsible for opening databases and exposing them through message
channels. This package takes care of these channels, but you are still
responsible for opening databases in your workers. To do so, extend the
`DatabaseController` class, e.g. [like this](https://github.com/simolus3/sqlite3.dart/blob/main/sqlite3_web/example/controller.dart).

With a controller ready, you can define an entrypoint for a web worker like this:

```dart
import 'package:sqlite3_web/sqlite3_web.dart';

import 'controller.dart';

void main() {
  WebSqlite.workerEntrypoint(controller: ExampleController());
}
```

This worker is ready to be compiled with `dart compile js` (consider using `-O4`).

Additionally, you need a `sqlite3.wasm` file containing native sqlite3 code to load.
You can

- grab a prebuilt version [from our releases](https://github.com/simolus3/sqlite3.dart/releases),
- [compile it yourself](https://github.com/simolus3/sqlite3.dart/tree/main/sqlite3#compiling), or
- [compile a custom build](https://github.com/simolus3/sqlite3.dart/tree/main/sqlite3/example/custom_wasm_build) with your own sqlite3 extensions or functions linked directly into the module.

With those ready, this package can be used to provide async access to databases
that are transparently hosted in the worker:

```dart
Future<void> connectToDatabase() async {
  final sqlite = await WebSqlite.open(
    worker: Uri.parse('worker.dart.js'),
    wasmModule: Uri.parse('sqlite3.wasm'),
  );

  final features = await sqlite.runFeatureDetection();
  print('got features: $features');

  final connection = await sqlite.connectToRecommended('my_database');
  print(await connection.database.select('select sqlite_version()'));
}
```

## Custom requests

In some cases, it may be useful to re-use the worker communication scheme
created by `package:sqlite3_web` for functionality implemented in your library.
For instance, you could use shared workers to let different tabs connect to a
single instance of a database.
In that case, some synchronization primitives to coordinate which tab gets to
open transactions can be implemented in the worker by overriding
`handleCustomRequest` in `WorkerDatabase`. You can encode requests and
responses as arbitrary values exchanged as `JSAny?`.
On the client side, requests can be issued with `Database.customRequest`.
