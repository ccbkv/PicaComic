part of comic_source;

/// Represents a target for page navigation
class PageJumpTarget {
  final String sourceKey;
  final String page;
  final Map<String, dynamic>? attributes;

  const PageJumpTarget(this.sourceKey, this.page, this.attributes);

  static PageJumpTarget parse(String sourceKey, dynamic value) {
    if (value is Map) {
      if (value['page'] != null) {
        return PageJumpTarget(
          sourceKey,
          value["page"] ?? "search",
          value["attributes"] != null ? Map<String, dynamic>.from(value["attributes"]) : null,
        );
      } else if (value["action"] != null) {
        // old version `onClickTag`
        var page = value["action"];
        if (page == "search") {
          return PageJumpTarget(
            sourceKey,
            "search",
            {"text": value["keyword"]},
          );
        } else if (page == "category") {
          return PageJumpTarget(
            sourceKey,
            "category",
            {
              "category": value["keyword"],
              "param": value["param"],
            },
          );
        } else {
          return PageJumpTarget(sourceKey, page, null);
        }
      }
    } else if (value is String) {
      // old version string encoding
      var segments = value.split(":");
      var page = segments[0];
      if (page == "search") {
        return PageJumpTarget(
          sourceKey,
          "search",
          {"text": segments.length > 1 ? segments[1] : ""},
        );
      } else if (page == "category") {
        var c = segments.length > 1 ? segments[1] : "";
        if (c.contains('@')) {
          var parts = c.split('@');
          return PageJumpTarget(
            sourceKey,
            "category",
            {
              "category": parts[0],
              "param": parts.length > 1 ? parts[1] : null,
            },
          );
        } else {
          return PageJumpTarget(
            sourceKey,
            "category",
            {"category": c},
          );
        }
      } else {
        return PageJumpTarget(sourceKey, page, null);
      }
    }
    return PageJumpTarget(sourceKey, "Invalid Data", null);
  }
}

/// Category item with label and navigation target
class CategoryItem {
  final String label;
  final PageJumpTarget? target;

  const CategoryItem(this.label, this.target);
}

class CategoryData {
  /// The title is displayed in the tab bar.
  final String title;

  /// 当使用中文语言时, 英文的分类标签将在构建页面时被翻译为中文
  final List<BaseCategoryPart> categories;

  final bool enableRankingPage;

  final String key;

  final List<CategoryButtonData> buttons;

  /// Data class for building category page.
  const CategoryData({
    required this.title,
    required this.categories,
    required this.enableRankingPage,
    required this.key,
    this.buttons = const [],
  });
}

class CategoryButtonData {
  final String label;

  final void Function() onTap;

  const CategoryButtonData({
    required this.label,
    required this.onTap,
  });
}

abstract class BaseCategoryPart {
  String get title;

  List<String> get categories;

  /// Category items with labels and targets (venera format)
  List<CategoryItem>? get categoryItems;

  List<String>? get categoryParams => null;

  bool get enableRandom;

  String get categoryType;

  /// Data class for building a part of category page.
  const BaseCategoryPart();
}

class FixedCategoryPart extends BaseCategoryPart {
  @override
  final List<String> categories;

  @override
  final List<CategoryItem>? categoryItems;

  @override
  bool get enableRandom => false;

  @override
  final String title;

  @override
  final String categoryType;

  @override
  final List<String>? categoryParams;

  /// A [BaseCategoryPart] that show fixed tags on category page.
  const FixedCategoryPart(this.title, this.categories, this.categoryType,
      [this.categoryParams])
      : categoryItems = null;

  /// Create from category items (venera format)
  FixedCategoryPart.fromItems(this.title, this.categoryItems, this.categoryType,
      [this.categoryParams])
      : categories = categoryItems?.map((e) => e.label).toList() ?? [];
}

class RandomCategoryPart extends BaseCategoryPart {
  final List<String> tags;

  final int randomNumber;

  @override
  final String title;

  @override
  bool get enableRandom => true;

  @override
  final String categoryType;

  @override
  List<CategoryItem>? get categoryItems => null;

  List<String> _categories() {
    if (randomNumber >= tags.length) {
      return tags;
    }
    return tags.sublist(math.Random().nextInt(tags.length - randomNumber));
  }

  @override
  List<String> get categories => _categories();

  /// A [BaseCategoryPart] that show random tags on category page.
  const RandomCategoryPart(
      this.title, this.tags, this.randomNumber, this.categoryType);
}

typedef CategoryParamBuilder = String Function(String tag);

class RandomCategoryPartWithRuntimeData extends BaseCategoryPart {
  final Iterable<String> Function() loadTags;

  final int randomNumber;

  final CategoryParamBuilder? buildParam;

  @override
  final String title;

  @override
  bool get enableRandom => true;

  @override
  final String categoryType;

  @override
  List<CategoryItem>? get categoryItems => null;

  static final random = math.Random();

  List<String> _lastCategories = const [];

  List<String> _categories() {
    var tags = loadTags().toList();
    if (randomNumber >= tags.length) {
      return tags;
    }
    final start = random.nextInt(tags.length - randomNumber);
    return tags.sublist(start, start + randomNumber);
  }

  @override
  List<String> get categories {
    _lastCategories = _categories();
    return _lastCategories;
  }

  @override
  List<String>? get categoryParams {
    if (buildParam == null) {
      return null;
    }
    final tags = _lastCategories.isEmpty ? categories : _lastCategories;
    return tags.map(buildParam!).toList();
  }

  /// A [BaseCategoryPart] that show random tags on category page.
  RandomCategoryPartWithRuntimeData(this.title, this.loadTags,
      this.randomNumber, this.categoryType,
      {this.buildParam});
}

CategoryData getCategoryDataWithKey(String key) {
  for (var source in ComicSource.sources) {
    if (source.categoryData?.key == key) {
      return source.categoryData!;
    }
  }
  throw "Unknown category key $key";
}
