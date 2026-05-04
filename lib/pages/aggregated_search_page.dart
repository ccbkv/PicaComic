import "package:flutter/material.dart";
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/comic_source/comic_source.dart';
import 'package:pica_comic/network/base_comic.dart';
import 'package:pica_comic/network/res.dart';
import 'package:pica_comic/pages/comic_page.dart';
import 'package:pica_comic/pages/search_result_page.dart';
import 'package:pica_comic/utils/extensions.dart';
import 'package:pica_comic/utils/translations.dart';

class AggregatedSearchPage extends StatefulWidget {
  const AggregatedSearchPage({
    super.key,
    required this.keyword,
    this.displayMode = 1,
  });

  final String keyword;

  /// 1: separate display (分开展示), 2: merged display (合并展示)
  final int displayMode;

  @override
  State<AggregatedSearchPage> createState() => _AggregatedSearchPageState();
}

class _AggregatedSearchPageState extends State<AggregatedSearchPage> {
  late final List<ComicSource> sources;

  late final TextEditingController searchController;

  var _keyword = "";

  @override
  void initState() {
    var all = ComicSource.sources
        .where((e) => e.searchPageData != null)
        .map((e) => e.key)
        .toList();
    sources = all.map((e) => ComicSource.find(e)!).toList();
    _keyword = widget.keyword;
    searchController = TextEditingController(text: widget.keyword);
    super.initState();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void onSearch(String text) {
    setState(() {
      _keyword = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.displayMode == 2) {
      return Scaffold(
        appBar: AppBar(
          title: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: "搜索".tl,
              border: InputBorder.none,
            ),
            onSubmitted: onSearch,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => onSearch(searchController.text),
            ),
          ],
        ),
        body: _MergedSearchComicList(
          key: ValueKey(_keyword),
          keyword: _keyword,
          header: const SliverToBoxAdapter(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: "搜索".tl,
            border: InputBorder.none,
          ),
          onSubmitted: onSearch,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => onSearch(searchController.text),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverList(
            key: ValueKey(_keyword),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final source = sources[index];
                return _SearchResultItem(
                  key: ValueKey(source.key + _keyword),
                  source: source,
                  keyword: _keyword,
                );
              },
              childCount: sources.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _MergedSearchComicList extends ComicsPage<BaseComic> {
  const _MergedSearchComicList({
    super.key,
    required this.keyword,
    required this.header,
  });

  final String keyword;

  @override
  final Widget header;

  @override
  String get sourceKey => "__aggregated__";

  @override
  String? get title => null;

  @override
  String? get tag => "aggregated_merged_$keyword";

  @override
  Future<Res<List<BaseComic>>> getComics(int i) async {
    final sources = ComicSource.sources
        .where((e) =>
            e.searchPageData != null && e.searchPageData!.loadPage != null)
        .toList();

    final merged = <BaseComic>[];
    final ids = <String>{};
    String? firstSubData;

    for (final source in sources) {
      final options = (source.searchPageData!.searchOptions ?? [])
          .map((e) => e.defaultValue)
          .toList();
      final res = await source.searchPageData!.loadPage!(keyword, i, options);
      if (res.error) continue;
      firstSubData ??= res.subData;
      for (final comic in res.data) {
        if (ids.add(comic.id)) {
          merged.add(comic);
        }
      }
    }

    return Res<List<BaseComic>>(merged, subData: firstSubData);
  }
}

class _SearchResultItem extends StatefulWidget {
  const _SearchResultItem({
    required this.source,
    required this.keyword,
    super.key,
  });

  final ComicSource source;

  final String keyword;

  @override
  State<_SearchResultItem> createState() => _SearchResultItemState();
}

class _SearchResultItemState extends State<_SearchResultItem>
    with AutomaticKeepAliveClientMixin {
  bool isLoading = true;

  static const _kComicHeight = 200.0;

  get _comicWidth => _kComicHeight * 0.7;

  static const _kLeftPadding = 16.0;

  List<BaseComic>? comics;

  String? error;

  void load() async {
    final data = widget.source.searchPageData!;
    var options =
        (data.searchOptions ?? []).map((e) => e.defaultValue).toList();
    if (data.loadPage != null) {
      var res = await data.loadPage!(widget.keyword, 1, options);
      if (!res.error) {
        setState(() {
          comics = res.data;
          isLoading = false;
        });
      } else {
        setState(() {
          error = res.errorMessage ?? "Unknown error".tl;
          isLoading = false;
        });
      }
    } else {
      setState(() {
        error = "Search not supported".tl;
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(_SearchResultItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keyword != widget.keyword) {
      setState(() {
        isLoading = true;
        comics = null;
        error = null;
      });
      load();
    }
  }

  Widget buildPlaceHolder() {
    return Container(
      height: _kComicHeight,
      width: _comicWidth,
      margin: const EdgeInsets.only(left: _kLeftPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget buildComic(BaseComic c) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          App.mainNavigatorKey!.currentContext!.to(
            () => ComicPage(
              sourceKey: widget.source.key,
              id: c.id,
              cover: c.cover,
            ),
          );
        },
        child: SizedBox(
          width: _comicWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: IgnorePointer(
                  child: buildComicTile(
                    context,
                    c,
                    widget.source.key,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  c.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    ).paddingLeft(_kLeftPadding).paddingBottom(2);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          App.mainNavigatorKey!.currentContext!.to(
            () => SearchResultPage(
              keyword: widget.keyword,
              sourceKey: widget.source.key,
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(widget.source.name.tl),
            ),
            if (isLoading)
            SizedBox(
              height: _kComicHeight,
              width: double.infinity,
              child: Shimmer(
                child: LayoutBuilder(builder: (context, constrains) {
                  var itemWidth = _comicWidth + _kLeftPadding;
                  var items = (constrains.maxWidth / itemWidth).ceil();
                  return Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Row(
                          children: List.generate(
                            items,
                            (index) => buildPlaceHolder(),
                          ),
                        ),
                      )
                    ],
                  );
                }),
              ),
            )
          else if (error != null || comics == null || comics!.isEmpty)
            SizedBox(
              height: _kComicHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error ?? "No search results found".tl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: _kComicHeight,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var c in comics!) buildComic(c),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
