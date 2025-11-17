part of 'components.dart';

///显示侧边栏的变换
///
/// 此组件会自动适应窗口大小:
/// 大于600显示为右侧的侧边栏
/// 小于600显示为从侧边划入的页面
class SideBarRoute<T> extends PopupRoute<T> {
  SideBarRoute(this.title, this.widget,
      {this.showBarrier = true,
      this.useSurfaceTintColor = false,
      required this.width,
      this.addBottomPadding = true,
      this.addTopPadding = true});

  ///标题
  final String? title;

  ///子组件
  final Widget widget;

  ///是否显示Barrier
  final bool showBarrier;

  ///使用SurfaceTintColor作为背景色
  final bool useSurfaceTintColor;

  ///宽度
  final double width;

  final bool addTopPadding;

  final bool addBottomPadding;



  @override
  void install() {
    super.install();
    Future.delayed(const Duration(milliseconds: 500), () {
      _barrierDismissible = true;
      changedInternalState();
    });
  }

  @override
  Color? get barrierColor => showBarrier ? Colors.black54 : Colors.transparent;

  @override
  bool _barrierDismissible = false;

  @override
  bool get barrierDismissible => _barrierDismissible;

  @override
  String? get barrierLabel => "exit";

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    bool showSideBar = MediaQuery.of(context).size.width > width;

    Widget body = SidebarBody(
      title: title,
      widget: widget,
      autoChangeTitleBarColor: !useSurfaceTintColor,
    );

    if (addTopPadding) {
      body = Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: body,
        ),
      );
    }

    final sideBarWidth = math.min(width, MediaQuery.of(context).size.width);

    body = Container(
      decoration: BoxDecoration(
          borderRadius: showSideBar
              ? const BorderRadius.horizontal(left: Radius.circular(16))
              : null,
          color: Theme.of(context).colorScheme.surfaceTint),
      clipBehavior: Clip.antiAlias,
      constraints: BoxConstraints(maxWidth: sideBarWidth),
      height: MediaQuery.of(context).size.height,
      child: GestureDetector(
        child: Material(
          child: ClipRect(
            clipBehavior: Clip.antiAlias,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  0,
                  0,
                  MediaQuery.of(context).padding.right,
                  addBottomPadding
                      ? MediaQuery.of(context).padding.bottom +
                          MediaQuery.of(context).viewInsets.bottom
                      : 0),
              color: useSurfaceTintColor
                  ? Theme.of(context).colorScheme.surfaceTint.withAlpha(20)
                  : null,
              child: body,
            ),
          ),
        ),
      ),
    );

    if (App.isIOS) {
      body = IOSBackGestureDetector(
        enabledCallback: () => true,
        gestureWidth: 20.0,
        onStartPopGesture: () => IOSBackGestureController(controller!, navigator!),
        child: body,
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: body,
    );
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    var offset =
        Tween<Offset>(begin: const Offset(1, 0), end: const Offset(0, 0));
    return SlideTransition(
      position: offset.animate(CurvedAnimation(
        parent: animation,
        curve: Curves.fastOutSlowIn,
      )),
      child: child,
    );
  }
}





class SidebarBody extends StatefulWidget {
  const SidebarBody(
      {required this.title,
      required this.widget,
      required this.autoChangeTitleBarColor,
      super.key});

  final String? title;
  final Widget widget;
  final bool autoChangeTitleBarColor;

  @override
  State<SidebarBody> createState() => _SidebarBodyState();
}

class _SidebarBodyState extends State<SidebarBody> {
  bool top = true;

