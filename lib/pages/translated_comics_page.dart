import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/comic_source/comic_source.dart';
import 'package:pica_comic/foundation/history.dart';
import 'package:pica_comic/foundation/image_translation/pre_translation_tasks.dart';
import 'package:pica_comic/foundation/image_translation/translation_service.dart';
import 'package:pica_comic/foundation/image_translation/translation_store.dart';
import 'package:pica_comic/foundation/local_favorites.dart';
import 'package:pica_comic/network/base_comic.dart';
import 'package:pica_comic/pages/comic_page.dart';
import 'package:pica_comic/utils/translations.dart';

class _TranslationComicEntry {
  const _TranslationComicEntry({
    required this.sourceKey,
    required this.comicId,
    required this.title,
    required this.cover,
    this.tags = const <String>[],
    this.categories = const <String>[],
    this.translated,
  });

  final String sourceKey;
  final String comicId;
  final String title;
  final String cover;
  final List<String> tags;
  final List<String> categories;
  final StoredTranslationComic? translated;
}

final _metadataHydrationInFlight = <String>{};
final _tagMetadataCache =
    <String, ({List<String> tags, List<String> categories})>{};

List<String> translatedComicTagsFor(String sourceKey, String comicId) {
  var key = '$sourceKey\u0000$comicId';
  return List<String>.from(_tagMetadataCache[key]?.tags ?? const <String>[]);
}

List<String> translatedComicCategoriesFor(String sourceKey, String comicId) {
  var key = '$sourceKey\u0000$comicId';
  return List<String>.from(
    _tagMetadataCache[key]?.categories ?? const <String>[],
  );
}

/// Resolves missing titles, covers, chapter names and card tags. The result is
/// shared by the home card, the library page and the chapter picker.
Future<void> hydrateTranslatedComicMetadata() async {
  var pending = <String, (String, String)>{};
  for (var item in ImageTranslationService.translatedComics) {
    pending['${item.sourceKey}\u0000${item.comicId}'] = (
      item.sourceKey,
      item.comicId,
    );
  }
  for (var rawKey in ImageTranslationService.enabledComicKeys) {
    var separator = rawKey.lastIndexOf('@');
    if (separator <= 0 || separator == rawKey.length - 1) continue;
    var comicId = rawKey.substring(0, separator);
    var sourceKey = rawKey.substring(separator + 1);
    pending['$sourceKey\u0000$comicId'] = (sourceKey, comicId);
  }

  for (var entry in pending.entries) {
    var key = entry.key;
    if (_tagMetadataCache.containsKey(key) ||
        !_metadataHydrationInFlight.add(key)) {
      continue;
    }
    var sourceKey = entry.value.$1;
    var comicId = entry.value.$2;
    try {
      var source = ComicSource.find(sourceKey);
      if (source?.loadComicInfo == null) {
        _metadataHydrationInFlight.remove(key);
        continue;
      }
      var res = await source!.loadComicInfo!(comicId);
      if (res.error) {
        _metadataHydrationInFlight.remove(key);
        continue;
      }
      var details = res.data;
      var tags = <String>[];
      var categories = <String>[];
      for (var group in details.tags.entries) {
        var isCategory = const {
          'category',
          'categories',
          '分类',
          '分類',
        }.contains(group.key.toLowerCase());
        for (var value in group.value) {
          if (value.trim().isEmpty) continue;
          if (isCategory) {
            categories.add(value);
          } else {
            tags.add(group.key.isEmpty ? value : '${group.key}:$value');
          }
        }
      }
      _tagMetadataCache[key] = (tags: tags, categories: categories);
      TranslationStore().updateComicMetadata(
        sourceKey,
        comicId,
        comicTitle: details.title,
        comicCover: details.cover,
        chapterTitles: details.chapters?.allChapters ?? {},
      );
    } catch (e, s) {
      _metadataHydrationInFlight.remove(key);
      debugPrint('Failed to hydrate translated comic metadata: $e\n$s');
    }
  }
}

class TranslationComicTile extends CustomComicTile {
  const TranslationComicTile(
    super.comic, {
    super.key,
    super.badge_,
    required this.onOpen,
    this.onDelete,
    this.categoryTags = const <String>[],
  });

  final VoidCallback onOpen;
  final VoidCallback? onDelete;
  final List<String> categoryTags;

