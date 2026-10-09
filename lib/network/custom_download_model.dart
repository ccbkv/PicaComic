import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:pica_comic/base.dart';
import 'package:pica_comic/components/components.dart' show showToast;
import 'package:pica_comic/foundation/comic_source/comic_source.dart';
import 'package:pica_comic/foundation/image_manager.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/network/app_dio.dart';
import 'package:pica_comic/network/download_model.dart';
import 'package:pica_comic/network/jm_network/jm_download.dart';
import 'package:pica_comic/network/picacg_network/picacg_download_model.dart';
import 'package:pica_comic/utils/translations.dart';
import 'package:pica_comic/utils/zip_utils.dart';

import '../utils/io_tools.dart';
import 'download.dart';

class CustomDownloadedItem extends DownloadedItem {
  @override
  double? comicSize;

  @override
  final List<int> downloadedEps;

  final ComicChapters? chapters;

  @override
  List<String> get eps => chapters?.titles.toList() ?? ["EP 1"];

  final String comicId;

  final String? subId;

  @override
  final String id;

  @override
  final String name;

  @override
  final String subTitle;

  @override
  final List<String> tags;

  final List<String> categories;

  @override
  DownloadType get type => DownloadType.other;

  final String sourceKey;

  final String sourceName;

  final String cover;

  CustomDownloadedItem(
      this.comicSize,
      this.downloadedEps,
      this.chapters,
      this.id,
      this.name,
      this.subTitle,
      this.tags,
      this.sourceKey,
      this.sourceName,
      this.cover,
      this.comicId,
      [this.subId, this.categories = const []]);

  @override
  Map<String, dynamic> toJson() => {
        "comicSize": comicSize,
        "downloadedEps": downloadedEps,
        "chapters": chapters?.toJson(),
        "id": id,
        "name": name,
        "subTitle": subTitle,
        "tags": tags,
        "categories": categories,
        "sourceKey": sourceKey,
        "sourceName": sourceName,
        "cover": cover,
        "comicId": comicId,
        "subId": subId,
      };

  CustomDownloadedItem.fromJson(Map<String, dynamic> json)
      : comicSize = json["comicSize"],
        downloadedEps = List<int>.from(json["downloadedEps"]),
        chapters = ComicChapters.fromJsonOrNull(json["chapters"]),
        id = json["id"],
        name = json["name"],
        subTitle = json["subTitle"],
        tags = List<String>.from(json["tags"]),
        categories = List<String>.from(json["categories"] ?? const <String>[]),
        sourceKey = json["sourceKey"],
        sourceName = json["sourceName"],
        cover = json["cover"],
        comicId = json["comicId"],
        subId = json["subId"];
}

class CustomDownloadingItem extends DownloadingItem {
  CustomDownloadingItem(this.comic, this._downloadEps, super.whenFinish,
      super.whenError, super.updateInfo, super.id,
      {super.type = DownloadType.other});

  final ComicInfoData comic;

  final List<int> _downloadEps;

  ComicSource get source {
    final source = ComicSource.find(comic.sourceKey);
    if (source == null || source.isBuiltIn) {
      throw '请先添加对应漫画源'.tl;
    }
    return source;
  }

  @override
  void start() {
    final current = ComicSource.find(comic.sourceKey);
    if (current == null || current.isBuiltIn) {
      Future.microtask(() {
        if (!identical(DownloadManager().downloading.firstOrNull, this)) return;
        showToast(message: '请先添加对应漫画源'.tl);
        onError?.call();
      });
      return;
    }
    super.start();
  }

  @override
  Future<void> onStart() async {
    if (this is! CustomArchiveDownloadingItem && source.loadComicPages == null) {
      throw '漫画源不支持下载'.tl;
    }
    final previous = await DownloadManager().getComicOrNull(id);
    if (previous != null) {
      final previousHasEps = previous is CustomDownloadedItem
          ? previous.chapters != null
          : previous is DownloadedComic || previous is DownloadedJmComic;
      if (previousHasEps != haveEps) {
        throw '章节目录格式已变化，已保留旧下载文件'.tl;
      }
      final ids = comic.chapters?.ids.toList() ?? <String>[];
      if (previous is DownloadedJmComic) {
        final oldIds = previous.comic.series.isEmpty
            ? {1: previous.comic.id}
            : previous.comic.series;
        for (final ep in oldIds.entries) {
          if (ids.elementAtOrNull(ep.key - 1) != ep.value) {
            throw '章节顺序已变化，已保留旧下载文件'.tl;
          }
        }
      } else if (previous is DownloadedComic) {
        if (ids.length < previous.eps.length ||
            ids.indexed.any((entry) => entry.$2 != '${entry.$1 + 1}')) {
          throw '章节顺序已变化，已保留旧下载文件'.tl;
        }
      } else if (previous is CustomDownloadedItem) {
        final oldIds = previous.chapters?.ids.toList() ?? <String>[];
        for (int i = 0; i < oldIds.length; i++) {
          if (ids.elementAtOrNull(i) != oldIds[i]) {
            throw '章节顺序已变化，已保留旧下载文件'.tl;
          }
        }
      }
    }
    await super.onStart();
  }

