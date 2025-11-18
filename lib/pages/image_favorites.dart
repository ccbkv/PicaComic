import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pica_comic/comic_source/comic_source.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/history.dart';
import 'package:pica_comic/foundation/image_loader/base_image_provider.dart';
import 'package:pica_comic/foundation/image_manager.dart';
import 'package:pica_comic/foundation/ui_mode.dart';
import 'package:pica_comic/network/eh_network/eh_models.dart';
import 'package:pica_comic/network/hitomi_network/hitomi_models.dart';
import 'package:pica_comic/tools/translations.dart';
import 'package:pica_comic/base.dart';
import 'package:pica_comic/components/components.dart';

import 'ehentai/eh_gallery_page.dart';
import 'hitomi/hitomi_comic_page.dart';
import 'htmanga/ht_comic_page.dart';
import 'image_favorites/image_favorites_comic.dart';
import 'image_favorites/type.dart';
import 'jm/jm_comic_page.dart';
import 'reader/comic_reading_page.dart';
import 'picacg/comic_page.dart';
import 'nhentai/comic_page.dart';
import 'comic_page.dart';

class ImageFavoritesPage extends StatefulWidget {
  const ImageFavoritesPage({super.key, this.initialKeyword});

  final String? initialKeyword;

  @override
  State<ImageFavoritesPage> createState() => _ImageFavoritesPageState();
}

class _ImageFavoritesPageState extends State<ImageFavoritesPage> {
  late ImageFavoriteSortType sortType;
  late TimeRange timeFilterSelect;
  late int numFilterSelect;

  // 所有的图片收藏漫画分组
  List<ImageFavoritesComic> comics = [];

  late var controller =
      TextEditingController(text: widget.initialKeyword ?? "");

  String get keyword => controller.text;

  // 进入关键词搜索模式
  bool searchMode = false;

  bool multiSelectMode = false;

  // 多选的时候选中的图片
  Map<ImageFavorite, bool> selectedImageFavorites = {};

  void update() {
    if (mounted) {
      setState(() {});
    }
  }

  void updateImageFavorites() async {
    var allFavorites = searchMode
        ? ImageFavoriteManager.search(keyword)
        : ImageFavoriteManager.getAll();
    comics = ImageFavoritesComic.fromFavorites(allFavorites);
    sortImageFavorites();
    update();
  }

  void sortImageFavorites() {
    var allFavorites = searchMode
        ? ImageFavoriteManager.search(keyword)
        : ImageFavoriteManager.getAll();
    comics = ImageFavoritesComic.fromFavorites(allFavorites);

    // 筛选到最终列表
    comics = comics.where((ele) {
      bool isFilter = true;
      if (timeFilterSelect != TimeRange.all) {
        isFilter = timeFilterSelect.contains(ele.time);
      }
      if (numFilterSelect != numFilterList[0]) {
        isFilter = ele.images.length > numFilterSelect;
      }
      return isFilter;
    }).toList();

    // 给列表排序
    switch (sortType) {
      case ImageFavoriteSortType.title:
        comics.sort((a, b) => a.title.compareTo(b.title));
        break;
      case ImageFavoriteSortType.timeAsc:
        comics.sort((a, b) => a.time.compareTo(b.time));
        break;
      case ImageFavoriteSortType.timeDesc:
        comics.sort((a, b) => b.time.compareTo(a.time));
        break;
      case ImageFavoriteSortType.maxFavorites:
        comics.sort((a, b) => b.images.length.compareTo(a.images.length));
        break;
      case ImageFavoriteSortType.favoritesCompareComicPages:
        comics.sort((a, b) {
          double tempA = a.images.length / a.maxPageFromEp;
          double tempB = b.images.length / b.maxPageFromEp;
          return tempB.compareTo(tempA);
        });
        break;
    }
  }

