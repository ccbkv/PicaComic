import "dart:async";

import "package:collection/collection.dart";
import "package:flutter/material.dart";
import "package:flutter_reorderable_grid_view/widgets/reorderable_builder.dart";
import "package:pica_comic/base.dart";
import "package:pica_comic/comic_source/comic_source.dart";
import 'package:pica_comic/components/components.dart';
import "package:pica_comic/foundation/app.dart";
import "package:pica_comic/foundation/local_favorites.dart";
import "package:pica_comic/foundation/log.dart";
import "package:pica_comic/network/download.dart";
import "package:pica_comic/tools/translations.dart";

import "../../network/net_fav_to_local.dart";
import "../../tools/io_tools.dart";
import "../settings/settings_page.dart";
import "local_favorites.dart";
import "local_search_page.dart";
import "network_favorite_page.dart";

class FavoritesPageController extends StateController {
  String? current;

  bool? isNetwork;

  bool selectingFolder = true;

  FavoriteData? networkData;

  var selectedComics = <FavoriteItem>[];

  var openComicMenuFuncs = <FavoriteItem, Function>{};

  bool get isSelectingComics => selectedComics.isNotEmpty;

  // 添加状态变量跟踪侧边栏是否已经消失
  bool isSidebarHidden = false;

  FavoritesPageController() {
    var data = appdata.implicitData[0].split(";");
    selectingFolder = data[0] == "1";
    if (data[1] == "") {
      isNetwork = null;
    } else {
      isNetwork = data[1] == "1";
    }
    if (data.length > 3) {
      current = data.sublist(2).join(";");
    } else {
      current = data[2];
    }
    if (current == "") {
      current = null;
    }
    if (isNetwork ?? false) {
      final folders =
          appdata.settings[68].split(',').map((e) => getFavoriteDataOrNull(e));
      networkData =
          folders.firstWhereOrNull((element) => element?.title == current);
      if (networkData == null) {
        current = null;
        selectingFolder = true;
        isNetwork = null;
      }
    }
  }

  @override
  void update([List<Object>? ids]) {
    if (selectedComics.isEmpty) {
      openComicMenuFuncs.clear();
    }
    super.update(ids);
  }

  // 添加方法来设置侧边栏隐藏状态
  void setSidebarHidden(bool hidden) {
    isSidebarHidden = hidden;
    update();
  }
}

const _kSecondaryTopBarHeight = 48.0;
const _kTopBarHeight = 56.0;

class FavoritesPage extends StatelessWidget with _LocalFavoritesManager {
  FavoritesPage({super.key});

  final controller = StateController.putIfNotExists<FavoritesPageController>(
      FavoritesPageController());

  @override
  Widget build(BuildContext context) {
    return StateBuilder<FavoritesPageController>(builder: (controller) {
      return buildPage(context);
    });
  }

  Widget buildPage(BuildContext context) {
    return LayoutBuilder(builder: (context, constrains) {
      // 根据屏幕宽度决定侧边栏宽度
      final sidebarWidth =
          constrains.maxWidth < 600 ? constrains.maxWidth * 0.3 : 280.0;
      final isSmallScreen = constrains.maxWidth < 768;

      // 使用 addPostFrameCallback 延迟状态更新，避免在构建过程中调用 setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isSmallScreen && !controller.isSidebarHidden) {
          controller.setSidebarHidden(true);
        } else if (!isSmallScreen && controller.isSidebarHidden) {
          controller.setSidebarHidden(false);
        }
      });

