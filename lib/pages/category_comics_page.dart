import "package:flutter/material.dart";
import "package:pica_comic/comic_source/comic_source.dart";
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/components/category_selector.dart';
import "package:pica_comic/foundation/app.dart";
import 'package:pica_comic/network/base_comic.dart';
import "package:pica_comic/network/res.dart";
import "package:pica_comic/tools/translations.dart";

class CategoryComicsPage extends StatefulWidget {
  const CategoryComicsPage({
    required this.category,
    this.param,
    required this.categoryKey,
    super.key,
  });

  final String category;

  final String? param;

  final String categoryKey;

  @override
  State<CategoryComicsPage> createState() => _CategoryComicsPageState();
}

class _CategoryComicsPageState extends State<CategoryComicsPage> {
  late final CategoryComicsData data;
  late final List<CategoryComicsOptions> options;
  late List<String> optionsValue;
  List<String> selectedCategories = [];
  bool showCategorySelector = false;

  void findData() {
    for (final source in ComicSource.sources) {
      if (source.categoryData?.key == widget.categoryKey) {
        data = source.categoryComicsData!;
        options = data.options.where((element) {
          if (element.notShowWhen.contains(widget.category)) {
            return false;
          } else if (element.showWhen != null) {
            return element.showWhen!.contains(widget.category);
          }
          return true;
        }).toList();
        optionsValue = options.map((e) => e.options.keys.first).toList();
        
        // 初始化选中的分类
        if (widget.param != null && widget.param!.contains(',')) {
          selectedCategories = widget.param!.split(',');
        } else {
          selectedCategories = [widget.category];
        }
        return;
      }
    }
    throw "${widget.categoryKey} Not found";
  }

  @override
  void initState() {
    findData();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // 获取分类列表
    final source = ComicSource.sources
        .firstWhere((e) => e.categoryData?.key == widget.categoryKey);
    final categories = _getCategories(source);
    
    return Scaffold(
      appBar: Appbar(
        title: Text(selectedCategories.length > 1 
            ? "${selectedCategories.length}个分类" 
            : selectedCategories.firstOrNull ?? widget.category),
        actions: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black),
            ),
            child: TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => CategorySelectorDialog(
                    categories: categories,
                    initialSelectedCategories: selectedCategories,
                    onCategoriesSelected: (newSelectedCategories) {
                      setState(() {
                        selectedCategories = newSelectedCategories;
                      });
                    },
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text("分类过滤"),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 显示已选分类
          if (selectedCategories.length > 1) ...[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: selectedCategories.map((category) {
                  return Chip(
                    label: Text(category),
                    onDeleted: () {
                      setState(() {
                        selectedCategories.remove(category);
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ],
          
          Expanded(
            child: _CategoryComicsList(
              key: ValueKey(
                  "${selectedCategories.join(',')} with $optionsValue"),
              loader: data.load,
              category: selectedCategories.join(','),
              options: optionsValue,
              param: widget.param, // 保留原始参数，特别是作者搜索的"a"参数
              header: buildOptions(),
              sourceKey: source.key,
            ),
          ),
        ],
      ),
    );
  }
  
  // 获取分类列表
  List<String> _getCategories(ComicSource source) {
    // 尝试从picacg源获取分类列表
    if (source.key == "picacg") {
      return const [
        "大家都在看",
        "大濕推薦",
        "那年今天",
        "官方都在看",
        "嗶咔漢化",
        "全彩",
        "長篇",
        "同人",
        "短篇",
        "圓神領域",
        "碧藍幻想",
        "CG雜圖",
        "英語 ENG",
        "生肉",
        "純愛",
        "百合花園",
        "耽美花園",
        "偽娘哲學",
        "後宮閃光",
        "扶他樂園",
        "單行本",
        "姐姐系",
        "妹妹系",
        "SM",
        "性轉換",
        "足の恋",
        "人妻",
        "NTR",
        "強暴",
        "非人類",
        "艦隊收藏",
        "Love Live",
        "SAO 刀劍神域",
        "Fate",
        "東方",
        "WEBTOON",
        "禁書目錄",
        "歐美",
        "Cosplay",
        "重口地帶"
      ];
    }
    
    // 默认返回当前分类
    return [widget.category];
  }

  Widget buildOptionItem(
      String text, String value, int group, BuildContext context) {
    return OptionChip(
      text: text,
      isSelected: value == optionsValue[group],
      onTap: () {
        if (value == optionsValue[group]) return;
        setState(() {
          optionsValue[group] = value;
        });
      },
    );
  }

  Widget buildOptions() {
    List<Widget> children = [];
    for (var optionList in options) {
      children.add(Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var option in optionList.options.entries)
            buildOptionItem(
              option.value.tl,
              option.key,
              options.indexOf(optionList),
              context,
            )
        ],
      ));
      if (options.last != optionList) {
        children.add(const SizedBox(height: 8));
      }
    }
    return SliverToBoxAdapter(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [...children, const Divider()],
      ).paddingLeft(8).paddingRight(8),
    );
  }
}

class _CategoryComicsList extends ComicsPage<BaseComic> {
  const _CategoryComicsList({
    super.key,
    required this.loader,
    required this.category,
    required this.options,
    this.param,
    required this.header,
    required this.sourceKey,
  });

  final CategoryComicsLoader loader;

  final String category;

  final List<String> options;

  final String? param;

  @override
  final String sourceKey;

  @override
  final Widget header;

  @override
  Future<Res<List<BaseComic>>> getComics(int i) async {
    return await loader(category, param, options, i);
  }

  @override
  String? get tag => "$category with $param and $options";

  @override
  String? get title => null;
}
