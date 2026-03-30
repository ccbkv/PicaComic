part of 'favorites_page.dart';

Future<bool> _deleteComic(
  String cid,
  String? fid,
  String sourceKey,
  String? favId,
) async {
  var source = ComicSource.find(sourceKey);
  if (source == null) {
    return false;
  }

  var result = false;

  await showDialog(
    context: App.globalContext!,
    builder: (context) {
      bool loading = false;
      return StatefulBuilder(builder: (context, setState) {
        return ContentDialog(
          title: "Remove".tl,
          content: Text("从收藏中移除漫画".tl).paddingHorizontal(16),
          actions: [
            Button.filled(
              isLoading: loading,
              color: Theme.of(context).colorScheme.error,
              onPressed: () async {
                setState(() {
                  loading = true;
                });
                if (source.favoriteData?.addOrDelFavorite != null) {
                  var res = await source.favoriteData!.addOrDelFavorite!(
                    cid,
                    fid ?? '',
                    false,
                  );
                  if (!res.error) {
                    showToast(message: "Deleted".tl);
                    result = true;
                    Navigator.of(context).pop();
                  } else {
                    setState(() {
                      loading = false;
                    });
                    showToast(message: res.errorMessage ?? "Error");
                  }
                }
              },
              child: Text("Confirm".tl),
            ),
          ],
        );
      });
    },
  );

  return result;
}

class NetworkFavoritePage extends StatelessWidget {
  const NetworkFavoritePage(this.data, {super.key});

  final FavoriteData data;

  @override
  Widget build(BuildContext context) {
    return data.multiFolder
        ? _MultiFolderFavoritesPage(data)
        : _NormalFavoritePage(data);
  }
}

class _NormalFavoritePage extends StatefulWidget {
  const _NormalFavoritePage(this.data);

  final FavoriteData data;

  @override
  State<_NormalFavoritePage> createState() => _NormalFavoritePageState();
}

class _NormalFavoritePageState extends State<_NormalFavoritePage> {
  void showFolders() {
    context
        .findAncestorStateOfType<_FavoritesPageState>()!
        .showFolderSelector();
  }

  @override
  Widget build(BuildContext context) {
    return _NormalFavoriteComicsPage(widget.data, showFolders);
  }
}

class _NormalFavoriteComicsPage extends ComicsPage<BaseComic> {
  _NormalFavoriteComicsPage(this.data, this.showFolders);

  final FavoriteData data;
  final VoidCallback showFolders;

  @override
  String? get title => null;

  @override
  bool get centerTitle => false;

  @override
  Future<Res<List<BaseComic>>> getComics(int i) {
    return data.loadComic(i);
  }

  @override
  String get sourceKey => data.key;

  @override
  String? get tag => "Network Comics Page: ${data.title}";

  @override
  Widget? get header {
    final context = App.globalContext!;
    final shouldShowMenuButton = MediaQuery.of(context).size.width <= _kTwoPanelChangeWidth;
    final isMobileView = MediaQuery.of(context).size.width <= changePoint;
    return SliverPersistentHeader(
      pinned: true,
      delegate: _NetworkFavoritesAppBarDelegate(
        title: data.title,
        topPadding: isMobileView ? 0 : MediaQuery.of(context).padding.top,
        leading: shouldShowMenuButton
            ? IconButton(
                icon: const Icon(Icons.menu),
                color: Theme.of(context).colorScheme.primary,
                onPressed: showFolders,
              )
            : null,
        actions: [
          Tooltip(
            message: "刷新".tl,
            child: IconButton(
              icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onSurfaceVariant),
              onPressed: () {
                refresh();
              },
            ),
          ),
          MenuButton(entries: [
            MenuEntry(
              icon: Icons.sync,
              text: "转换为本地".tl,
              onClick: () {
                importNetworkFolder(data.key, 9999999, null, null);
              },
            )
          ]),
        ],
      ),
    );
  }
}

class _NetworkFavoritesAppBarDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final Widget? leading;
  final List<Widget> actions;
  final double topPadding;

  _NetworkFavoritesAppBarDelegate({
    required this.title,
    this.leading,
    required this.actions,
    required this.topPadding,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: shrinkOffset > 0 ? 2 : 0,
        child: Row(
          children: [
            const SizedBox(width: 8),
            leading ?? (Navigator.of(context).canPop()
                ? Tooltip(
                    message: "返回".tl,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                  )
                : const SizedBox()),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            ...actions,
            const SizedBox(width: 8),
          ],
        ).paddingTop(topPadding),
      ),
    );
  }

  @override
  double get maxExtent => 52.0 + topPadding;

  @override
  double get minExtent => 52.0 + topPadding;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return oldDelegate is! _NetworkFavoritesAppBarDelegate ||
        title != oldDelegate.title ||
        leading != oldDelegate.leading ||
        actions != oldDelegate.actions;
  }
}

