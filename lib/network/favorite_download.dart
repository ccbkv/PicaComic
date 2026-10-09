import 'dart:async';

import 'package:pica_comic/foundation/image_manager.dart';
import 'package:pica_comic/foundation/local_favorites.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/network/custom_download_model.dart';
import 'package:pica_comic/network/download.dart';
import 'package:pica_comic/network/download_model.dart';
import 'package:pica_comic/components/components.dart';

class FavoriteDownloading extends DownloadingItem{
  FavoriteDownloading(this.comic, super.whenFinish, super.onError,
      super.updateInfo, super.id, {super.type = DownloadType.favorite});

  FavoriteItem comic;

  DownloadingItem? downloadLogic;

  @override
  void start() async{
    if (downloadLogic != null) {
      downloadLogic!.start();
      return;
    }
    await onStart();
  }

  @override
  Future<void> onStart() async{
    try {
      downloadLogic = await _createDownloadLogic();
    }
    catch(e, s) {
      Log.error("Download", "$e$s");
      showToast(message: e.toString());
      onError?.call();
      return;
    }
    pause();
    DownloadManager().downloading.removeFirst();
    DownloadManager().downloading.addFirst(downloadLogic!);
    downloadLogic!.start();
  }

  Future<DownloadingItem> _createDownloadLogic() async {
    final source = comic.type.comicSource;
    if (source.isBuiltIn) throw "Comic Source Not Found: ${source.key}";
    if (source.loadComicInfo == null || source.loadComicPages == null) {
      throw "Comic source ${source.name} does not support downloading";
    }
    final res = await source.loadComicInfo!(comic.target);
    if (res.error) throw res.errorMessageWithoutNull;
    final eps = List.generate(res.data.chapters?.length ?? 0, (i) => i);
    return CustomDownloadingItem(res.data, eps, onFinish, onError, updateInfo,
        DownloadManager().generateId(source.key, res.data.comicId));
  }

  @override
  String get cover => comic.coverPath;

  @override
  Future<Map<int, List<String>>> getLinks() => downloadLogic!.getLinks();

  @override
  String get title => comic.name;

  @override
  Map<String, dynamic> toMap() {
    return {
      "comic": comic.toJson(),
      ...toBaseMap()
    };
  }

  FavoriteDownloading.fromMap(Map<String, dynamic> json,
      DownloadProgressCallback whenFinish,
      DownloadProgressCallback whenError,
      DownloadProgressCallbackAsync updateInfo,
      String id)
      : comic = FavoriteItem.fromJson(json["comic"]),
        super.fromMap(json, whenFinish, whenError, updateInfo);

  @override
  FutureOr<DownloadedItem> toDownloadedItem() =>
      downloadLogic!.toDownloadedItem();

  @override
  Future<Stream<DownloadProgress>> downloadImage(String link) async {
    return downloadLogic!.downloadImage(link);
  }
}