  @override
  void initState() {
    if (widget.initialKeyword != null) {
      searchMode = true;
    }
    sortType = ImageFavoriteSortType.values.firstWhere(
        (e) => e.value == appdata.implicitData[4]?.toString(),
        orElse: () => ImageFavoriteSortType.title);
    timeFilterSelect =
        TimeRange.fromString(appdata.implicitData[5]?.toString() ?? "");
    numFilterSelect = int.tryParse(appdata.implicitData[6]?.toString() ?? "") ??
        numFilterList[0];
    updateImageFavorites();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StateBuilder(
      tag: "image_favorites_page",
      init: SimpleController(),
      builder: (controller) {
        if (UiMode.m1(context)) {
          return Scaffold(
            appBar: AppBar(
              title: Text("图片收藏".tl),
              actions: _buildAppBarActions(),
            ),
            body: buildPage(),
          );
        } else {
          return Material(
            child: Column(
              children: [
                Appbar(
                  title: Text("图片收藏".tl),
                  actions: _buildAppBarActions(),
                ),
                Expanded(
                  child: buildPage(),
                )
              ],
            ),
          );
        }
      },
    );
  }

  List<Widget> _buildAppBarActions() {
    if (searchMode) {
      return [
        IconButton(
          icon: Icon(Icons.close),
          onPressed: () {
            setState(() {
              searchMode = false;
              controller.clear();
              updateImageFavorites();
            });
          },
        )
      ];
    } else if (multiSelectMode) {
      return [
        IconButton(
          icon: Icon(Icons.select_all),
          onPressed: selectAll,
        ),
        IconButton(
          icon: Icon(Icons.deselect),
          onPressed: deSelect,
        ),
        IconButton(
          icon: Icon(Icons.delete_outline),
          onPressed: deleteSelected,
        ),
        IconButton(
          icon: Icon(Icons.close),
          onPressed: () {
            setState(() {
              multiSelectMode = false;
              selectedImageFavorites.clear();
            });
          },
        )
      ];
    } else {
      return [
        IconButton(
          icon: Icon(Icons.search),
          onPressed: () {
            setState(() {
              searchMode = true;
            });
          },
        ),
        IconButton(
          icon: Icon(Icons.sort),
          onPressed: sort,
        ),
        IconButton(
          icon: Icon(Icons.checklist),
          onPressed: () {
            setState(() {
              multiSelectMode = true;
            });
          },
        )
      ];
    }
  }

  Widget buildPage() {
    if (searchMode) {
      return Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: "搜索图片收藏".tl,
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                updateImageFavorites();
              },
            ),
          ),
          Expanded(child: _buildComicsList()),
        ],
      );
    } else {
      return _buildComicsList();
    }
  }

  Widget _buildComicsList() {
    return ListView.builder(
      itemCount: comics.length,
      itemBuilder: (context, index) {
        return _ImageFavoritesComicTile(
          comic: comics[index],
          selectedImageFavorites: selectedImageFavorites,
          addSelected: addSelected,
          multiSelectMode: multiSelectMode,
        );
      },
    );
  }

  void selectAll() {
    for (var c in comics) {
      for (var i in c.images) {
        selectedImageFavorites[i] = true;
      }
    }
    update();
  }

  void deSelect() {
    setState(() {
      selectedImageFavorites.clear();
    });
  }

  void addSelected(ImageFavorite i) {
    if (selectedImageFavorites[i] == null) {
      selectedImageFavorites[i] = true;
    } else {
      selectedImageFavorites.remove(i);
    }
    if (selectedImageFavorites.isEmpty) {
      multiSelectMode = false;
    } else {
      multiSelectMode = true;
    }
    update();
  }

  void deleteSelected() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("确认删除".tl),
        content: Text("确定要删除选中的 ${selectedImageFavorites.length} 个图片收藏吗？".tl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("取消".tl),
          ),
          TextButton(
            onPressed: () {
              ImageFavoriteManager.deleteMultiple(selectedImageFavorites.keys);
              setState(() {
                multiSelectMode = false;
                selectedImageFavorites.clear();
                updateImageFavorites();
              });
              Navigator.pop(context);
            },
            child: Text("删除".tl),
          ),
        ],
      ),
    );
  }

  void sort() {
    // 避免与触发点击同一帧的手势冲突导致弹窗立即被遮罩关闭
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 再额外延迟一小段时间，避免 iPad 小窗下同一次点击事件被 ModalBarrier 捕获
      Future.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: true,
          useRootNavigator: false,
          builder: (context) {
            return _ImageFavoritesDialog(
              initSortType: sortType,
              initTimeFilterSelect: timeFilterSelect,
              initNumFilterSelect: numFilterSelect,
              updateConfig: (sortType, timeFilter, numFilter) {
                setState(() {
                  this.sortType = sortType;
                  timeFilterSelect = timeFilter;
                  numFilterSelect = numFilter;
                });
                sortImageFavorites();
              },
            );
          },
        );
      });
    });
  }
}