      return Stack(
        children: [
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            bottom: 0,
            child: Row(
              children: [
                // 左侧文件夹侧边栏
                SizedBox(
                  width: isSmallScreen ? 0 : sidebarWidth,
                  child: isSmallScreen
                      ? const SizedBox.shrink()
                      : Material(
                          elevation: 1,
                          color: Theme.of(context).colorScheme.surface,
                          child: buildFoldersList(context),
                        ),
                ),
                // 右侧内容区域
                Expanded(
                  child: Padding(
                    // 添加顶部内边距，避免内容被顶部栏遮挡
                    padding: EdgeInsets.only(top: _kTopBarHeight),
                    child: controller.current != null
                        ? buildContent(context)
                        : Container(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.folder_open,
                                    size: 64,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "请选择一个收藏夹".tl,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: isSmallScreen ? 0 : sidebarWidth, // 根据屏幕大小调整位置
            right: 0,
            child: buildTopBar(context),
          ),
        ],
      );
    });
  }

  void multiSelectedMenu() {
    final size = MediaQuery.of(App.globalContext!).size;
    showMenu(
        context: App.globalContext!,
        position: RelativeRect.fromLTRB(size.width, 0, 0, size.height),
        items: [
          PopupMenuItem(
            child: Text("删除".tl),
            onTap: () {
              for (var comic in controller.selectedComics) {
                LocalFavoritesManager().deleteComic(controller.current!, comic);
              }
              controller.selectedComics.clear();
              controller.update();
            },
          ),
          PopupMenuItem(
            child: Text("复制到".tl),
            onTap: () {
              Future.delayed(
                const Duration(milliseconds: 200),
                () => copyAllTo(controller.current!, controller.selectedComics),
              );
            },
          ),
          PopupMenuItem(
            child: Text("下载".tl),
            onTap: () {
              Future.delayed(
                const Duration(milliseconds: 200),
                () {
                  var comics = controller.selectedComics;
                  for (var comic in comics) {
                    DownloadManager().addFavoriteDownload(comic);
                  }
                  showToast(message: "已添加下载任务".tl);
                },
              );
            },
          ),
          PopupMenuItem(
            child: Text("更新漫画信息".tl),
            onTap: () {
              Future.delayed(
                const Duration(milliseconds: 200),
                () {
                  var comics = controller.selectedComics;
                  UpdateFavoritesInfoDialog.show(comics, controller.current!);
                },
              );
            },
          ),
        ]);
  }

  Widget buildTopBar(BuildContext context) {
    final iconColor = Theme.of(context).colorScheme.primary;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 1024;

    if (controller.isSelectingComics) {
      return Material(
        elevation: 1,
        color: Theme.of(context).colorScheme.surface,
        child: SizedBox(
          height: _kSecondaryTopBarHeight,
          child: Row(children: [
            if (controller.isSidebarHidden) ...[
              // 在侧边栏隐藏后才显示菜单按钮
              IconButton(
                icon: const Icon(Icons.reorder),
                onPressed: () {
                  _showFoldersDrawer(context);
                },
              ),
            ] else ...[
              // 在大屏幕上保持原有左边距
              const SizedBox(width: 16),
            ],
            Icon(
              Icons.rule_folder,
              color: iconColor,
            ),
            const SizedBox(
              width: 8,
            ),
            Expanded(
              child: Text(
                "已选择 @num 个项目".tlParams(
                    {"num": controller.selectedComics.length.toString()}),
                style: const TextStyle(fontSize: 16),
              ).paddingBottom(3),
            ),
            Tooltip(
              message: "全选".tl,
              child: IconButton(
                icon: const Icon(Icons.select_all),
                onPressed: () {
                  controller.selectedComics = LocalFavoritesManager()
                      .getAllComics(controller.current!)
                      .toList();
                  controller.update();
                },
              ),
            ),
            Tooltip(
              message: "取消".tl,
              child: IconButton(
                icon: const Icon(Icons.deselect),
                onPressed: () {
                  controller.selectedComics.clear();
                  controller.update();
                },
              ),
            ),
            Tooltip(
              message: "菜单".tl,
              child: IconButton(
                icon: const Icon(Icons.more_horiz),
                onPressed: () {
                  if (controller.selectedComics.length == 1) {
                    controller.openComicMenuFuncs[controller.selectedComics[0]]
                        ?.call();
                  } else {
                    multiSelectedMenu();
                  }
                },
              ),
            ),
          ]),
        ),
      );
    }

    return Material(
      elevation: 1,
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        height: _kSecondaryTopBarHeight,
        child: Row(children: [
          if (controller.isSidebarHidden) ...[
            // 在侧边栏隐藏后才显示菜单按钮
            IconButton(
              icon: const Icon(Icons.reorder),
              onPressed: () {
                _showFoldersDrawer(context);
              },
            ),
          ] else ...[
            // 在大屏幕上保持原有左边距
            const SizedBox(width: 16),
          ],
          if (controller.isNetwork == null)
            Icon(
              Icons.folder_outlined,
              color: iconColor,
            )
          else if (controller.isNetwork!)
            Icon(
              Icons.folder_special,
              color: iconColor,
            )
          else
            Icon(
              Icons.folder,
              color: iconColor,
            ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: Text(
              controller.current != null ? controller.current!.tl : "未选择".tl,
              style: const TextStyle(fontSize: 16),
            ).paddingBottom(3),
          ),
        ]),
      ),
    );
  }

