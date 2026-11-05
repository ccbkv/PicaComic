import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

import 'package:pica_comic/network/eh_network/eh_main_network.dart';
import 'package:pica_comic/network/jm_network/jm_image.dart';
import 'package:pica_comic/network/picacg_network/models.dart';
import 'package:pica_comic/foundation/image_loader/cached_image.dart';
import 'package:pica_comic/pages/comic_page.dart';
import 'package:pica_comic/pages/local_add_comic.dart';
import 'package:pica_comic/utils/time.dart';
import 'package:pica_comic/foundation/history.dart';
import '../base.dart';
import '../foundation/app.dart';
import 'package:pica_comic/utils/translations.dart';
import 'package:pica_comic/components/components.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final comics = HistoryManager().getAll();
  bool searchInit = false;
  bool searchMode = false;
  String keyword = "";
  var results = <History>[];
  bool isModified = false;
  final controller = FlyoutController();
  final _scrollController = ScrollController();
  static const _pageSize = 20;
  int _currentPage = 1;

  ModalRoute? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      _route?.animation?.removeStatusListener(_handleStatusChange);
      _route = route;
      _route?.animation?.addStatusListener(_handleStatusChange);
    }
  }

  void _handleStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.reverse) {
      if (App.isFluent) {
        App.mainAppbarActions.value = null;
      }
    }
  }

  @override
  void dispose() {
    _route?.animation?.removeStatusListener(_handleStatusChange);
    if (App.isFluent) {
      App.mainAppbarActions.value = null;
    }
    if (isModified) {
      appdata.history.saveData();
    }
    _scrollController.dispose();
    super.dispose();
  }

  Widget? buildTitle() {
    if (searchMode) {
      if(App.isFluent) {
        return fluent.TextBox(
          autofocus: true,
          placeholder: "搜索".tl,
          onChanged: (s) {
            setState(() {
              keyword = s.toLowerCase();
            });
          },
        );
      }
      final FocusNode focusNode = FocusNode();
      focusNode.requestFocus();
      bool focus = searchInit;
      searchInit = false;
      final searchField = TextField(
        focusNode: focus ? focusNode : null,
        decoration:
        InputDecoration(border: InputBorder.none, hintText: "搜索".tl),
        onChanged: (s) {
          setState(() {
            keyword = s.toLowerCase();
          });
        },
      );
      if (enableLiquidGlassUi) {
        return GlassSurface(
          height: 42,
          borderRadius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Center(child: searchField),
        );
      }
      return searchField;
    } else {
      return null;
    }
  }

  void find() {
    results.clear();
    if (keyword == "") {
      results.addAll(comics);
    } else {
      for (var element in comics) {
        if (element.title.toLowerCase().contains(keyword) ||
            element.subtitle.toLowerCase().contains(keyword)) {
          results.add(element);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (searchMode) {
      find();
    }

    final displayList = searchMode ? results : comics;
    final maxPage = _maxPageForCount(displayList.length);
    final currentPage = _clampPage(_currentPage, maxPage);
    final visibleComics = appdata.settings[25] == "1"
        ? _paginateComics(displayList, currentPage)
        : displayList;

    if (App.isFluent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        var route = ModalRoute.of(context);
        if (mounted && route != null && route.isCurrent) {
          if (route.animation?.status == AnimationStatus.reverse) {
            return;
          }
          App.mainAppbarActions.value = fluent.CommandBar(
            mainAxisAlignment: MainAxisAlignment.end,
            primaryItems: [
              fluent.CommandBarButton(
                icon: const Icon(fluent.FluentIcons.delete),
                label: Text("清除".tl),
                onPressed: () {
                  fluent.showDialog(
                    context: context,
                    builder: (context) => fluent.ContentDialog(
                      title: Text("清除记录".tl),
                      content: Text("要清除历史记录吗?".tl),
                      actions: [
                        fluent.Button(
                            onPressed: () => App.globalBack(),
                            child: Text("取消".tl)),
                        fluent.FilledButton(
                            onPressed: () {
                              appdata.history.clearHistory();
                              setState(() {
                                comics.clear();
                                _currentPage = 1;
                              });
                              isModified = true;
                              StateController.find(tag: "me_page_history").update();
                              App.globalBack();
                            },
                            child: Text("清除".tl)),
                      ],
                    ),
                  );
                },
              ),
              fluent.CommandBarButton(
                icon: Icon(searchMode
                    ? fluent.FluentIcons.cancel
                    : fluent.FluentIcons.search),
                label: Text(searchMode ? "取消搜索".tl : "搜索".tl),
                onPressed: () {
                  setState(() {
                    searchMode = !searchMode;
                    searchInit = true;
                    _currentPage = 1;
                    if (!searchMode) {
                      keyword = "";
                    }
                  });
                },
              )
            ],
          );
        }
      });
      return fluent.ScaffoldPage(
        header: fluent.PageHeader(
          title: searchMode
              ? SizedBox(
                  width: 300,
                  child: fluent.TextBox(
                    autofocus: true,
                    placeholder: "搜索".tl,
                    onChanged: (s) {
                      setState(() {
                        keyword = s.toLowerCase();
                      });
                    },
                  ),
                )
              : null,
        ),
        content: CustomScrollView(
          controller: _scrollController,
          slivers: [
            if (appdata.settings[25] == "1")
              SliverToBoxAdapter(
                child: _buildPaginationSection(
                  context,
                  currentPage: currentPage,
                  maxPage: maxPage,
                ),
              ),
            buildComics(visibleComics),
            if (appdata.settings[25] == "1")
              SliverToBoxAdapter(
                child: _buildPaginationSection(
                  context,
                  currentPage: currentPage,
                  maxPage: maxPage,
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom),
            )
          ],
        ),
      );
    }

    return Scaffold(
      body: SmoothCustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppbar(
            title: buildTitle() ?? Text("${"历史记录".tl}(${comics.length})"),
            actions: [
              Tooltip(
                message: '清除'.tl,
                child: Flyout(
                  controller: controller,
                  flyoutBuilder: (context) {
                    return FlyoutContent(
                      title: '清除'.tl,
                      content: Text('要清除历史记录吗?'.tl),
                      actions: [
                        Button.filled(
                          color: context.colorScheme.error,
                          onPressed: () {
                            appdata.history.clearHistory();
                            setState(() {
                              comics.clear();
                              _currentPage = 1;
                            });
                            isModified = true;
                            StateController.find(tag: "me_page_history").update();
                            context.pop();
                          },
                          child: Text('清除'.tl),
                        ),
                      ],
                    );
                  },
                  child: enableLiquidGlassUi
                      ? GlassIconActionButton(
                          icon: Icons.delete_forever,
                          tooltip: '清除'.tl,
                          onTap: () {
                            controller.show();
                          },
                        )
                      : IconButton(
                          icon: const Icon(Icons.delete_forever),
                          onPressed: () {
                            controller.show();
                          },
                        ),
                ),
              ),
              Tooltip(
                message: "搜索".tl,
                child: enableLiquidGlassUi
                    ? GlassIconActionButton(
                        icon: Icons.search,
                        tooltip: "搜索".tl,
                        onTap: () {
                          setState(() {
                            searchMode = !searchMode;
                            searchInit = true;
                            _currentPage = 1;
                            if (!searchMode) {
                              keyword = "";
                            }
                          });
                        },
                      )
                    : IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () {
                          setState(() {
                            searchMode = !searchMode;
                            searchInit = true;
                            _currentPage = 1;
                            if (!searchMode) {
                              keyword = "";
                            }
                          });
                        },
                      ),
              )
            ],
          ),
          if (appdata.settings[25] == "1")
            SliverToBoxAdapter(
              child: _buildPaginationSection(
                context,
                currentPage: currentPage,
                maxPage: maxPage,
              ),
            ),
          buildComics(visibleComics),
          if (appdata.settings[25] == "1")
            SliverToBoxAdapter(
              child: _buildPaginationSection(
                context,
                currentPage: currentPage,
                maxPage: maxPage,
              ),
            ),
          SliverPadding(
            padding:
                EdgeInsets.only(top: MediaQuery.of(context).padding.bottom),
          )
        ],
      ),
    );
  }

  int _maxPageForCount(int count) {
    if (count <= 0) {
      return 1;
    }
    return ((count - 1) ~/ _pageSize) + 1;
  }

  int _clampPage(int page, int maxPage) {
    if (page < 1) {
      return 1;
    }
    if (page > maxPage) {
      return maxPage;
    }
    return page;
  }

  List<History> _paginateComics(List<History> comics, int currentPage) {
    final startIndex = (currentPage - 1) * _pageSize;
    if (startIndex >= comics.length) {
      return <History>[];
    }
    final endIndex = startIndex + _pageSize;
    return comics.sublist(
      startIndex,
      endIndex > comics.length ? comics.length : endIndex,
    );
  }

  void _changePage(int page, int maxPage) {
    final nextPage = _clampPage(page, maxPage);
    if (nextPage == _currentPage) {
      return;
    }
    setState(() {
      _currentPage = nextPage;
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildPaginationSection(
    BuildContext context, {
    required int currentPage,
    required int maxPage,
  }) {
    return Row(
      children: [
        FilledButton(
          onPressed: currentPage > 1
              ? () => _changePage(currentPage - 1, maxPage)
              : null,
          child: Text("后退".tl),
        ).fixWidth(84),
        Expanded(
          child: Center(
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final page = await showDialog<int>(
                    context: context,
                    builder: (context) {
                      final controller = TextEditingController(
                        text: currentPage.toString(),
                      );
                      return ContentDialog(
                        title: "输入页码".tl,
                        content: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "页码".tl,
                            hintText: "1-$maxPage",
                          ),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ).paddingHorizontal(16),
                        actions: [
                          Button.filled(
                            onPressed: () {
                              final p = int.tryParse(controller.text);
                              if (p != null && p >= 1 && p <= maxPage) {
                                Navigator.pop(context, p);
                              } else {
                                showToast(message: "页码无效".tl);
                              }
                            },
                            child: Text("确认".tl),
                          ),
                        ],
                      );
                    },
                  );
                  if (page != null) {
                    _changePage(page, maxPage);
                  }
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text("${"页面".tl} $currentPage / $maxPage"),
                ),
              ),
            ),
          ),
        ),
        FilledButton(
          onPressed: currentPage < maxPage
              ? () => _changePage(currentPage + 1, maxPage)
              : null,
          child: Text("前进".tl),
        ).fixWidth(84),
      ],
    ).paddingVertical(8).paddingHorizontal(16);
  }

  Widget buildComics(List<History> comics_) {
    return SliverGrid(
      delegate:
          SliverChildBuilderDelegate(childCount: comics_.length, (context, i) {
        final isLocal = isLocalHistoryEntry(comics_[i]);
        final cover = isLocal
            ? (comics_[i].cover.isNotEmpty
                ? comics_[i].cover
                : resolveLocalComicCoverSync(comics_[i].target) ?? "")
            : (comics_[i].cover != ""
                ? comics_[i].cover
                : getJmCoverUrl(comics_[i].target));
        final comic = ComicItemBrief(
          comics_[i].title,
          comics_[i].subtitle,
          0,
          comics_[i].cover != ""
              ? comics_[i].cover
              : getJmCoverUrl(comics_[i].target),
          comics_[i].target,
          [],
        );
        if (isLocal) {
          return _LocalHistoryComicTile(
            key: Key(comics_[i].target),
            history: comics_[i],
            onTap: () => toComicPageWithHistory(context, comics_[i]),
            onLongTap: () {
              if (App.isFluent) {
                fluent.showDialog(
                  context: context,
                  builder: (context) => fluent.ContentDialog(
                    title: Text("删除".tl),
                    content: Text("要删除这条历史记录吗".tl),
                    actions: [
                      fluent.Button(
                        onPressed: () => App.globalBack(),
                        child: Text("取消".tl),
                      ),
                      fluent.FilledButton(
                        onPressed: () {
                          appdata.history.remove(comics_[i].target);
                          setState(() {
                            isModified = true;
                            comics.removeWhere((element) =>
                                element.target == comics_[i].target);
                          });
                          StateController.find(tag: "me_page_history").update();
                          App.globalBack();
                        },
                        child: Text("删除".tl),
                      ),
                    ],
                  ),
                );
                return;
              }
              showConfirmDialog(
                context: context,
                title: "删除".tl,
                content: "要删除这条历史记录吗".tl,
                btnColor: context.colorScheme.error,
                onConfirm: () {
                  appdata.history.remove(comics_[i].target);
                  setState(() {
                    isModified = true;
                    comics.removeWhere((element) =>
                        element.target == comics_[i].target);
                  });
                  StateController.find(tag: "me_page_history").update();
                },
              );
            },
          );
        }
        return NormalComicTile(
          key: Key(comics_[i].target),
          sourceKey: isLocal ? null : comics_[i].type.comicSource?.key,
          onLongTap: () {
            if (App.isFluent) {
              fluent.showDialog(
                context: context,
                builder: (context) => fluent.ContentDialog(
                  title: Text("删除".tl),
                  content: Text("要删除这条历史记录吗".tl),
                  actions: [
                    fluent.Button(
                        onPressed: () => App.globalBack(),
                        child: Text("取消".tl)),
                    fluent.FilledButton(
                        onPressed: () {
                          appdata.history.remove(comics_[i].target);
                          setState(() {
                            isModified = true;
                            comics.removeWhere((element) =>
                                element.target == comics_[i].target);
                          });
                          StateController.find(tag: "me_page_history").update();
                          App.globalBack();
                        },
                        child: Text("删除".tl)),
                  ],
                ),
              );
              return;
            }
            showConfirmDialog(
              context: context,
              title: "删除".tl,
              content: "要删除这条历史记录吗".tl,
              btnColor: context.colorScheme.error,
              onConfirm: () {
                appdata.history.remove(comics_[i].target);
                setState(() {
                  isModified = true;
                  comics.removeWhere((element) =>
                      element.target == comics_[i].target);
                });
                StateController.find(tag: "me_page_history").update();
              },
            );
          },
          description_: timeToString(comics_[i].time),
          coverPath: isLocal ? "" : comic.path,
          name: comic.title,
          subTitle_: comic.author,
          badgeName: isLocal ? "本地".tl : comics_[i].type.name,
          headers: {
            if (comics_[i].type == HistoryType.ehentai)
              "cookie": EhNetwork().cookiesStr,
            if (comics_[i].type == HistoryType.ehentai ||
                comics_[i].type == HistoryType.hitomi)
              "User-Agent": webUA,
            if (comics_[i].type == HistoryType.hitomi)
              "Referer": "https://hitomi.la/"
          },
          onTap: () {
            toComicPageWithHistory(context, comics_[i]);
          },
        );
      }),
      gridDelegate: SliverGridDelegateWithComics(),
    );
  }
}