class _ImageFavoritesComicTile extends StatefulWidget {
  const _ImageFavoritesComicTile({
    required this.comic,
    required this.selectedImageFavorites,
    required this.addSelected,
    required this.multiSelectMode,
  });

  final ImageFavoritesComic comic;
  final Map<ImageFavorite, bool> selectedImageFavorites;
  final Function(ImageFavorite) addSelected;
  final bool multiSelectMode;

  @override
  State<_ImageFavoritesComicTile> createState() =>
      _ImageFavoritesComicTileState();
}

class _ImageFavoritesComicTileState extends State<_ImageFavoritesComicTile> {
  void _onLongPress() {
    // 使用第一个图片显示菜单
    var image = widget.comic.images.first;
    // 获取触摸位置
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset target = box.localToGlobal(Offset.zero, ancestor: overlay);
    final Rect rect = target & box.size;
    _showImageMenu(image, rect);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onLongPress: _onLongPress,
        onSecondaryTap: () {
          if (!widget.multiSelectMode) {
            // 获取鼠标右键点击位置
            final RenderBox overlay =
                Overlay.of(context).context.findRenderObject() as RenderBox;
            final RenderBox box = context.findRenderObject() as RenderBox;
            final Offset target =
                box.localToGlobal(Offset.zero, ancestor: overlay);
            final Rect rect = target & box.size;
            // 使用第一个图片作为菜单显示对象
            final image = widget.comic.images.first;
            _showImageMenu(image, rect);
          }
        },
        onTap: () {
          if (widget.multiSelectMode) {
            for (var ele in widget.comic.images) {
              widget.addSelected(ele);
            }
          } else {
            // 跳转到漫画详情页
            var image = widget.comic.images.first;
            var type = image.id.split("-")[0];
            _goToComicDetail(type, image.id.replaceFirst("$type-", ""),
                image.title, image.otherInfo);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 漫画标题和统计信息
            Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.comic.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        // Text(
                        //"收藏数: ${widget.comic.images.length}".tl,
                        //style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        //      color: Theme.of(context).colorScheme.onSurfaceVariant,
                        //    ),
                        // ),
                        //Text(
                        //  "收藏于: ${DateFormat('yyyy-MM-dd').format(widget.comic.time)}".tl,
                        //  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        //       color: Theme.of(context).colorScheme.onSurfaceVariant,
                        //      ),
                        //),
                        Text(
                          "来源: ${_getSourceName(widget.comic.images.first.id)}"
                              .tl,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.comic.maxPageFromEp > 0)
                    Text(
                      "${widget.comic.images.length}/${widget.comic.maxPageFromEp}",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                ],
              ),
            ),

            // 图片网格 - 使用LayoutBuilder和Wrap确保图片位置固定且间距紧凑
            LayoutBuilder(
              builder: (context, constraints) {
                // 计算每行可以放多少个图片，确保图片大小固定
                const itemWidth = 90.0; // 固定宽度
                const itemHeight = 120.0; // 固定高度
                const spacing = 2.0; // 间距

                final crossAxisCount =
                    (constraints.maxWidth / (itemWidth + spacing)).floor();
                final totalWidth =
                    crossAxisCount * itemWidth + (crossAxisCount - 1) * spacing;
                final leftMargin = (constraints.maxWidth - totalWidth) / 2;

                return Wrap(
                  alignment: WrapAlignment.start,
                  spacing: spacing,
                  runSpacing: spacing,
                  children: List.generate(widget.comic.images.length, (index) {
                    final image = widget.comic.images[index];
                    final isSelected =
                        widget.selectedImageFavorites[image] == true;

                    return SizedBox(
                      width: itemWidth,
                      height: itemHeight,
                      child: GestureDetector(
                        onTap: () {
                          if (widget.multiSelectMode) {
                            widget.addSelected(image);
                          } else {
                            var type = image.id.split("-")[0];
                            _readWithKey(
                                type,
                                image.id.replaceFirst("$type-", ""),
                                image.ep,
                                image.page,
                                image.title,
                                image.otherInfo);
                          }
                        },
                        onLongPress: () {
                          if (!widget.multiSelectMode) {
                            // 获取触摸位置
                            final RenderBox overlay = Overlay.of(context)
                                .context
                                .findRenderObject() as RenderBox;
                            final RenderBox box =
                                context.findRenderObject() as RenderBox;
                            final Offset target = box.localToGlobal(Offset.zero,
                                ancestor: overlay);
                            final Rect rect = target & box.size;
                            _showImageMenu(image, rect);
                          }
                        },
                        onSecondaryTap: () {
                          if (!widget.multiSelectMode) {
                            // 获取鼠标右键点击位置
                            final RenderBox overlay = Overlay.of(context)
                                .context
                                .findRenderObject() as RenderBox;
                            final RenderBox box =
                                context.findRenderObject() as RenderBox;
                            final Offset target = box.localToGlobal(Offset.zero,
                                ancestor: overlay);
                            final Rect rect = target & box.size;
                            _showImageMenu(image, rect);
                          }
                        },
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: itemWidth,
                                height: itemHeight,
                                color: Colors.grey[200], // 添加背景色，避免加载时闪烁
                                child: Image(
                                  image: _ImageProvider(image),
                                  fit: BoxFit.cover,
                                  width: itemWidth,
                                  height: itemHeight,
                                ),
                              ),
                            ),
                            // 页码显示
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                color: Colors.black.withOpacity(0.6),
                                child: Text(
                                  'P${image.page}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            if (isSelected)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.check_circle,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    size: 32,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                );
              },
            ),

            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _goToComicDetail(
      String type, String id, String title, Map<String, dynamic> otherInfo) {
    switch (type) {
      case "picacg":
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => PicacgComicPage(id, otherInfo["cover"])));
        break;
      case "ehentai":
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => EhGalleryPage.fromLink(id)));
        break;
      case "jm":
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (context) => JmComicPage(id)));
        break;
      case "hitomi":
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => HitomiComicPage.fromLink(id)));
        break;
      case "htmanga":
      case "htManga":
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (context) => HtComicPage(id)));
        break;
      case "nhentai":
        Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => NhentaiComicPage(id)));
        break;
      default:
        if (ComicSource.sources.any((s) => s.key == type)) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => ComicPage(
                    sourceKey: type,
                    id: id,
                    cover: otherInfo["cover"],
                  )));
        } else {
          showToast(message: "Unknown source $type");
        }
    }
  }

  void _showImageMenu(ImageFavorite image, Rect rect) {
    showDialog(
        context: App.globalContext!,
        builder: (context) => Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: SelectableText(
                        image.title.replaceAll("\n", ""),
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.chrome_reader_mode_rounded),
                      title: Text("查看漫画".tl),
                      onTap: () {
                        App.globalBack();
                        var type = image.id.split("-")[0];
                        _readWithKey(type, image.id.replaceFirst("$type-", ""),
                            image.ep, image.page, image.title, image.otherInfo);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.copy),
                      title: Text("复制标题".tl),
                      onTap: () {
                        App.globalBack();
                        Clipboard.setData(ClipboardData(text: image.title));
                        showToast(message: "标题已复制".tl);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.select_all),
                      title: Text("全选本漫画".tl),
                      onTap: () {
                        App.globalBack();
                        for (var ele in widget.comic.images) {
                          widget.addSelected(ele);
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.image),
                      title: Text("图片视图".tl),
                      onTap: () {
                        App.globalBack();
                        var type = image.id.split("-")[0];
                        _readWithKey(type, image.id.replaceFirst("$type-", ""),
                            image.ep, image.page, image.title, image.otherInfo);
                      },
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                  ],
                ),
              ),
            ));
  }

  void _readWithKey(String key, String target, int ep, int page, String title,
      Map<String, dynamic> otherInfo) async {
    switch (key) {
      case "picacg":
        App.globalTo(() => ComicReadingPage.picacg(
            target, ep, List.from(otherInfo["eps"]), title,
            initialPage: page));
      case "ehentai":
        App.globalTo(
          () => ComicReadingPage.ehentai(
            Gallery.fromJson(otherInfo["gallery"]),
            initialPage: page,
          ),
        );
      case "jm":
        App.globalTo(
          () => ComicReadingPage(
            JmReadingData(
              title,
              target,
              List.from(otherInfo["eps"]),
              List.from(
                otherInfo["jmEpNames"],
              ),
            ),
            page,
            ep,
          ),
        );
      case "hitomi":
        App.globalTo(
          () => ComicReadingPage(
            HitomiReadingData(
              title,
              target,
              (otherInfo["hitomi"] as List)
                  .map((e) => HitomiFile.fromMap(e))
                  .toList(),
              target,
            ),
            page,
            0,
          ),
        );
      case "htManga":
      case "htmanga":
        App.globalTo(
          () => ComicReadingPage.htmanga(target, title, initialPage: page),
        );
      case "nhentai":
        App.globalTo(
          () => ComicReadingPage.nhentai(target, title, initialPage: page),
        );
      default:
        var source = ComicSource.find(key);
        if (source == null) throw "Unknown source $key";
        App.globalTo(
          () => ComicReadingPage(
            CustomReadingData(
              target,
              title,
              source,
              Map.from(otherInfo["eps"]),
            ),
            page,
            ep,
          ),
        );
    }
  }

  /// 根据漫画ID获取漫画源名称
  String _getSourceName(String id) {
    if (id.isEmpty) return "未知";

    // ID格式通常是 "源类型-漫画ID"，例如 "picacg-12345"
    var parts = id.split("-");
    if (parts.isEmpty) return "未知";

    var sourceType = parts[0];
    switch (sourceType) {
      case "picacg":
        return "哔咔漫画";
      case "ehentai":
        return "E-Hentai";
      case "jm":
        return "禁漫";
      case "hitomi":
        return "Hitomi";
      case "htmanga":
      case "htManga":
        return "HTManga";
      case "nhentai":
        return "NHentai";
      default:
        // 尝试从自定义漫画源获取名称
        var source = ComicSource.find(sourceType);
        return source?.name ?? sourceType;
    }
  }
}