class _MultiFolderFavoritesPage extends StatefulWidget {
  const _MultiFolderFavoritesPage(this.data);

  final FavoriteData data;

  @override
  State<_MultiFolderFavoritesPage> createState() =>
      _MultiFolderFavoritesPageState();
}

class _MultiFolderFavoritesPageState extends State<_MultiFolderFavoritesPage> {
  bool _loading = true;

  String? _errorMessage;

  Map<String, String>? folders;

  void showFolders() {
    context
        .findAncestorStateOfType<_FavoritesPageState>()!
        .showFolderSelector();
  }

  void loadPage() async {
    if (widget.data.loadFolders != null) {
      var res = await widget.data.loadFolders!();
      if (!mounted) return;
      _loading = false;
      if (res.error) {
        setState(() {
          _errorMessage = res.errorMessage;
        });
      } else {
        setState(() {
          folders = res.data;
        });
      }
    }
  }

  void openFolder(String key, String title) {
    context.to(() => _FavoriteFolder(widget.data, key, title));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      loadPage();
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _NetworkFavoritesAppBarDelegate(
                title: widget.data.title,
                topPadding: MediaQuery.of(context).size.width <= changePoint ? 0 : MediaQuery.of(context).padding.top,
                leading: MediaQuery.of(context).size.width <= _kTwoPanelChangeWidth
                    ? IconButton(
                        icon: const Icon(Icons.menu),
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: showFolders,
                      )
                    : null,
                actions: const [],
              ),
            ),
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ),
      );
    } else if (_errorMessage != null) {
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _NetworkFavoritesAppBarDelegate(
                title: widget.data.title,
                topPadding: MediaQuery.of(context).size.width <= changePoint ? 0 : MediaQuery.of(context).padding.top,
                leading: MediaQuery.of(context).size.width <= _kTwoPanelChangeWidth
                    ? IconButton(
                        icon: const Icon(Icons.menu),
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: showFolders,
                      )
                    : null,
                actions: const [],
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: NetworkError(
                message: _errorMessage!,
                retry: () {
                  setState(() {
                    _loading = true;
                    _errorMessage = null;
                  });
                },
                withAppbar: false,
              ),
            ),
          ],
        ),
      );
    } else {
      var length = folders!.length;
      if (widget.data.allFavoritesId != null) length++;
      final keys = folders!.keys.toList();

      return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _NetworkFavoritesAppBarDelegate(
                title: widget.data.title,
                topPadding: MediaQuery.of(context).size.width <= changePoint ? 0 : MediaQuery.of(context).padding.top,
                leading: MediaQuery.of(context).size.width <= _kTwoPanelChangeWidth
                    ? IconButton(
                        icon: const Icon(Icons.menu),
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: showFolders,
                      )
                    : null,
                actions: const [],
              ),
            ),
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 450,
              mainAxisExtent: 52,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                if (widget.data.allFavoritesId != null) {
                  if (i == 0) {
                    return _FolderTile(
                        name: "All".tl,
                        onTap: () =>
                            openFolder(widget.data.allFavoritesId!, "All".tl));
                  } else {
                    i--;
                    return _FolderTile(
                      name: folders![keys[i]]!,
                      onTap: () => openFolder(keys[i], folders![keys[i]]!),
                      deleteFolder: widget.data.deleteFolder == null
                          ? null
                          : () => widget.data.deleteFolder!(keys[i]),
                      updateState: () => setState(() {
                        _loading = true;
                      }),
                    );
                  }
                } else {
                  return _FolderTile(
                    name: folders![keys[i]]!,
                    onTap: () => openFolder(keys[i], folders![keys[i]]!),
                    deleteFolder: widget.data.deleteFolder == null
                        ? null
                        : () => widget.data.deleteFolder!(keys[i]),
                    updateState: () => setState(() {
                      _loading = true;
                    }),
                  );
                }
              },
              childCount: length,
            ),
          ),
          if (widget.data.addFolder != null)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 60,
                width: double.infinity,
                child: Center(
                  child: TextButton(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("新建收藏夹".tl),
                        const Icon(
                          Icons.add,
                          size: 18,
                        ),
                      ],
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return _CreateFolderDialog(
                            widget.data,
                            () => setState(() {
                              _loading = true;
                            }),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.name,
    required this.onTap,
    this.deleteFolder,
    this.updateState,
  });

  final String name;

  final Future<Res<bool>> Function()? deleteFolder;

  final void Function()? updateState;

  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Icon(
                Icons.folder,
                size: 28,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(
                width: 16,
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              if (deleteFolder != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => onDeleteFolder(context),
                )
              else
                const Icon(Icons.arrow_right),
            ],
          ),
        ),
      ),
    );
  }

  void onDeleteFolder(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        bool loading = false;
        return StatefulBuilder(builder: (context, setState) {
          return ContentDialog(
            title: "Delete".tl,
            content: Text("Delete folder?".tl).paddingHorizontal(16),
            actions: [
              Button.filled(
                isLoading: loading,
                color: Theme.of(context).colorScheme.error,
                onPressed: () async {
                  setState(() {
                    loading = true;
                  });
                  var res = await deleteFolder!();
                  if (!res.error) {
                    showToast(message: "Deleted".tl);
                    Navigator.of(context).pop();
                    updateState?.call();
                  } else {
                    setState(() {
                      loading = false;
                    });
                    showToast(message: res.errorMessage ?? "Error");
                  }
                },
                child: Text("Confirm".tl),
              ),
            ],
          );
        });
      },
    );
  }
}

