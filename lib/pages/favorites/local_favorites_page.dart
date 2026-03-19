part of 'favorites_page.dart';

const _localAllFolderLabel = '^_^[%local_all%]^_^';

/// If the number of comics in a folder exceeds this limit, it will be
/// fetched asynchronously.
const _asyncDataFetchLimit = 500;

class _LocalFavoritesPage extends StatefulWidget {
  const _LocalFavoritesPage({required this.folder, super.key});

  final String folder;

  @override
  State<_LocalFavoritesPage> createState() => _LocalFavoritesPageState();
}

class _LocalFavoritesPageState extends State<_LocalFavoritesPage> {
  late _FavoritesPageState favPage;

  late List<FavoriteItem> comics;

  String? networkSource;
  String? networkFolder;

  Map<FavoriteItem, bool> selectedComics = {};

  var selectedLocalFolders = <String>{};

  late List<String> added = [];

  String keyword = "";
  bool searchHasUpper = false;

  bool searchMode = false;

  bool multiSelectMode = false;

  int? lastSelectedIndex;

  bool get isAllFolder => widget.folder == _localAllFolderLabel;

  LocalFavoritesManager get manager => LocalFavoritesManager();

  bool isLoading = false;

  late String readFilterSelect;

  var searchResults = <FavoriteItem>[];

  void updateSearchResult() {
    setState(() {
      if (keyword.trim().isEmpty) {
        searchResults = comics;
      } else {
        searchResults = [];
        for (var comic in comics) {
          if (matchKeyword(keyword, comic) ||
              matchKeywordT(keyword, comic) ||
              matchKeywordS(keyword, comic)) {
            searchResults.add(comic);
          }
        }
      }
    });
  }

  void updateComics() {
    if (isLoading) return;
    if (isAllFolder) {
      var totalComics = manager.totalComics;
      if (totalComics < _asyncDataFetchLimit) {
        comics = manager.allComics().map((e) => e.comic).toList();
      } else {
        isLoading = true;
        Future(() async {
          var all = manager.allComics().map((e) => e.comic).toList();
          await Future.delayed(const Duration(milliseconds: 200));
          if (mounted) {
            setState(() {
              isLoading = false;
              comics = all;
            });
          }
        });
      }
    } else {
      var folderComics = manager.folderComics(widget.folder);
      if (folderComics < _asyncDataFetchLimit) {
        comics = manager.getAllComics(widget.folder);
      } else {
        isLoading = true;
        Future(() async {
          var all = manager.getAllComics(widget.folder);
          await Future.delayed(const Duration(milliseconds: 200));
          if (mounted) {
            setState(() {
              isLoading = false;
              comics = all;
            });
          }
        });
      }
    }
    setState(() {});
  }

  List<FavoriteItem> filterComics(List<FavoriteItem> curComics) {
    return curComics.where((comic) {
      var history = HistoryManager().findSync(comic.target);
      if (readFilterSelect == "未完成") {
        return history == null || history.page != history.maxPage;
      } else if (readFilterSelect == "已完成") {
        return history != null && history.page == history.maxPage;
      }
      return true;
    }).toList();
  }

  bool matchKeyword(String keyword, FavoriteItem comic) {
    var list = keyword.split(" ");
    for (var k in list) {
      if (k.isEmpty) continue;
      if (checkKeyWordMatch(k, comic.name, false)) {
        continue;
      } else if (comic.author.isNotEmpty && checkKeyWordMatch(k, comic.author, false)) {
        continue;
      } else if (comic.tags.any((tag) {
        if (checkKeyWordMatch(k, tag, true)) {
          return true;
        } else if (tag.contains(':') && checkKeyWordMatch(k, tag.split(':')[1], true)) {
          return true;
        } else if (App.locale.languageCode != 'en' &&
            checkKeyWordMatch(k, tag.translateTagsToCN, true)) {
          return true;
        }
        return false;
      })) {
        continue;
      } else if (checkKeyWordMatch(k, comic.author, true)) {
        continue;
      }
      return false;
    }
    return true;
  }

  bool checkKeyWordMatch(String keyword, String compare, bool needEqual) {
    String temp = compare;
    // 没有大写的话, 就转成小写比较, 避免搜索需要注意大小写
    if (!searchHasUpper) {
      temp = temp.toLowerCase();
    }
    if (needEqual) {
      return keyword == temp;
    }
    return temp.contains(keyword);
  }

