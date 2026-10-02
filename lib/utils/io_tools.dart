import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
//import 'package:file_picker_ohos/file_picker_ohos.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pica_comic/base.dart';
import 'package:pica_comic/foundation/comic_source/comic_source.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/foundation/cache_manager.dart';
import 'package:pica_comic/foundation/history.dart';
import 'package:pica_comic/foundation/local_favorites.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/foundation/platform_utils.dart';
import 'package:pica_comic/network/cookie_jar.dart';
import 'package:pica_comic/network/download.dart';
import 'package:pica_comic/network/download_model.dart';
import 'package:pica_comic/utils/io_extensions.dart';
import 'package:pica_comic/utils/sync_merge.dart';
import 'package:pica_comic/utils/zip_utils.dart';

import '../foundation/app.dart';

Future<double> getFolderSize(Directory path) async {
  double total = 0;
  for (var f in path.listSync(recursive: true)) {
    if (FileSystemEntity.typeSync(f.path) == FileSystemEntityType.file) {
      total += File(f.path).lengthSync() / 1024 / 1024;
    }
  }
  return total;
}

Future<bool> exportComic(String id, String name,
    [List<String>? epNames]) async {
  try {
    name = sanitizeFileName(name, maxLength: 251);
    var data = ExportComicData(
      id,
      downloadManager.path!,
      name,
      epNames,
      downloadManager.getDirectory(id),
    );
    var res = await compute(runningExportComic, data);
    if (!res) {
      return false;
    }

    if (PlatformUtils.isOhos) {
      await FilePicker.platform.saveFile(
        fileName: '$name.zip',
        type: FileType.any,
        bytes: await File('${data.path}$pathSep$name.zip').readAsBytes(),
      );
    } else if (App.isMobile) {
      var params =
          SaveFileDialogParams(sourceFilePath: '${data.path}$pathSep$name.zip');
      await FlutterFileDialog.saveFile(params: params);
    } else {
      final FileSaveLocation? result =
          await getSaveLocation(suggestedName: '$name.zip');

      if (result != null) {
        const String mimeType = 'application/zip';
        final XFile textFile =
            XFile('${data.path}$pathSep$name.zip', mimeType: mimeType);
        await textFile.saveTo(result.path);
      }
    }

    var file = File('${data.path}$pathSep$name.zip');
    file.delete();
    return true;
  } catch (e) {
    return false;
  }
}

Future<bool> exportComics(List<DownloadedItem> comics) async {
  try {
    var exportDatas = <ExportComicData>[];
    for (var comic in comics) {
      var id = comic.id;
      var name = sanitizeFileName(comic.name);
      var path = downloadManager.path;
      var epNames = comic.eps;
      exportDatas.add(ExportComicData(
        id,
        path!,
        name,
        epNames,
        downloadManager.getDirectory(id),
      ));
    }
    await Isolate.run(() => runningExportComics(exportDatas));
    if (PlatformUtils.isOhos) {
      await FilePicker.platform.saveFile(
        fileName: 'comics.zip',
        type: FileType.any,
        bytes: await File('${downloadManager.path}/comics.zip').readAsBytes(),
      );
    } else if (App.isMobile) {
      var params = SaveFileDialogParams(
          sourceFilePath: '${downloadManager.path}/comics.zip');
      await FlutterFileDialog.saveFile(params: params);
    } else {
      final FileSaveLocation? result =
          await getSaveLocation(suggestedName: 'comics.zip');

      if (result != null) {
        const String mimeType = 'application/zip';
        final XFile textFile =
            XFile('${downloadManager.path}/comics.zip', mimeType: mimeType);
        await textFile.saveTo(result.path);
      }
    }
    var file = File('${downloadManager.path}/comics.zip');
    if (file.existsSync()) {
      file.delete();
    }
    return true;
  } catch (e) {
    return false;
  }
}

