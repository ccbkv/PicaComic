import 'package:flutter/material.dart';
import 'package:pica_comic/network/eh_network/eh_main_network.dart';
import 'package:pica_comic/network/jm_network/jm_image.dart';
import 'package:pica_comic/network/picacg_network/models.dart';
import 'package:pica_comic/pages/comic_page.dart';
import 'package:pica_comic/tools/time.dart';
import 'package:pica_comic/foundation/history.dart';
import '../base.dart';
import '../foundation/app.dart';
import 'package:pica_comic/tools/translations.dart';
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
      return TextField(
        focusNode: focus ? focusNode : null,
        decoration:
        InputDecoration(border: InputBorder.none, hintText: "搜索".tl),
        onChanged: (s) {
          setState(() {
            keyword = s.toLowerCase();
          });
        },
      );
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
                              setState(() => comics.clear());
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
          slivers: [
            if (!searchMode) buildComics(comics) else buildComics(results),
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
        slivers: [
          SliverAppbar(
            title: buildTitle() ?? Text("${"历史记录".tl}(${comics.length})"),
            actions: [
              Tooltip(
                message: "清除".tl,
                child: IconButton(
                  icon: const Icon(Icons.delete_forever),
                  onPressed: () {
                    final now = DateTime.now();
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (dialogContext) => TapRegion(
                        onTapOutside: (_) {
                          // Workaround for https://github.com/flutter/flutter/issues/177992
                          if (DateTime.now().difference(now) < const Duration(milliseconds: 500)) {
                            return;
                          }
                          if (Navigator.canPop(dialogContext)) {
                            Navigator.pop(dialogContext);
                          }
                        },
                        child: AlertDialog(
                          title: Text("清除记录".tl),
                          content: Text("要清除历史记录吗?".tl),
                          actions: [
                            TextButton(
                                onPressed: () => App.globalBack(),
                                child: Text("取消".tl)),
                            TextButton(
                                onPressed: () {
                                  appdata.history.clearHistory();
                                  setState(() => comics.clear());
                                  isModified = true;
                                  StateController.find(tag: "me_page_history").update();
                                  App.globalBack();
                                },
                                child: Text("清除".tl)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Tooltip(
                message: "搜索".tl,
                child: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      searchMode = !searchMode;
                      searchInit = true;
                      if (!searchMode) {
                        keyword = "";
                      }
                    });
                  },
                ),
              )
            ],
          ),
          if (!searchMode) buildComics(comics) else buildComics(results),
          SliverPadding(
            padding:
                EdgeInsets.only(top: MediaQuery.of(context).padding.bottom),
          )
        ],
      ),
    );
  }

  Widget buildComics(List<History> comics_) {
    return SliverGrid(
      delegate:
          SliverChildBuilderDelegate(childCount: comics_.length, (context, i) {
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
        return NormalComicTile(
          key: Key(comics_[i].target),
          sourceKey: comics_[i].type.comicSource?.key,
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
            final now = DateTime.now();
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) => TapRegion(
                onTapOutside: (_) {
                  // Workaround for https://github.com/flutter/flutter/issues/177992
                  if (DateTime.now().difference(now) < const Duration(milliseconds: 500)) {
                    return;
                  }
                  if (Navigator.canPop(dialogContext)) {
                    Navigator.pop(dialogContext);
                  }
                },
                child: AlertDialog(
                  title: Text("删除".tl),
                  content: Text("要删除这条历史记录吗".tl),
                  actions: [
                    TextButton(
                        onPressed: () => App.globalBack(),
                        child: Text("取消".tl)),
                    TextButton(
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
              ),
            );
          },
          description_: timeToString(comics_[i].time),
          coverPath: comic.path,
          name: comic.title,
          subTitle_: comic.author,
          badgeName: comics_[i].type.name,
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

void toComicPageWithHistory(BuildContext context, History history) {
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
