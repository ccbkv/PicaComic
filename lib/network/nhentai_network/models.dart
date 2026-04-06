import 'package:flutter/cupertino.dart';
import 'package:pica_comic/foundation/history.dart';
import 'package:pica_comic/network/base_comic.dart';

@immutable
class NhentaiComicBrief extends BaseComic{
  @override
  final String title;
  @override
  final String cover;
  @override
  final String id;
  final String lang;
  @override
  final List<String> tags;
  @override
  final int? pages;

  const NhentaiComicBrief(this.title, this.cover, this.id, this.lang, this.tags, {this.pages} );

  @override
  String get description => lang;

  @override
  String get subTitle => id;

  @override
  bool get enableTagsTranslation => true;
}

class NhentaiHomePageData{
  final List<NhentaiComicBrief> popular;
  List<NhentaiComicBrief> latest;
  int page = 1;

  NhentaiHomePageData(this.popular, this.latest);
}

class NhentaiComic with HistoryMixin{
  String id;
  @override
  String title;
  @override
  String subTitle;
  @override
  String cover;
  Map<String, List<String>> tags;
  bool favorite;
  List<String> thumbnails;
  List<NhentaiComicBrief> recommendations;
  String token;
  int pages;

  NhentaiComic(this.id, this.title, this.subTitle, this.cover, this.tags, this.favorite,
      this.thumbnails, this.recommendations, this.token, {this.pages = 0});

  Map<String, dynamic> toMap() => {
    "id": id,
    "title": title,
    "subTitle": subTitle,
    "cover": cover,
  };

  NhentaiComic.fromMap(Map<String, dynamic> map):
      id = map["id"],
      title = map["title"],
      subTitle = map["subTitle"],
      cover = map["cover"],
      tags = {},
      favorite = false,
      thumbnails = [],
      recommendations = [],
      token = "",
      pages = 0;

  @override
  HistoryType get historyType => HistoryType.nhentai;

  @override
  String get target => id;
}

class NhentaiComment{
  String userName;
  String avatar;
  String content;
  int date;

  NhentaiComment(this.userName, this.avatar, this.content, this.date);
}

// v2 API Models

class NhentaiTagV2 {
  final int id;
  final String name;
  final int count;
  final String type;
  final String url;
  final String? slug;

  NhentaiTagV2({
    required this.id,
    required this.name,
    required this.count,
    required this.type,
    required this.url,
    this.slug,
  });

  factory NhentaiTagV2.fromJson(Map<String, dynamic> json) {
    return NhentaiTagV2(
      id: json['id'],
      name: json['name'],
      count: json['count'],
      type: json['type'],
      url: json['url'],
      slug: json['slug'],
    );
  }
}

class NhentaiCoverV2 {
  final String path;
  final int width;
  final int height;

  NhentaiCoverV2({
    required this.path,
    required this.width,
    required this.height,
  });

  factory NhentaiCoverV2.fromJson(Map<String, dynamic> json) {
    return NhentaiCoverV2(
      path: json['path'],
      width: json['width'],
      height: json['height'],
    );
  }

  String get imageUrl {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    if (path.startsWith('/')) {
      return 'https://t.nhentai.net$path';
    }
    return 'https://t.nhentai.net/$path';
  }
}

class NhentaiPageInfoV2 {
  final int number;
  final String path;
  final int width;
  final int height;
  final String thumbnail;
  final int thumbnailWidth;
  final int thumbnailHeight;

  NhentaiPageInfoV2({
    required this.number,
    required this.path,
    required this.width,
    required this.height,
    required this.thumbnail,
    required this.thumbnailWidth,
    required this.thumbnailHeight,
  });

  factory NhentaiPageInfoV2.fromJson(Map<String, dynamic> json) {
    return NhentaiPageInfoV2(
      number: json['number'],
      path: json['path'],
      width: json['width'],
      height: json['height'],
      thumbnail: json['thumbnail'],
      thumbnailWidth: json['thumbnail_width'],
      thumbnailHeight: json['thumbnail_height'],
    );
  }

  String get imageUrl {
    if (path.startsWith('http')) {
      return path;
    }
    if (path.startsWith('/')) {
      return 'https://i.nhentai.net$path';
    }
    return 'https://i.nhentai.net/$path';
  }

  String get thumbnailUrl {
    if (thumbnail.startsWith('http')) {
      return thumbnail;
    }
    if (thumbnail.startsWith('/')) {
      return 'https://t.nhentai.net$thumbnail';
    }
    return 'https://t.nhentai.net/$thumbnail';
  }
}