Future<bool> exportPdf(String pdfPath) async {
  try {
    if (PlatformUtils.isOhos) {
      await FilePicker.platform.saveFile(
        fileName: File(pdfPath).name,
        type: FileType.any,
        bytes: await File(pdfPath).readAsBytes(),
      );
    } else if (App.isMobile) {
      var params = SaveFileDialogParams(sourceFilePath: pdfPath);
      await FlutterFileDialog.saveFile(params: params);
    } else {
      final FileSaveLocation? result = await getSaveLocation(
        suggestedName: File(pdfPath).name,
        acceptedTypeGroups: [
          const XTypeGroup(label: 'pdf', extensions: ['pdf'])
        ],
      );

      if (result != null) {
        const String mimeType = 'application/pdf';
        final XFile textFile = XFile(pdfPath, mimeType: mimeType);
        await textFile.saveTo(result.path);
      }
    }
    if (File(pdfPath).existsSync()) {
      File(pdfPath).delete();
    }
    return true;
  } catch (e) {
    return false;
  }
}

class ExportComicData {
  String id;
  String path;
  String name;
  String directory;
  List<String>? epNames;

  ExportComicData(this.id, this.path, this.name, this.epNames, this.directory);
}

Future<bool> runningExportComic(ExportComicData data) async {
  final fileName = '${data.path}/${data.name}.zip';
  try {
    final path = Directory("${data.path}/${data.directory}");
    var zipFile = createZipWriter(fileName);
    String? currentDirName;

    void walk(String path) {
      for (var entry in Directory(path).listSync()) {
        if (entry is Directory) {
          var index = int.parse(entry.name) - 1;
          currentDirName = sanitizeFileName(
              data.epNames?.elementAtOrNull(index) ?? "Chapter ${index + 1}");
          walk(entry.path);
        } else {
          var filePathInZip = sanitizeFileName(data.name);
          if (currentDirName != null) {
            filePathInZip += "/$currentDirName";
          }
          filePathInZip += "/${entry.name}";
          zipFile.addFile(filePathInZip, entry.path);
        }
      }
    }

    walk(path.path);
    zipFile.close();
    return true;
  } catch (e, s) {
    LogManager.addLog(LogLevel.error, "IO", "$e\n$s");
    return false;
  }
}

Future<bool> runningExportComics(List<ExportComicData> datas) async {
  try {
    var result = "${datas.first.path}/comics.zip";
    if (File(result).existsSync()) {
      File(result).deleteSync();
    }
    var zipFile = createZipWriter(result);
    for (var data in datas) {
      final directory = Directory('${data.path}/${data.directory}');

      String? currentDirName;

      void walk(String path) {
        for (var entry in Directory(path).listSync()) {
          if (entry is Directory) {
            var index = int.parse(entry.name) - 1;
            currentDirName = sanitizeFileName(
                data.epNames?.elementAtOrNull(index) ?? "Chapter ${index + 1}");
            walk(entry.path);
          } else {
            var filePathInZip = sanitizeFileName(data.name);
            if (currentDirName != null) {
              filePathInZip += "/$currentDirName";
            }
            filePathInZip += "/${entry.name}";
            zipFile.addFile(filePathInZip, entry.path);
          }
        }
      }

      walk(directory.path);
    }
    zipFile.close();
    return true;
  } catch (e, s) {
    LogManager.addLog(LogLevel.error, "IO", "$e\n$s");
    return false;
  }
}

Future<void> eraseCache() async {
  return CacheManager().clear();
}

Future<void> copyDirectory(Directory source, Directory destination) async {
  try {
    List<FileSystemEntity> contents = source.listSync();
    for (FileSystemEntity content in contents) {
      String newPath = destination.path +
          Platform.pathSeparator +
          content.path.split(Platform.pathSeparator).last;

      if (content is File) {
        content.copySync(newPath);
      } else if (content is Directory) {
        Directory newDirectory = Directory(newPath);
        newDirectory.createSync();
        copyDirectory(content.absolute, newDirectory.absolute);
      }
    }
  } catch (e, s) {
    LogManager.addLog(LogLevel.error, "IO", "$e\n$s");
    rethrow;
  }
}