class FavoriteImageTile extends StatelessWidget {
  const FavoriteImageTile(this.image, {super.key});

  final ImageFavorite image;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        elevation: 1,
        child: Column(
          children: [
            // 图片区域 - 固定大小
            Container(
                width: 120, // 固定宽度
                height: 120, // 固定高度
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8)),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Image(
                      image: _ImageProvider(image),
                      fit: BoxFit.cover, // 保持图片比例
                      width: 120,
                      height: 120,
                    ),
                    // 点击区域
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onTap,
                          onLongPress: onLongTap,
                          onSecondaryTapDown: onSecondaryTap,
                          borderRadius: BorderRadius.circular(8),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    )
                  ],
                )),
            // 页码显示
            Container(
              width: 120, // 与图片宽度一致
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Text(
                '页码: ${image.page}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF424242),
                ),
              ),
            ),
            // 标题显示
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
              child: Text(
                image.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.0,
                  color: Color(0xFF616161),
                ),
              ),
            ),
            // 标题显示在页数下方
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
              child: Text(
                image.title.replaceAll("\n", ""),
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14.0,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void onTap() {
    var type = image.id.split("-")[0];
    _readWithKey(type, image.id.replaceFirst("$type-", ""), image.ep,
        image.page, image.title, image.otherInfo);
  }

  void _readWithKey(String key, String target, int ep, int page, String title,
      Map<String, dynamic> otherInfo) async {
    switch (key) {
      case "picacg":
        App.globalTo(() => ComicReadingPage.picacg(
            target, ep, List.from(otherInfo["eps"]), title,
            initialPage: page));
      case "ehentai":
        App.globalTo(
          () => ComicReadingPage.ehentai(
            Gallery.fromJson(otherInfo["gallery"]),
            initialPage: page,
          ),
        );
      case "jm":
        App.globalTo(
          () => ComicReadingPage(
            JmReadingData(
              title,
              target,
              List.from(otherInfo["eps"]),
              List.from(
                otherInfo["jmEpNames"],
              ),
            ),
            page,
            ep,
          ),
        );
      case "hitomi":
        App.globalTo(
          () => ComicReadingPage(
            HitomiReadingData(
              title,
              target,
              (otherInfo["hitomi"] as List)
                  .map((e) => HitomiFile.fromMap(e))
                  .toList(),
              target,
            ),
            page,
            0,
          ),
        );
      case "htManga":
      case "htmanga":
        App.globalTo(
          () => ComicReadingPage.htmanga(target, title, initialPage: page),
        );
      case "nhentai":
        App.globalTo(
          () => ComicReadingPage.nhentai(target, title, initialPage: page),
        );
      default:
        var source = ComicSource.find(key);
        if (source == null) throw "Unknown source $key";
        App.globalTo(
          () => ComicReadingPage(
            CustomReadingData(
              target,
              title,
              source,
              Map.from(otherInfo["eps"]),
            ),
            page,
            ep,
          ),
        );
    }
  }

  void onLongTap() {
    showConfirmDialog(App.globalContext!, "确认删除".tl, "要删除这个图片吗".tl, delete);
  }

  void delete() {
    ImageFavoriteManager.delete(image);
    showToast(message: "删除成功".tl);
    StateController.findOrNull(tag: "image_favorites_page")?.update();
  }

  void onSecondaryTap(TapDownDetails details) {
    showDesktopMenu(App.globalContext!, details.globalPosition, [
      DesktopMenuEntry(text: "查看".tl, onClick: onTap),
      DesktopMenuEntry(text: "删除".tl, onClick: delete),
    ]);
  }
}