  void _openDetails() {
    App.globalContext!.to(
      () => ComicPage(
        id: comic.id,
        sourceKey: comic.sourceKey,
        cover: comic.cover,
      ),
    );
  }

  List<MenuEntry> _menuEntries(BuildContext context) {
    return [
      MenuEntry(
        icon: Icons.info_outline_rounded,
        text: '打开漫画详情'.tl,
        onClick: _openDetails,
      ),
      if (onDelete != null)
        MenuEntry(
          icon: Icons.delete_outline_rounded,
          text: '删除本漫画翻译'.tl,
          color: context.colorScheme.error,
          onClick: onDelete!,
        ),
    ];
  }

  @override
  void onTap_() => onOpen();

  @override
  void onLongTap_() {
    final renderBox = App.globalContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;
    showMenuX(
      App.globalContext!,
      Offset((size.width - 242) / 2, size.height / 2),
      _menuEntries(App.globalContext!),
      title: NonScrollableSelectableText(
        title.replaceAll('\n', ''),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  void onSecondaryTap_(TapDownDetails details) {
    showDesktopMenu(
      App.globalContext!,
      Offset(details.globalPosition.dx, details.globalPosition.dy),
      [
        DesktopMenuEntry(
          text: '打开漫画详情'.tl,
          onClick: _openDetails,
        ),
        if (onDelete != null)
          DesktopMenuEntry(
            text: '删除本漫画翻译'.tl,
            onClick: onDelete!,
          ),
      ],
    );
  }

  @override
  FavoriteItem? get favoriteItem => null;

  @override
  void Function()? get read => null;

  @override
  bool get showFavorite => false;

  @override
  List<String>? get categories => List<String>.from(categoryTags);
}

class TranslatedComicsPage extends StatefulWidget {
  const TranslatedComicsPage({super.key});

  @override
  State<TranslatedComicsPage> createState() => _TranslatedComicsPageState();
}

class _TranslatedComicsPageState extends State<TranslatedComicsPage>
    with SingleTickerProviderStateMixin {
  var keyword = '';
  final searchController = TextEditingController();
  late final TabController _tabController;

  bool get _showTranslated => _tabController.index == 0;

  @override
  void initState() {
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_onTabChanged);
    TranslationStore().addListener(_reload);
    ImageTranslationService.instance.addListener(_reload);
    unawaited(_hydrateMetadata());
    super.initState();
  }

  @override
  void dispose() {
    TranslationStore().removeListener(_reload);
    ImageTranslationService.instance.removeListener(_reload);
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    searchController.dispose();
    super.dispose();
  }

  void _reload() {
    if (mounted) setState(() {});
  }

  void _onTabChanged() {
    if (mounted && !_tabController.indexIsChanging) setState(() {});
  }

  Future<void> _hydrateMetadata() async {
    await hydrateTranslatedComicMetadata();
    if (mounted) setState(() {});
  }

  String _key(String sourceKey, String comicId) => '$sourceKey\u0000$comicId';

  Map<String, ({String title, String cover})> _knownMetadata() {
    var result = <String, ({String title, String cover})>{};
    void add(String sourceKey, String comicId, String title, String cover) {
      var key = _key(sourceKey, comicId);
      var old = result[key];
      result[key] = (
        title: title.isNotEmpty ? title : old?.title ?? '',
        cover: cover.isNotEmpty ? cover : old?.cover ?? '',
      );
    }

    for (var history in HistoryManager().getAll()) {
      var sourceKey = history.type.comicSource?.key;
      if (sourceKey != null) {
        add(sourceKey, history.target, history.title, history.cover);
      }
    }
    return result;
  }

  List<_TranslationComicEntry> get _allItems {
    var stored = ImageTranslationService.translatedComics;
    var byKey = <String, _TranslationComicEntry>{};
    var metadata = _knownMetadata();
    for (var item in stored) {
      var key = _key(item.sourceKey, item.comicId);
      var known = metadata[key];
      var tagMetadata = _tagMetadataCache[key];
      byKey[key] = _TranslationComicEntry(
        sourceKey: item.sourceKey,
        comicId: item.comicId,
        title: item.title.isNotEmpty ? item.title : known?.title ?? '',
        cover: item.cover.isNotEmpty ? item.cover : known?.cover ?? '',
        tags: tagMetadata?.tags ?? const <String>[],
        categories: tagMetadata?.categories ?? const <String>[],
        translated: item,
      );
    }
    for (var rawKey in ImageTranslationService.enabledComicKeys) {
      var separator = rawKey.lastIndexOf('@');
      if (separator <= 0 || separator == rawKey.length - 1) continue;
      var comicId = rawKey.substring(0, separator);
      var sourceKey = rawKey.substring(separator + 1);
      var key = _key(sourceKey, comicId);
      if (byKey.containsKey(key)) continue;
      var known = metadata[key];
      var tagMetadata = _tagMetadataCache[key];
      byKey[key] = _TranslationComicEntry(
        sourceKey: sourceKey,
        comicId: comicId,
        title: known?.title ?? '',
        cover: known?.cover ?? '',
        tags: tagMetadata?.tags ?? const <String>[],
        categories: tagMetadata?.categories ?? const <String>[],
      );
    }
    var query = keyword.trim().toLowerCase();
    return byKey.values.where((item) {
      if ((item.translated != null) != _showTranslated) return false;
      if (query.isEmpty) return true;
      var source = ComicSource.find(item.sourceKey)?.name ?? item.sourceKey;
      return item.title.toLowerCase().contains(query) ||
          item.comicId.toLowerCase().contains(query) ||
          source.toLowerCase().contains(query);
    }).toList()
      ..sort((a, b) {
        var aTime =
            a.translated?.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        var bTime =
            b.translated?.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
  }

  CustomComic _asComic(_TranslationComicEntry item) {
    var title = item.title.isEmpty ? item.comicId : item.title;
    return CustomComic(
      title,
      '',
      item.cover,
      item.comicId,
      List<String>.from(item.tags),
      '',
      item.sourceKey,
    );
  }

  void _delete(StoredTranslationComic comic) {
    showConfirmDialog(
      context: context,
      title: '删除本漫画的全部翻译？'.tl,
      content:
          '将删除本漫画所有已存的翻译和嵌字页面，原图不受影响。'
              .tl,
      btnColor: context.colorScheme.error,
      onConfirm: () async {
        var running = PreTranslationTaskManager.instance.runningTaskFor(
          comic.comicId,
          comic.sourceKey,
        );
        if (running != null) {
          PreTranslationTaskManager.instance.cancel(running.id);
        }
        await ImageTranslationService.instance.retranslate(
          comic.comicId,
          comic.sourceKey,
        );
        PreTranslationTaskManager.instance.resetComicStatus(
          comic.comicId,
          comic.sourceKey,
        );
        if (mounted) {
          setState(() {});
          App.globalContext!.showMessage(
            message: '翻译结果已清除'.tl,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var items = _allItems;
    return Scaffold(
      body: SmoothCustomScrollView(
        slivers: [
          SliverAppbar(title: Text('翻译库'.tl)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: searchController,
                onChanged: (value) => setState(() => keyword = value),
                decoration: InputDecoration(
                  hintText: '搜索'.tl,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Material(
              child: AppTabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: '已翻译'.tl),
                  Tab(text: '未翻译'.tl),
                ],
              ),
            ),
          ),
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  ImageTranslationService.translatedComics.isEmpty &&
                          ImageTranslationService.enabledComicKeys.isEmpty
                      ? '暂无翻译记录'.tl
                      : '没有匹配的内容'.tl,
                  style: ts.s16,
                ),
              ),
            )
          else
            SliverGrid(
              gridDelegate: SliverGridDelegateWithComics(),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  var item = items[index];
                  var translated = item.translated;
                  return TranslationComicTile(
                    _asComic(item),
                    badge_: translated == null
                        ? '未翻译'.tl
                        : '@count 章'.tlParams({
                            'count': translated.chapterCount.toString(),
                          }),
                    onOpen: () {
                      if (translated != null) {
                        openTranslatedChaptersPage(context, translated);
                      } else {
                        context.to(
                          () => ComicPage(
                            id: item.comicId,
                            sourceKey: item.sourceKey,
                            cover: item.cover,
                          ),
                        );
                      }
                    },
                    onDelete:
                        translated == null ? null : () => _delete(translated),
                    categoryTags: item.categories,
                  );
                },
                childCount: items.length,
              ),
            ),
        ],
      ),
    );
  }
}