class _CreateFolderDialog extends StatefulWidget {
  const _CreateFolderDialog(this.data, this.updateState);

  final FavoriteData data;

  final void Function() updateState;

  @override
  State<_CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<_CreateFolderDialog> {
  var controller = TextEditingController();
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: "新建收藏夹".tl,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: "名称".tl,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
      actions: [
        Button.filled(
          isLoading: loading,
          onPressed: () {
            if (widget.data.addFolder != null) {
              setState(() {
                loading = true;
              });
              widget.data.addFolder!(controller.text).then((b) {
                if (b.error) {
                  showToast(message: b.errorMessage ?? "Error");
                  setState(() {
                    loading = false;
                  });
                } else {
                  Navigator.of(context).pop();
                  showToast(message: "创建成功".tl);
                  widget.updateState();
                }
              });
            }
          },
          child: Text("提交".tl),
        ),
      ],
    );
  }
}

class _FavoriteFolder extends StatefulWidget {
  const _FavoriteFolder(this.data, this.folderID, this.folderTitle);

  final FavoriteData data;
  final String folderID;
  final String folderTitle;

  @override
  State<_FavoriteFolder> createState() => _FavoriteFolderState();
}

class _FavoriteFolderState extends State<_FavoriteFolder> {
  void showFolders() {
    App.globalContext
        ?.findAncestorStateOfType<_FavoritesPageState>()
        ?.showFolderSelector();
  }

  @override
  Widget build(BuildContext context) {
    return _FavoriteFolderComicsPage(
        widget.data, widget.folderID, widget.folderTitle, showFolders);
  }
}

class _FavoriteFolderComicsPage extends ComicsPage<BaseComic> {
  _FavoriteFolderComicsPage(
      this.data, this.folderID, this.folderTitle, this.showFolders);

  final FavoriteData data;
  final String folderID;
  final String folderTitle;
  final VoidCallback showFolders;

  @override
  String? get title => null;

  @override
  bool get centerTitle => false;

  @override
  Future<Res<List<BaseComic>>> getComics(int i) {
    return data.loadComic(i, folderID);
  }

  @override
  String get sourceKey => data.key;

  @override
  String? get tag => "Favorites Folder $folderID";

  @override
  Widget? get header {
    final context = App.globalContext!;
    final shouldShowMenuButton = MediaQuery.of(context).size.width <= _kTwoPanelChangeWidth;
    final isMobileView = MediaQuery.of(context).size.width <= changePoint;
    return SliverPersistentHeader(
      pinned: true,
      delegate: _NetworkFavoritesAppBarDelegate(
        title: folderTitle,
        topPadding: isMobileView ? 0 : MediaQuery.of(context).padding.top,
        leading: shouldShowMenuButton
                ? Tooltip(
                    message: "返回".tl,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => App.mainNavigatorKey?.currentState?.pop(),
                    ),
                  )
            : null,
        actions: [
          MenuButton(entries: [
            MenuEntry(
              icon: Icons.sync,
              text: "转换为本地".tl,
              onClick: () {
                importNetworkFolder(data.key, 9999999, folderTitle, folderID);
              },
            )
          ]),
        ],
      ),
    );
  }
} 