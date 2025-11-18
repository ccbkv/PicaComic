import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/network/hitomi_network/hitomi_main_network.dart';
import 'package:pica_comic/network/hitomi_network/hitomi_models.dart';
import 'package:shimmer_animation/shimmer_animation.dart';

import '../../base.dart';
import '../../foundation/app.dart';
import '../../network/res.dart';

class SearchPageComicList extends StatefulWidget {
  const SearchPageComicList(
      {super.key, required this.keyword, required this.head});

  final String keyword;

  final Widget head;

  @override
  State<SearchPageComicList> createState() => _SearchPageComicListState();
}

class _SearchPageComicListState
    extends LoadingState<SearchPageComicList, List<HitomiComicBrief>> {
  @override
  Widget buildContent(BuildContext context, List<HitomiComicBrief> data) {
    if (data.isEmpty) {
      return SmoothCustomScrollView(
        slivers: [
          widget.head,
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off, size: 56),
                  SizedBox(height: 12),
                  Text("无匹配结果"),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return SmoothCustomScrollView(
      slivers: [
        widget.head,
        SliverGridComics(
          comics: data,
          sourceKey: "hitomi",
        ),
      ],
    );
  }

  @override
  Future<Res<List<HitomiComicBrief>>> loadData() async {
    var res = await HiNetwork().search(widget.keyword);
    if (res.error) return Res(null, errorMessage: res.errorMessage!);
    var ids = res.data;
    const int batchSize = 12;
    const int targetCount = 60; // render ~60 items initially
    const int maxPreload = 180; // cap preload to avoid long waiting
    var briefs = <HitomiComicBrief>[];
    for (var i = 0; i < ids.length && i < maxPreload; i += batchSize) {
      var end = i + batchSize > ids.length ? ids.length : i + batchSize;
      var batch = ids.sublist(i, end);
      var futures = batch.map((id) => HiNetwork().getComicInfoBrief(id.toString())).toList();
      var results = await Future.wait(futures);
      for (var r in results) {
        if (!r.error) {
          var brief = r.data;
          if (!appdata.appSettings.fullyHideBlockedWorks || isBlocked(brief) == null) {
            briefs.add(brief);
            if (briefs.length >= targetCount) break;
          }
        }
      }
      if (briefs.length >= targetCount) break;
    }
    return Res(briefs);
  }
}

class HitomiSearchPage extends StatefulWidget {
  const HitomiSearchPage(this.keyword, {Key? key}) : super(key: key);
  final String keyword;

  @override
  State<HitomiSearchPage> createState() => _HitomiSearchPageState();
}

class _HitomiSearchPageState extends State<HitomiSearchPage> {
  late String keyword;
  var controller = TextEditingController();

  @override
  void initState() {
    keyword = widget.keyword;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    controller.text = keyword;
    return SearchPageComicList(
      keyword: keyword,
      key: Key(keyword),
      head: SliverPersistentHeader(
        floating: true,
        delegate: _SliverAppBarDelegate(
          minHeight: 60,
          maxHeight: 0,
          child: FloatingSearchBar(
            onSearch: (s) {
              App.back(context);
              if (s == "") return;
              setState(() {
                keyword = s;
              });
            },
            controller: controller,
          ),
        ),
      ),
    ).paddingTop(context.padding.top);
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(
      {required this.child, required this.maxHeight, required this.minHeight});

  final double minHeight;
  final double maxHeight;
  final Widget child;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(
      child: child,
    );
  }

  @override
  double get maxExtent => minHeight;

  @override
  double get minExtent => max(maxHeight, minHeight);

  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxExtent ||
        minHeight != oldDelegate.minExtent;
  }
}

class HitomiComicTileDynamicLoading extends StatefulWidget {
  const HitomiComicTileDynamicLoading(this.id,
      {Key? key, this.addonMenuOptions})
      : super(key: key);
  final int id;

  final List<ComicTileMenuOption>? addonMenuOptions;

  @override
  State<HitomiComicTileDynamicLoading> createState() =>
      _HitomiComicTileDynamicLoadingState();
}

class _HitomiComicTileDynamicLoadingState
    extends State<HitomiComicTileDynamicLoading> {
  HitomiComicBrief? comic;
  bool onScreen = true;

  static List<HitomiComicBrief> cache = [];

  @override
  void dispose() {
    onScreen = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (var cachedComic in cache) {
      var id = RegExp(r"\d+(?=\.html)").firstMatch(cachedComic.link)![0]!;
      if (id == widget.id.toString()) {
        comic = cachedComic;
      }
    }
    if (comic == null) {
      HiNetwork().getComicInfoBrief(widget.id.toString()).then((c) {
        if (c.error) {
          showToast(message: c.errorMessage!);
          return;
        }
        cache.add(c.data);
        if (onScreen) {
          setState(() {
            comic = c.data;
          });
        }
      });

      return buildLoadingWidget();
    } else {
      return buildComicTile(context, comic!, 'hitomi');
    }
  }

  Widget buildPlaceHolder() {
    return const ComicTilePlaceholder();
  }

  Widget buildLoadingWidget() {
    return Shimmer(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: buildPlaceHolder(),
    );
  }
}