/// move all files and directories from source to destination
Future<void> moveDirectory(Directory source, Directory destination) async {
  try {
    source = source.absolute;
    destination = destination.absolute;
    List<FileSystemEntity> contents = source.listSync();
    for (FileSystemEntity content in contents) {
      if (content is File) {
        await content
            .rename(destination.path + Platform.pathSeparator + content.name);
      } else if (content is Directory) {
        Directory newDirectory =
            Directory(destination.path + Platform.pathSeparator + content.name);
        newDirectory.createSync(recursive: true);
        await moveDirectory(content, newDirectory);
      }
    }
    await source.deleteIgnoreError(recursive: true);
  } catch (e, s) {
    LogManager.addLog(LogLevel.error, "IO", "$e\n$s");
    rethrow;
  }
}

///检查下载目录是否可用, 不可用则重置
Future<void> checkDownloadPath() async {
  var path = appdata.settings[22];
  if (PlatformUtils.isOhos) {
    if (path.isNotEmpty) {
      appdata.settings[22] = "";
      appdata.updateSettings();
    }
    return;
  }
  if (path.isNotEmpty) {
    var directory = Directory(path);
    if (!directory.existsSync()) {
      appdata.settings[22] = "";
      appdata.updateSettings();
    }
  }
}

Future<String?> _exportData(String path, String appdataString,
    String? downloadPath, String outPath) async {
  var encode = createPortableZipWriter(outPath);
  try {
    void addDirectoryToZip(Directory directory, String zipPath) {
      for (final entry in directory.listSync()) {
        if (entry is File) {
          encode.addFile('$zipPath/${entry.name}', entry.path);
        } else if (entry is Directory) {
          addDirectoryToZip(entry, '$zipPath/${entry.name}');
        }
      }
    }

    void addOptionalDirectoryWithMarker(String name) {
      final directory = Directory("$path${pathSep}$name");
      final marker = File("$path${pathSep}$name.marker");
      if (directory.existsSync()) {
        marker.writeAsStringSync("");
        encode.addFile(marker.name, marker.path);
        addDirectoryToZip(directory, name);
      }
    }

    var filePath = "$path${pathSep}appdata";
    var file = File(filePath);
    if (file.existsSync()) {
      file.deleteSync();
    }
    file.createSync();
    file.writeAsStringSync(appdataString);
    encode.addFile(file.uri.pathSegments.last, file.path);
    var localFavorite = File("$path${pathSep}local_favorite.db");
    var history = File("$path${pathSep}history.db");
    var localComicFolders = File("$path${pathSep}local_comic_folders.json");
    var localAddComicUi = File("$path${pathSep}local_add_comic_ui.json");
    var localAddComic = Directory("$path${pathSep}local_add_comic");
    var localAddComicMarker = File("$path${pathSep}local_add_comic.marker");
    if (!localFavorite.existsSync()) {
      localFavorite.createSync();
    }
    if (!history.existsSync()) {
      history.createSync();
    }
    if (!localComicFolders.existsSync()) {
      localComicFolders.createSync();
      localComicFolders.writeAsStringSync("[]");
    }
    if (!localAddComicUi.existsSync()) {
      localAddComicUi.createSync();
      localAddComicUi.writeAsStringSync("{}");
    }
    encode.addFile(
        localFavorite.name, localFavorite.path.replaceAll("\\", "/"));
    encode.addFile(history.name, history.path);
    encode.addFile(localComicFolders.name, localComicFolders.path);
    encode.addFile(localAddComicUi.name, localAddComicUi.path);
    encode.addFile('cookies.db', "$path/cookies.db");
    await for (var entry in Directory("$path/comic_source").list()) {
      if (entry is File) {
        encode.addFile('comic_source/${entry.name}', entry.path);
      }
    }
    if (localAddComic.existsSync()) {
      localAddComicMarker.writeAsStringSync("");
      encode.addFile(localAddComicMarker.name, localAddComicMarker.path);
      addDirectoryToZip(localAddComic, 'local_add_comic');
    }
    addOptionalDirectoryWithMarker('chapter_comments');
    addOptionalDirectoryWithMarker('comic_comments');
    if (downloadPath != null) {
      downloadPath = downloadPath.replaceAll('\\', '/');
      var sourceFolder =
          downloadPath.substring(0, downloadPath.lastIndexOf('/'));
      void walk(String path) {
        for (var entry in Directory(path).listSync()) {
          if (entry is Directory) {
            walk(entry.path);
          } else {
            var filePathInZip = entry.path.replaceFirst(sourceFolder, "");
            if (filePathInZip.startsWith('/') ||
                filePathInZip.startsWith('\\')) {
              filePathInZip = filePathInZip.substring(1);
            }
            encode.addFile(filePathInZip, entry.path);
          }
        }
      }

      walk(downloadPath);
    }
    return null;
  } catch (e) {
    return e.toString();
  } finally {
    final localAddComicMarker = File("$path${pathSep}local_add_comic.marker");
    if (localAddComicMarker.existsSync()) {
      localAddComicMarker.deleteSync();
    }
    for (final markerName in ['chapter_comments.marker', 'comic_comments.marker']) {
      final marker = File("$path${pathSep}$markerName");
      if (marker.existsSync()) {
        marker.deleteSync();
      }
    }
    encode.close();
  }
}