  // Convert keyword to traditional Chinese to match comics
  bool matchKeywordT(String keyword, FavoriteItem comic) {
    return false; // Simplified for now
  }

  // Convert keyword to simplified Chinese to match comics
  bool matchKeywordS(String keyword, FavoriteItem comic) {
    return false; // Simplified for now
  }

  @override
  void initState() {
    readFilterSelect = (appdata.implicitData.length > 1 &&
            readFilterList.contains(appdata.implicitData[1]))
        ? appdata.implicitData[1]
        : readFilterList[0];
    if (!isAllFolder) {
      var syncs = LocalFavoritesManager().folderSync;
      var sync = syncs.firstWhereOrNull((s) => s.folderName == widget.folder);
      if (sync != null) {
        networkSource = sync.key;
        var data = jsonDecode(sync.syncData);
        networkFolder = data['folderId']?.toString();
      }
    } else {
      networkSource = null;
      networkFolder = null;
    }
    comics = [];
    updateComics();
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    favPage = context.findAncestorStateOfType<_FavoritesPageState>()!;
  }

  @override
  void dispose() {
    super.dispose();
  }

  void selectAll() {
    setState(() {
      if (searchMode) {
        selectedComics = {for (var c in searchResults) c: true};
      } else {
        selectedComics = {for (var c in comics) c: true};
      }
    });
  }

  void invertSelection() {
    setState(() {
      if (searchMode) {
        for (var c in searchResults) {
          if (selectedComics.containsKey(c)) {
            selectedComics.remove(c);
          } else {
            selectedComics[c] = true;
          }
        }
      } else {
        for (var c in comics) {
          if (selectedComics.containsKey(c)) {
            selectedComics.remove(c);
          } else {
            selectedComics[c] = true;
          }
        }
      }
    });
  }