class _LocalHistoryComicTile extends ComicTile {
  const _LocalHistoryComicTile({
    super.key,
    required this.history,
    required this.onTap,
    this.onLongTap,
  });

  final History history;
  final VoidCallback onTap;
  final VoidCallback? onLongTap;

  @override
  Widget get image => buildHistoryCover(
        history,
        width: double.infinity,
        height: double.infinity,
      );

  @override
  String get title => history.title;

  @override
  String get subTitle =>
      history.subtitle.isNotEmpty ? history.subtitle : timeToString(history.time);

  @override
  String get description => timeToString(history.time);

  @override
  String? get badge => "本地".tl;

  @override
  String? get comicID => history.target;

  @override
  bool get showFavorite => false;

  @override
  void onTap_() => onTap();

  @override
  void onLongTap_() => onLongTap?.call();
}

Widget buildHistoryCover(
  History history, {
  required double width,
  required double height,
  BoxFit fit = BoxFit.cover,
  FilterQuality filterQuality = FilterQuality.medium,
}) {
  final isLocal = isLocalHistoryEntry(history);
  if (isLocal) {
    final localPath = history.cover.isNotEmpty
        ? history.cover
        : (resolveLocalComicCoverSync(history.target) ?? "");
    if (localPath.isNotEmpty && File(localPath).existsSync()) {
      return Image.file(
        File(localPath),
        width: width,
        height: height,
        fit: fit,
        filterQuality: filterQuality,
      );
    }
  }

  return AnimatedImage(
    image: CachedImageProvider(
      history.cover,
      sourceKey: history.type.comicSource?.key,
    ),
    width: width,
    height: height,
    fit: fit,
    filterQuality: filterQuality,
  );
}

void toComicPageWithHistory(BuildContext context, History history) {
  if (isLocalHistoryEntry(history)) {
    openLocalHistory(history);
    return;
  }
  var source = history.type.comicSource;
  if (source == null) {
    showToast(message: "Comic Source Not Found");
    return;
  }
  context.to(
    () => ComicPage(
      sourceKey: source.key,
      id: history.target,
      cover: history.cover,
    ),
  );
}
