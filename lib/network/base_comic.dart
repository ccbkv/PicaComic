abstract class BaseComic {
  String get title;

  String get subTitle;

  String get cover;

  String get id;

  List<String> get tags;

  String get description;

  bool get enableTagsTranslation => false;

  const BaseComic();
}

class CustomComic extends BaseComic {
  @override
  final String title;

  @override
  final String subTitle;

  @override
  final String cover;

  @override
  final String id;

  @override
  final List<String> tags;

  @override
  final String description;

  final String sourceKey;

  final int? pages;
  final String? language;

  const CustomComic(
    this.title,
    this.subTitle,
    this.cover,
    this.id,
    this.tags,
    this.description,
    this.sourceKey, {
    this.pages,
    this.language,
  });

  CustomComic.fromJson(Map json, this.sourceKey)
      : title = json["title"],
        subTitle = json["subTitle"] ?? "",
        cover = json["cover"],
        id = json["id"],
        tags = List<String>.from(json["tags"] ?? []),
        description = json["description"] ?? "",
        language = sourceKey == 'ehentai' ? json["language"] as String? : null,
        pages = switch (json["pages"] ?? json["maxPage"]) {
          num value when value.isFinite => value.toInt(),
          String value => int.tryParse(value),
          _ => null,
        };
}
