part of 'comic_reading_page.dart';

class EpsView extends StatefulWidget {
  const EpsView(this.data, {Key? key}) : super(key: key);
  final ReadingData data;

  @override
  State<EpsView> createState() => _EpsViewState();
}

class _EpsViewState extends State<EpsView>
    with SingleTickerProviderStateMixin {
  bool desc = false;

  late final ScrollController _scrollController;
  TabController? _tabController;

  var logic = StateController.find<ComicReadingPageLogic>();

  ComicChapters? _groupedChapters;
  int _selectedGroupIndex = 0;

  bool get _isGrouped => _groupedChapters != null && _groupedChapters!.isGrouped;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    if (widget.data is CustomReadingData) {
      _groupedChapters = (widget.data as CustomReadingData).comicChapters;
      if (_isGrouped) {
        int epIndex = logic.order - 1;
        int groupIdx = 0;
        while (epIndex >= 0 && groupIdx < _groupedChapters!.groupCount) {
          epIndex -= _groupedChapters!.getGroupByIndex(groupIdx).length;
          groupIdx++;
        }
        _selectedGroupIndex = (groupIdx - 1).clamp(0, _groupedChapters!.groupCount - 1);
        _tabController = TabController(
          length: _groupedChapters!.groupCount,
          initialIndex: _selectedGroupIndex,
          vsync: this,
        );
      }
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        int epIndex = logic.order - 2;
        double offset = (epIndex * 48.0).clamp(0, double.infinity);
        _scrollController.jumpTo(offset);
      }
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isGrouped) {
      return _buildGroupedView(context);
    }
    return _buildNormalView(context);
  }

  Widget _buildNormalView(BuildContext context) {
    var data = widget.data;
    var epsCount = data.eps!.length;
    var current = logic.order - 1;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _EpsViewAppBarDelegate(
              title: "章节".tl,
              topPadding: MediaQuery.of(context).padding.top,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                if (_shouldShowChapterComments())
                  IconButton(
                    icon: Icon(Icons.comment,
                        color: Theme.of(context).colorScheme.secondary),
                    onPressed: _openChapterComments,
                  ),
                Tooltip(
                  message: "点击切换排序".tl,
                  child: TextButton.icon(
                    icon: Icon(
                      !desc ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 18,
                    ),
                    label: Text(!desc ? "升序".tl : "倒序".tl),
                    onPressed: () {
                      setState(() {
                        desc = !desc;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (desc) {
                  index = epsCount - 1 - index;
                }
                String title = data.eps!.values.elementAt(index);
                bool isActive = current == index;
                bool isDownloaded = data.downloadedEps.contains(index);

                return _ChapterListTile(
                  onTap: () {
                    Navigator.pop(App.globalContext!);
                    logic.jumpToChapter(index + 1);
                  },
                  title: title,
                  isActive: isActive,
                  isDownloaded: isDownloaded,
                );
              },
              childCount: epsCount,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedView(BuildContext context) {
    var data = widget.data;
    var groups = _groupedChapters!.groups.toList();
    var currentGroupIndex = _selectedGroupIndex;
    var group = _groupedChapters!.getGroupByIndex(currentGroupIndex);
    var groupKeys = group.keys.toList();
    var groupValues = group.values.toList();
    var current = logic.order - 1;

    int currentEpInGroup = current;
    for (int i = 0; i < currentGroupIndex; i++) {
      currentEpInGroup -= _groupedChapters!.getGroupByIndex(i).length;
    }

    return Scaffold(
      body: Column(
        children: [
          _EpsViewAppBar(
            title: "章节".tl,
            topPadding: MediaQuery.of(context).padding.top,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (_shouldShowChapterComments())
                IconButton(
                  icon: Icon(Icons.comment,
                      color: Theme.of(context).colorScheme.secondary),
                  onPressed: _openChapterComments,
                ),
              Tooltip(
                message: "点击切换排序".tl,
                child: TextButton.icon(
                  icon: Icon(
                    !desc ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 18,
                  ),
                  label: Text(!desc ? "升序".tl : "倒序".tl),
                  onPressed: () {
                    setState(() {
                      desc = !desc;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          SizedBox(
            height: 40,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 2.5,
              indicatorColor: Theme.of(context).colorScheme.primary,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurface,
              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              onTap: (index) {
                if (index != _selectedGroupIndex) {
                  setState(() {
                    _selectedGroupIndex = index;
                  });
                }
              },
              tabs: groups.map((name) => Tab(text: name)).toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: groupValues.length,
              itemBuilder: (context, index) {
                var epIndexInGroup = index;
                if (desc) {
                  epIndexInGroup = groupValues.length - 1 - index;
                }
                int chapterIndex = 0;
                for (int j = 0; j < currentGroupIndex; j++) {
                  chapterIndex += _groupedChapters!.getGroupByIndex(j).length;
                }
                chapterIndex += epIndexInGroup;
                String title = groupValues[epIndexInGroup];
                bool isActive = current == chapterIndex;
                bool isDownloaded = data.downloadedEps.contains(chapterIndex);

                return _ChapterListTile(
                  onTap: () {
                    Navigator.pop(App.globalContext!);
                    logic.jumpToChapter(chapterIndex + 1);
                  },
                  title: title,
                  isActive: isActive,
                  isDownloaded: isDownloaded,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowChapterComments() {
    var data = widget.data;
    if (data.eps == null || data.eps!.isEmpty) return false;
    var showChapterComments = appdata.settings.length > 92 && appdata.settings[92] == "1";
    if (!showChapterComments) return false;
    var source = ComicSource.find(data.sourceKey);
    if (source == null || source.chapterCommentsLoader == null) return false;
    return true;
  }

  void _openChapterComments() {
    var data = widget.data;
    var source = ComicSource.find(data.sourceKey);
    if (source == null) return;

    var logic = StateController.find<ComicReadingPageLogic>();
    var epId = data.eps!.keys.elementAt(logic.order - 1);
    var chapterTitle = data.eps!.values.elementAt(logic.order - 1);

    showSideBar(
      context,
      ChapterCommentsPage(
        comicId: data.id,
        epId: epId,
        source: source,
        comicTitle: data.title,
        chapterTitle: chapterTitle,
      ),
      title: "章节评论".tl,
    );
  }
}

class _EpsViewAppBar extends StatelessWidget {
  final String title;
  final Widget? leading;
  final List<Widget> actions;
  final double topPadding;

  const _EpsViewAppBar({
    required this.title,
    this.leading,
    required this.actions,
    required this.topPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      child: SizedBox(
        height: 52.0 + topPadding,
        child: Row(
          children: [
            const SizedBox(width: 8),
            leading ?? const SizedBox(),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            ...actions,
          ],
        ).paddingTop(topPadding),
      ),
    );
  }
}

class _EpsViewAppBarDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final Widget? leading;
  final List<Widget> actions;
  final double topPadding;

  _EpsViewAppBarDelegate({
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
            leading ?? const SizedBox(),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            ...actions,
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
    return oldDelegate is! _EpsViewAppBarDelegate ||
        title != oldDelegate.title ||
        leading != oldDelegate.leading ||
        actions != oldDelegate.actions;
  }
}

/// 章节列表项 
class _ChapterListTile extends StatelessWidget {
  const _ChapterListTile({
    required this.title,
    required this.isActive,
    required this.isDownloaded,
    required this.onTap,
  });

  final String title;
  final bool isActive;
  final bool isDownloaded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
            ),
            const Spacer(),
            if (isDownloaded)
              Icon(
                Icons.download_done_rounded,
                color: Theme.of(context).colorScheme.secondary,
              ),
          ],
        ),
      ),
    );
  }
}