  bool downloadComic(FavoriteItem c) {
    var source = c.type.comicSource;
    if (source != null) {
      bool isDownloaded = DownloadManager().isExists(c.toDownloadId());
      if (isDownloaded) {
        return false;
      }
      try {
        DownloadManager().addFavoriteDownload(c);
        return true;
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  void downloadSelected() {
    int count = 0;
    for (var c in selectedComics.keys) {
      if (downloadComic(c)) {
        count++;
      }
    }
    if (count > 0) {
      showToast(
        message: "Added @c comics to download queue.".tlParams({"c": count.toString()}),
      );
    }
  }

  var scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    var title = favPage.folder ?? "未选择".tl;
    if (title == _localAllFolderLabel) {
      title = "全部".tl;
    }

    var displayComics = searchMode ? searchResults : comics;
    displayComics = filterComics(displayComics);

    Widget body = CustomScrollView(
      controller: scrollController,
      slivers: [
        if (!searchMode && !multiSelectMode)
          SliverAppBar(
            pinned: true,
            leading: MediaQuery.of(context).size.width <= _kTwoPanelChangeWidth
                ? IconButton(
                    icon: const Icon(Icons.menu),
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: favPage.showFolderSelector,
                  )
                : null,
            title: GestureDetector(
              onTap: MediaQuery.of(context).size.width < _kTwoPanelChangeWidth
                  ? favPage.showFolderSelector
                  : null,
              child: Text(title),
            ),
            actions: [
              if (networkSource != null && !isAllFolder)
                Tooltip(
                  message: "同步".tl,
                  child: IconButton(
                    icon: const Icon(Icons.sync),
                    onPressed: () {
                      final GlobalKey<_SelectUpdatePageNumState>
                          selectUpdatePageNumKey =
                          GlobalKey<_SelectUpdatePageNumState>();
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text("同步".tl),
                          content: _SelectUpdatePageNum(
                            networkSource: networkSource!,
                            networkFolder: networkFolder,
                            key: selectUpdatePageNumKey,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text("取消".tl),
                            ),
                            FilledButton(
                              child: Text("更新".tl),
                              onPressed: () {
                                Navigator.of(context).pop();
                                importNetworkFolder(
                                  networkSource!,
                                  selectUpdatePageNumKey
                                      .currentState!.updatePageNum,
                                  widget.folder,
                                  networkFolder,
                                ).then((_) {
                                  updateComics();
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              Tooltip(
                message: "筛选".tl,
                child: IconButton(
                  icon: const Icon(Icons.sort_rounded),
                  color: readFilterSelect != "全部"
                      ? Theme.of(context).colorScheme.onSurface
                      : null,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return _LocalFavoritesFilterDialog(
                          initReadFilterSelect: readFilterSelect,
                          updateConfig: (readFilter) {
                            setState(() {
                              readFilterSelect = readFilter;
                            });
                            updateComics();
                          },
                        );
                      },
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
                      keyword = "";
                      searchMode = true;
                      updateSearchResult();
                    });
                  },
                ),
              ),
              if (!isAllFolder)
                PopupMenuButton(
                  tooltip: "更多".tl,
                  icon: const Icon(Icons.more_horiz),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined),
                          const SizedBox(width: 8),
                          Text("重命名".tl),
                        ],
                      ),
                      onTap: () {
                        Future.delayed(const Duration(milliseconds: 100), () {
                          showDialog(
                            context: App.globalContext!,
                            builder: (context) => RenameFolderDialog(widget.folder),
                          ).then((_) => favPage.folderList?.updateFolders());
                        });
                      },
                    ),
                    PopupMenuItem(
                      child: Row(
                        children: [
                          const Icon(Icons.reorder),
                          const SizedBox(width: 8),
                          Text("排序".tl),
                        ],
                      ),
                      onTap: () {
                        Future.delayed(const Duration(milliseconds: 100), () {
                          App.globalTo(() => LocalFavoritesFolder(widget.folder));
                        });
                      },
                    ),
                    PopupMenuItem(
                      child: Row(
                        children: [
                          const Icon(Icons.upload_file),
                          const SizedBox(width: 8),
                          Text("导出".tl),
                        ],
                      ),
                      onTap: () {
                        Future.delayed(const Duration(milliseconds: 100), () async {
                          var json = LocalFavoritesManager().folderToJsonString(widget.folder);
                          await exportStringDataAsFile(json, "${widget.folder}.json");
                        });
                      },
                    ),
                    PopupMenuItem(
                      child: Row(
                        children: [
                          const Icon(Icons.update),
                          const SizedBox(width: 8),
                          Text("更新漫画信息".tl),
                        ],
                      ),
                      onTap: () {
                        Future.delayed(const Duration(milliseconds: 100), () {
                          UpdateFavoritesInfoDialog.show(comics, widget.folder);
                        });
                      },
                    ),
                    PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: 8),
                          Text("删除收藏夹".tl),
                        ],
                      ),
                      onTap: () {
                        Future.delayed(const Duration(milliseconds: 100), () {
                          showDialog(
                            context: App.globalContext!,
                            builder: (context) => AlertDialog(
                              title: Text("删除".tl),
                              content: Text("Delete folder '@f' ?".tlParams({"f": widget.folder})),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text("取消".tl),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    favPage.setFolder(false, null);
                                    LocalFavoritesManager().deleteFolder(widget.folder);
                                    favPage.folderList?.updateFolders();
                                    Navigator.of(context).pop();
                                  },
                                  style: ButtonStyle(
                                    backgroundColor: MaterialStateProperty.all(
                                      Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                                  child: Text("删除".tl),
                                ),
                              ],
                            ),
                          );
                        });
                      },
                    ),
                  ],
                ),
            ],
          )
        else if (multiSelectMode)
          SliverAppBar(
            leading: Tooltip(
              message: "取消".tl,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    multiSelectMode = false;
                    selectedComics.clear();
                  });
                },
              ),
            ),
            title: Text(
                "已选择 @c 本漫画".tlParams({"c": selectedComics.length.toString()})),
            actions: [
              PopupMenuButton(
                itemBuilder: (context) => [
                  if (!isAllFolder)
                    PopupMenuItem(
                      child: Row(
                        children: [
                          const Icon(Icons.drive_file_move),
                          const SizedBox(width: 8),
                          Text("移动到文件夹".tl),
                        ],
                      ),
                      onTap: () => favoriteOption('move'),
                    ),
                  if (!isAllFolder)
                    PopupMenuItem(
                      child: Row(
                        children: [
                          const Icon(Icons.copy),
                          const SizedBox(width: 8),
                          Text("复制到文件夹".tl),
                        ],
                      ),
                      onTap: () => favoriteOption('add'),
                    ),
                  PopupMenuItem(
                    child: Row(
                      children: [
                        const Icon(Icons.select_all),
                        const SizedBox(width: 8),
                        Text("全选".tl),
                      ],
                    ),
                    onTap: selectAll,
                  ),
                  PopupMenuItem(
                    child: Row(
                      children: [
                        const Icon(Icons.deselect),
                        const SizedBox(width: 8),
                        Text("取消选择".tl),
                      ],
                    ),
                    onTap: () => setState(() => selectedComics.clear()),
                  ),
                  PopupMenuItem(
                    child: Row(
                      children: [
                        const Icon(Icons.flip),
                        const SizedBox(width: 8),
                        Text("反选".tl),
                      ],
                    ),
                    onTap: invertSelection,
                  ),
                  if (!isAllFolder)
                    PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: 8),
                          Text("删除漫画".tl),
                        ],
                      ),
                      onTap: () {
                        Future.delayed(const Duration(milliseconds: 100), () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text("删除".tl),
                              content: Text("删除 @c 本漫画？"
                                  .tlParams({"c": selectedComics.length.toString()})),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text("取消".tl),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _deleteComicWithId();
                                  },
                                  style: ButtonStyle(
                                    backgroundColor: MaterialStateProperty.all(
                                      Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                                  child: Text("删除".tl),
                                ),
                              ],
                            ),
                          );
                        });
                      },
                    ),
                  PopupMenuItem(
                    child: Row(
                      children: [
                        const Icon(Icons.download),
                        const SizedBox(width: 8),
                        Text("下载".tl),
                      ],
                    ),
                    onTap: downloadSelected,
                  ),
                  if (selectedComics.length == 1)
                    PopupMenuItem(
                      child: Row(
                        children: [
                          const Icon(Icons.edit_note),
                          const SizedBox(width: 8),
                          Text("编辑标签".tl),
                        ],
                      ),
                      onTap: () {
                        Future.delayed(const Duration(milliseconds: 100), () {
                          _editTags(selectedComics.keys.first);
                        });
                      },
                    ),
                  PopupMenuItem(
                    child: Row(
                      children: [
                        const Icon(Icons.update),
                        const SizedBox(width: 8),
                        Text("更新漫画信息".tl),
                      ],
                    ),
                    onTap: () {
                      Future.delayed(const Duration(milliseconds: 100), () {
                        UpdateFavoritesInfoDialog.show(
                          selectedComics.keys.toList(),
                          widget.folder,
                        );
                      });
                    },
                  ),
                  if (selectedComics.length == 1)
                    PopupMenuItem(
                      child: Row(
                        children: [
                          const Icon(Icons.copy),
                          const SizedBox(width: 8),
                          Text("复制标题".tl),
                        ],
                      ),
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(
                            text: selectedComics.keys.first.name,
                          ),
                        );
                        showToast(message: "已复制".tl);
                      },
                    ),
                  if (selectedComics.length == 1)
                    PopupMenuItem(
                      child: Row(
                        children: [
                          const Icon(Icons.chrome_reader_mode_outlined),
                          const SizedBox(width: 8),
                          Text("阅读".tl),
                        ],
                      ),
                      onTap: () {
                        final c = selectedComics.keys.first;
                        _readComic(c);
                      },
                    ),
                  if (selectedComics.length == 1)
                    PopupMenuItem(
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_forward_ios),
                          const SizedBox(width: 8),
                          Text("查看详情".tl),
                        ],
                      ),
                      onTap: () {
                        final c = selectedComics.keys.first;
                        App.mainNavigatorKey?.currentContext?.to(() => ComicPage(
                              id: c.target,
                              sourceKey: c.type.comicSource?.key ?? '',
                            ));
                      },
                    ),
                ],
              ),
            ],
          )
        else if (searchMode)
          SliverAppBar(
            leading: Tooltip(
              message: "取消".tl,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    searchMode = false;
                  });
                },
              ),
            ),
            title: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: "搜索".tl,
                border: InputBorder.none,
              ),
              onChanged: (s) {
                keyword = s;
                searchHasUpper = s.toLowerCase() != s;
                updateSearchResult();
              },
            ),
          ),
        if (isLoading)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (displayComics.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "这里什么都没有".tl,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium,
                      children: [
                        TextSpan(
                          text: '前往'.tl,
                        ),
                        TextSpan(
                          text: '探索页面'.tl,
                        ),
                        TextSpan(
                          text: '寻找漫画'.tl,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SliverGrid(
            gridDelegate: SliverGridDelegateWithComics(),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                var comic = displayComics[index];
                var tile = LocalFavoriteTile(
                  comic,
                  widget.folder,
                  () {
                    setState(() {
                      comics.remove(comic);
                    });
                  },
                  true,
                  onLongPressed: () {
                    setState(() {
                      multiSelectMode = true;
                      selectedComics[comic] = true;
                    });
                  },
                  onTap: () {
                    if (multiSelectMode) {
                      setState(() {
                        if (selectedComics.containsKey(comic)) {
                          selectedComics.remove(comic);
                        } else {
                          selectedComics[comic] = true;
                        }
                      });
                      return true;
                    }
                    return false;
                  },
                );

                Color? color;
                if (selectedComics.containsKey(comic)) {
                  color = Theme.of(context).colorScheme.surfaceContainerHighest;
                }
                return AnimatedContainer(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  duration: const Duration(milliseconds: 160),
                  child: tile,
                );
              },
              childCount: displayComics.length,
            ),
          ),
      ],
    );

    return body;
  }

  void _deleteComicWithId() {
    for (var c in selectedComics.keys) {
      LocalFavoritesManager().deleteComic(widget.folder, c);
    }
    setState(() {
      selectedComics.clear();
      multiSelectMode = false;
      updateComics();
    });
  }

  void favoriteOption(String type) {
    var folders = LocalFavoritesManager().folderNames;
    folders.remove(widget.folder);

    showDialog(
      context: App.globalContext!,
      builder: (context) {
        String? selectedFolder;

        return StatefulBuilder(builder: (context, setState) {
          return ContentDialog(
            title: type == 'move' ? "移动到文件夹".tl : "复制到文件夹".tl,
            content: ListTile(
              title: Text("文件夹".tl),
              trailing: DropdownButton<String>(
                value: selectedFolder,
                items: folders.map((f) => DropdownMenuItem(
                  value: f,
                  child: Text(f),
                )).toList(),
                onChanged: (v) {
                  setState(() {
                    selectedFolder = v;
                  });
                },
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  if (selectedFolder != null) {
                    for (var c in selectedComics.keys) {
                      if (type == 'move') {
                        LocalFavoritesManager().deleteComic(widget.folder, c);
                      }
                      LocalFavoritesManager().addComic(selectedFolder!, c);
                    }
                    Navigator.of(context).pop();
                    setState(() {
                      selectedComics.clear();
                      multiSelectMode = false;
                      updateComics();
                    });
                  }
                },
                child: Text("确认".tl),
              ),
            ],
          );
        });
      },
    );
  }

  void _readComic(FavoriteItem c) async {
    if (DownloadManager().isExists(c.toDownloadId())) {
      var download = await DownloadManager().getComicOrNull(c.toDownloadId());
      if (download != null) {
        // For downloaded comics, navigate to comic page
        App.globalTo(() => ComicPage(
          id: c.target,
          sourceKey: c.type.comicSource.key,
          cover: c.coverPath,
        ));
        return;
      }
    }
    
    bool cancel = false;
    var dialog = showLoadingDialog(
      App.globalContext!,
      onCancel: () => cancel = true,
      barrierDismissible: false,
    );

    var comicSource = c.type.comicSource;
    if (comicSource?.loadComicInfo != null) {
      var res = await comicSource!.loadComicInfo!(c.target);
      if (cancel) return;
      dialog.close();
      if (res.error) {
        showToast(message: res.errorMessage ?? "Error");
      } else {
        var history = await HistoryManager().find(c.target);
        if (history == null) {
          history = History(
            HistoryType(c.type.key),
            DateTime.now(),
            c.name,
            c.author,
            c.coverPath,
            0,
            0,
            c.target,
          );
          await HistoryManager().addHistory(history);
        }
        // Navigate to reader using CustomReadingData
        App.globalTo(
          () => ComicReadingPage(
            CustomReadingData(
              res.data.target,
              res.data.title,
              comicSource,
              res.data.chapters,
            ),
            history?.page ?? 0,
            history?.ep ?? 0,
          ),
        );
      }
    }
  }

  void _editTags(FavoriteItem comic) {
    showDialog(
        context: App.globalContext!,
        builder: (context) {
          var tags = comic.tags;
          var controller = TextEditingController();
          return SimpleDialog(
            elevation: 1,
            title: Text("编辑标签".tl),
            children: [
              StatefulBuilder(
                  builder: (context, setState) => SizedBox(
                        width: 400,
                        child: Column(
                          children: [
                            Wrap(
                              children: tags
                                  .map((e) => Container(
                                        margin: const EdgeInsets.all(4),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondaryContainer,
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(e),
                                            const SizedBox(
                                              width: 4,
                                            ),
                                            InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: const Icon(
                                                Icons.close,
                                                size: 20,
                                              ),
                                              onTap: () {
                                                tags.remove(e);
                                                setState(() {});
                                              },
                                            )
                                          ],
                                        ),
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(
                              height: 8,
                            ),
                            SizedBox(
                              height: 56,
                              child: TextField(
                                controller: controller,
                                decoration: InputDecoration(
                                  border: const UnderlineInputBorder(),
                                  suffix: IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () {
                                      var value = controller.text;
                                      if (value.isNotEmpty) {
                                        controller.clear();
                                        tags.add(value);
                                        setState(() {});
                                      }
                                    },
                                  ).paddingTop(8),
                                ),
                                onSubmitted: (value) {
                                  if (value.isNotEmpty) {
                                    tags.add(value);
                                    controller.clear();
                                    setState(() {});
                                  }
                                },
                              ),
                            ).paddingHorizontal(36),
                            const SizedBox(
                              height: 16,
                            ),
                            Center(
                              child: FilledButton(
                                  onPressed: () {
                                    LocalFavoritesManager().editTags(
                                        comic.target, widget.folder, tags);
                                    App.globalBack();
                                    updateComics();
                                  },
                                  child: Text("提交".tl)),
                            )
                          ],
                        ),
                      ))
            ],
          );
        });
  }
}

