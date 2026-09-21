part of 'favorites_page.dart';

/// 收藏概览页: 以网格形式展示本地与网络收藏夹, 每行显示的文件夹数量可配置(1-5)。
class _FavoritesOverview extends StatefulWidget {
  const _FavoritesOverview({required this.favPage});

  final _FavoritesPageState favPage;

  @override
  State<_FavoritesOverview> createState() => _FavoritesOverviewState();
}

class _FavoritesOverviewState extends State<_FavoritesOverview> {
  static const int _minColumns = 1;
  static const int _maxColumns = 5;

  /// 单个文件夹卡片的最小宽度, 用于保证窄屏也能放下 5 列。
  static const double _minCardWidth = 72;

  int get _configuredColumns {
    final columns = appdata.appSettings.favoritesOverviewColumns;
    return columns.clamp(_minColumns, _maxColumns);
  }

  /// 根据内容区实际宽度限制列数。仅在卡片会被压得过窄时才减少列数。
  int _columnsForWidth(double width) {
    final maxByWidth = (width / _minCardWidth).floor();
    if (maxByWidth < _minColumns) {
      return _minColumns;
    }
    return _configuredColumns
        .clamp(_minColumns, _maxColumns)
        .clamp(_minColumns, maxByWidth.clamp(_minColumns, _maxColumns));
  }

  List<String> get _networkFolderKeys {
    final keys = <String>[];
    for (final key in appdata.settings[68].split(',')) {
      if (key.isEmpty) {
        continue;
      }
      if (getFavoriteDataOrNull(key) != null && !keys.contains(key)) {
        keys.add(key);
      }
    }
    return keys;
  }

  String _localFolderTitle(String name) {
    if (name == _localAllFolderLabel) {
      return "全部".tl;
    }
    return getFavoriteDataOrNull(name)?.title ?? name;
  }

  int _localFolderCount(String name) {
    if (name == _localAllFolderLabel) {
      return LocalFavoritesManager().totalComics;
    }
    return LocalFavoritesManager().folderComics(name);
  }

  void _openLocalFolder(String name) {
    widget.favPage.setFolder(false, name);
  }

  void _openNetworkFolder(String key) {
    widget.favPage.setFolder(true, key);
  }

  void _setColumns(int columns) {
    final clamped = columns.clamp(_minColumns, _maxColumns);
    appdata.appSettings.favoritesOverviewColumns = clamped;
    appdata.updateSettings();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = bottomOverlayInsetOf(context);
    final isNarrow = MediaQuery.of(context).size.width <= _kTwoPanelChangeWidth;

    final localFolders = <String>[
      _localAllFolderLabel,
      ...LocalFavoritesManager().folderNames,
    ];
    final networkFolders = _networkFolderKeys;
    final hasData = localFolders.length > 1 || networkFolders.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsForWidth(constraints.maxWidth);
        final itemHeight = _cardHeightFor(constraints.maxWidth, columns);
        return CustomScrollView(
          slivers: [
            SliverAppBar(
              leading: isNarrow
                  ? Tooltip(
                      message: "文件夹".tl,
                      child: IconButton(
                        icon: const Icon(Icons.menu),
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: widget.favPage.showFolderSelector,
                      ),
                    )
                  : null,
              title: Text("收藏概览".tl),
              actions: [
                if (hasData) _buildColumnSelector(context),
              ],
            ),
            if (localFolders.length > 1)
              ..._buildSection(
                context,
                columns: columns,
                itemHeight: itemHeight,
                icon: Icons.local_activity,
                title: "本地".tl,
                folders: localFolders,
                isNetwork: false,
              ),
            if (networkFolders.isNotEmpty)
              ..._buildSection(
                context,
                columns: columns,
                itemHeight: itemHeight,
                icon: Icons.cloud,
                title: "网络".tl,
                folders: networkFolders,
                isNetwork: true,
              ),
            if (!hasData)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(context),
              ),
            SliverToBoxAdapter(child: SizedBox(height: bottomInset + 16)),
          ],
        );
      },
    );
  }

  /// 网格左右内边距 (SliverPadding horizontal * 2)
  static const double _gridHorizontalPadding = 24;
  static const double _gridSpacing = 8;

  /// 依据内容区宽度与列数推算单张卡片的实际宽度。
  double _cardWidthFor(double width, int columns) {
    final available =
        width - _gridHorizontalPadding - _gridSpacing * (columns - 1);
    if (available <= 0) {
      return _minCardWidth;
    }
    return available / columns;
  }

  /// 依据卡片宽度动态计算行高, 保持接近方形到微扁的合理比例, 避免窄列时被拉成竖长条。
  double _cardHeightFor(double width, int columns) {
    final cardWidth = _cardWidthFor(width, columns);
    return (cardWidth * 0.82).clamp(72.0, 116.0);
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            "请选择一个收藏夹".tl,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSection(
    BuildContext context, {
    required int columns,
    required double itemHeight,
    required IconData icon,
    required String title,
    required List<String> folders,
    required bool isNetwork,
  }) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey[700]),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(
            horizontal: _gridHorizontalPadding / 2),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: itemHeight,
            mainAxisSpacing: _gridSpacing,
            crossAxisSpacing: _gridSpacing,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final folder = folders[index];
              if (isNetwork) {
                final data = getFavoriteDataOrNull(folder);
                return _FolderOverviewCard(
                  name: data?.title ?? folder,
                  isNetwork: true,
                  onTap: () => _openNetworkFolder(folder),
                );
              }
              return _FolderOverviewCard(
                name: _localFolderTitle(folder),
                count: _localFolderCount(folder),
                onTap: () => _openLocalFolder(folder),
              );
            },
            childCount: folders.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildColumnSelector(BuildContext context) {
    final current = _configuredColumns;
    return MenuButton(
      icon: const Icon(Icons.grid_view),
      entries: [
        for (var i = _minColumns; i <= _maxColumns; i++)
          MenuEntry(
            icon: i == current ? Icons.check : null,
            text: "@n 列".tlParams({"n": i.toString()}),
            onClick: () => _setColumns(i),
          ),
      ],
    );
  }
}

class _FolderOverviewCard extends StatelessWidget {
  const _FolderOverviewCard({
    required this.name,
    required this.onTap,
    this.count,
    this.isNetwork = false,
  });

  final String name;

  final int? count;

  final bool isNetwork;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;

        // 依据卡片实际宽度动态计算尺寸, 保证 4-5 列等窄卡片下文字也能容纳。
        final iconSize = (cardWidth / 6.5).clamp(14.0, 20.0);
        final titleFontSize = (cardWidth / 8.5).clamp(9.0, 13.0);
        final padding = cardWidth < 100 ? 6.0 : 10.0;
        final badgePadding = cardWidth < 100
            ? const EdgeInsets.symmetric(horizontal: 5, vertical: 1)
            : const EdgeInsets.symmetric(horizontal: 8, vertical: 2);

        final scheme = Theme.of(context).colorScheme;
        final content = InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isNetwork ? Icons.cloud_outlined : Icons.folder,
                      size: iconSize,
                      color: scheme.secondary,
                    ),
                    const Spacer(),
                    if (count != null)
                      Container(
                        padding: badgePadding,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          count.toString(),
                          style: TextStyle(
                            fontSize: (titleFontSize - 1).clamp(8.0, 11.0),
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );

        if (enableLiquidGlassUi) {
          return GlassContainerLite(
            shape: const LiquidRoundedSuperellipse(borderRadius: 18),
            child: content,
          );
        }

        return Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: content,
        );
      },
    );
  }
}
