import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pica_comic/foundation/log.dart';

class FontManager {
  static final FontManager _instance = FontManager._internal();
  factory FontManager() => _instance;
  FontManager._internal();

  List<String> availableFonts = [];

  Future<void> init() async {
    await scanFonts();
  }

  Future<String?> getFontsDir() async {
    Directory? dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory();
    } else {
      dir = await getApplicationSupportDirectory();
    }
    if (dir != null) {
      return "${dir.path}/fonts";
    }
    return null;
  }

  Future<void> scanFonts() async {
    availableFonts.clear();
    Directory? dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory();
    } else {
      dir = await getApplicationSupportDirectory();
    }

    if (dir != null) {
      final fontsDir = Directory("${dir.path}/fonts");
      if (!await fontsDir.exists()) {
        try {
          await fontsDir.create();
        } catch (e) {
          LogManager.addLog(LogLevel.error, "FontManager",
              "Failed to create fonts directory: $e");
          return;
        }
      }

      try {
        await for (var entity in fontsDir.list()) {
          if (entity is File) {
            final path = entity.path.toLowerCase();
            if (path.endsWith('.ttf') || path.endsWith('.otf')) {
              String name = entity.uri.pathSegments.last.split('.').first;
              availableFonts.add(name);

              var loader = FontLoader(name);
              loader.addFont(Future.value(
                  ByteData.sublistView(await entity.readAsBytes())));
              await loader.load();
              LogManager.addLog(
                  LogLevel.info, "FontManager", "Loaded font: $name");
            }
          }
        }
      } catch (e) {
        LogManager.addLog(
            LogLevel.error, "FontManager", "Error loading fonts: $e");
      }
    }
  }

  Future<String?> addFont(String path) async {
    try {
      var file = File(path);
      if (!await file.exists()) return null;

      Directory? dir;
      if (Platform.isAndroid) {
        dir = await getExternalStorageDirectory();
      } else {
        dir = await getApplicationSupportDirectory();
      }

      if (dir == null) return null;
      final fontsDir = Directory("${dir.path}/fonts");
      if (!await fontsDir.exists()) {
        await fontsDir.create();
      }

      var fileName = file.uri.pathSegments.last;
      var newPath = "${fontsDir.path}/$fileName";

      // Check if file already exists
      if (await File(newPath).exists()) {
        await File(newPath).delete();
      }

      await file.copy(newPath);

      // Reload fonts
      await scanFonts();

      return fileName.split('.').first;
    } catch (e) {
      LogManager.addLog(LogLevel.error, "FontManager", "Error adding font: $e");
      return null;
    }
  }
}
