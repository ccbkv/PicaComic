import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_image_gallery_saver/flutter_image_gallery_saver.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/tools/file_type.dart';
import 'package:pica_comic/tools/io_tools.dart';
import 'package:pica_comic/tools/translations.dart';
import 'package:share_plus/share_plus.dart';

import '../foundation/app.dart';

///保存图片
void saveImage(File file) async {
  final imageSaver = ImageGallerySaver();
  var data = await file.readAsBytes();
  var type = detectFileType(data);
  var fileName = file.name;
  if (!fileName.contains('.')) {
    fileName += type.ext;
  }
  if (App.isAndroid || App.isIOS) {
    await imageSaver.saveImage(data);
    showToast(message: "已保存".tl);
  } else if (App.isDesktop) {
    try {
      final String? path =
          (await getSaveLocation(suggestedName: fileName))?.path;
      if (path != null) {
        final mimeType = type.mime;
        final XFile xFile =
            XFile.fromData(data, mimeType: mimeType, name: fileName);
        await xFile.saveTo(path);
      }
    } catch (e, s) {
      LogManager.addLog(LogLevel.error, "Save Image", "$e\n$s");
    }
  }
}

Future<String> persistentCurrentImage(File file) async {
  final data = await file.readAsBytes();
  final type = detectFileType(data);
  final hash = md5.convert(data).toString();
  final fileName = "$hash${type.ext})}";
  final newFile = File("${App.dataPath}/images/$fileName");
  if (!(await newFile.exists())) {
    newFile.createSync(recursive: true);
    newFile.writeAsBytesSync(data);
  }
  return newFile.path;
}

void shareImage(File file) {
  Share.shareXFiles([XFile(file.path)]);
}
