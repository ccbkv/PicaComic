## 0.6.4

- Fix compilation on Android by upgrading `compileSdk` version.

## 0.6.3

- Enable extension loading on Windows and Linux to match the compile options
  used on other platforms.

## 0.6.2

- Update SQLCipher to `4.5.7`.

## 0.6.1

- Update SQLCipher to `4.5.6`.
- For Linux builds, you can now include `set(OPENSSL_USE_STATIC_LIBS OFF)` in your
  `CMakeLists.txt` to link OpenSSL dynamically.

## 0.6.0

- Update SQLCipher to `4.5.5` (https://www.zetetic.net/blog/2023/08/31/sqlcipher-4.5.5-release/)
- On Android, migrate from `android-database-sqlcipher` to `sqlcipher-android`.
  If you use SQLCipher APIs in your native Android platform code, consider migrating as well and
  follow the [migration guide](https://www.zetetic.net/sqlcipher/sqlcipher-for-android-migration/).

## 0.5.7

- Consistently compile `SQLCipher` with `SQLITE_THREADSAFE=1` on all supported platforms.

## 0.5.6

- Upgrade `SQLCipher` to version `4.5.4` (https://www.zetetic.net/blog/2023/04/27/sqlcipher-4.5.4-release).

## 0.5.5

- Support Android projects built with Gradle 8.

## 0.5.4

- Fix building `SQLCipher` on Windows - see the readme for more details.

## 0.5.3

- Upgrade `SQLCipher` to version `4.5.2`.

## 0.5.2

- This package now works on Windows and Linux too!
- Upgrade `SQLCipher` to version `4.5.1`

## 0.5.1

- Upgrade `SQLCipher` to version `4.5.0`

## 0.5.0

- Initial pub release to match the version of `sqlite3_flutter_libs`
