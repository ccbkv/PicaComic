part of 'comic_reading_page.dart';

class EpsView extends StatefulWidget {
  const EpsView(this.data, {Key? key}) : super(key: key);
  final ReadingData data;

  @override
  State<EpsView> createState() => _EpsViewState();
}

class _EpsViewState extends State<EpsView> {
  bool desc = false;

  late final ScrollController _scrollController;

  var logic = StateController.find<ComicReadingPageLogic>();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // 延迟滚动到当前章节，避免构建时调度帧的错误
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        int epIndex = logic.order - 2;
        double offset = (epIndex * 48.0).clamp(0, double.infinity);
        _scrollController.jumpTo(offset);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var type = widget.data.type;
    var data = widget.data;
    var epsCount = data.eps!.length;
    var current = logic.order - 1;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // AppBar - 使用 SliverPersistentHeader 实现固定颜色+阴影效果
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
                // JM评论按钮
                if (type == ReadingType.jm)
                  IconButton(
                    icon: Icon(Icons.comment_outlined,
                        color: Theme.of(context).colorScheme.secondary),
                    onPressed: () {
                      showComments(context, data.eps!.keys.elementAt(logic.order - 1),
                          (logic.data as JmReadingData).commentsLength ?? 9999);
                    },
                  ),
                // 章节评论按钮
                if (_shouldShowChapterComments())
                  IconButton(
                    icon: Icon(Icons.comment,
                        color: Theme.of(context).colorScheme.secondary),
                    onPressed: _openChapterComments,
                  ),
                // 排序按钮
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
          // 章节列表
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

  bool _shouldShowChapterComments() {
    var data = widget.data;
    // 检查是否有章节
    if (data.eps == null || data.eps!.isEmpty) return false;

    // 检查设置是否启用
    var showChapterComments = appdata.settings.length > 92 && appdata.settings[92] == "1";
    if (!showChapterComments) return false;

    // 检查漫画源是否支持章节评论
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

/// 自定义 AppBar Delegate - 固定颜色 + 滑动阴影
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