class _ImageProvider extends BaseImageProvider<_ImageProvider> {
  _ImageProvider(this.image);

  final ImageFavorite image;

  @override
  String get key => image.id + image.ep.toString() + image.page.toString();

  @override
  Future<Uint8List> load(StreamController<ImageChunkEvent> chunkEvents) async {
    var localFile = File("${App.dataPath}/images/${image.imagePath}");
    if (localFile.existsSync()) {
      return await localFile.readAsBytes();
    } else {
      var type = image.id.split("-")[0];
      Stream<DownloadProgress> stream;
      switch (type) {
        case "ehentai":
          stream = ImageManager().getEhImageNew(
              Gallery.fromJson(image.otherInfo["gallery"]), image.page);
        case "jm":
          stream = ImageManager().getJmImage(image.otherInfo["url"], null,
              epsId: image.otherInfo["epsId"],
              scrambleId: "220980",
              bookId: image.otherInfo["bookId"]);
        case "hitomi":
          stream = ImageManager().getHitomiImage(
              HitomiFile.fromMap(image.otherInfo["hitomi"][image.page - 1]),
              image.otherInfo["galleryId"]);
        default:
          var sourceKey = type;
          var comicId = image.id.replaceFirst("$type-", "");
          var eps = image.otherInfo["eps"];
          String epId;
          if (eps is Map) {
            epId = (eps.keys.elementAtOrNull(image.ep - 1)?.toString()) ??
                comicId;
          } else if (eps is List) {
            epId = (eps.elementAtOrNull(image.ep - 1)?.toString()) ?? comicId;
          } else {
            epId = comicId;
          }
          stream = ImageManager()
              .getCustomImage(image.otherInfo["url"], comicId, epId, sourceKey);
      }
      DownloadProgress? finishProgress;
      await for (var progress in stream) {
        if (progress.currentBytes == progress.expectedBytes) {
          finishProgress = progress;
        }
        chunkEvents.add(ImageChunkEvent(
            cumulativeBytesLoaded: progress.currentBytes,
            expectedTotalBytes: progress.expectedBytes));
      }
      var file = finishProgress!.getFile();
      var data = await file.readAsBytes();
      var file2 = File("${App.dataPath}/images/${image.imagePath}");
      if (!file2.existsSync()) {
        await file2.create(recursive: true);
      }
      await file2.writeAsBytes(data);
      return data;
    }
  }