Future<String> exportDataToFile(bool includeDownload, String outPath) async {
  var path = App.dataPath;
  try {
    var appdataString = const JsonEncoder().convert(appdata.toJson());
    var downloadPath = includeDownload ? DownloadManager().path : null;
    var res = await compute<List<String?>, String?>(
        (message) =>
            _exportData(message[0]!, message[1]!, message[2], message[3]!),
        [path, appdataString, downloadPath, outPath]);

    if (res != null) {
      throw Exception(res);
    }
  } catch (e, s) {
    LogManager.addLog(LogLevel.error, "IO", "$e\n$s");
    rethrow;
  }
  return outPath;
}

Future<bool> runExportData(bool includeDownload) async {
  try {
    var outPath = '${App.cachePath}/userdata.picadata';
    if (App.isDesktop) {
      final FileSaveLocation? result =
          await getSaveLocation(suggestedName: 'userData.picadata');
      if (result == null) {
        return true;
      }
      outPath = result.path;
    }
    if (await File(outPath).exists()) {
      await File(outPath).delete();
    }
    await exportDataToFile(includeDownload, outPath);

    var dialog = showLoadingDialog(
      App.globalContext!,
      barrierDismissible: false,
      allowCancel: false,
    );

    if (PlatformUtils.isOhos) {
      await downloadManager.init();
      var downloadPath = downloadManager.path;
      if (downloadPath == null || downloadPath.isEmpty) {
        throw Exception("Download directory unavailable");
      }
      var targetFile = File("$downloadPath/userData.picadata");
      if (await targetFile.exists()) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        targetFile = File("$downloadPath/userData_$timestamp.picadata");
      }
      await File(outPath).copy(targetFile.path);
      await File(outPath).delete();
    } else if (App.isMobile) {
      var params = SaveFileDialogParams(sourceFilePath: outPath);
      await FlutterFileDialog.saveFile(params: params);
      File(outPath).delete();
    }

    dialog.close();
  } catch (e, s) {
    LogManager.addLog(LogLevel.error, "IO", "$e\n$s");
    return false;
  }
  return true;
}

/// import data, filePath is used for webdav
/// Human-readable reason for the most recent [importData] failure.
/// Used to surface a concrete error instead of a generic "sync failed".
String? _lastImportError;

String? get lastImportError => _lastImportError;

/// 最近一次导入实际发生的收藏变更数（新增或更新的条目）。
/// 大于 0 说明本次导入让本机收藏变多了，需要把合并结果回传服务器，
/// 否则下次其它设备同步时又会用旧备份覆盖掉这些新增收藏。
int _lastMergeChanges = 0;

/// 本次导入是否确实合并进了新数据（需要回传）。
bool get lastImportMergedSomething => _lastMergeChanges > 0;

