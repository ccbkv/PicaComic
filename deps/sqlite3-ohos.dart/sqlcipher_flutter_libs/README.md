# sqlcipher_flutter_libs

Flutter apps depending on this package will contain native `SQLCipher` libraries
on Android, iOS, macOS, Linux and Windows.

As `SQLCipher` has an ABI compatible to the regular `sqlite3` library, it can be used
with an unmodified `sqlite3` package.

## Using this package

Depending on your platform, a bit of setup work and precautions are necessary.
In particular, __please be aware of the [compatibility concerns on iOS and macOS](#incompatibilities-with-sqlite3-on-ios-and-macos)!
Also, a special code snippet is [necessary on Android](#compilation).

Apart from that, this package works well with the regular `sqlite3` package. To open an encrypted database,
use the `sqlite3` package and run a pragma to decrypt it:

```dart
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';

import 'package:sqlite3/sqlite3.dart';

void main() {
  open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
  final db = sqlite3.open('path/to/your/database/file');

  if (db.select('PRAGMA cipher_version;').isEmpty) {
    // Make sure that we're actually using SQLCipher, since the pragma used to encrypt
    // databases just fails silently with regular sqlite3 (meaning that we'd accidentally
    // use plaintext databases).
    throw StateError('SQLCipher library is not available, please check your dependencies!');
  }

  // Set the encryption key for the database
  db.execute("PRAGMA key = 'your passphrase';");

  // From this point on, you can use this encrypted database like any other sqlite3 database.
}
```

### Compilation

Depending on your target platform, additional dependencies may be needed:

- Android: Uses a precompiled library, no additional setup is needed.
- macOS and iOS: Depends on the [SQLCipher](https://www.zetetic.net/sqlcipher/ios-tutorial/#option-2-cocoapod-integration) pod.
  **IMPORTANT NOTE**: Bad things will happen if you depend on any other package linking the regular sqlite3 library.
  Please be sure to read the [advisory](https://discuss.zetetic.net/t/important-advisory-sqlcipher-with-xcode-8-and-new-sdks/1688) before using this package.
- Linux: SQLCipher is compiled and linked against a static OpenSSL library that you need to install manually (e.g. `apt install libssl-dev` on Debian).
  OpenSSL is linked into the generated `.so`, so your users don't have to have OpenSSL installed.
- Windows: SQLCipher is compiled and linked against a static OpenSSL library that you need to install manually (`choco install openssl` works with Chocolatey).
  OpenSSL is statically linked into the generated `.dll`, so your users don't have to have OpenSSL installed.

When using this package on Android, you need to tell the `sqlite3` package
how to open `sqlcipher` since it will attempt to open the regular
`sqlite3` binary by default:

```dart
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';

// Do this before using any sqlite3 api
open.overrideFor(
    OperatingSystem.android, openCipherOnAndroid);
```

You will also need to do this when using a package wrapping the `sqlite3`
package like `drift` or `sqflite_common_ffi`!
No Dart code changes are necessary for other platforms.
When using `package:sqlite3` in a background isolate (even if just indirectly through
say `package:drift`), `overrideFor` should also be called on that isolate before interacting with sqlite.

For more details on how to actually use this package in a Flutter app, see
[sqlite3](https://pub.dev/packages/sqlite3).

## Incompatibilities with `sqlite3` on iOS and macOS

For iOS and macOS builds, depending on this package will install the `SQLCipher` pod.
When depending on another package linking the regular `sqlite3` pod or library, this can lead to undefined
behavior which may mean that __SQLCipher will not be available in your app__.
On such problematic package is `google_mobile_ads`, or `firebase_messaging`.

To fix this problem, you can put `-framework SQLCipher` in "Other Linker Flags" in your project's settings
on XCode.
For more details on this, see

- [Important Advisory: SQLCipher with Xcode 8 and new SDKs](https://discuss.zetetic.net/t/important-advisory-sqlcipher-with-xcode-8-and-new-sdks/1688)
- [Cannot open encrypted database with SQLCipher 4](https://discuss.zetetic.net/t/cannot-open-encrypted-database-with-sqlcipher-4/3654/3)

To catch these errors early, I recommend selecting `PRAGMA cipher_version` after opening a database
and throwing an exception if you get an empty string back, as you're not running with SQLCipher in
that case.

Alternatively, you can prevent other pods from linking sqlite3 by adding [this snippet](https://github.com/simolus3/drift/issues/1810#issuecomment-1119426006)
to your podfile.

## Different behavior on different platforms

On Android, iOS and macOS, this package relies on dependencies managed by Zetetic (the authors of SQLCipher)
to include SQLCipher in your application.
As no such solutions exist for Windows and Linux, a custom build script is used there.
This build script is inspired from the one used in `sqlite3_flutter_libs` and disables the [double-quoted strings](https://sqlite.org/quirks.html#double_quoted_string_literals_are_accepted)
misfeature.
The official SQLCipher builds don't do that.

To avoid your app relying on double-quoted strings in SQL, you should test your app on Linux or Windows before release if you
target these platforms.

On Android, iOS, macOS and Windows, SQLCipher uses native crypto libraries shipped with the operating system.
On Linux, a statically linked version of OpenSSL is included with your app by default. If you prefer to link
OpenSSL statically, add this to `linux/CMakeLists.txt`:

```
set(OPENSSL_USE_STATIC_LIBS OFF)
```

## Problems on Android 6

There appears to be a problem when loading native libraries on Android 6 (see [this issue](https://github.com/simolus3/moor/issues/895#issuecomment-720195005)).
If you're seeing those crashes, you could try setting `android.bundle.enableUncompressedNativeLibs=false` in your `gradle.properties`
file. Be aware that this increases the size of your application when installed.

Alternatively, you can use the `applyWorkaroundToOpenSqlCipherOnOldAndroidVersions` method from this library.
It will try to open `sqlcipher` in Java, which seems to work more reliably. After the native library has been loaded from Java,
we can open it in Dart too.
The method should be called before using `sqlite3` (either directly or indirectly through say a `NativeDatabase` from `package:drift`).

As `applyWorkaroundToOpenSqlCipherOnOldAndroidVersions` uses platform channels, there may be issues when using it on a background isolate.
We recommend awaiting it in the main isolate, _before_ spawning a background isolate that might use the database.
