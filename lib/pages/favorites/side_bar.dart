part of 'favorites_page.dart';

class _LeftBar extends StatefulWidget {
  const _LeftBar({super.key, this.favPage, this.onSelected, this.withAppbar = false});

  final _FavoritesPageState? favPage;

  final VoidCallback? onSelected;

  final bool withAppbar;

  @override
  State<_LeftBar> createState() => _LeftBarState();
}

class _LeftBarState extends State<_LeftBar> implements FolderList {
  _FavoritesPageState? _favPage;

  _FavoritesPageState get favPage => _favPage!;

  var folders = <String>[];

  var networkFolders = <String>[];

  void findNetworkFolders() {
    networkFolders.clear();
    var all = ComicSource.sources
        .where((e) => e.favoriteData != null)
        .map((e) => e.favoriteData!.key)
        .toList();
    var settings = appdata.settings[68].toString().split(',');
    for (var p in settings) {
      if (all.contains(p) && !networkFolders.contains(p)) {
        networkFolders.add(p);
      }
    }
  }

  @override
  void initState() {
    folders = LocalFavoritesManager().folderNames;
    findNetworkFolders();
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    var newFavPage = widget.favPage ??
        context.findAncestorStateOfType<_FavoritesPageState>()!;
    if (newFavPage != _favPage) {
      _favPage = newFavPage;
      _favPage!.folderList = this;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.6,
          ),
        ),
      ),
      child: Column(
        children: [
          if (widget.withAppbar)
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  const CloseButton(),
                  const SizedBox(width: 8),
                  Text(
                    "文件夹".tl,
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ).paddingTop(MediaQuery.of(context).padding.top),
          Expanded(
            child: ListView.builder(
              padding: widget.withAppbar
                  ? EdgeInsets.zero
                  : EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              itemCount: folders.length + networkFolders.length + 3,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return buildLocalTitle();
                }
                index--;
                if (index == 0) {
                  return buildLocalFolder(_localAllFolderLabel);
                }
                index--;
                if (index < folders.length) {
                  return buildLocalFolder(folders[index]);
                }
                index -= folders.length;
                if (index == 0) {
                  return buildNetworkTitle();
                }
                index--;
                return buildNetworkFolder(networkFolders[index]);
              },
            ),
          )
        ],
      ),
    );
  }

  Widget buildLocalTitle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.local_activity,
            color: Colors.grey[700],
          ),
          const SizedBox(width: 12),
          Text("本地".tl),
          const Spacer(),
          MenuButton(
            entries: [
              MenuEntry(
                icon: Icons.add,
                text: '创建收藏夹'.tl,
                onClick: () {
                  newFolder().then((value) {
                    setState(() {
                      folders = LocalFavoritesManager().folderNames;
                    });
                  });
                },
              ),
              MenuEntry(
                icon: Icons.reorder,
                text: '排序'.tl,
                onClick: () {
                  sortFolders(
                    onReorder: () {
                      setState(() {
                        folders = LocalFavoritesManager().folderNames;
                      });
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ).paddingHorizontal(16),
    );
  }

  Widget buildNetworkTitle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.6,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud,
            color: Colors.grey[700],
          ),
          const SizedBox(width: 12),
          Text("网络".tl),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.settings, color: Colors.grey[700]),
            onPressed: () {
              showPopUpWidget(
                App.globalContext!,
                MultiPagesFilter("网络收藏页面".tl, 68, networkFavorites(),
                    onChange: update, helpContent: "重新排序\n长按并拖动以重新排序。".tl),
              );
            },
          ),
        ],
      ).paddingHorizontal(16),
    );
  }

  Widget buildLocalFolder(String name) {
    bool isSelected = name == favPage.folder && !favPage.isNetwork;
    int count = 0;
    if (name == _localAllFolderLabel) {
      count = LocalFavoritesManager().totalComics;
    } else {
      count = LocalFavoritesManager().folderComics(name);
    }
    var folderName = name == _localAllFolderLabel
        ? "全部".tl
        : getFavoriteDataOrNull(name)?.title ?? name;
    return InkWell(
      onTap: () {
        if (isSelected) {
          return;
        }
        favPage.setFolder(false, name);
        widget.onSelected?.call();
      },
      onLongPress: () {
        if (App.isDesktop) {
          var renderObject = context.findRenderObject() as RenderBox;
          var offset = renderObject.localToGlobal(Offset.zero);
          _showDesktopMenu(name, offset);
        } else {
          var renderObject = context.findRenderObject() as RenderBox;
          var offset = renderObject.localToGlobal(Offset.zero);
          _showMenu(name, offset);
        }
      },
      onSecondaryTapUp: (details) {
        if (App.isDesktop) {
          _showDesktopMenu(name, details.globalPosition);
        } else {
          _showMenu(name, details.globalPosition);
        }
      },
      child: Container(
        height: 42,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.36)
              : null,
          border: Border(
            left: BorderSide(
              color:
                  isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(folderName),
            ),
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(count.toString()),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildNetworkFolder(String key) {
    var data = getFavoriteDataOrNull(key);
    if (data == null) {
      return const SizedBox();
    }
    bool isSelected = key == favPage.folder && favPage.isNetwork;
    return InkWell(
      onTap: () {
        if (isSelected) {
          return;
        }
        favPage.setFolder(true, key);
        widget.onSelected?.call();
      },
      child: Container(
        height: 42,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.36)
              : null,
          border: Border(
            left: BorderSide(
              color:
                  isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 16),
        child: Text(data.title),
      ),
    );
  }

  @override
  void update() {
    if (!mounted) return;
    setState(() {
      findNetworkFolders();
    });
  }

  @override
  void updateFolders() {
    if (!mounted) return;
    setState(() {
      folders = LocalFavoritesManager().folderNames;
      findNetworkFolders();
    });
  }

  void _showMenu(String folder, Offset location) {
    showMenu(
        context: App.globalContext!,
        position: RelativeRect.fromLTRB(
            location.dx, location.dy, location.dx, location.dy),
        items: [
          PopupMenuItem(
            child: Text("删除".tl),
            onTap: () {
              App.globalBack();
              _deleteFolder(folder);
            },
          ),
          PopupMenuItem(
            child: Text("排序".tl),
            onTap: () {
              App.globalBack();
              App.globalTo(() => LocalFavoritesFolder(folder))
                  .then((value) => updateFolders());
            },
          ),
          PopupMenuItem(
            child: Text("重命名".tl),
            onTap: () {
              App.globalBack();
              _rename(folder);
            },
          ),
          PopupMenuItem(
            child: Text("检查漫画存活".tl),
            onTap: () {
              App.globalBack();
              checkFolder(folder).then((value) {
                updateFolders();
              });
            },
          ),
          PopupMenuItem(
            child: Text("导出".tl),
            onTap: () {
              App.globalBack();
              _export(folder);
            },
          ),
          PopupMenuItem(
            child: Text("下载全部".tl),
            onTap: () {
              App.globalBack();
              _addDownload(folder);
            },
          ),
          PopupMenuItem(
            child: Text("更新漫画信息".tl),
            onTap: () {
              App.globalBack();
              var comics = LocalFavoritesManager().getAllComics(folder);
              UpdateFavoritesInfoDialog.show(comics, folder);
            },
          ),
        ]);
  }

  void _showDesktopMenu(String folder, Offset location) {
    showDesktopMenu(App.globalContext!, location, [
      DesktopMenuEntry(
          text: "删除".tl,
          onClick: () {
            _deleteFolder(folder);
          }),
      DesktopMenuEntry(
          text: "排序".tl,
          onClick: () {
            App.globalTo(() => LocalFavoritesFolder(folder))
                .then((value) => updateFolders());
          }),
      DesktopMenuEntry(
          text: "重命名".tl,
          onClick: () {
            _rename(folder);
          }),
      DesktopMenuEntry(
          text: "检查漫画存活".tl,
          onClick: () {
            checkFolder(folder).then((value) {
              updateFolders();
            });
          }),
      DesktopMenuEntry(
          text: "导出".tl,
          onClick: () {
            _export(folder);
          }),
      DesktopMenuEntry(
          text: "下载全部".tl,
          onClick: () {
            _addDownload(folder);
          }),
      DesktopMenuEntry(
          text: "更新漫画信息".tl,
          onClick: () {
            var comics = LocalFavoritesManager().getAllComics(folder);
            UpdateFavoritesInfoDialog.show(comics, folder);
          }),
    ]);
  }

  void _deleteFolder(String folder) {
    showConfirmDialog(
      context: App.globalContext!,
      title: "确认删除".tl,
      content: "此操作无法撤销, 是否继续?".tl,
      onConfirm: () {
        App.globalBack();
        LocalFavoritesManager().deleteFolder(folder);
        updateFolders();
      },
    );
  }

  void _rename(String folder) async {
    await showDialog(
        context: App.globalContext!,
        builder: (context) => RenameFolderDialog(folder));
    updateFolders();
  }

  void _export(String folder) async {
    var controller = showLoadingDialog(
      App.globalContext!,
      onCancel: () {},
      message: "正在导出".tl,
    );
    try {
      await exportStringDataAsFile(
          LocalFavoritesManager().folderToJsonString(folder), "$folder.json");
      controller.close();
    } catch (e, s) {
      controller.close();
      showToast(message: e.toString());
      log("$e\n$s", "IO", LogLevel.error);
    }
  }

  void _addDownload(String folder) {
    for (var comic in LocalFavoritesManager().getAllComics(folder)) {
      comic.addDownload();
    }
    showToast(message: "已添加下载任务".tl);
  }
}
