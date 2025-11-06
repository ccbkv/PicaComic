import 'package:pica_comic/comic_source/comic_source.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:flutter/material.dart';
import 'package:pica_comic/pages/ranking_page.dart';
import 'package:pica_comic/pages/search_result_page.dart';
import 'package:pica_comic/tools/tags_translation.dart';
import 'package:pica_comic/pages/category_comics_page.dart';
import 'package:pica_comic/base.dart';
import 'package:pica_comic/tools/translations.dart';

class AllCategoryPage extends StatefulWidget {
  const AllCategoryPage({super.key});

  @override
  State<AllCategoryPage> createState() => _AllCategoryPageState();
}

class _AllCategoryPageState extends State<AllCategoryPage>
    with AutomaticKeepAliveClientMixin<AllCategoryPage> {
  
  @override
  bool get wantKeepAlive => true; // 保持页面状态
  
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    // 初始化TabController
    var categories = appdata.appSettings.categoryPages;
    var allCategories = ComicSource.sources
        .map((e) => e.categoryData?.key)
        .where((element) => element != null)
        .map((e) => e!)
        .toList();
    categories = categories.where((element) => allCategories.contains(element)).toList();
    
    _tabController = TabController(
      length: categories.length,
      vsync: Navigator.of(context),
    );
    
    // 添加监听器，在标签切换时保存状态
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        // 保存当前标签索引到PageStorage
        PageStorage.of(context).writeState(context, _tabController.index, identifier: 'category_tab_index');
      }
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // 从PageStorage恢复之前保存的标签索引
    final savedIndex = PageStorage.of(context).readState(context, identifier: 'category_tab_index') as int?;
    if (savedIndex != null && savedIndex >= 0 && savedIndex < _tabController.length) {
      _tabController.index = savedIndex;
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用，以使AutomaticKeepAliveClientMixin生效
    
    var categories = appdata.appSettings.categoryPages;
    var allCategories = ComicSource.sources
        .map((e) => e.categoryData?.key)
        .where((element) => element != null)
        .map((e) => e!)
        .toList();
    categories = categories.where((element) => allCategories.contains(element)).toList();

    // 如果分类数量发生变化，需要重新创建TabController
    if (_tabController.length != categories.length) {
      _tabController.dispose();
      _tabController = TabController(
        length: categories.length,
        vsync: Navigator.of(context),
      );
      
      // 重新添加监听器
      _tabController.addListener(() {
        if (_tabController.indexIsChanging) {
          // 保存当前标签索引到PageStorage
          PageStorage.of(context).writeState(context, _tabController.index, identifier: 'category_tab_index');
        }
      });
    }

    return Material(
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          FilledTabBar(
            tabs: categories.map((e) {
              String title = e;
              try {
                title = getCategoryDataWithKey(e).title;
              } catch (e) {
                //
              }
              return Tab(
                text: title.tl,
                key: Key(e),
              );
            }).toList(),
            controller: _tabController,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: categories.map((e) => CategoryPage(
                e,
                key: PageStorageKey(e), // 使用PageStorageKey确保状态保存
              )).toList(),
            ),
          )
        ],
      ),
    );
  }
}

typedef ClickTagCallback = void Function(String, String?);

class CategoryPage extends StatelessWidget {
  const CategoryPage(this.category, {super.key});

  final String category;

  CategoryData get data => getCategoryDataWithKey(category);

  String findComicSourceKey() {
    for (var source in ComicSource.sources) {
      if (source.categoryData?.key == category) {
        return source.key;
      }
    }
    return "";
  }

  void handleClick(
    String tag,
    String? param,
    String type,
    String namespace,
    String categoryKey,
  ) {
    if (type == 'search') {
      App.mainNavigatorKey?.currentContext?.to(
        () => SearchResultPage(
          keyword: tag,
          options: const [],
          sourceKey: findComicSourceKey(),
        ),
      );
    } else if (type == "search_with_namespace") {
      if (tag.contains(" ")) {
        tag = '"$tag"';
      }
      App.mainNavigatorKey?.currentContext?.to(
        () => SearchResultPage(
          keyword: "$namespace:$tag",
          options: const [],
          sourceKey: findComicSourceKey(),
        ),
      );
    } else if (type == "category") {
      App.mainNavigatorKey!.currentContext!.to(
        () => CategoryComicsPage(
          category: tag,
          categoryKey: categoryKey,
          param: param,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    var children = <Widget>[];
    if (data.enableRankingPage || data.buttons.isNotEmpty) {
      children.add(buildTitle(data.title));
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
        child: Wrap(
          children: [
            if (data.enableRankingPage)
              buildTag("排行榜".tl, (p0, p1) {
                context.to(() => RankingPage(sourceKey: findComicSourceKey()));
              }),
            for (var buttonData in data.buttons)
              buildTag(buttonData.label.tl, (p0, p1) => buttonData.onTap())
          ],
        ),
      ));
    }

    for (var part in data.categories) {
      if (part.enableRandom) {
        children.add(StatefulBuilder(builder: (context, updater) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildTitleWithRefresh(part.title, () => updater(() {})),
              buildTagsWithParams(
                part.categories,
                part.categoryParams,
                part.title,
                (key, param) => handleClick(
                  key,
                  param,
                  part.categoryType,
                  part.title,
                  category,
                ),
              )
            ],
          );
        }));
      } else {
        children.add(buildTitle(part.title));
        children.add(
          buildTagsWithParams(
            part.categories,
            part.categoryParams,
            part.title,
            (tag, param) => handleClick(
              tag,
              param,
              part.categoryType,
              part.title,
              data.key,
            ),
          ),
        );
      }
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget buildTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 5, 10),
      child: Text(title.tl,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
    );
  }

  Widget buildTitleWithRefresh(String title, void Function() onRefresh) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 5, 10),
      child: Row(
        children: [
          Text(
            title.tl,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh))
        ],
      ),
    );
  }

  Widget buildTagsWithParams(
    List<String> tags,
    List<String>? params,
    String? namespace,
    ClickTagCallback onClick,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
      child: Wrap(
        children: List<Widget>.generate(
          tags.length,
          (index) => buildTag(
            tags[index],
            onClick,
            namespace,
            params?.elementAtOrNull(index),
          ),
        ),
      ),
    );
  }

  Widget buildTag(String tag, ClickTagCallback onClick,
      [String? namespace, String? param]) {
    String translateTag(String tag) {
      if (enableTranslation) {
        if (namespace != null) {
          tag = TagsTranslation.translationTagWithNamespace(tag, namespace);
        } else {
          tag = tag.translateTagsToCN;
        }
      }
      return tag;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        onTap: () => onClick(tag, param),
        child: Builder(
          builder: (context) {
            return Material(
              elevation: 1,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              color: context.colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(translateTag(tag)),
              ),
            );
          },
        ),
      ),
    );
  }

  bool get enableTranslation => App.locale.languageCode == 'zh';
}
