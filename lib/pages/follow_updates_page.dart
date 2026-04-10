import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/local_favorites.dart';
import 'package:pica_comic/utils/translations.dart';
import 'package:pica_comic/foundation/global_state.dart';
import 'package:pica_comic/foundation/follow_updates.dart';
import 'package:pica_comic/pages/favorites/local_favorites.dart';

import '../base.dart';

class FollowUpdatesWidget extends StatefulWidget {
  const FollowUpdatesWidget({super.key});

  @override
  State<FollowUpdatesWidget> createState() => _FollowUpdatesWidgetState();
}

class _FollowUpdatesWidgetState
    extends AutomaticGlobalState<FollowUpdatesWidget> {
  int _count = 0;

  String? get folder => appdata.appSettings.followUpdatesFolder.isEmpty
      ? null
      : appdata.appSettings.followUpdatesFolder;

  void getCount() {
    if (folder == null) {
      _count = 0;
      return;
    }
    if (!LocalFavoritesManager().folderNames.contains(folder)) {
      _count = 0;
      appdata.appSettings.followUpdatesFolder = "";
      Future.microtask(() {
        appdata.writeData();
      });
    } else {
      _count = LocalFavoritesManager().countUpdates(folder!);
    }
  }

  void updateCount() {
    setState(() {
      getCount();
    });
  }

  @override
  void initState() {
    super.initState();
    getCount();
  }

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.6,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            context.to(() => FollowUpdatesPage());
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    Center(
                      child: Text('追更'.tl, style: ts.s18),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_right),
                  ],
                ),
              ).paddingHorizontal(16),
              if (_count > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  margin: const EdgeInsets.only(bottom: 16, left: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  child: Text(
                    '@c 项更新'.tlParams({
                      'c': _count.toString(),
                    }),
                    style: ts.s16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Object? get key => 'FollowUpdatesWidget';
}

class FollowUpdatesPage extends StatefulWidget {
  const FollowUpdatesPage({super.key});

  @override
  State<FollowUpdatesPage> createState() => _FollowUpdatesPageState();
}

class _FollowUpdatesPageState extends AutomaticGlobalState<FollowUpdatesPage> {
  String? get folder => appdata.appSettings.followUpdatesFolder.isEmpty
      ? null
      : appdata.appSettings.followUpdatesFolder;

  var updatedComics = <FavoriteItemWithUpdateInfo>[];
  var allComics = <FavoriteItemWithUpdateInfo>[];

  void sortComics() {
    allComics.sort((a, b) {
      if (a.updateTime == null && b.updateTime == null) {
        return 0;
      } else if (a.updateTime == null) {
        return -1;
      } else if (b.updateTime == null) {
        return 1;
      }
      try {
        var aNums = a.updateTime!.split('-').map(int.parse).toList();
        var bNums = b.updateTime!.split('-').map(int.parse).toList();
        for (int i = 0; i < aNums.length; i++) {
          if (aNums[i] != bNums[i]) {
            return bNums[i] - aNums[i];
          }
        }
        return 0;
      } catch (_) {
        return 0;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    if (folder != null) {
      allComics = LocalFavoritesManager().getComicsWithUpdatesInfo(folder!);
      sortComics();
      updatedComics = allComics.where((c) => c.hasNewUpdate).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SmoothCustomScrollView(
        slivers: [
          SliverAppbar(title: Text('追更'.tl)),
          if (folder == null)
            buildNotConfigured(context)
          else
            buildConfigured(context),
          SliverPadding(padding: const EdgeInsets.only(top: 8)),
          buildUpdatedComics(),
          buildAllComics(),
        ],
      ),
    );
  }

  Widget buildNotConfigured(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.6,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Icon(Icons.info_outline),
              title: Text("未配置".tl),
            ),
            Text(
              "选择一个文件夹以追更".tl,
              style: ts.s16,
            ).paddingHorizontal(16),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: showSelector,
              child: Text("选择收藏夹".tl),
            ).paddingHorizontal(16).toAlign(Alignment.centerRight),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget buildConfigured(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.6,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Icon(Icons.stars_outlined),
              title: Text(folder!),
            ),
            Text(
              "已启用自动更新检查".tl,
              style: ts.s14,
            ).paddingHorizontal(16),
            Text(
              "APP将每天最多检查一次更新".tl,
              style: ts.s14,
            ).paddingHorizontal(16),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: showSelector,
                  child: Text("更改文件夹".tl),
                ),
                FilledButton.tonal(
                  onPressed: checkNow,
                  child: Text("立即检查".tl),
                ),
                const SizedBox(width: 16),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget buildUpdatedComics() {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 0.6,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.update),
                const SizedBox(width: 8),
                Text(
                  "更新".tl,
                  style: ts.s18,
                ),
                const Spacer(),
                if (updatedComics.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.clear_all),
                    onPressed: () {
                      showConfirmDialog(
                        context: App.globalContext!,
                        title: "全部标记为已读".tl,
                        content: "您要全部标记为已读吗？".tl,
                        onConfirm: () {
                          for (var comic in updatedComics) {
                            LocalFavoritesManager().markAsRead(
                              comic.target,
                              comic.type,
                            );
                          }
                          updateFollowUpdatesUI();
                          appdata.writeData();
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        if (updatedComics.isNotEmpty)
          SliverToBoxAdapter(
            child: Text(
                    "阅读漫画后将自动标记为无更新。".tl)
                .paddingHorizontal(16)
                .paddingVertical(4),
          ),
        if (updatedComics.isNotEmpty)
          buildComicsGrid(updatedComics)
        else
          SliverToBoxAdapter(
            child: Row(
              children: [
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "未找到更新".tl,
                        style: ts.s16,
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
      ],
    );
  }

  Widget buildAllComics() {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 0.6,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.list),
                const SizedBox(width: 8),
                Text(
                  "全部漫画".tl,
                  style: ts.s18,
                ),
              ],
            ),
          ),
        ),
        buildComicsGrid(allComics),
      ],
    );
  }

  Widget buildComicsGrid(List<FavoriteItemWithUpdateInfo> comics) {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        childCount: comics.length,
        (context, index) {
          var comic = comics[index];
          return LocalFavoriteTile(
            comic,
            folder ?? '',
            () {},
            true,
          );
        },
      ),
      gridDelegate: SliverGridDelegateWithComics(),
    );
  }

  void showSelector() {
    var folders = LocalFavoritesManager().folderNames;
    if (folders.isEmpty) {
      context.showMessage(message: "没有可用的收藏夹".tl);
      return;
    }
    String? selectedFolder;
    showDialog(
      context: App.globalContext!,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return ContentDialog(
            title: "选择收藏夹".tl,
            content: Column(
              children: [
                ListTile(
                  title: Text("收藏夹".tl),
                  trailing: Select(
                    minWidth: 120,
                    current: selectedFolder,
                    values: folders,
                    onTap: (i) {
                      setState(() {
                        selectedFolder = folders[i];
                      });
                    },
                  ),
                ),
              ],
            ),
            actions: [
              if (appdata.appSettings.followUpdatesFolder.isNotEmpty)
                TextButton(
                  onPressed: () {
                    disable();
                    context.pop();
                  },
                  child: Text("禁用".tl),
                ),
              FilledButton(
                onPressed: selectedFolder == null
                    ? null
                    : () {
                        context.pop();
                        setFolder(selectedFolder!);
                      },
                child: Text("确认".tl),
              ),
            ],
          );
        });
      },
    );
  }

  void disable() {
    appdata.appSettings.followUpdatesFolder = "";
    appdata.writeData();
    updateFollowUpdatesUI();
  }

  void setFolder(String folder) async {
    FollowUpdatesService._cancelChecking?.call();
    LocalFavoritesManager().prepareTableForFollowUpdates(folder);

    var count = LocalFavoritesManager().count(folder);

    if (count > 0) {
      bool isCanceled = false;
      void onCancel() {
        isCanceled = true;
      }

      var loadingController = showLoadingDialog(
        App.globalContext!,
        withProgress: true,
        cancelButtonText: "取消".tl,
        onCancel: onCancel,
        message: "更新漫画中...".tl,
      );

      await for (var progress in updateFolder(folder, true)) {
        if (isCanceled) {
          loadingController.close();
          return;
        }
        loadingController.setProgress(progress.current / progress.total);

      }

      loadingController.close();
    }

    setState(() {
      appdata.appSettings.followUpdatesFolder = folder;
      updatedComics = [];
      allComics = LocalFavoritesManager().getComicsWithUpdatesInfo(folder);
      sortComics();
    });
    appdata.writeData();
  }

  void checkNow() async {
    FollowUpdatesService._cancelChecking?.call();

    bool isCanceled = false;
    void onCancel() {
      isCanceled = true;
    }

    var loadingController = showLoadingDialog(
      App.globalContext!,
      withProgress: true,
      cancelButtonText: "取消".tl,
      onCancel: onCancel,
      message: "更新漫画中...".tl,
    );

    int updated = 0;

    await for (var progress in updateFolder(folder!, true)) {
      if (isCanceled) {
        loadingController.close();
        return;
      }
      loadingController.setProgress(progress.current / progress.total);
      updated = progress.updated;
    }

    loadingController.close();

    if (updated > 0) {
      GlobalState.findOrNull<_FollowUpdatesWidgetState>()?.updateCount();
      updateComics();
    }
  }

  void updateComics() {
    if (folder == null) {
      setState(() {
        allComics = [];
        updatedComics = [];
      });
      return;
    }
    setState(() {
      allComics = LocalFavoritesManager().getComicsWithUpdatesInfo(folder!);
      sortComics();
      updatedComics = allComics.where((c) => c.hasNewUpdate).toList();
    });
  }

  @override
  Object? get key => 'FollowUpdatesPage';
}

abstract class FollowUpdatesService {
  static bool _isChecking = false;

  static void Function()? _cancelChecking;

  static bool _isInitialized = false;

  static void _check() async {
    if (_isChecking) {
      return;
    }
    var folder = appdata.appSettings.followUpdatesFolder.isEmpty
        ? null
        : appdata.appSettings.followUpdatesFolder;
    if (folder == null) {
      return;
    }
    bool isCanceled = false;
    _cancelChecking = () {
      isCanceled = true;
    };

    _isChecking = true;

    int updated = 0;
    try {
      await for (var progress in updateFolder(folder, false)) {
        if (isCanceled) {
          return;
        }
        updated = progress.updated;
      }
    } finally {
      _cancelChecking = null;
      _isChecking = false;
      if (updated > 0) {
        updateFollowUpdatesUI();
      }
    }
  }

  static void initChecker() {
    if (_isInitialized) return;
    _isInitialized = true;
    _check();
    Timer.periodic(const Duration(minutes: 10), (timer) {
      _check();
    });
  }
}

void updateFollowUpdatesUI() {
  GlobalState.findOrNull<_FollowUpdatesWidgetState>()?.updateCount();
  GlobalState.findOrNull<_FollowUpdatesPageState>()?.updateComics();
}
