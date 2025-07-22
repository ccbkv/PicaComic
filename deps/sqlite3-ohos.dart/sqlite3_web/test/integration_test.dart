import 'dart:io';

import 'package:sqlite3_web/src/types.dart';
import 'package:test/test.dart';
import 'package:webdriver/async_io.dart';

import '../tool/server.dart';

enum Browser {
  chrome(
    driverUriString: 'http://localhost:4444/wd/hub/',
    isChromium: true,
    unsupportedImplementations: {
      (StorageMode.opfs, AccessMode.throughSharedWorker)
    },
    missingFeatures: {MissingBrowserFeature.dedicatedWorkersInSharedWorkers},
    defaultImplementation: (
      StorageMode.opfs,
      AccessMode.throughDedicatedWorker
    ),
  ),
  firefox(
    driverUriString: 'http://localhost:4444/',
    defaultImplementation: (StorageMode.opfs, AccessMode.throughSharedWorker),
  );

  final bool isChromium;
  final String driverUriString;
  final Set<(StorageMode, AccessMode)> unsupportedImplementations;
  final Set<MissingBrowserFeature> missingFeatures;
  final (StorageMode, AccessMode) defaultImplementation;

  const Browser({
    required this.driverUriString,
    required this.defaultImplementation,
    this.isChromium = false,
    this.unsupportedImplementations = const {},
    this.missingFeatures = const {},
  });

  Uri get driverUri => Uri.parse(driverUriString);

  Set<(StorageMode, AccessMode)> get availableImplementations {
    final available = <(StorageMode, AccessMode)>{};
    for (final storage in StorageMode.values) {
      for (final access in AccessMode.values) {
        if (access != AccessMode.inCurrentContext &&
            !unsupportedImplementations.contains((storage, access))) {
          available.add((storage, access));
        }
      }
    }

    return available;
  }

  bool supports((StorageMode, AccessMode) impl) =>
      !unsupportedImplementations.contains(impl);

  Future<Process> spawnDriver() async {
    return switch (this) {
      firefox => Process.start('geckodriver', []).then((result) async {
          // geckodriver seems to take a while to initialize
          await Future.delayed(const Duration(seconds: 1));
          return result;
        }),
      chrome =>
        Process.start('chromedriver', ['--port=4444', '--url-base=/wd/hub']),
    };
  }
}

void main() {
  late TestAssetServer server;

  setUpAll(() async {
    server = await TestAssetServer.start();
  });
  tearDownAll(() => server.close());

  for (final browser in Browser.values) {
    group(browser.name, () {
      late Process driverProcess;
      late TestWebDriver driver;

      setUpAll(() async => driverProcess = await browser.spawnDriver());
      tearDownAll(() => driverProcess.kill());

      setUp(() async {
        final rawDriver = await createDriver(
          spec: browser.isChromium ? WebDriverSpec.JsonWire : WebDriverSpec.W3c,
          uri: browser.driverUri,
          desired: {
            'goog:chromeOptions': {
              'args': [
                '--headless=new',
                '--disable-search-engine-choice-screen',
              ],
            },
            'moz:firefoxOptions': {
              'args': ['-headless']
            },
          },
        );

        rawDriver.logs.get(LogType.browser).listen((entry) {
          print('[console]: ${entry.message}');
        });

        driver = TestWebDriver(server, rawDriver);
        await driver.driver.get('http://localhost:8080/');

        while (true) {
          try {
            // This element is created after main() has completed, make sure
            // all the callbacks have been installed.
            await driver.driver.findElement(By.id('ready'));
            break;
          } on NoSuchElementException {
            continue;
          }
        }
      });

      tearDown(() => driver.driver.quit());

      test('compatibility check', () async {
        final result = await driver.probeImplementations();

        expect(result.missingFeatures, browser.missingFeatures);
        expect(result.impls, browser.availableImplementations);
      });

      test('picks recommended option', () async {
        final (storage, access) = await driver.openDatabase();
        expect((storage, access), browser.defaultImplementation);
      });

      for (final (storage, access) in browser.availableImplementations) {
        test('$storage through $access', () async {
          await driver.openDatabase((storage, access));
          await driver.execute('CREATE TABLE foo (bar TEXT);');
          expect(await driver.countUpdateEvents(), 0);
          await driver.execute("INSERT INTO foo (bar) VALUES ('hello');");
          expect(await driver.countUpdateEvents(), 1);
        });
      }
    });
  }
}