class _LocalFavoritesFilterDialog extends StatefulWidget {
  const _LocalFavoritesFilterDialog({
    required this.initReadFilterSelect,
    required this.updateConfig,
  });

  final String initReadFilterSelect;
  final Function(String) updateConfig;

  @override
  State<_LocalFavoritesFilterDialog> createState() =>
      _LocalFavoritesFilterDialogState();
}

const readFilterList = ['全部', '未完成', '已完成'];

class _LocalFavoritesFilterDialogState
    extends State<_LocalFavoritesFilterDialog> {
  late String readFilter = readFilterList.contains(widget.initReadFilterSelect)
      ? widget.initReadFilterSelect
      : readFilterList[0];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("筛选".tl),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text("过滤阅读状态".tl),
            trailing: DropdownButton<String>(
              value: readFilter,
              items: readFilterList.map((e) => DropdownMenuItem(
                value: e,
                child: Text(e.tl),
              )).toList(),
              onChanged: (v) {
                setState(() {
                  readFilter = v!;
                });
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text("取消".tl),
        ),
        FilledButton(
          onPressed: () {
            appdata.implicitData[1] = readFilter;
            appdata.writeImplicitData();
            widget.updateConfig(readFilter);
            Navigator.of(context).pop();
          },
          child: Text("确认".tl),
        ),
      ],
    );
  }
}