  // 在小屏幕上显示文件夹抽屉
  void _showFoldersDrawer(BuildContext context) {
    // 使用 Drawer 替代 BottomSheet，实现从左边滑出的效果
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (BuildContext buildContext, Animation<double> animation,
          Animation<double> secondaryAnimation) {
        // 保存原始context的引用，用于按钮点击事件
        final originalContext = context;

        return StateBuilder<FavoritesPageController>(
          builder: (controller) => SlideTransition(
            position: Tween<Offset>(
            begin: const Offset(-1.0, 0.0), // 从左侧开始
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          )),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Theme.of(buildContext).colorScheme.surface,
              child: Container(
                width: 280, // 设置抽屉宽度
                height: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题栏
                    Container(
                      padding: const EdgeInsets.only(
                          top: 35, left: 16, right: 16, bottom: 16), // 进一步增加上边距
                      decoration: BoxDecoration(
                        color: Theme.of(buildContext).colorScheme.surface,
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(buildContext).dividerColor,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.folder,
                            color: Theme.of(buildContext).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "收藏夹",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(buildContext).colorScheme.onSurface,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(buildContext).pop(),
                          ),
                        ],
                      ),
                    ),
                    // 收藏夹列表
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 本地收藏夹
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(Icons.local_activity,
                                      size: 16,
                                      color: Theme.of(buildContext)
                                          .colorScheme
                                          .onSurface),
                                  const SizedBox(width: 8),
                                  Text(
                                    "本地",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(buildContext)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                  const Spacer(),
                                  Builder(
                                    builder: (context) => IconButton(
                                      icon: const Icon(Icons.more_horiz),
                                      onPressed: () {
                                        final renderBox = context
                                            .findRenderObject() as RenderBox;
                                        final offset = renderBox
                                            .localToGlobal(Offset.zero);
                                        showDesktopMenu(
                                          context,
                                          Offset(offset.dx, offset.dy),
                                          [
                                            DesktopMenuEntry(
                                              icon: Icons.add,
                                              text: '创建收藏夹'.tl,
                                              onClick: () {
                                                Future.delayed(
                                                    const Duration(
                                                        milliseconds: 0), () {
                                                  showDialog(
                                                          context: App
                                                              .globalContext!,
                                                          builder: (context) =>
                                                              const CreateFolderDialog())
                                                      .then((value) =>
                                                          controller.update());
                                                });
                                              },
                                            ),
                                            DesktopMenuEntry(
                                              icon: Icons.reorder,
                                              text: '排序'.tl,
                                              onClick: () {
                                                Future.delayed(
                                                    const Duration(
                                                        milliseconds: 0), () {
                                                  App.globalTo(() =>
                                                      const _FoldersReorderPage());
                                                });
                                              },
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            buildLocalList(),
                            const SizedBox(height: 16),
                            // 添加灰色分割线
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: Theme.of(buildContext).dividerColor,
                            ),
                            // 网络收藏夹
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(Icons.cloud,
                                      size: 16,
                                      color: Theme.of(buildContext)
                                          .colorScheme
                                          .onSurface),
                                  const SizedBox(width: 8),
                                  Text(
                                    "网络",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(buildContext)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.settings, size: 20),
                                    onPressed: () {
                                      showPopUpWidget(
                                          App.globalContext!,
                                          MultiPagesFilter(
                                              "网络收藏页面".tl,
                                              68,
                                              networkFavorites(),
                                              onChange: controller.update));
                                    },
                                  ),
                                ],
                              ),
                            ),
                            buildNetworkList(),
                          ],
                        ),
                      ),
                    ),
                    // 工具按钮
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(buildContext).colorScheme.surface,
                        border: Border(
                          top: BorderSide(
                            color: Theme.of(buildContext).dividerColor,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          // 第一行按钮
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              const SizedBox(width: 8),
                              // 搜索按钮
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(buildContext).pop(); // 关闭抽屉
                                    App.globalTo(() => const LocalSearchPage());
                                  },
                                  icon: const Icon(Icons.search, size: 16),
                                  label: const Text("搜索",
                                      style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ));
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return child;
      },
    );
  }

  Widget buildFoldersList(BuildContext context) {
    return Column(
      children: [
        // 顶部标题栏
        Container(
          height: _kSecondaryTopBarHeight,
          padding:
              const EdgeInsets.only(top: 8, left: 16, right: 16), // 进一步增加上边距
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center, // 居中对齐
            children: [
              Icon(
                Icons.folder,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                "收藏夹".tl,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Spacer(),
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.more_horiz),
                  onPressed: () {
                    final renderBox = context.findRenderObject() as RenderBox;
                    final offset = renderBox.localToGlobal(Offset.zero);
                    showDesktopMenu(
                      context,
                      Offset(offset.dx, offset.dy),
                      [
                        DesktopMenuEntry(
                          icon: Icons.add,
                          text: '创建收藏夹'.tl,
                          onClick: () {
                            Future.delayed(const Duration(milliseconds: 0), () {
                              showDialog(
                                      context: App.globalContext!,
                                      builder: (context) =>
                                          const CreateFolderDialog())
                                  .then((value) => controller.update());
                            });
                          },
                        ),
                        DesktopMenuEntry(
                          icon: Icons.reorder,
                          text: '排序'.tl,
                          onClick: () {
                            Future.delayed(const Duration(milliseconds: 0), () {
                              App.globalTo(() => const _FoldersReorderPage());
                            });
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // 文件夹列表
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 本地收藏夹
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_activity,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "本地".tl,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                buildLocalList(),
                // 网络收藏夹
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "网络".tl,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.settings, size: 20),
                        onPressed: () {
                          showPopUpWidget(
                              App.globalContext!,
                              MultiPagesFilter(
                                  "网络收藏页面".tl,
                                  68,
                                  networkFavorites(),
                                  onChange: controller.update));
                        },
                      ),
                    ],
                  ),
                ),
                buildNetworkList(),
                // 工具按钮
                buildUtils(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget buildNetwork() {
    return Column(
      children: [
        if (controller.selectingFolder) buildNetworkList(),
        if (!controller.selectingFolder) buildNetworkList(),
      ],
    );
  }

  Widget buildNetworkList() {
    var folders = appdata.appSettings.networkFavorites
        .map((e) => getFavoriteDataOrNull(e));
    folders = folders.whereType<FavoriteData>();

    return Column(
      children: folders.map((data) {
        final isSelected =
            controller.current == data?.title && controller.isNetwork == true;
        return Builder(
          builder: (context) => InkWell(
            onTap: () {
              if (controller.isSidebarHidden) {
                Navigator.of(context).pop();
              }
              Future.microtask(() {
                controller.current = data?.title;
                controller.isNetwork = true;
                controller.selectingFolder = false;
                controller.networkData = data;
                controller.update();
                appdata.implicitData[0] = "0;1;${data?.title ?? ""}";
                appdata.writeImplicitData();
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.3)
                    : null,
                border: Border(
                  left: BorderSide(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_special,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.secondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      data?.title != null ? data!.title.tl : "未知".tl,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget buildLocal() {
    return Column(
      children: [
        if (controller.selectingFolder) buildLocalList(),
        if (!controller.selectingFolder) buildLocalList(),
      ],
    );
  }

  Widget buildLocalList() {
    final folders = LocalFavoritesManager().folderNames;

    return Column(
      children: folders.map((data) {
        final isSelected =
            controller.current == data && controller.isNetwork == false;
        return Builder(
          builder: (context) => InkWell(
            onTap: () {
              if (controller.isSidebarHidden) {
                Navigator.of(context).pop();
              }
              Future.microtask(() {
                controller.current = data;
                controller.isNetwork = false;
                controller.selectingFolder = false;
                controller.update();
                appdata.implicitData[0] = "0;0;$data";
                appdata.writeImplicitData();
              });
            },
            onLongPress: () {
              // 获取点击位置并显示菜单
              final RenderBox renderBox =
                  context.findRenderObject() as RenderBox;
              final Offset tapPosition = renderBox
                  .localToGlobal(renderBox.size.centerRight(Offset.zero));
              _showMenu(data, tapPosition);
            },
            onSecondaryTapUp: (details) =>
                _showDesktopMenu(data, details.globalPosition),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.3)
                    : null,
                border: Border(
                  left: BorderSide(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.folder,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.secondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      data,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      LocalFavoritesManager().folderComics(data).toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget buildTitle(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(title, style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  Widget buildUtils(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // 搜索按钮
          Divider(
            height: 1,
            thickness: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => App.to(context, () => const LocalSearchPage()),
              icon: const Icon(Icons.search, size: 18),
              label: Text("搜索".tl),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 排序按钮

        ],
      ),
    );
  }

  Widget buildContent(BuildContext context) {
    if (controller.current == null) {
      return const SizedBox();
    } else if (controller.isNetwork!) {
      return NetworkFavoritePage(
        controller.networkData!,
        key: Key(controller.current ?? ""),
      );
    } else {
      var count = LocalFavoritesManager().count(controller.current!);
      return ComicsPageView(
        key: Key(controller.current! + count.toString()),
        folder: controller.current!,
        selectedComics: controller.selectedComics,
        onClick: (key) {
          if (controller.isSelectingComics) {
            if (controller.selectedComics.contains(key)) {
              controller.selectedComics.remove(key);
            } else {
              controller.selectedComics.add(key);
            }
            controller.update();
            return true;
          }
          return false;
        },
        onLongPressed: (key) {
          if (controller.selectedComics.contains(key)) {
            controller.selectedComics.remove(key);
          } else {
            controller.selectedComics.add(key);
          }
          controller.update();
        },
      );
    }
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
              deleteFolder(folder);
            },
          ),
          PopupMenuItem(
            child: Text("排序".tl),
            onTap: () {
              App.globalBack();
              App.globalTo(() => LocalFavoritesFolder(folder))
                  .then((value) => controller.update());
            },
          ),
          PopupMenuItem(
            child: Text("重命名".tl),
            onTap: () {
              App.globalBack();
              rename(folder);
            },
          ),
          PopupMenuItem(
            child: Text("检查漫画存活".tl),
            onTap: () {
              App.globalBack();
              checkFolder(folder).then((value) {
                controller.update();
              });
            },
          ),
          PopupMenuItem(
            child: Text("导出".tl),
            onTap: () {
              App.globalBack();
              export(folder);
            },
          ),
          PopupMenuItem(
            child: Text("下载全部".tl),
            onTap: () {
              App.globalBack();
              addDownload(folder);
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
            deleteFolder(folder);
          }),
      DesktopMenuEntry(
          text: "排序".tl,
          onClick: () {
            App.globalTo(() => LocalFavoritesFolder(folder))
                .then((value) => controller.update());
          }),
      DesktopMenuEntry(
          text: "重命名".tl,
          onClick: () {
            rename(folder);
          }),
      DesktopMenuEntry(
          text: "检查漫画存活".tl,
          onClick: () {
            checkFolder(folder).then((value) {
              controller.update();
            });
          }),
      DesktopMenuEntry(
          text: "导出".tl,
          onClick: () {
            export(folder);
          }),
      DesktopMenuEntry(
          text: "下载全部".tl,
          onClick: () {
            addDownload(folder);
          }),
      DesktopMenuEntry(
          text: "更新漫画信息".tl,
          onClick: () {
            var comics = LocalFavoritesManager().getAllComics(folder);
            UpdateFavoritesInfoDialog.show(comics, folder);
          }),
    ]);
  }
}

mixin class _LocalFavoritesManager {
  void deleteFolder(String folder) {
    showConfirmDialog(App.globalContext!, "确认删除".tl, "此操作无法撤销, 是否继续?".tl, () {
      App.globalBack();
      LocalFavoritesManager().deleteFolder(folder);
      final controller = StateController.find<FavoritesPageController>();
      if (controller.current == folder && !controller.isNetwork!) {
        controller.current = null;
        controller.isNetwork = null;
      }
      controller.update();
    });
  }

  void rename(String folder) async {
    await showDialog(
        context: App.globalContext!,
        builder: (context) => RenameFolderDialog(folder));
    StateController.find<FavoritesPageController>().update();
  }

  void export(String folder) async {
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

  void addDownload(String folder) {
    for (var comic in LocalFavoritesManager().getAllComics(folder)) {
      comic.addDownload();
    }
    showToast(message: "已添加下载任务".tl);
  }
}

class ComicsPageView extends StatefulWidget {
  const ComicsPageView(
      {required this.folder,
      required this.onClick,
      required this.selectedComics,
      required this.onLongPressed,
      super.key});

  final String folder;

  /// return true to disable default action
  final bool Function(FavoriteItem item) onClick;

  final void Function(FavoriteItem item) onLongPressed;

  final List<FavoriteItem> selectedComics;

  @override
  State<ComicsPageView> createState() => _ComicsPageViewState();
}

class _ComicsPageViewState extends StateWithController<ComicsPageView> {
  late ScrollController scrollController;
  bool showFB = true;
  double location = 0;

  String get folder => widget.folder;

  FolderSync? folderSync() {
    final folderSyncArr = LocalFavoritesManager()
        .folderSync
        .where((element) => element.folderName == folder)
        .toList();
    if (folderSyncArr.isEmpty) return null;
    return folderSyncArr[0];
  }

  late List<FavoriteItem> comics;

  @override
  void initState() {
    scrollController = ScrollController();
    scrollController.addListener(() {
      var current = scrollController.offset;

      if ((current > location && current != 0) && showFB) {
        setState(() {
          showFB = false;
        });
      } else if ((current < location || current == 0) && !showFB) {
        setState(() {
          showFB = true;
        });
      }

      location = current;
    });
    comics = LocalFavoritesManager().getAllComics(folder);
    super.initState();
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildFolderComics(folder);
  }

  void rebuild() {
    setState(() {
      comics = LocalFavoritesManager().getAllComics(folder);
    });
  }

  Future<void> onRefresh(context) async {
    return startFolderSync(context, folderSync()!);
  }

  Widget buildFolderComics(String folder) {
    if (comics.isEmpty) {
      return buildEmptyView();
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: MediaQuery.removePadding(
        key: Key(folder),
        removeTop: true,
        context: context,
        child: RefreshIndicator(
          notificationPredicate: (notify) {
            return folderSync() != null;
          },
          onRefresh: () => onRefresh(context),
          child: Scrollbar(
            controller: scrollController,
            interactive: true,
            thickness: App.isMobile ? 12 : null,
            radius: const Radius.circular(8),
            child: ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(scrollbars: false),
              child: SmoothScrollProvider(
                controller: scrollController,
                builder: (context, controller, physic) {
                  return GridView.builder(
                    key: Key(folder),
                    primary: false,
                    controller: controller,
                    gridDelegate: SliverGridDelegateWithComics(),
                    itemCount: comics.length,
                    padding: EdgeInsets.zero,
                    physics: physic,
                    itemBuilder: (BuildContext context, int index) {
                      var comic = comics[index];
                      var tile = LocalFavoriteTile(
                        key: ValueKey(comic.toString()),
                        comic,
                        folder,
                        () {
                          rebuild();
                          if (widget.selectedComics.contains(comic)) {
                            var c =
                                StateController.find<FavoritesPageController>();
                            c.selectedComics.remove(comic);
                            c.update();
                          }
                        },
                        true,
                        onTap: () => widget.onClick(comic),
                        onLongPressed: () => widget.onLongPressed(comic),
                        showFolderInfo: true,
                      );
                      StateController.find<FavoritesPageController>()
                          .openComicMenuFuncs[comic] = tile.showMenu;

                      Color? color;

                      if (widget.selectedComics.contains(comic)) {
                        color = Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest;
                      }
                      return AnimatedContainer(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.symmetric(
                            vertical: 2, horizontal: 4),
                        duration: const Duration(milliseconds: 160),
                        child: tile,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        reverseDuration: const Duration(milliseconds: 150),
        child: showFB && folderSync() != null ? buildFAB() : const SizedBox(),
        transitionBuilder: (widget, animation) {
          var tween =
              Tween<Offset>(begin: const Offset(0, 1), end: const Offset(0, 0));
          return SlideTransition(
            position: tween.animate(animation),
            child: widget,
          );
        },
      ),
    );
  }

  Widget buildFAB() => Material(
        color: Colors.transparent,
        child: FloatingActionButton(
          key: const Key("FAB"),
          onPressed: () => onRefresh(context),
          child: const Icon(Icons.refresh),
        ),
      );

  Widget buildEmptyView() {
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("这里什么都没有".tl),
          const SizedBox(
            height: 8,
          ),
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
          )
        ],
      ),
    );
  }

  @override
  Object? get tag => "ComicsPageView $folder";

  @override
  refresh() {
    comics = LocalFavoritesManager().getAllComics(folder);
    update();
  }
}

class _FoldersReorderPage extends StatefulWidget {
  const _FoldersReorderPage();

  @override
  State<_FoldersReorderPage> createState() => _FoldersReorderPageState();
}

class _FoldersReorderPageState extends State<_FoldersReorderPage> {
  var folders = LocalFavoritesManager().folderNames;
  var changed = false;

  final reorderKey = UniqueKey();
  final _scrollController = ScrollController();
  final _key = GlobalKey();

  Color lightenColor(Color color, double lightenValue) {
    int red = (color.red + ((255 - color.red) * lightenValue)).round();
    int green = (color.green + ((255 - color.green) * lightenValue)).round();
    int blue = (color.blue + ((255 - color.blue) * lightenValue)).round();

    return Color.fromARGB(color.alpha, red, green, blue);
  }

  @override
  void dispose() {
    if (changed) {
      LocalFavoritesManager().updateOrder(Map<String, int>.fromEntries(
          folders.mapIndexed((index, element) => MapEntry(element, index))));
      scheduleMicrotask(() {
        StateController.find<FavoritesPageController>().update();
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var tiles = List.generate(
        folders.length,
        (index) => MouseRegion(
              key: ValueKey(folders[index]),
              cursor: SystemMouseCursors.click,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(
                    Icons.folder,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      folders[index],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ));

    return Scaffold(
      appBar: AppBar(title: Text("排序".tl)),
      body: Column(
        children: [
          Expanded(
            child: ReorderableBuilder(
              key: reorderKey,
              scrollController: _scrollController,
              longPressDelay: App.isDesktop
                  ? const Duration(milliseconds: 100)
                  : const Duration(milliseconds: 500),
              onReorder: (reorderFunc) {
                changed = true;
                setState(() {
                  folders = reorderFunc(folders) as List<String>;
                });
              },
              dragChildBoxDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: lightenColor(
                      Theme.of(context).splashColor.withOpacity(1), 0.2)),
              builder: (children) {
                return GridView(
                  key: _key,
                  controller: _scrollController,
                  gridDelegate: const SliverGridDelegateWithFixedHeight(
                    maxCrossAxisExtent: 260,
                    itemHeight: 56,
                  ),
                  children: children,
                );
              },
              children: tiles,
            ),
          )
        ],
      ),
    );
  }
}
