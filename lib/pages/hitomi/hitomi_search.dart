import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/network/hitomi_network/hitomi_main_network.dart';
import 'package:pica_comic/network/hitomi_network/hitomi_models.dart';
import 'package:shimmer_animation/shimmer_animation.dart';

import '../../base.dart';
import '../../foundation/app.dart';
import 'package:pica_comic/network/res.dart';
import 'package:flutter/rendering.dart';
import 'package:pica_comic/foundation/history.dart';
import 'package:pica_comic/foundation/image_loader/cached_image.dart';
import 'package:pica_comic/foundation/local_favorites.dart';
import 'package:pica_comic/pages/comic_page.dart';
import 'package:pica_comic/pages/reader/comic_reading_page.dart';
import 'package:pica_comic/tools/tags_translation.dart';

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
        SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return _HitomiSearchComicTile(data[index]);
            },
            childCount: data.length,
          ),
          gridDelegate: const _HitomiSearchGridDelegate(),
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

class _HitomiSearchGridDelegate extends SliverGridDelegate {
  const _HitomiSearchGridDelegate();

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    var setting = appdata.settings[44].split(',');
    var scale = 1.0;
    if (setting.length > 1) {
      scale = double.parse(setting[1]);
    }
    return getDetailedModeLayout(constraints, scale);
  }

  SliverGridLayout getDetailedModeLayout(SliverConstraints constraints, double scale) {
    const maxCrossAxisExtent = 650.0;
    final width = constraints.crossAxisExtent;
    var crossAxisCount = (width / maxCrossAxisExtent).ceil();
    final itemWidth = width / crossAxisCount;
    final bool isSmall = itemWidth < 600.0;
    final itemHeight = (isSmall ? 230.0 : 200.0) * scale; 
    
    return SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: itemHeight,
      crossAxisStride: width / crossAxisCount,
      childMainAxisExtent: itemHeight,
      childCrossAxisExtent: width / crossAxisCount,
      reverseCrossAxis: false,
    );
  }

  @override
  bool shouldRelayout(covariant SliverGridDelegate oldDelegate) => true;
}

class _HitomiSearchComicTile extends ComicTile {
  final HitomiComicBrief comic;

  const _HitomiSearchComicTile(this.comic, {super.key}) : super(sourceKey: 'hitomi');

  @override
  String get description => "${comic.type}    ${comic.lang}";

  @override
  Widget get image => AnimatedImage(
        image: CachedImageProvider(
          comic.cover,
          headers: {"User-Agent": webUA, "Referer": "https://hitomi.la/"},
        ),
        fit: BoxFit.cover,
        height: double.infinity,
        width: double.infinity,
      );

  @override
  void onTap_() {
    App.mainNavigatorKey!.currentContext!.to(
      () => ComicPage(
        sourceKey: 'hitomi',
        id: comic.link,
        cover: comic.cover,
      ),
    );
  }

  @override
  String get subTitle => comic.artist;

  @override
  String get title => comic.name;

  @override
  FavoriteItem? get favoriteItem => FavoriteItem.fromHitomi(comic);

  @override
  String get comicID => comic.link;

  @override
  ActionFunc? get read => () async {
        bool cancel = false;
        var dialog = showLoadingDialog(App.globalContext!,
            onCancel: () => cancel = true);
        var res = await HiNetwork().getComicInfo(comic.link);
        if (cancel) {
          return;
        }
        dialog.close();
        if (res.error) {
          showToast(message: res.errorMessage ?? "Error");
        } else {
          var history = await History.findOrCreate(res.data);
          App.globalTo(
            () => ComicReadingPage.hitomi(
              res.data,
              comic.link,
              initialPage: history.page,
            ),
          );
        }
      };

  @override
  Widget build(BuildContext context) {
    if (!appdata.appSettings.fullyHideBlockedWorks) {
      var blockWord = isBlocked(comic);
      if (blockWord != null) {
        return Stack(
          children: [
             const Positioned.fill(child: ComicTilePlaceholder(type: '')),
             Positioned.fill(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text("屏蔽: $blockWord"),
                  ),
                ),
             ),
          ],
        );
      }
    }

    return LayoutBuilder(builder: (context, constrains) {
      final height = constrains.maxHeight - 16;
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap_,
        onLongPress: onLongTap_,
        onSecondaryTapDown: onSecondaryTap_,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 24, 8),
          child: Row(
            children: [
              Container(
                width: height * 0.68,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: image,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _HitomiSearchComicDescription(
                  title: title,
                  user: subTitle,
                  description: description,
                  tags: _generateTags(comic.tagList),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  List<String> _generateTags(List<Tag> tags) {
    var res = <String>[];
    for (var tag in tags) {
      var name = tag.name;
      if (App.locale.languageCode == "zh") {
        if (name.contains('♀')) {
          name = "${name.replaceFirst(" ♀", "").translateTagsToCN}♀";
        } else if (name.contains('♂')) {
          name = "${name.replaceFirst(" ♂", "").translateTagsToCN}♂";
        } else {
          name = name.translateTagsToCN;
        }
      }
      res.add(name);
    }
    return res;
  }
}

class _HitomiSearchComicDescription extends StatelessWidget {
  const _HitomiSearchComicDescription({
    required this.title,
    required this.user,
    required this.description,
    this.tags,
  });

  final String title;
  final String user;
  final String description;
  final List<String>? tags;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14.0,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (user != "")
          Text(
            user,
            style: const TextStyle(fontSize: 10.0),
            maxLines: 1,
          ),
        const SizedBox(height: 4),
        if (tags != null && tags!.isNotEmpty)
          Expanded(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => ClipRect(
                    child: Wrap(
                      runAlignment: WrapAlignment.start,
                      clipBehavior: Clip.hardEdge,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                            for (var s in tags!.take(10))
                              Padding(
                                padding: const EdgeInsets.fromLTRB(0, 0, 4, 3),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(3, 1, 3, 3),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondaryContainer,
                                borderRadius: const BorderRadius.all(Radius.circular(8)),
                              ),
                              child: Text(
                                _truncateTag(s),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12.0,
                ),
              ),
            ],
          ),
        ) else ...[
          const Spacer(),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12.0,
            ),
          ),
        ]
      ],
    );
  }
  
  String _truncateTag(String tag) {
    if (tag.length > 12) {
      return "${tag.substring(0, 11)}…";
    }
    return tag;
  }
}