  @override
  String get cover => comic.cover;

  @override
  bool get haveEps => comic.chapters != null;

  Future<Stream<DownloadProgress>> _getImage(String url) async {
    final ep = links!.keys.elementAt(downloadingEp);
    return ImageManager().getCustomImage(
      url,
      comic.comicId,
      comic.chapters?.ids.elementAtOrNull(ep - 1) ?? comic.comicId,
      source.key,
    );
  }

  @override
  Map<String, String> get headers => {
        "User-Agent": webUA,
      };

  @override
  Future<void> downloadCover() async {
    if (source.getThumbnailLoadingConfig == null) {
      return super.downloadCover();
    }
    final file = File("$path/cover.jpg");
    if (file.existsSync()) return;

    DownloadProgress? result;
    await for (final progress
        in ImageManager().getCustomThumbnail(cover, source.key, headers)) {
      if (progress.currentBytes == progress.expectedBytes) {
        result = progress;
      }
    }
    if (result == null) {
      throw StateError("Cover download did not complete");
    }
    final bytes = result.data ?? await result.getFile().readAsBytes();
    if (file.existsSync()) return;
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  Future<void> getOneEp(int i, Map<int, List<String>> links) async {
    if (links[i + 1] != null) return;

    int retry = 0;

    while (retry < 3) {
      try {
        links[i + 1] = (await source.loadComicPages!(
                comic.comicId, comic.chapters!.ids.elementAt(i)))
            .data;
        return;
      } catch (e) {
        await Future.delayed(const Duration(seconds: 3));
        retry++;
      }
    }

    throw Exception("Failed to get chapters");
  }

  @override
  Future<Map<int, List<String>>> getLinks() async {
    var links = <int, List<String>>{};
    if (comic.chapters != null) {
      var futures = <Future>[];
      for (var i in _downloadEps) {
        futures.add(getOneEp(i, links));
        await Future.delayed(const Duration(milliseconds: 200));
        if (futures.length % 5 == 0) {
          await Future.wait(futures);
          futures.clear();
        }
      }
      await Future.wait(futures);
    } else {
      var res = await source.loadComicPages!(comic.comicId, null);
      links[0] = res.data;
    }
    return links;
  }

  @override
  String get title => comic.title;

  @override
  Map<String, dynamic> toMap() => {
        "comic": comic.toJson(),
        "_downloadEps": _downloadEps,
        ...super.toBaseMap()
      };

  CustomDownloadingItem.fromMap(
      Map<String, dynamic> map,
      DownloadProgressCallback whenFinish,
      DownloadProgressCallback whenError,
      DownloadProgressCallbackAsync updateInfo,
      String id)
      : comic = ComicInfoData.fromJson(map["comic"]),
        _downloadEps = List<int>.from(map["_downloadEps"]),
        super.fromMap(map, whenFinish, whenError, updateInfo);

  @override
  Future<DownloadedItem> toDownloadedItem() async {
    final existing = await DownloadManager().getComicOrNull(id);
    final previous = existing?.downloadedEps ?? <int>[];
    var downloaded = (_downloadEps + previous).toSet().toList();
    downloaded.sort();
    final size = await getFolderSize(Directory(path));
    // Retain the legacy record format as well as its ID and chapter directory.
    if (existing is DownloadedComic) {
      existing.chapters = comic.chapters!.titles.toList();
      existing.downloadedChapters = downloaded;
      existing.comicSize = size;
      return existing;
    }
    if (existing is DownloadedJmComic) {
      final ids = comic.chapters!.ids.toList();
      existing.comic.series = {
        for (int i = 0; i < ids.length; i++) i + 1: ids[i],
      };
      existing.comic.epNames = comic.chapters!.titles.toList();
      existing.downloadedChapters = downloaded;
      existing.comicSize = size;
      return existing;
    }
    if (existing != null && existing is! CustomDownloadedItem) {
      existing.comicSize = size;
      return existing;
    }
    var tags = <String>[];
    comic.tags.forEach((key, value) => tags.addAll(value));
    final categories = comic.tags.entries
        .where((entry) => const {
              '分类', '分類', '类别', '類別', 'category', 'categories',
            }.contains(entry.key.trim().toLowerCase()))
        .expand((entry) => entry.value)
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .toList();
    return CustomDownloadedItem(
      size,
      downloaded,
      haveEps ? comic.chapters : null,
      id,
      comic.title,
      comic.subTitle ?? "",
      tags,
      comic.sourceKey,
      source.name,
      comic.cover,
      comic.comicId,
      comic.subId,
      categories,
    );
  }

  @override
  Future<Stream<DownloadProgress>> downloadImage(String link) async {
    return await _getImage(link);
  }

  @override
  Future<void> saveChapterComments() async {
    if (!(appdata.settings.length > 102 && appdata.settings[102] == "1"))
      return;
    if (source.chapterCommentsLoader == null || comic.chapters == null) return;
    for (var ep in _downloadEps) {
      try {
        var epId = comic.chapters!.ids.elementAt(ep);
        var chapterTitle = comic.chapters!.titles.elementAt(ep);
        var res = await source.chapterCommentsLoader!(
          comic.comicId,
          epId,
          1,
          null,
        );
        if (!res.error && res.data.isNotEmpty) {
          var allComments = res.data.toList();
          var maxP = res.subData;
          for (var p = 2; maxP != null && p <= maxP; p++) {
            var r = await source.chapterCommentsLoader!(
              comic.comicId,
              epId,
              p,
              null,
            );
            if (r.error) break;
            allComments.addAll(r.data);
          }
          await ChapterCommentsStorage.saveComments(
            sourceKey: source.key,
            comicId: comic.comicId,
            epId: epId,
            comments: allComments.map((c) => c.toJson()).toList(),
            comicName: comic.title,
            chapterTitle: chapterTitle,
          );
        }
      } catch (e) {
        continue;
      }
    }
  }
}

class CustomArchiveDownloadingItem extends CustomDownloadingItem {
  CustomArchiveDownloadingItem(
      ComicInfoData comic, this.archiveUrl,
      DownloadProgressCallback onFinish, DownloadProgressCallback onError,
      DownloadProgressCallbackAsync updateInfo, String id)
      : super(comic, [0], onFinish, onError, updateInfo, id);