  @override
  Future<_ImageProvider> obtainKey(ImageConfiguration configuration) async {
    return this;
  }
}

class _ImageFavoritesDialog extends StatefulWidget {
  const _ImageFavoritesDialog({
    required this.initSortType,
    required this.initTimeFilterSelect,
    required this.initNumFilterSelect,
    required this.updateConfig,
  });

  final ImageFavoriteSortType initSortType;
  final TimeRange initTimeFilterSelect;
  final int initNumFilterSelect;
  final Function(ImageFavoriteSortType, TimeRange, int) updateConfig;

  @override
  State<_ImageFavoritesDialog> createState() => _ImageFavoritesDialogState();
}

class _ImageFavoritesDialogState extends State<_ImageFavoritesDialog> {
  late ImageFavoriteSortType sortType;
  late TimeRange timeFilterSelect;
  late int numFilterSelect;
  bool _allowPop = false;

  @override
  void initState() {
    sortType = widget.initSortType;
    timeFilterSelect = widget.initTimeFilterSelect;
    numFilterSelect = widget.initNumFilterSelect;
    // iPad 小窗下，打开同一帧的点击可能被遮罩捕获导致立刻关闭，先阻止短时间的 pop
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _allowPop = true);
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => _allowPop,
      child: AlertDialog(
        title: Text("排序和筛选".tl),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: DefaultTabController(
            length: 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TabBar(
                  tabs: [
                    Tab(text: "排序".tl),
                    Tab(text: "时间".tl),
                    Tab(text: "数量".tl),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // 排序方式选项卡
                      SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 16),
                            ...ImageFavoriteSortType.values.map((e) {
                              return RadioListTile<ImageFavoriteSortType>(
                                value: e,
                                groupValue: sortType,
                                title: Text(e.displayName),
                                onChanged: (value) {
                                  setState(() {
                                    sortType = value!;
                                  });
                                },
                              );
                            }).toList(),
                          ],
                        ),
                      ),