/// Import user data from a backup file.
///
/// [filePath]  - the .picadata file to import. When null a file picker is shown.
/// [force]     - when true, skip the version check entirely and always import.
///               Manual "download data" from WebDAV must pass true, otherwise a
///               device whose settings[46] already matches the server will
///               silently refuse to import (the sync "deadlock" bug).
Future<bool> importData([String? filePath, bool force = false]) async {
  final enableCheck = filePath != null && !force;
  var path = (await getApplicationSupportDirectory()).path;
  if (filePath == null) {
    if (PlatformUtils.isOhos) {
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['picadata'],
          allowMultiple: false,
          withData: true,
        );
        if (result != null && result.files.isNotEmpty) {
          final picked = result.files.first;
          filePath = picked.path;
          if ((filePath == null || filePath.isEmpty) &&
              picked.bytes != null &&
              picked.bytes!.isNotEmpty) {
            final temp = File(
                '$path${pathSep}picked_${DateTime.now().millisecondsSinceEpoch}.picadata');
            temp.writeAsBytesSync(picked.bytes!);
            filePath = temp.path;
            LogManager.addLog(LogLevel.info, "importData",
                "OHOS picker fallback: wrote bytes to $filePath");
          }
        }
      } catch (e, s) {
        LogManager.addLog(
            LogLevel.error, "importData", "OHOS file picker failed: $e\n$s");
      }
      if (filePath == null) {
        return false;
      }
    }
    if (filePath == null && App.isMobile) {
      var params = const OpenFileDialogParams();
      filePath = await FlutterFileDialog.pickFile(params: params);
    } else if (filePath == null && !PlatformUtils.isOhos) {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'data',
      );
      final XFile? file =
          await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
      filePath = file?.path;
    }
    if (filePath == null) {
      LogManager.addLog(LogLevel.error, "importData", "filePath is null");
      _lastImportError = "未选择备份文件";
      return false;
    }
  }
  try {
    final pickedFile = File(filePath);
    final exists = pickedFile.existsSync();
    final size = exists ? pickedFile.lengthSync() : 0;
    LogManager.addLog(LogLevel.info, "importData",
        "准备导入: $filePath, 存在=$exists, 大小=${size}B");
    if (!exists || size == 0) {
      LogManager.addLog(LogLevel.error, "importData", "选中的备份文件不存在或大小为0");
      _lastImportError = "备份文件不存在或大小为 0 (下载可能未完成)";
      return false;
    }
    final raf = pickedFile.openSync();
    try {
      final header = raf.readSync(4);
      LogManager.addLog(LogLevel.info, "importData",
          "文件头: ${header.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}");
    } finally {
      raf.closeSync();
    }
  } catch (e, s) {
    LogManager.addLog(
        LogLevel.error, "importData", "检查备份文件出错: $e\n$s\n路径: $filePath");
    return false;
  }
  SingleInstanceCookieJar.instance?.dispose();
  DownloadManager().dispose();
  // 合并收藏需要独占访问 local_favorite.db：这里先关闭本机收藏库连接，
  // 否则合并时的写入会与已打开的连接冲突（SQLite 锁库）。
  // 合并完成后在 finally 里通过 readData() 重新打开。
  await LocalFavoritesManager().closeForMerge();
  String data = '';
  try {
    data = await compute<List<String>, String>((data) async {
      var path = data[0];
      await extractPortableZipFile(data[1], "$path/dataTemp");
      _flattenExtractedRoot("$path/dataTemp");
      var downloadPath = Directory(data[2]);
      List<FileSystemEntity> contents = Directory("$path/dataTemp").listSync();
      const knownDirectories = {
        "comic_source",
        "download",
        "local_add_comic",
        "chapter_comments",
        "comic_comments",
      };
      for (FileSystemEntity item in contents) {
        if (item is Directory) {
          if (!knownDirectories.contains(item.name) &&
              !Directory('$path/dataTemp/download').existsSync()) {
            item.renameSync('$path/dataTemp/download');
          }
        }
      }
      final appdataFile = File("$path/dataTemp/appdata");
      if (!appdataFile.existsSync()) {
        final dir = Directory("$path/dataTemp");
        final entries = dir.listSync(recursive: true).map((entity) {
          final relative =
              entity.path.replaceFirst("$path/dataTemp", "dataTemp");
          return "${entity is Directory ? "Dir" : "File"}:$relative";
        }).toList();
        final listing = entries.isEmpty ? "<empty>" : entries.join("\n");
        LogManager.addLog(
            LogLevel.error, "importData", "未找到appdata，目录结构:\n$listing");
        throw Exception("未找到appdata文件, 解压结果如下:\n$listing");
      }
      final json = appdataFile.readAsStringSync();
      int fileVersion = int.parse(
          ((const JsonDecoder().convert(json))["settings"] as List)
                  .elementAtOrNull(46) ??
              "1");
      if (fileVersion <= int.parse(data[3]) && data[4] == "1") {
        return json;
      }
      // 从这一版开始，收藏不再"整库覆盖"，改为按条目合并。
      // 旧逻辑直接 copySync 覆盖 local_favorite.db，会让多设备各自收藏
      // 的内容互相覆盖丢失，这里全部改为并集合并。
      var mergedCount = 0;
      var localFavorite = File('$path/dataTemp/localFavorite');
      if (localFavorite.existsSync()) {
        // 老版本导出的是 json 格式的 localFavorite，交给
        // LocalFavoritesManager.readData 自己合并（它本来就是并集逻辑）。
        localFavorite.copySync('$path/localFavorite');
      }
      var backupFavoriteDb = File('$path/dataTemp/local_favorite.db');
      if (backupFavoriteDb.existsSync()) {
        mergedCount = SyncMerge.mergeFavoriteDb(
          localPath: '$path/local_favorite.db',
          backupPath: backupFavoriteDb.path,
        );
        if (mergedCount != 0) {
          LogManager.addLog(LogLevel.info, "importData",
              "favorites merged, changed=$mergedCount");
        }
      }
      var history = File('$path/dataTemp/history.db');
      if (history.existsSync()) {
        // 历史本来就是合并式（HistoryManager.tryUpdateDb 按 target 去重补入）
        history.copySync('$path/history_temp.db');
      }
      var localComicFolders = File('$path/dataTemp/local_comic_folders.json');
      if (localComicFolders.existsSync()) {
        localComicFolders.copySync('$path/local_comic_folders.json');
      }
      var localAddComicUi = File('$path/dataTemp/local_add_comic_ui.json');
      if (localAddComicUi.existsSync()) {
        localAddComicUi.copySync('$path/local_add_comic_ui.json');
      }
      var comicSource = Directory('$path/dataTemp/comic_source');
      if (comicSource.existsSync()) {
        // 合并：本机已有的书源保留，备份里新增的补进来（不再 deleteSync 清空）
        var added = SyncMerge.mergeComicSource(
          localDir: '$path/comic_source',
          backupDir: comicSource.path,
        );
        mergedCount += added;
        LogManager.addLog(
            LogLevel.info, "importData", "comic_source merged, added=$added");
      }
      // 记录本次合并产生的变更数，供主 isolate 判断是否需要回传服务器。
      try {
        File('$path/.last_merge_changes')
            .writeAsStringSync(mergedCount.toString());
      } catch (_) {}
      var cookies = File('$path/dataTemp/cookies.db');
      if (cookies.existsSync()) {
        cookies.copySync('$path/cookies.db');
      }
      var downloadData = Directory("$path/dataTemp/download");
      if (downloadData.existsSync()) {
        downloadPath.deleteSync(recursive: true);
        downloadPath.createSync();
        await moveDirectory(downloadData, downloadPath);
      }
      var localAddComicMarker = File('$path/dataTemp/local_add_comic.marker');
      var localAddComicData = Directory('$path/dataTemp/local_add_comic');
      if (localAddComicMarker.existsSync() || localAddComicData.existsSync()) {
        var currentLocalAddComic = Directory('$path/local_add_comic');
        if (localAddComicData.existsSync()) {
          // 合并：本地添加的漫画按文件补齐，不再整目录清空
          SyncMerge.mergeDirectory(
            localDir: currentLocalAddComic.path,
            backupDir: localAddComicData.path,
          );
        }
      }
      for (final directoryName in ['chapter_comments', 'comic_comments']) {
        final marker = File('$path/dataTemp/$directoryName.marker');
        final backupDirectory = Directory('$path/dataTemp/$directoryName');
        if (marker.existsSync() || backupDirectory.existsSync()) {
          final currentDirectory = Directory('$path/$directoryName');
          if (backupDirectory.existsSync()) {
            // 合并：评论按文件补齐，不再整目录清空
            SyncMerge.mergeDirectory(
              localDir: currentDirectory.path,
              backupDir: backupDirectory.path,
            );
          }
        }
      }
      return json;
    }, [
      path,
      filePath,
      DownloadManager().path!,
      appdata.settings[46],
      (enableCheck ? "1" : "0")
    ]);
  } catch (e, s) {
    Log.error("importData", "$e\n$s");
    _lastImportError = "解压或读取备份文件失败: $e";
    return false;
  } finally {
    await ComicSource.reload();
    SingleInstanceCookieJar.instance?.init();
    await DownloadManager().init();
    try {
      Directory("$path/dataTemp").deleteSync(recursive: true);
    } catch (_) {}
    // 读取隔离区写下的合并变更数（compute 不共享静态变量）
    try {
      var f = File('$path/.last_merge_changes');
      if (f.existsSync()) {
        _lastMergeChanges = int.tryParse(f.readAsStringSync()) ?? 0;
        f.deleteSync();
      }
    } catch (_) {
      _lastMergeChanges = 0;
    }
  }
  var json = const JsonDecoder().convert(data);
  int fileVersion =
      int.parse((json["settings"] as List).elementAtOrNull(46) ?? "1");
  int appVersion = int.parse(appdata.settings[46]);
  if (fileVersion <= appVersion && enableCheck) {
    LogManager.addLog(
        LogLevel.info,
        "Appdata",
        "The data file version is $fileVersion, while the app data version is "
            "$appVersion\nStop importing data");
  }
  // 判断是否为「全新设备」：未完成初始引导时，需要完整继承备份里的设置
  // （否则新设备会停留在默认配置，同步"看起来没生效"）。
  // 已完成引导的设备则采用合并式导入，保留本机原有配置。
  var isFreshDevice = !(appdata.firstUse.length > 3 &&
      appdata.firstUse[3] == "1");
  var dataReadRes = await appdata.readDataFromJson(
    json,
    mergeSettings: !isFreshDevice,
  );
  if (!dataReadRes) {
    LogManager.addLog(
        LogLevel.error, "Appdata", "appdata.readDataFromJson(json) failed");
    _lastImportError = "解析备份内容失败 (readDataFromJson)";
    return false;
  }
  // 重新打开收藏库连接（合并前已 closeForMerge）。
  // 合并模式下不清空本机收藏：备份里已有的会被补入，本机独有的保留。
  await LocalFavoritesManager().reopenAfterMerge();
  await LocalFavoritesManager().readData(merge: true);
  LocalFavoritesManager().updateUI();
  await HistoryManager().tryUpdateDb();
  _lastImportError = null;
  return true;
}

