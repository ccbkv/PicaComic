import 'package:flutter/material.dart';
import 'package:pica_comic/foundation/comic_source/comic_source.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/foundation/history.dart';
import 'package:pica_comic/foundation/image_loader/cached_image.dart';
import 'package:pica_comic/network/download.dart';
import 'package:pica_comic/pages/settings/settings_page.dart';
import 'accounts_page.dart';
import 'package:pica_comic/pages/download_page.dart';
import 'package:pica_comic/pages/tools.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/base.dart';
import 'history_page.dart';
import 'package:pica_comic/utils/translations.dart';
import 'package:pica_comic/utils/data_sync.dart';
import 'image_favorites.dart';
import 'package:pica_comic/pages/pre_search_page.dart';
import 'package:pica_comic/pages/follow_updates_page.dart';
import 'package:pica_comic/foundation/local_favorites.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    if (App.isFluent) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: fluent.TextBox(
          placeholder: '搜索'.tl,
          prefix: const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(fluent.FluentIcons.search),
          ),
          readOnly: true,
          onTap: () {
            context.to(() => PreSearchPage());
          },
        ),
      );
    }
    return Container(
      height: App.isMobile ? 52 : 46,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(32),
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: () {
            context.to(() => PreSearchPage());
          },
          child: Row(
            children:
            [
              const SizedBox(width: 16),
              const Icon(Icons.search),
              const SizedBox(width: 8),
              Text('搜索'.tl),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class MePage extends StatelessWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context) {
    if (App.isFluent) {
      return fluent.ScaffoldPage.scrollable(
        children: [
          const _SearchBar(),
          buildHistory(context),
          buildFollowUpdates(context),
          buildAccount(1000), // width not critical for Fluent layout here
          buildDownload(context, 1000),
          buildImageFavorite(context, 1000),
          buildComicSource(context, 1000),
          buildTools(context, 1000),
          buildSyncData(context, 1000),
          const SizedBox(height: 24),
        ],
      );
    }
    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constrains) {
          final width = constrains.maxWidth;
          bool shouldShowTwoPanel = width > 600;
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).padding.top,
                ),
                const _SearchBar(),
                buildHistory(context),
                buildFollowUpdates(context),
                if (shouldShowTwoPanel)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            buildAccount(width),
                            buildDownload(context, width),
                            buildComicSource(context, width),
                          ],
                        ),
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            buildImageFavorite(context, width),
                            buildTools(context, width),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  ...[
                    buildAccount(width),
                    buildDownload(context, width),
                    buildImageFavorite(context, width),
                    buildComicSource(context, width),
                    buildTools(context, width),
                  ],
                buildSyncData(context, width),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget buildHistory(BuildContext context) {
    return StateBuilder<SimpleController>(
        tag: "me_page_history",
        init: SimpleController(),
        builder: (controller) {
          var history = HistoryManager().getRecent();
          if (App.isFluent) {
            return fluent.Card(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  fluent.ListTile(
                    leading: const Icon(fluent.FluentIcons.history),
                    title: Text("${"历史记录".tl}(${HistoryManager().count()})"),
                    trailing: const Icon(fluent.FluentIcons.chevron_right),
                    onPressed: () => context.to(() => const HistoryPage()),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: appdata.appSettings.homePageHistoryDisplayType == 0 ? 128 : 88,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        if (appdata.appSettings.homePageHistoryDisplayType == 1) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: SizedBox(
                              width: 220,
                              child: fluent.HoverButton(
                                onPressed: () => toComicPageWithHistory(context, history[index]),
                                builder: (context, states) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: fluent.FluentTheme.of(context)
                                          .resources
                                          .cardBackgroundFillColorSecondary,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            history[index].title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          history[index].type.name,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: fluent.HoverButton(
                            onPressed: () => toComicPageWithHistory(context, history[index]),
                            builder: (context, states) {
                              return Container(
                                width: 96,
                                height: 128,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: AnimatedImage(
                                  image: CachedImageProvider(
                                    history[index].cover,
                                    sourceKey:
                                        history[index].type.comicSource?.key,
                                  ),
                                  width: 96,
                                  height: 128,
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.medium,
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }
          return Container(
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
              onTap: () => context.to(() => const HistoryPage()),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        const Icon(Icons.history).paddingLeft(16),
                        const SizedBox(width: 12),
                        Center(
                          child: Text("${"历史记录".tl}(${HistoryManager().count()})", style: ts.s16),
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_right).paddingRight(16),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: appdata.appSettings.homePageHistoryDisplayType == 0 ? 128 : 88,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        if (appdata.appSettings.homePageHistoryDisplayType == 1) {
                          return InkWell(
                            onTap: () =>
                                toComicPageWithHistory(context, history[index]),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 220,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      history[index].title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    history[index].type.name,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return InkWell(
                          onTap: () =>
                              toComicPageWithHistory(context, history[index]),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 96,
                            height: 128,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: AnimatedImage(
                              image: CachedImageProvider(
                                history[index].cover,
                                sourceKey:
                                    history[index].type.comicSource?.key,
                              ),
                              width: 96,
                              height: 128,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        );
                      },
                    ),
                  ).paddingHorizontal(8).paddingBottom(12),
                ],
              ),
            ),
          );
        });
  }

  Widget buildFollowUpdates(BuildContext context) {
    return StateBuilder<SimpleController>(
      tag: "me_page_follow_updates",
      init: SimpleController(),
      builder: (controller) {
        String? folder = appdata.appSettings.followUpdatesFolder.isEmpty
            ? null
            : appdata.appSettings.followUpdatesFolder;
        int count = 0;
        if (folder != null && LocalFavoritesManager().folderNames.contains(folder)) {
          count = LocalFavoritesManager().countUpdates(folder);
        }

        if (App.isFluent) {
          return fluent.Card(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            child: fluent.ListTile(
              leading: const Icon(fluent.FluentIcons.sync),
              title: Text('追更'.tl),
              subtitle: count > 0 ? Text('@c 个更新'.tlParams({'c': count.toString()})) : null,
              trailing: const Icon(fluent.FluentIcons.chevron_right),
              onPressed: () => context.to(() => const FollowUpdatesPage()),
            ),
          );
        }

        return Container(
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
              context.to(() => const FollowUpdatesPage());
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
                if (count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    margin: const EdgeInsets.only(bottom: 16, left: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(context).colorScheme.primaryContainer,
                    ),
                    child: Text(
                      '@c 个更新'.tlParams({'c': count.toString()}),
                      style: ts.s16,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildAccount(double width) {
    return StateBuilder<SimpleController>(
      tag: "me_page_accounts",
      init: SimpleController(),
      builder: (controller) {
        var accounts = findAccounts();

        Widget buildItem(String name) {
          if (App.isFluent) {
             return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: fluent.FluentTheme.of(App.globalContext!).resources.cardBackgroundFillColorSecondary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                name,
                style: const TextStyle(fontSize: 12),
              ),
            );
          }
          return Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(App.globalContext!).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              name,
              style: const TextStyle(fontSize: 12),
            ).paddingTop(4),
          );
        }

        return _MePageCard(
          icon: const Icon(Icons.switch_account),
          title: "账号管理".tl,
          description:
              "已登录 @a 个账号".tlParams({"a": accounts.length.toString()}),
          onTap: () => showPopUpWidget(App.globalContext!, const AccountsPage()),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: accounts.map((e) => buildItem(e)).toList(),
          ).paddingHorizontal(12).paddingBottom(12),
        );
      },
    );
  }

  Widget buildDownload(BuildContext context, double width) {
    return StateBuilder<SimpleController>(
      tag: "me_page_downloads",
      init: SimpleController(),
      builder: (controller) {
        return _MePageCard(
          icon: const Icon(Icons.download_for_offline),
          title: "已下载".tl,
          description: "共 @a 部漫画"
              .tlParams({"a": DownloadManager().total.toString()}),
          onTap: () => context.to(() => const DownloadPage()),
        );
      },
    );
  }

  

  Widget buildImageFavorite(BuildContext context, double width) {
    return StateBuilder<SimpleController>(
      tag: "me_page",
      init: SimpleController(),
      builder: (controller) {
        return _MePageCard(
          icon: const Icon(Icons.image),
          title: "图片收藏".tl,
          description: "@a 条图片收藏"
              .tlParams({"a": ImageFavoriteManager.length.toString()}),
          onTap: () => context.to(() => const ImageFavoritesPage()),
        );
      },
    );
  }

  Widget buildComicSource(BuildContext context, double width) {
    return StateBuilder<SimpleController>(
      tag: "me_page_sources",
      init: SimpleController(),
      builder: (controller) {
        var comicSources = ComicSource.sources;
        Widget buildItem(String name) {
          if (App.isFluent) {
             return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: fluent.FluentTheme.of(App.globalContext!).resources.cardBackgroundFillColorSecondary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                name,
                style: const TextStyle(fontSize: 12),
              ),
            );
          }
          return Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color:
                  Theme.of(App.globalContext!).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              name,
              style: const TextStyle(fontSize: 12),
            ).paddingTop(4),
          );
        }

        return _MePageCard(
          icon: const Icon(Icons.dashboard_customize),
          title: "漫画源".tl,
          description: "共 @a 个漫画源"
              .tlParams({"a": comicSources.length.toString()}),
          onTap: () => App.mainNavigatorKey?.currentContext
              ?.to(() => const ComicSourceSettings()),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: comicSources.map((e) => buildItem(e.name.tl)).toList(),
          ).paddingHorizontal(12).paddingBottom(12),
        );
      },
    );
  }

  Widget buildTools(BuildContext context, double width) {
    Widget buildItem(String name) {
      if (App.isFluent) {
          return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: fluent.FluentTheme.of(App.globalContext!).resources.cardBackgroundFillColorSecondary,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            name,
            style: const TextStyle(fontSize: 12),
          ),
        );
      }
      return Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(App.globalContext!).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          name,
          style: const TextStyle(fontSize: 12),
        ).paddingTop(4),
      );
    }

    return _MePageCard(
      icon: const Icon(Icons.build_circle),
      title: "工具".tl,
      description: "使用工具发现更多漫画".tl,
      onTap: () => openTool(context),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          buildItem("EH订阅".tl),
          buildItem("图片搜索".tl),
          buildItem("打开链接".tl),
        ],
      ).paddingHorizontal(12).paddingBottom(12),
    );
  }

  Widget buildSyncData(BuildContext context, double width) {
    if (!DataSync().isEnabled) {
      return const SizedBox.shrink();
    }
    return StateBuilder<DataSync>(
      init: DataSync(),
      builder: (controller) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: const Icon(Icons.sync),
            title: Text('Sync Data'.tl),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (DataSync().lastError != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      showDialogMessage(
                        App.globalContext!,
                        "Error".tl,
                        DataSync().lastError!,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text('Error'.tl, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ).paddingRight(4),
                IconButton(
                  icon: const Icon(Icons.cloud_upload_outlined),
                  onPressed: () async {
                    DataSync().uploadData();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cloud_download_outlined),
                  onPressed: () async {
                    DataSync().downloadData();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<String> findAccounts() {
    var result = <String>[];
    for (var source in ComicSource.sources) {
      if (source.isLogin) {
        result.add(source.name.tl);
      }
    }
    return result;
  }
}

class _MePageCard extends StatelessWidget {
  const _MePageCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.child,
  });

  final Widget icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (App.isFluent) {
      return fluent.Card(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: EdgeInsets.zero,
        child: fluent.ListTile(
          onPressed: onTap,
          title: Text(title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(description).paddingVertical(4),
              if (child != null) child!,
            ],
          ),
          leading: icon,
          trailing: const Icon(fluent.FluentIcons.chevron_right),
        ),
      );
    }
    return Container(
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
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  icon.paddingLeft(16),
                  const SizedBox(width: 16),
                  Center(
                    child: Text(title, style: ts.s18),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_right).paddingRight(16),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 16),
              child: Text(description, style: ts.s14),
            ),
            if (child != null) child!
          ],
        ),
      ),
    );
  }
}