                      // 时间筛选选项卡
                      SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 16),
                            ...TimeRangeType.values.map((e) {
                              return RadioListTile<TimeRangeType>(
                                value: e,
                                groupValue: timeFilterSelect.type,
                                title: Text(e.displayName),
                                onChanged: (value) {
                                  setState(() {
                                    timeFilterSelect =
                                        TimeRange.fromType(value!);
                                  });
                                },
                              );
                            }).toList(),
                          ],
                        ),
                      ),

                      // 收藏数量筛选选项卡
                      SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 16),
                            ...numFilterList.map((e) {
                              return RadioListTile<int>(
                                value: e,
                                groupValue: numFilterSelect,
                                title: Text(
                                    e == numFilterList[0] ? "不限" : "大于$e".tl),
                                onChanged: (value) {
                                  setState(() {
                                    numFilterSelect = value!;
                                  });
                                },
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _allowPop = true);
              Navigator.pop(context);
            },
            child: Text("取消".tl),
          ),
          TextButton(
            onPressed: () {
              appdata.implicitData[4] = sortType.value.toString();
              appdata.implicitData[5] = timeFilterSelect.toString();
              appdata.implicitData[6] = numFilterSelect.toString();
              appdata.writeData();
              widget.updateConfig(sortType, timeFilterSelect, numFilterSelect);
              setState(() => _allowPop = true);
              Navigator.pop(context);
            },
            child: Text("确定".tl),
          ),
        ],
      ),
    );
  }
}