void saveLog(String log) async {
  var path = (await getTemporaryDirectory()).path;
  var file = File("$path${pathSep}logs.txt");
  file.writeAsStringSync(log);
  if (PlatformUtils.isOhos) {
    await FilePicker.platform.saveFile(
      fileName: "logs.txt",
      type: FileType.any,
      bytes: await file.readAsBytes(),
    );
  } else if (App.isMobile) {
    var params =
        SaveFileDialogParams(sourceFilePath: "$path${pathSep}logs.txt");
    await FlutterFileDialog.saveFile(params: params);
  } else {
    final String? directoryPath = await getDirectoryPath();
    if (directoryPath != null) {
      await file.copy("$directoryPath${pathSep}logs.txt");
    }
  }
}

Future<void> exportStringDataAsFile(String data, String fileName) async {
  if (PlatformUtils.isOhos) {
    final Uint8List fileData =
        Uint8List.fromList(const Utf8Encoder().convert(data));
    await FilePicker.platform.saveFile(
      fileName: fileName,
      type: FileType.any,
      bytes: fileData,
    );
  } else if (App.isMobile) {
    var cachePath = (await getApplicationCacheDirectory()).path;
    var file = File("$cachePath$pathSep$fileName");
    if (!file.existsSync()) {
      file.createSync();
    }
    file.writeAsStringSync(data);
    var params = SaveFileDialogParams(sourceFilePath: file.path);
    await FlutterFileDialog.saveFile(params: params);
  } else {
    final FileSaveLocation? result =
        await getSaveLocation(suggestedName: fileName);
    if (result == null) {
      return;
    }

    final Uint8List fileData =
        Uint8List.fromList(const Utf8Encoder().convert(data));
    const String mimeType = 'text/plain';
    final XFile textFile =
        XFile.fromData(fileData, mimeType: mimeType, name: fileName);
    await textFile.saveTo(result.path);
  }
}

