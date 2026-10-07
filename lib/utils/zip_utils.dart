import 'dart:io';

import 'package:archive/archive_io.dart' as archive;
import 'package:collection/collection.dart';
import 'package:zip_flutter/zip_flutter.dart' as zip_flutter;

import '../foundation/platform_utils.dart';

abstract class ZipArchiveWriter {
  void addFile(String archivePath, String sourcePath);
  void close();
}

/// Flatten a script archive into numbered pages for the existing local reader.
Future<int> extractComicArchive(List<String> paths) async {
  final input = archive.InputFileStream(paths[0]);
  try {
    final contents = archive.ZipDecoder().decodeBuffer(input);
    var totalSize = 0;
    if (contents.length > 20000) {
      throw const FormatException('Archive contains too many entries');
    }
    for (final file in contents) {
      final name = file.name.replaceAll('\\', '/');
      if (file.isSymbolicLink ||
          name.startsWith('/') ||
          name.contains('\u0000') ||
          RegExp(r'^[A-Za-z]:').hasMatch(name) ||
          name.split('/').contains('..')) {
        throw const FormatException('Unsafe archive entry');
      }
      totalSize += file.size;
      if (file.size < 0 || file.size > 256 * 1024 * 1024 ||
          totalSize > 8 * 1024 * 1024 * 1024) {
        throw const FormatException('Archive exceeds extraction size limits');
      }
    }
    final images = contents.where((file) {
      final name = file.name.replaceAll('\\', '/');
      return file.isFile &&
          !name.split('/').contains('__MACOSX') &&
          !name.split('/').last.startsWith('._') &&
          RegExp(r'\.(jpg|jpeg|png|gif|webp|avif|bmp)$', caseSensitive: false)
              .hasMatch(name);
    }).toList()
      ..sort((a, b) => compareNatural(a.name, b.name));
    if (images.isEmpty) {
      throw const FormatException('Archive contains no images');
    }
    final output = Directory(paths[1]);
    if (await output.exists()) await output.delete(recursive: true);
    await output.create(recursive: true);
    for (var i = 0; i < images.length; i++) {
      final file = images[i];
      final bytes = file.content as List<int>;
      if (bytes.length != file.size || archive.getCrc32(bytes) != file.crc32) {
        throw const FormatException('Invalid archive image checksum');
      }
      final extension = file.name.split('.').last.toLowerCase();
      await File('${output.path}/$i.$extension').writeAsBytes(bytes);
      file.clear();
    }
    return images.length;
  } finally {
    await input.close();
  }
}

ZipArchiveWriter createPortableZipWriter(String outputPath) {
  return _ArchiveZipWriter(outputPath);
}

ZipArchiveWriter createZipWriter(String outputPath) {
  if (PlatformUtils.isOhos || Platform.isWindows) {
    return _ArchiveZipWriter(outputPath);
  }
  return _ZipFlutterWriter(outputPath);
}

Future<void> extractPortableZipFile(
    String zipFilePath, String destinationDir) async {
  final bytes = File(zipFilePath).readAsBytesSync();
  final archiveData = archive.ZipDecoder().decodeBytes(bytes, verify: true);
  Directory(destinationDir).createSync(recursive: true);
  for (final file in archiveData) {
    final outPath = '$destinationDir/${file.name}';
    if (file.isFile) {
      File(outPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(file.content as List<int>);
    } else {
      Directory(outPath).createSync(recursive: true);
    }
  }
}

Future<void> extractZipFile(String zipFilePath, String destinationDir) async {
  if (PlatformUtils.isOhos) {
    // 在 OHOS 上直接读入内存解压，避免 InputFileStream 可能的兼容问题
    await extractPortableZipFile(zipFilePath, destinationDir);
    return;
  }
  zip_flutter.ZipFile.openAndExtract(zipFilePath, destinationDir);
}

class _ZipFlutterWriter implements ZipArchiveWriter {
  final zip_flutter.ZipFile _zipFile;

  _ZipFlutterWriter(String outputPath)
      : _zipFile = zip_flutter.ZipFile.open(outputPath);

  @override
  void addFile(String archivePath, String sourcePath) {
    _zipFile.addFile(archivePath, sourcePath);
  }

  @override
  void close() {
    _zipFile.close();
  }
}

class _ArchiveZipWriter implements ZipArchiveWriter {
  final archive.ZipFileEncoder _encoder = archive.ZipFileEncoder();

  _ArchiveZipWriter(String outputPath) {
    _encoder.create(outputPath);
  }

  @override
  void addFile(String archivePath, String sourcePath) {
    final file = File(sourcePath);
    if (!file.existsSync()) {
      throw FileSystemException("File not found", sourcePath);
    }
    _encoder.addFile(file, archivePath);
  }

  @override
  void close() {
    _encoder.close();
  }
}