  CustomArchiveDownloadingItem.fromMap(
      Map<String, dynamic> map,
      DownloadProgressCallback onFinish, DownloadProgressCallback onError,
      DownloadProgressCallbackAsync updateInfo, String id)
      : archiveUrl = map['archiveUrl'] as String,
        super.fromMap(map, onFinish, onError, updateInfo, id);

  final String archiveUrl;
  CancelToken? _cancel;
  Future<void>? _work;
  bool _stopped = false;
  int _received = 0;
  int _total = 1;
  int _speed = 0;

  @override
  bool get haveEps => false;

  @override
  int get totalPages => _total;

  @override
  int get downloadedPages => _received;

  @override
  int get currentSpeed => _speed;

  @override
  Map<String, dynamic> toMap() => {...super.toMap(), 'archiveUrl': archiveUrl};

  @override
  void start() {
    if (_stopped) return;
    _cancel?.cancel();
    final previous = _work;
    final cancel = CancelToken();
    _cancel = cancel;
    _work = _downloadArchive(cancel, previous);
  }

  Future<void> _downloadArchive(CancelToken cancel, Future<void>? previous) async {
    final dio = logDio();
    try {
      // Serialize runs so resumed downloads cannot race extraction or file writes.
      await previous;
      if (cancel.isCancelled) return;
      await onStart();
      if (cancel.isCancelled) return;
      await updateInfo?.call();
      await downloadCover();
      if (cancel.isCancelled) return;
      _received = 0;
      _total = 1;
      _speed = 0;
      final clock = Stopwatch()..start();
      var lastBytes = 0;
      final zip = File('$path/.archive.zip');
      await dio.download(archiveUrl, zip.path, cancelToken: cancel,
          onReceiveProgress: (received, total) {
        if (cancel.isCancelled) return;
        _received = received;
        _total = (total > received ? total : received) + 1;
        if (clock.elapsedMilliseconds >= 500) {
          _speed = (received - lastBytes) * 1000 ~/ clock.elapsedMilliseconds;
          lastBytes = received;
          clock.reset();
          updateInfo?.call();
        }
      });
      if (cancel.isCancelled) return;
      _speed = 0;
      await updateInfo?.call();
      final staging = Directory('$path/.archive-pages');
      await compute(extractComicArchive, [zip.path, staging.path]);
      if (cancel.isCancelled) return;
      // Remove pages from an interrupted publish before copying the new result.
      await for (final file in Directory(path).list()) {
        if (cancel.isCancelled) return;
        if (file is File &&
            RegExp(r'^\d+\.(jpg|jpeg|png|gif|webp|avif|bmp)$')
                .hasMatch(file.uri.pathSegments.last)) {
          await file.delete();
        }
      }
      await for (final file in staging.list()) {
        if (cancel.isCancelled) return;
        if (file is File) {
          await file.copy('$path/${file.uri.pathSegments.last}');
        }
      }
      if (cancel.isCancelled) return;
      await staging.delete(recursive: true);
      await zip.delete();
      if (cancel.isCancelled) return;
      _received = _total;
      if (identical(DownloadManager().downloading.firstOrNull, this)) {
        onFinish?.call();
      }
    } catch (e, s) {
      if (!cancel.isCancelled) {
        log('$e\n$s', 'Download', LogLevel.error);
        onError?.call();
      }
    } finally {
      dio.close(force: true);
    }
  }

  @override
  void pause() {
    _cancel?.cancel();
    _speed = 0;
    super.pause();
  }

  @override
  void stop() async {
    _stopped = true;
    _cancel?.cancel();
    await _work;
    if (directory != null) super.stop();
  }

  @override
  Future<void> saveChapterComments() async {}
}
