## sqlite3 web example

This folder contains a very simple example demonstrating how to load a sqlite3 database in the
web.

To run this example, first obtain a `sqlite3.debug.wasm` file from the [releases](https://github.com/simolus3/sqlite3.dart/releases)
of this package and put it in this `web/` folder.
In a real app, you'll want to use the `sqlite3.wasm` file from the releases, but the debug variant
prints more log messages which are relevant for the example.

In the `sqlite3/` folder (`../..`), run `dart run build_runner serve example:8080`.
Then, you can visit the example at http://localhost:8080/web/.

------

For larger applications using sqlite3, you may want to try out a database framework such as
[drift](https://drift.simonbinder.eu/web/), which takes care of the complex setup steps for you.
It automatically determines features supported by the current browser to choose a suitable filesystem
implementation.