class _SelectUpdatePageNum extends StatefulWidget {
  const _SelectUpdatePageNum({
    required this.networkSource,
    this.networkFolder,
    super.key,
  });

  final String? networkFolder;
  final String networkSource;

  @override
  State<_SelectUpdatePageNum> createState() => _SelectUpdatePageNumState();
}

class _SelectUpdatePageNumState extends State<_SelectUpdatePageNum> {
  int updatePageNum = 9999999;

  String get _allPageText => '全部'.tl;

  List<String> get pageNumList =>
      ['1', '2', '3', '5', '10', '20', '50', '100', '200', _allPageText];

  @override
  void initState() {
    if (appdata.implicitData.length > 15) {
      updatePageNum = int.parse(appdata.implicitData[15]);
    } else {
      updatePageNum = 9999999;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var source = ComicSource.find(widget.networkSource);
    var sourceName = source?.name ?? widget.networkSource;
    var text = "文件夹已关联到 @source".tlParams({
      "source": sourceName,
    });
    if (widget.networkFolder != null && widget.networkFolder!.isNotEmpty) {
      text += "\n${"源文件夹".tl}: ${widget.networkFolder}";
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [Text(text)],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text("按最新收藏更新页数".tl),
            const Spacer(),
            DropdownButton<String>(
              value: updatePageNum.toString() == '9999999'
                  ? _allPageText
                  : updatePageNum.toString(),
              items: pageNumList.map((e) => DropdownMenuItem(
                value: e,
                child: Text(e),
              )).toList(),
              onChanged: (v) {
                setState(() {
                  updatePageNum = int.parse(v == _allPageText
                      ? '9999999'
                      : v!);
                  if (appdata.implicitData.length > 15) {
                    appdata.implicitData[15] = updatePageNum.toString();
                  } else {
                    appdata.implicitData.add(updatePageNum.toString());
                  }
                  appdata.writeImplicitData();
                });
              },
            ),
          ],
        ),
      ],
    );
  }
}
