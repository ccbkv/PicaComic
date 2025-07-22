import 'dart:io';

import 'package:build_daemon/client.dart';
import 'package:build_daemon/constants.dart';
import 'package:build_daemon/data/build_target.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_proxy/shelf_proxy.dart';

Future<void> main() async {
  final script = Platform.script.toFilePath(windows: Platform.isWindows);
  final packageDir = p.dirname(p.dirname(script));

  final buildRunner = await BuildDaemonClient.connect(
    packageDir,
    [
      Platform.executable, // dart
      'run',
      'build_runner',
      'daemon',
    ],
    logHandler: (log) => print(log.message),
  );

  buildRunner
    ..registerBuildTarget(DefaultBuildTarget((b) => b.target = 'example'))
    ..startBuild();

  final assetServerPortFile =
      File(p.join(daemonWorkspace(packageDir), '.asset_server_port'));
  final assetServerPort = int.parse(await assetServerPortFile.readAsString());

  final proxy = proxyHandler('http://localhost:$assetServerPort/example/');

  await serve(
    (request) async {
      final pathSegments = request.url.pathSegments;

      if (pathSegments.isEmpty) {
        return Response(302, headers: {
          'Location': 'http://localhost:8080/web/',
        });
      }

      final response = await proxy(request);

      return response.change(headers: {
        // Needed for shared array buffers to work
        'Cross-Origin-Opener-Policy': 'same-origin',
        'Cross-Origin-Embedder-Policy': 'require-corp'
      });
    },
    'localhost',
    8080,
  );
  print('Listening on http://localhost:8080');
}
