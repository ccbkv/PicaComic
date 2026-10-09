import 'package:pica_comic/base.dart';
import 'package:pica_comic/components/components.dart' show showToast;
import 'package:pica_comic/foundation/comic_source/comic_source.dart';
import 'package:pica_comic/utils/translations.dart';
import 'package:pica_comic/network/download_model.dart';
import 'package:pica_comic/network/nhentai_network/download.dart';
import 'package:pica_comic/network/picacg_network/picacg_download_model.dart';
import 'package:pica_comic/network/jm_network/jm_download.dart';
import 'package:pica_comic/network/eh_network/eh_download_model.dart';
import 'package:pica_comic/network/custom_download_model.dart';

/// 漫画评论获取
///
/// 根据已下载漫画的类型, 调用对应漫画源的网络接口获取评论,
/// 仅返回文字内容 (userName, content, time, 可选 replyTo).
class ComicCommentsHelper {
  /// 判断已下载项是否支持获取漫画普通评论
  static bool supports(DownloadedItem item) {
    if (item is DownloadedComic) return true;
    if (item is DownloadedJmComic) return true;
    if (item is DownloadedGallery) return true;
    if (item is NhentaiDownloadedComic) return true;
    if (item is CustomDownloadedItem) {
      return ComicSource.find(item.sourceKey)?.commentsLoader != null;
    }
    return false;
  }

  /// 获取已下载项对应的漫画源 key
  static String getSourceKey(DownloadedItem item) {
    if (item is CustomDownloadedItem) return item.sourceKey;
    switch (item.type) {
      case DownloadType.picacg:
        return "picacg";
      case DownloadType.ehentai:
        return "ehentai";
      case DownloadType.jm:
        return "jm";
      case DownloadType.hitomi:
        return "hitomi";
      case DownloadType.htmanga:
        return "htmanga";
      case DownloadType.nhentai:
        return "nhentai";
      case DownloadType.other:
        return "other";
      case DownloadType.favorite:
        return "favorite";
    }
  }

  /// 获取用于评论存储的漫画 ID (不含源前缀)
  static String getComicId(DownloadedItem item) {
    if (item is DownloadedComic) return item.id;
    if (item is DownloadedJmComic) return item.comic.id;
    if (item is DownloadedGallery) return item.id;
    if (item is NhentaiDownloadedComic) return item.comicID;
    if (item is CustomDownloadedItem) return item.comicId;
    return item.id;
  }

  /// 获取已下载项的所有漫画普通评论 (仅文字), 失败返回 null
  static Future<List<Map<String, dynamic>>?> fetchForDownloadedItem(
      DownloadedItem item) async {
    try {
      final source = ComicSource.find(getSourceKey(item));
      if (source == null || source.isBuiltIn) {
        showToast(message: '请先添加对应漫画源'.tl);
        return null;
      }
      if (source.commentsLoader == null) {
        showToast(message: '漫画源不支持评论'.tl);
        return null;
      }
      final id = item is DownloadedGallery
          ? item.gallery.link
          : item is NhentaiDownloadedComic
              ? item.comicID.replaceFirst(RegExp(r'^nhentai'), '')
              : getComicId(item);
      return await _fetchCustom(
          source, id, item is CustomDownloadedItem ? item.subId : null);
    } catch (e) {
      showToast(message: e.toString());
      return null;
    }
  }

  /// 自定义源: 分页拉取全部评论
  static Future<List<Map<String, dynamic>>> _fetchCustom(
      ComicSource source, String comicId, String? subId) async {
    var allComments = <Map<String, dynamic>>[];
    var page = 1;
    int? maxPage;
    while (true) {
      if (!identical(source, ComicSource.find(source.key))) {
        throw '请先添加对应漫画源'.tl;
      }
      var res = await source.commentsLoader!(comicId, subId, page, null);
      if (res.error) throw res.errorMessageWithoutNull;
      for (final c in res.data) {
        allComments.add(<String, dynamic>{
          'userName': c.userName,
          'content': c.content,
          'time': c.time,
        });
        if ((c.replyCount ?? 0) > 0 && (c.id?.isNotEmpty ?? false)) {
          int replyPage = 1;
          int received = 0;
          while (received < c.replyCount!) {
            if (!identical(source, ComicSource.find(source.key))) {
              throw '请先添加对应漫画源'.tl;
            }
            final replies = await source.commentsLoader!(
                comicId, subId, replyPage, c.id);
            if (replies.error) throw replies.errorMessageWithoutNull;
            for (final reply in replies.data) {
              allComments.add({
                'userName': reply.userName,
                'content': reply.content,
                'time': reply.time,
                'replyTo': c.userName,
              });
            }
            received += replies.data.length;
            if (replies.data.isEmpty ||
                (replies.subData is int && replyPage >= replies.subData)) {
              break;
            }
            replyPage++;
          }
        }
      }
      maxPage ??= res.subData;
      if (res.data.isEmpty) break;
      if (maxPage != null && page >= maxPage) break;
      page++;
    }
    return allComments;
  }

  /// 获取并保存评论到本地, 仅在内容变化时写入
  /// 返回 true 表示有更新 (新保存), false 表示无变化或失败
  static Future<bool> fetchAndSave(DownloadedItem item) async {
    var comments = await fetchForDownloadedItem(item);
    // 空结果通常是网络失败, 不保存以免误清空已有评论
    if (comments == null || comments.isEmpty) return false;
    var saved = await ComicCommentsStorage.saveComments(
      sourceKey: getSourceKey(item),
      comicId: getComicId(item),
      comments: comments,
      comicName: item.name,
    );
    return saved;
  }
}