  @override
  Widget build(BuildContext context) {
    Widget body = Expanded(child: widget.widget);

    if (widget.autoChangeTitleBarColor) {
      body = NotificationListener<ScrollNotification>(
        onNotification: (notifications) {
          if (notifications.metrics.pixels ==
                  notifications.metrics.minScrollExtent &&
              !top) {
            setState(() {
              top = true;
            });
          } else if (notifications.metrics.pixels !=
                  notifications.metrics.minScrollExtent &&
              top) {
            setState(() {
              top = false;
            });
          }
          return false;
        },
        child: body,
      );
    }

    return Column(
      children: [
        if (widget.title != null)
          Container(
            height: 60 + MediaQuery.of(context).padding.top,
            color: top
                ? null
                : Theme.of(context).colorScheme.surfaceTint.withAlpha(20),
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: Row(
              children: [
                const SizedBox(
                  width: 8,
                ),
                Tooltip(
                  message: "返回",
                  child: IconButton(
                    iconSize: 25,
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Text(
                  widget.title!,
                  style: const TextStyle(fontSize: 22),
                )
              ],
            ),
          ),
        body
      ],
    );
  }
}

///显示侧边栏
///
/// 此组件会自动适应窗口大小:
/// 大于600显示为右侧的侧边栏
/// 小于600显示为从侧边划入的页面
///
/// [width] 侧边栏的宽度
///
/// [title] 标题, 为空时不显示顶部的Appbar
void showSideBar(BuildContext context, Widget widget,
    {String? title,
    bool showBarrier = true,
    bool useSurfaceTintColor = false,
    double width = 500,
    bool addTopPadding = false}) {
  Navigator.of(context).push(SideBarRoute(title, widget,
      showBarrier: showBarrier,
      useSurfaceTintColor: useSurfaceTintColor,
      width: width,
      addTopPadding: addTopPadding,
      addBottomPadding: true));
}

/// 收藏夹侧边栏组件，基于venera-master的实现适配到PicaComic
class FavoritesSideBar extends StatefulWidget {
  const FavoritesSideBar({
    super.key,
    this.onSelected,
    this.withAppbar = false,
    this.initialFolder,
    this.isNetwork = false,
    this.onFolderSelected,
  });

  final VoidCallback? onSelected;

  final bool withAppbar;

  final String? initialFolder;

  final bool isNetwork;

  final Function(String folderId, bool isNetwork)? onFolderSelected;

  @override
  State<FavoritesSideBar> createState() => _FavoritesSideBarState();
}

class _FavoritesSideBarState extends State<FavoritesSideBar> {
  var folders = <String>[];

  var networkFolders = <String>[];

  String? selectedFolder;
  bool selectedIsNetwork = false;

  void findNetworkFolders() {
    networkFolders.clear();
    // 使用与main_favorites_page.dart相同的方式获取网络收藏夹
    var folders = appdata.appSettings.networkFavorites
        .map((e) => getFavoriteDataOrNull(e));
    folders = folders.whereType<FavoriteData>();
    
    for (var data in folders) {
      if (data != null && !networkFolders.contains(data.key)) {
        networkFolders.add(data.key);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    folders = LocalFavoritesManager().folderNames;
    findNetworkFolders();
    selectedFolder = widget.initialFolder;
    selectedIsNetwork = widget.isNetwork;
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
            color: Theme.of(context).colorScheme.outlineVariant,
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
                    "Folders".tl,
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
              itemCount: folders.length + networkFolders.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return buildLocalTitle();
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
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 12),
          Text("Local".tl),
          const Spacer(),
          MenuButton(
            entries: [
              DesktopMenuEntry(
                icon: Icons.add,
                text: 'Create Folder'.tl,
                onClick: () {
                  newFolder().then((value) {
                    setState(() {
                      folders = LocalFavoritesManager().folderNames;
                    });
                  });
                },
              ),
              DesktopMenuEntry(
                icon: Icons.reorder,
                text: 'Sort'.tl,
                onClick: () {
                  sortFolders().then((value) {
                    setState(() {
                      folders = LocalFavoritesManager().folderNames;
                    });
                  });
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
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.6,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 12),
          Text("Network".tl),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // 空实现，保持兼容性
            },
          ),
        ],
      ).paddingHorizontal(16),
    );
  }

  Widget buildLocalFolder(String name) {
    bool isSelected = name == selectedFolder && !selectedIsNetwork;
    int count = LocalFavoritesManager().folderComics(name);
    var folderName = getFavoriteDataOrNull(name)?.title ?? name;
    return InkWell(
      onTap: () {
        if (isSelected) {
          return;
        }
        setState(() {
          selectedFolder = name;
          selectedIsNetwork = false;
        });
        // 调用新的回调，传递选中的文件夹信息
        widget.onFolderSelected?.call(name, false);
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
                color: Theme.of(context).colorScheme.surfaceContainer,
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
    bool isSelected = key == selectedFolder && selectedIsNetwork;
    return InkWell(
      onTap: () {
        if (isSelected) {
          return;
        }
        setState(() {
          selectedFolder = key;
          selectedIsNetwork = true;
        });
        // 调用新的回调，传递选中的文件夹信息
        widget.onFolderSelected?.call(key, true);
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

  void updateFolders() {
    if (!mounted) return;
    setState(() {
      folders = LocalFavoritesManager().folderNames;
      findNetworkFolders();
    });
  }

  void setFavoritesPagesWidget() {
    // 空实现，保持兼容性
  }
}

Future<void> newFolder() async {
  return showDialog(
      context: App.globalContext!,
      builder: (context) {
        var controller = TextEditingController();
        String? error;

        return StatefulBuilder(builder: (context, setState) {
          return SimpleDialog(
            title: Text("创建收藏夹".tl),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: "名称".tl,
                    errorText: error,
                  ),
                  onChanged: (s) {
                    if (error != null) {
                      setState(() {
                        error = null;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              SizedBox(
                width: 260,
                child: Row(
                  children: [
                    const Spacer(),
                    TextButton(
                      child: Text("从文件导入".tl),
                      onPressed: () async {
                        context.pop();
                        var data = await getDataFromUserSelectedFile(["json"]);
                        if (data == null) {
                          return;
                        }
                        var (error, message) =
                            LocalFavoritesManager().loadFolderData(data);
                        if (error) {
                          showToast(message: message);
                        } else {
                          StateController.find(tag: "me page").update();
                        }
                      },
                    ),
                    const Spacer(),
                    TextButton(
                      child: Text("从网络导入".tl),
                      onPressed: () async {
                        App.globalBack();
                        await Future.delayed(const Duration(milliseconds: 200));
                        networkToLocal();
                      },
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              SizedBox(
                height: 35,
                child: Center(
                  child: FilledButton(
                    onPressed: () {
                      var e = validateFolderName(controller.text);
                      if (e != null) {
                        setState(() {
                          error = e;
                        });
                      } else {
                        LocalFavoritesManager().createFolder(controller.text);
                        App.globalBack();
                      }
                    },
                    child: Text("提交".tl),
                  ),
                ),
              ),
            ],
          );
        });
      });
}

String? validateFolderName(String newFolderName) {
  var folders = LocalFavoritesManager().folderNames;
  if (newFolderName.isEmpty) {
    return "Folder name cannot be empty".tl;
  } else if (newFolderName.length > 50) {
    return "Folder name is too long".tl;
  } else if (folders.contains(newFolderName)) {
    return "Folder already exists".tl;
  }
  return null;
}

Future<void> sortFolders() async {
  var folders = LocalFavoritesManager().folderNames;

  await showDialog(
    context: App.globalContext!,
    builder: (context) {
      return StatefulBuilder(builder: (context, setState) {
        return SimpleDialog(
          title: Text("排序".tl),
          children: [
            SizedBox(
              width: 300,
              height: 400,
              child: ReorderableListView.builder(
                onReorder: (oldIndex, newIndex) {
                  if (oldIndex < newIndex) {
                    newIndex--;
                  }
                  setState(() {
                    var item = folders.removeAt(oldIndex);
                    folders.insert(newIndex, item);
                  });
                },
                itemCount: folders.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    key: ValueKey(folders[index]),
                    title: Text(folders[index]),
                    leading: const Icon(Icons.drag_handle),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text("取消".tl),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: () {
                    // 创建文件夹顺序映射
                    Map<String, int> folderOrder = {};
                    for (int i = 0; i < folders.length; i++) {
                      folderOrder[folders[i]] = i;
                    }
                    LocalFavoritesManager().updateOrder(folderOrder);
                    Navigator.of(context).pop();
                  },
                  child: Text("确定".tl),
                ),
              ],
            ),
          ],
        );
      });
    },
  );
}
