import 'dart:async';
import 'dart:typed_data';

import 'package:pica_comic/foundation/image_manager.dart';
import 'package:pica_comic/foundation/local_favorites.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/network/custom_download_model.dart';
import 'package:pica_comic/network/download.dart';
import 'package:pica_comic/network/download_model.dart';
import 'package:pica_comic/network/eh_network/eh_download_model.dart';
import 'package:pica_comic/network/eh_network/eh_main_network.dart';
import 'package:pica_comic/network/hitomi_network/hitomi_download_model.dart';
import 'package:pica_comic/network/hitomi_network/hitomi_main_network.dart';
import 'package:pica_comic/network/htmanga_network/ht_download_model.dart';
import 'package:pica_comic/network/htmanga_network/htmanga_main_network.dart';
import 'package:pica_comic/network/jm_network/jm_download.dart';
import 'package:pica_comic/network/jm_network/jm_network.dart';
import 'package:pica_comic/network/nhentai_network/download.dart';
import 'package:pica_comic/network/nhentai_network/nhentai_main_network.dart';
import 'package:pica_comic/network/picacg_network/methods.dart';
import 'package:pica_comic/network/picacg_network/picacg_download_model.dart';

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
      onError?.call();
      return;
    }
    pause();
    DownloadManager().downloading.removeFirst();
    DownloadManager().downloading.addFirst(downloadLogic!);
    downloadLogic!.start();
  }

  Future<DownloadingItem> _createDownloadLogic() async {
    switch(comic.type.comicSource.key){
      case "picacg":
        var comicItem = await PicacgNetwork().getComicInfo(comic.target);
        return PicDownloadingItem(
            comicItem.data, List.generate(comicItem.data.eps.length,
                (index) => index), onFinish, onError, updateInfo, id);
      case "ehentai":
        var gallery = await EhNetwork().getGalleryInfo(comic.target);
        return EhDownloadingItem(gallery.data,
            onFinish, onError, updateInfo, id, 0);
      case "jm":
        var jmComic = await JmNetwork().getComicInfo(comic.target);
        var downloadedEp = List.generate(jmComic.data.epNames.length, (index) => index);
        if(downloadedEp.isEmpty) {
          downloadedEp.add(0);
        }
        return JmDownloadingItem(jmComic.data, downloadedEp,
            onFinish, onError, updateInfo, id);
      case "hitomi":
        var hitomiComic = await HiNetwork().getComicInfo(comic.target);
        return HitomiDownloadingItem(hitomiComic.data,
            comic.coverPath, comic.target, onFinish, onError, updateInfo, id);
      case "htmanga":
        var htComic = await HtmangaNetwork().getComicInfo(comic.target);
        return DownloadingHtComic(htComic.data, onFinish, onError, updateInfo, id);
      case "nhentai":
        var nhComic = await NhentaiNetwork().getComicInfo(comic.target);
        return NhentaiDownloadingItem(nhComic.data, onFinish, onError, updateInfo, id);
      default:
        var comicSource = comic.type.comicSource;
        if (comicSource.loadComicInfo == null) {
          throw Exception(
              "Comic source ${comicSource.name} does not support loading comic info");
        }
        var comicInfoData = await comicSource.loadComicInfo!(comic.target);
        var downloadedCustomEp = List.generate(
            comicInfoData.data.chapters?.length ?? 0, (index) => index);
        return CustomDownloadingItem(comicInfoData.data, downloadedCustomEp,
            onFinish, onError, updateInfo, id);
    }
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