Future<String?> getDataFromUserSelectedFile(List<String> extensions) async {
  if (PlatformUtils.isOhos) {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        return null;
      }
      final picked = result.files.first;
      final path = picked.path;
      if (path != null && path.isNotEmpty) {
        return File(path).readAsStringSync();
      }
      final bytes = picked.bytes;
      if (bytes != null && bytes.isNotEmpty) {
        return utf8.decode(bytes, allowMalformed: true);
      }
    } catch (e, s) {
      LogManager.addLog(LogLevel.error, "getDataFromUserSelectedFile",
          "OHOS file picker failed: $e\n$s");
    }
    return null;
  }

  String? filePath;
  if (App.isMobile) {
    var params = const OpenFileDialogParams();
    filePath = await FlutterFileDialog.pickFile(params: params);
  } else {
    XTypeGroup typeGroup = XTypeGroup(
      label: 'data',
      extensions: extensions,
    );
    final XFile? file =
        await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    filePath = file?.path;
  }
  if (filePath == null) {
    return null;
  }
  return File(filePath).readAsStringSync();
}

void _flattenExtractedRoot(String dataTempPath) {
  final tempDir = Directory(dataTempPath);
  if (!tempDir.existsSync()) {
    return;
  }
  const appdataName = 'appdata';
  final appdataFile = File('$dataTempPath$pathSep$appdataName');
  if (appdataFile.existsSync()) {
    return;
  }
  final nestedAppdata = tempDir
      .listSync(recursive: true)
      .whereType<File>()
      .firstWhere(
          (file) =>
              file.name == appdataName && file.parent.path != dataTempPath,
          orElse: () => File(''));
  if (nestedAppdata.path.isEmpty) {
    return;
  }
  final nestedDir = nestedAppdata.parent;
  _moveDirectoryContentsToRoot(nestedDir, tempDir);
}

void _moveDirectoryContentsToRoot(Directory source, Directory targetRoot) {
  if (source.path == targetRoot.path) {
    return;
  }
  for (final entity in source.listSync()) {
    final targetPath = "${targetRoot.path}$pathSep${entity.name}";
    final targetType = FileSystemEntity.typeSync(targetPath);
    if (targetType == FileSystemEntityType.directory) {
      Directory(targetPath).deleteSync(recursive: true);
    } else if (targetType == FileSystemEntityType.file) {
      File(targetPath).deleteSync();
    }
    entity.renameSync(targetPath);
  }
  if (source.existsSync()) {
    source.deleteSync(recursive: true);
  }
}

extension FileExtension on File {
  String get name => uri.pathSegments.last;
}

String bytesLengthToReadableSize(int size) {
  if (size < 1024) {
    return "$size B";
  } else if (size < 1024 * 1024) {
    return "${(size / 1024).toStringAsFixed(2)} KB";
  } else if (size < 1024 * 1024 * 1024) {
    return "${(size / 1024 / 1024).toStringAsFixed(2)} MB";
  } else {
    return "${(size / 1024 / 1024 / 1024).toStringAsFixed(2)} GB";
  }
}