class NhentaiTitleV2 {
  final String english;
  final String? japanese;
  final String pretty;

  NhentaiTitleV2({
    required this.english,
    this.japanese,
    required this.pretty,
  });

  factory NhentaiTitleV2.fromJson(Map<String, dynamic> json) {
    return NhentaiTitleV2(
      english: json['english'] ?? '',
      japanese: json['japanese'],
      pretty: json['pretty'] ?? '',
    );
  }
}

class NhentaiGalleryListItemV2 {
  final int id;
  final String mediaId;
  final String thumbnail;
  final int thumbnailWidth;
  final int thumbnailHeight;
  final String englishTitle;
  final String? japaneseTitle;
  final List<int> tagIds;
  final int? pages;

  NhentaiGalleryListItemV2({
    required this.id,
    required this.mediaId,
    required this.thumbnail,
    required this.thumbnailWidth,
    required this.thumbnailHeight,
    required this.englishTitle,
    this.japaneseTitle,
    required this.tagIds,
    this.pages,
  });

  factory NhentaiGalleryListItemV2.fromJson(Map<String, dynamic> json) {
    return NhentaiGalleryListItemV2(
      id: json['id'],
      mediaId: json['media_id'].toString(),
      thumbnail: json['thumbnail'],
      thumbnailWidth: json['thumbnail_width'],
      thumbnailHeight: json['thumbnail_height'],
      englishTitle: json['english_title'] ?? '',
      japaneseTitle: json['japanese_title'],
      tagIds: List<int>.from(json['tag_ids'] ?? []),
      pages: json['num_pages'],
    );
  }

  String get coverUrl {
    if (thumbnail.startsWith('http')) {
      return thumbnail;
    }
    if (thumbnail.startsWith('/')) {
      return 'https://t.nhentai.net$thumbnail';
    }
    return 'https://t.nhentai.net/$thumbnail';
  }
}

class NhentaiSearchResponseV2 {
  final List<NhentaiGalleryListItemV2> result;
  final int numPages;
  final int perPage;
  final int? total;

  NhentaiSearchResponseV2({
    required this.result,
    required this.numPages,
    required this.perPage,
    this.total,
  });

  factory NhentaiSearchResponseV2.fromJson(Map<String, dynamic> json) {
    return NhentaiSearchResponseV2(
      result: (json['result'] as List)
          .map((e) => NhentaiGalleryListItemV2.fromJson(e))
          .toList(),
      numPages: json['num_pages'],
      perPage: json['per_page'],
      total: json['total'],
    );
  }
}

class NhentaiGalleryV2 {
  final int id;
  final String mediaId;
  final NhentaiTitleV2 title;
  final NhentaiCoverV2 cover;
  final NhentaiCoverV2 thumbnail;
  final String scanlator;
  final int uploadDate;
  final List<NhentaiTagV2> tags;
  final int numPages;
  final int numFavorites;
  final List<NhentaiPageInfoV2> pages;

  NhentaiGalleryV2({
    required this.id,
    required this.mediaId,
    required this.title,
    required this.cover,
    required this.thumbnail,
    required this.scanlator,
    required this.uploadDate,
    required this.tags,
    required this.numPages,
    required this.numFavorites,
    required this.pages,
  });

  factory NhentaiGalleryV2.fromJson(Map<String, dynamic> json) {
    return NhentaiGalleryV2(
      id: json['id'],
      mediaId: json['media_id'].toString(),
      title: NhentaiTitleV2.fromJson(json['title']),
      cover: NhentaiCoverV2.fromJson(json['cover']),
      thumbnail: NhentaiCoverV2.fromJson(json['thumbnail']),
      scanlator: json['scanlator'] ?? '',
      uploadDate: json['upload_date'] ?? 0,
      tags: (json['tags'] as List)
          .map((e) => NhentaiTagV2.fromJson(e))
          .toList(),
      numPages: json['num_pages'],
      numFavorites: json['num_favorites'] ?? 0,
      pages: (json['pages'] as List)
          .map((e) => NhentaiPageInfoV2.fromJson(e))
          .toList(),
    );
  }

  String get coverUrl => cover.imageUrl;

  String get preferredTitle {
    if (title.english.isNotEmpty) {
      return title.english;
    }
    if (title.japanese != null && title.japanese!.isNotEmpty) {
      return title.japanese!;
    }
    return title.pretty;
  }

  String? get subTitle {
    if (title.japanese != null && title.japanese!.isNotEmpty && title.japanese != title.english) {
      return title.japanese;
    }
    return null;
  }
}
