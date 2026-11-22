part of 'comic_page.dart';

ComicType _comicTypeForSource(String sourceKey) => switch (sourceKey) {
      'picacg' => ComicType.picacg,
      'ehentai' => ComicType.ehentai,
      'jm' => ComicType.jm,
      'hitomi' => ComicType.hitomi,
      'htmanga' => ComicType.htManga,
      'nhentai' => ComicType.nhentai,
      _ => ComicType.other,
    };

void openTranslatedChaptersPage(
  BuildContext context,
  StoredTranslationComic comic,
) {
  Future<void> open({ComicInfoData? details}) async {
    var stored = TranslationStore().chaptersFor(
      comic.sourceKey,
      comic.comicId,
      sourceLang: comic.sourceLang,
      targetLang: comic.targetLang,
    );

    var title = comic.title.isEmpty ? comic.comicId : comic.title;
    var cover = comic.cover;
    var chapterTitles = <String, String>{};
    if (details != null) {
      title = details.title.isEmpty ? title : details.title;
      cover = details.cover.isEmpty ? cover : details.cover;
      chapterTitles = details.chapters?.allChapters ?? {};
      TranslationStore().updateComicMetadata(
        comic.sourceKey,
        comic.comicId,
        comicTitle: details.title,
        comicCover: details.cover,
        chapterTitles: chapterTitles,
      );
      stored = TranslationStore().chaptersFor(
        comic.sourceKey,
        comic.comicId,
        sourceLang: comic.sourceLang,
        targetLang: comic.targetLang,
      );
    }

    // The details cache is the chapter-list source of truth. The durable
    // translation index only tells us which of those chapters have pages.
    // Keep indexed chapters that disappeared from a stale source response so
    // an old translation is never hidden from the user.
    final storedById = <String, StoredTranslationChapter>{
      for (var chapter in stored) chapter.identity.chapterId: chapter,
    };
    final sourceChapters =
        details?.chapters?.allChapters ?? const <String, String>{};
    final entries = <(String, String)>[];
    final seenIds = <String>{};
    for (var entry in sourceChapters.entries) {
      seenIds.add(entry.key);
      final storedTitle = storedById[entry.key]?.identity.chapterTitle ?? '';
      entries.add((
        entry.key,
        entry.value.isNotEmpty
            ? entry.value
            : (storedTitle.isNotEmpty ? storedTitle : entry.key),
      ));
    }
    for (var chapter in stored) {
      if (seenIds.add(chapter.identity.chapterId)) {
        entries.add((
          chapter.identity.chapterId,
          chapter.identity.chapterTitle.isEmpty
              ? chapter.identity.chapterId
              : chapter.identity.chapterTitle,
        ));
      }
    }
    if (entries.isEmpty) {
      context.showMessage(message: '暂无内容'.tl);
      return;
    }

    // A legacy page row may predate the chapter index. Hydrating it here makes
    // the status tabs accurate without requiring a new translation run.
    final translatedIds = <String>{...storedById.keys};
    for (var entry in entries) {
      if (translatedIds.contains(entry.$1)) continue;
      final pages = ImageTranslationService.storedPageCount(
        comic.comicId,
        comic.sourceKey,
        entry.$1,
        comicTitle: title,
        comicCover: cover,
        chapterTitle: entry.$2,
      );
      if (pages > 0) translatedIds.add(entry.$1);
    }
    stored = TranslationStore().chaptersFor(
      comic.sourceKey,
      comic.comicId,
      sourceLang: comic.sourceLang,
      targetLang: comic.targetLang,
    );
    translatedIds.addAll(stored.map((chapter) => chapter.identity.chapterId));

    List<(String, List<int>)>? groups;
    if (details?.chapters?.isGrouped == true) {
      var grouped = <(String, List<int>)>[];
      final groupedIndices = <int>{};
      for (var groupName in details!.chapters!.groups) {
        var ids = details.chapters!.getGroup(groupName).keys.toSet();
        var indices = [
          for (var index = 0; index < entries.length; index++)
            if (ids.contains(entries[index].$1)) index,
        ];
        if (indices.isNotEmpty) {
          grouped.add((groupName, indices));
          groupedIndices.addAll(indices);
        }
      }
      final ungrouped = [
        for (var index = 0; index < entries.length; index++)
          if (!groupedIndices.contains(index)) index,
      ];
      if (ungrouped.isNotEmpty) {
        grouped.add(('Other'.tl, ungrouped));
      }
      groups = grouped.isEmpty ? null : grouped;
    }

    void startJob(List<int> selected) {
      var task = PreTranslationTaskManager.instance.start(
        cid: comic.comicId,
        sourceKey: comic.sourceKey,
        comicType: _comicTypeForSource(comic.sourceKey),
        title: title,
        cover: cover,
        chapters: [
          for (var index in selected)
            PreTranslationChapter(
              eid: entries[index].$1,
              title: entries[index].$2,
            ),
        ],
      );
      App.globalContext!.showMessage(
        message: task == null
            ? (ImageTranslationService.isReadyForComic(
                comic.comicId,
                comic.sourceKey,
              )
                ? '该漫画的预翻译任务已在进行中'.tl
                : '请先配置 AI 翻译'.tl)
            : '已开始预翻译'.tl,
      );
    }

    context.to(
      () => _SelectPreTranslateChapter(
        cid: comic.comicId,
        sourceKey: comic.sourceKey,
        comicType: _comicTypeForSource(comic.sourceKey),
        title: title,
        cover: cover,
        entries: entries,
        groups: groups,
        translatedChapterIds: translatedIds,
        translatedView: true,
        finishSelect: startJob,
      ),
    );
  }

  Future<void> hydrateAndOpen() async {
    var cached = ComicDetailsCache().find(comic.sourceKey, comic.comicId);
    if (cached != null) {
      await open(details: cached);
      return;
    }
    var source = ComicSource.find(comic.sourceKey);
    if (source?.loadComicInfo != null) {
      try {
        var res = await source!.loadComicInfo!(comic.comicId);
        if (!res.error) {
          ComicDetailsCache().update(
            comic.sourceKey,
            comic.comicId,
            res.data,
          );
          await open(details: res.data);
          return;
        }
      } catch (e, s) {
        Log.error('Translated Comics', 'Failed to load comic metadata: $e\n$s');
      }
    }
    await open();
  }

  unawaited(hydrateAndOpen());
}

/// Chapter multi-select for background pre-translation. Mirrors
/// [_SelectDownloadChapter] but has no "already done" disabled rows — a
/// chapter can always be re-queued (cached pages are skipped at run time).
class _SelectPreTranslateChapter extends StatefulWidget {
  const _SelectPreTranslateChapter({
    required this.cid,
    required this.sourceKey,
    required this.comicType,
    required this.title,
    required this.cover,
    required this.entries,
    this.translatedChapterIds = const {},
    this.groups,
    this.translatedView = false,
    required this.finishSelect,
  });

  final String cid;
  final String sourceKey;
  final ComicType comicType;
  final String title;
  final String cover;

  /// Ordered list of chapter entries (eid, display title).
  final List<(String, String)> entries;

  /// Chapter ids that already have at least one durable translated page.
  /// Used by the translated-comics view to split the picker into status tabs.
  final Set<String> translatedChapterIds;

  /// When the source groups chapters (e.g. comick's English/Latin editions),
  /// each entry is (group name, flat indices into [entries]) so the picker can
  /// show a tab per group. Null when the comic has no groups.
  final List<(String, List<int>)>? groups;

  final bool translatedView;

  final void Function(List<int>) finishSelect;

  @override
  State<_SelectPreTranslateChapter> createState() =>
      _SelectPreTranslateChapterState();
}

enum _TranslationFilter { all, pending, translating, stored, attention }

enum _ChapterTranslationState {
  pending,
  stored,
  complete,
  failed,
  paused,
  running,
  queued,
}

class _ChapterFilterStatus {
  const _ChapterFilterStatus(
    this.state,
    this.saved,
    this.total,
    this.failed,
    this.progress,
    this.task,
  );

  final _ChapterTranslationState state;
  final int saved;
  final int total;
  final int failed;
  final double? progress;
  final PreTranslationTask? task;

  bool get stored => saved > 0;

  bool get active =>
      state == _ChapterTranslationState.running ||
      state == _ChapterTranslationState.paused ||
      state == _ChapterTranslationState.queued;
}

class _SelectPreTranslateChapterState extends State<_SelectPreTranslateChapter>
    with TickerProviderStateMixin {
  List<int> selected = [];
  final Set<String> _removedChapterIds = {};
  final _search = TextEditingController();
  Map<String, int> _savedPages = {};
  Map<String, int> _pageTotals = {};
  var _fetchingPageCounts = false;

  static const _availableFilters = [
    _TranslationFilter.all,
    _TranslationFilter.pending,
    _TranslationFilter.translating,
    _TranslationFilter.stored,
    _TranslationFilter.attention,
  ];

  late final TabController _statusTabController;
  final _tabStorage = PageStorageBucket();
  TabController? _groupTabController;

  _TranslationFilter get _currentFilter =>
      _availableFilters[_statusTabController.index];

  bool get _showTranslated => _currentFilter == _TranslationFilter.stored;

  /// Whether entry [index] is offered to the user at all: not deleted this
  /// session, not hidden as a duplicate, and matching the active status tab.
  bool _isVisible(int index) =>
      !_removedChapterIds.contains(widget.entries[index].$1) &&
      _matchesQuery(index) &&
      _matchesStatus(index);

  bool _matchesQuery(int index) {
    final query = _search.text.replaceAll(RegExp(r'\s'), '').toLowerCase();
    if (query.isEmpty) return true;
    final entry = widget.entries[index];
    final title = entry.$2.replaceAll(RegExp(r'\s'), '').toLowerCase();
    return title.contains(query) ||
        entry.$1.toLowerCase().contains(query) ||
        '${index + 1}' == query;
  }

  @override
  void initState() {
    super.initState();
    _loadStore();
    final initialFilter = widget.translatedView
        ? _TranslationFilter.stored
        : _TranslationFilter.pending;
    _statusTabController = TabController(
      length: _availableFilters.length,
      initialIndex: _availableFilters.indexOf(initialFilter),
      vsync: this,
    )..addListener(_onStatusTabChanged);
    _resetGroupTabController();
    PreTranslationTaskManager.instance.addListener(_onTaskUpdate);
    TranslationStore().addListener(_onStoreUpdate);
  }

  @override
  void dispose() {
    _statusTabController
      ..removeListener(_onStatusTabChanged)
      ..dispose();
    _groupTabController
      ?..removeListener(_onGroupTabChanged)
      ..dispose();
    PreTranslationTaskManager.instance.removeListener(_onTaskUpdate);
    TranslationStore().removeListener(_onStoreUpdate);
    _search.dispose();
    super.dispose();
  }

  void _loadStore() {
    final config = TranslationConfig.of(widget.cid, widget.sourceKey);
    _savedPages = {
      for (final chapter in TranslationStore().chaptersFor(
        widget.sourceKey,
        widget.cid,
        sourceLang: config.sourceLang,
        targetLang: config.targetLang,
      ))
        chapter.identity.chapterId: chapter.pageCount,
    };
    for (final entry in widget.entries) {
      final eid = entry.$1;
      if ((_savedPages[eid] ?? 0) > 0) continue;
      final pages = ImageTranslationService.storedPageCount(
        widget.cid,
        widget.sourceKey,
        eid,
        comicTitle: widget.title,
        comicCover: widget.cover,
        chapterTitle: entry.$2,
      );
      if (pages > 0) _savedPages[eid] = pages;
    }
    _pageTotals = TranslationStore().chapterPageCounts(
      widget.sourceKey,
      widget.cid,
    );
  }

  void _onSearchChanged(String _) {
    _resetGroupTabController();
    setState(selected.clear);
  }

  void _onStatusTabChanged() {
    if (!mounted || _statusTabController.indexIsChanging) return;
    // A selection belongs to one status action. Do not accidentally re-run a
    // translated chapter that was selected before switching to pending.
    _resetGroupTabController();
    setState(() {
      selected.clear();
    });
  }

  void _onGroupTabChanged() {
    if (mounted && !_groupTabController!.indexIsChanging) setState(() {});
  }

  List<(String, List<int>)> get _displayGroups {
    final groups = widget.groups;
    if (groups == null) return const [];
    return [
      for (var group in groups)
        if (group.$2.any(_isVisible)) group,
    ];
  }

  void _resetGroupTabController() {
    final groups = _displayGroups;
    final previousIndex = _groupTabController?.index ?? 0;
    _groupTabController
      ?..removeListener(_onGroupTabChanged)
      ..dispose();
    if (groups.isEmpty) {
      _groupTabController = null;
      return;
    }
    _groupTabController = TabController(
      length: groups.length,
      initialIndex: previousIndex.clamp(0, groups.length - 1),
      vsync: this,
    )..addListener(_onGroupTabChanged);
  }

  /// Flat entry indices the visible tab covers — the scope select-all acts on.
  /// A grouped comic shows one tab per edition, and selecting every chapter of
  /// every edition is virtually never what the user means, so the action stays
  /// inside the tab they are looking at.
  List<int> get _visibleIndices => widget.groups != null
      ? _displayGroups.isEmpty
          ? const []
          : _displayGroups[_groupTabController!.index]
              .$2
              .where(_isVisible)
              .toList()
      : [
          for (int i = 0; i < widget.entries.length; i++)
            if (_isVisible(i)) i,
        ];

  _ChapterFilterStatus _filterStatus(int index) {
    final eid = widget.entries[index].$1;
    final manager = PreTranslationTaskManager.instance;
    final chapter = manager.chapterProgressFor(
      widget.cid,
      widget.sourceKey,
      eid,
    );
    final stored = _savedPages[eid] ?? 0;
    final total = _pageTotals[eid] ?? chapter?.total ?? 0;
    if (chapter == null) {
      return _ChapterFilterStatus(
        stored > 0
            ? _ChapterTranslationState.stored
            : _ChapterTranslationState.pending,
        stored,
        total,
        0,
        null,
        null,
      );
    }

    final task = _taskForChapter(chapter);
    final active = task != null && manager.currentTasks.contains(task);
    final activity = active ? manager.activityOf(task.id) : null;
    final live = manager.livePagesOf(widget.cid, widget.sourceKey, chapter);
    final failures = math.max(0, live.processed - live.done);
    final complete = total > 0 && live.processed >= total;
    final taskComplete = chapter.total > 0 && live.processed >= chapter.total;
    final processing = active &&
        (!taskComplete || (failures > 0 && activity?.chapterEid == eid));
    final state = processing
        ? chapter.paused || task.status == PreTranslationTaskStatus.paused
            ? _ChapterTranslationState.paused
            : activity?.chapterEid == eid
                ? _ChapterTranslationState.running
                : _ChapterTranslationState.queued
        : complete
            ? failures > 0
                ? _ChapterTranslationState.failed
                : _ChapterTranslationState.complete
            : failures > 0
                ? _ChapterTranslationState.failed
                : stored > 0
                    ? _ChapterTranslationState.stored
                    : _ChapterTranslationState.pending;
    final uncommitted =
        activity?.chapterEid == eid ? activity!.uncommittedPages : 0.0;
    return _ChapterFilterStatus(
      state,
      math.max(stored, live.done),
      total,
      failures,
      total > 0
          ? (math.max(
                    stored,
                    chapter.done + chapter.failed + uncommitted,
                  ) /
                  total)
              .clamp(0.0, 1.0)
          : null,
      task,
    );
  }

  PreTranslationTask? _taskForChapter(PreTranslationChapter chapter) {
    final manager = PreTranslationTaskManager.instance;
    for (final task in [...manager.currentTasks, ...manager.historyTasks]) {
      if (task.chapters.contains(chapter)) return task;
    }
    return null;
  }

  Future<void> _fetchPageCounts(List<int> indices) async {
    if (_fetchingPageCounts || indices.isEmpty) return;
    setState(() => _fetchingPageCounts = true);
    var failures = 0;
    for (final index in indices) {
      if (!mounted) break;
      final eid = widget.entries[index].$1;
      try {
        final source = ComicSource.find(widget.sourceKey);
        if (source?.loadComicPages == null) {
          throw StateError('Missing comic source');
        }
        final result = await source!.loadComicPages!
                (widget.cid, eid == '0' ? null : eid)
            .timeout(const Duration(seconds: 30));
        if (result.error || result.data.isEmpty) {
          throw StateError('No pages');
        }
        TranslationStore().recordChapterPageCount(
          widget.sourceKey,
          widget.cid,
          eid,
          result.data.length,
        );
        if (!mounted) break;
        setState(_loadStore);
        if ((_pageTotals[eid] ?? 0) <= 0) failures++;
      } catch (e, s) {
        failures++;
        Log.error('Chapter page count', '$e\n$s');
      }
    }
    if (!mounted) return;
    setState(() => _fetchingPageCounts = false);
    if (failures > 0) {
      context.showMessage(
        message: '@count 个章节的页数获取失败'.tlParams({
          'count': failures.toString(),
        }),
      );
    }
  }

  bool _matchesStatus(int index) {
    final status = _filterStatus(index);
    return switch (_currentFilter) {
      _TranslationFilter.all => true,
      _TranslationFilter.pending =>
        status.state == _ChapterTranslationState.pending,
      _TranslationFilter.translating => status.active,
      _TranslationFilter.stored => status.stored,
      _TranslationFilter.attention =>
        status.failed > 0 || status.state == _ChapterTranslationState.paused,
    };
  }

  bool get _allVisibleSelected {
    var visible = _visibleIndices;
    return visible.isNotEmpty && visible.every(selected.contains);
  }

  /// Ticks or clears just the visible tab's chapters, leaving any selection in
  /// the other tabs alone. Ticking never starts translation — only Start does.
  void _toggleSelectVisible() {
    var visible = _visibleIndices;
    setState(() {
      if (_allVisibleSelected) {
        selected.removeWhere(visible.contains);
      } else {
        for (var i in visible) {
          if (!selected.contains(i)) selected.add(i);
        }
      }
    });
  }

  void _onTaskUpdate() {
    if (!mounted) return;
    setState(() {
      selected.removeWhere((index) => !_matchesStatus(index));
    });
    _resetGroupTabController();
  }

  void _onStoreUpdate() {
    if (!mounted) return;
    setState(() {
      _loadStore();
      selected.removeWhere((index) => !_matchesStatus(index));
    });
    _resetGroupTabController();
  }

  /// Resets the translations of the chapters the user checked and translates
  /// them again. Only the selected chapters' stored text + rendered pages are
  /// dropped (the learned glossary is kept, so other chapters stay consistent),
  /// their pre-translation status is cleared so the ticks go away, and a fresh
  /// job is queued for exactly those chapters. Nothing checked = a prompt, since
  /// re-translation is intentionally opt-in per chapter.
  void _reTranslate() {
    if (selected.isEmpty) {
      App.globalContext!.showMessage(
        message: "请先勾选要重新翻译的章节".tl,
      );
      return;
    }
    if (!ImageTranslationService.isReadyForComic(
      widget.cid,
      widget.sourceKey,
    )) {
      App.globalContext!.showMessage(message: '请先配置 AI 翻译'.tl);
      return;
    }
    var picked = List<int>.from(selected)..sort();
    showConfirmDialog(
      context: context,
      title: "重新翻译所选章节？".tl,
      content: "将清除所选 @count 个章节的翻译，然后重新翻译。"
          .tlParams({'count': picked.length.toString()}),
      onConfirm: () async {
        var service = ImageTranslationService.instance;
        var eids = <String>{};
        for (var i in picked) {
          var eid = widget.entries[i].$1;
          eids.add(eid);
          await service.retranslate(widget.cid, widget.sourceKey, eid: eid);
        }
        PreTranslationTaskManager.instance.resetChapterStatus(
          widget.cid,
          widget.sourceKey,
          eids,
        );
        widget.finishSelect(picked);
        if (mounted) {
          context.pop();
        }
      },
    );
  }

  String _status(_ChapterFilterStatus row) {
    final counts = {
      'done': row.saved.toString(),
      'total': row.total.toString(),
      'failed': row.failed.toString(),
    };
    return switch (row.state) {
      _ChapterTranslationState.pending =>
        '${'待翻译'.tl}${row.total > 0 ? ' · ${'@count 页'.tlParams({
                'count': row.total.toString()
              })}' : ''}',
      _ChapterTranslationState.stored => row.total > 0
          ? '已保存 @done/@total 页'.tlParams(counts)
          : '已保存 @count 页 · 总页数未知'.tlParams({
              'count': row.saved.toString(),
            }),
      _ChapterTranslationState.complete => '已完成 · @done/@total 页'.tlParams(
          counts,
        ),
      _ChapterTranslationState.failed => (row.total > 0
              ? '已翻译 @done/@total 页 · @failed 页失败'
              : '已保存 @done 页 · 总页数未知 · @failed 页失败')
          .tlParams(counts),
      _ChapterTranslationState.queued =>
        '${'排队中'.tl}${row.total > 0 ? ' · ${'@count 页'.tlParams({
                'count': row.total.toString()
              })}' : ''}',
      _ =>
        '${(row.state == _ChapterTranslationState.paused ? '已暂停' : '翻译中').tl} · '
            '${row.total > 0 ? '@done/@total 页'.tlParams(counts) : '已保存 @count 页 · 总页数未知'.tlParams({
                    'count': row.saved.toString()
                  })}'
            '${row.progress == null ? '' : ' · ${(row.progress! * 100).round()}%'}',
    };
  }

  Widget _buildChapterStatus(int index) {
    final row = _filterStatus(index);
    final color = switch (row.state) {
      _ChapterTranslationState.failed => context.colorScheme.error,
      _ChapterTranslationState.pending ||
      _ChapterTranslationState.queued =>
        context.colorScheme.onSurfaceVariant,
      _ => context.colorScheme.primary,
    };
    final icon = switch (row.state) {
      _ChapterTranslationState.pending => Icons.schedule_outlined,
      _ChapterTranslationState.stored => Icons.check_circle_outline,
      _ChapterTranslationState.complete => Icons.check_circle,
      _ChapterTranslationState.failed => Icons.error_outline,
      _ChapterTranslationState.paused => Icons.pause_circle_outline,
      _ChapterTranslationState.running => Icons.translate_rounded,
      _ChapterTranslationState.queued => Icons.queue_outlined,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                _status(row),
                style: ts.s12.withColor(color),
              ),
            ),
          ],
        ),
        if (row.active && row.progress != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: LinearProgressIndicator(value: row.progress),
          ),
      ],
    );
  }

  /// Confirms before starting: a multi-chapter run against a paid AI endpoint
  /// can be costly (the offline engine is free).
  /// Small selections start straight away; larger ones ask first.
  void _confirmAndStart() {
    selected.sort();
    void start() {
      widget.finishSelect(selected);
      context.pop();
    }

    // A single chapter is cheap enough to skip the prompt.
    if (selected.length < 2) {
      start();
      return;
    }
    showConfirmDialog(
      context: context,
      title: "开始预翻译？".tl,
      content: "即将翻译 @count 个章节。若你配置的 LLM 端点是付费的，可能产生费用。"
          .tlParams({'count': selected.length.toString()}),
      onConfirm: start,
    );
  }

  bool _isChapterActive(int index) =>
      PreTranslationTaskManager.instance.isChapterActive(
        widget.cid,
        widget.sourceKey,
        widget.entries[index].$1,
      );

  void _startChapter(int index) {
    if (!ImageTranslationService.isReadyForComic(
      widget.cid,
      widget.sourceKey,
    )) {
      context.showMessage(message: '请先配置 AI 翻译'.tl);
      return;
    }
    if (_isChapterActive(index)) {
      context.showMessage(message: '该章节的预翻译任务已在进行中'.tl);
      return;
    }
    showConfirmDialog(
      context: context,
      title: '开始预翻译？'.tl,
      content: '即将翻译「@title」。若你配置的 LLM 端点是付费的，可能产生费用。'
          .tlParams({'title': widget.entries[index].$2}),
      onConfirm: () {
        if (_isChapterActive(index)) {
          context.showMessage(message: '该章节的预翻译任务已在进行中'.tl);
          return;
        }
        widget.finishSelect([index]);
        if (mounted) setState(() => selected.remove(index));
      },
    );
  }

  /// Clears just this chapter's stored text + rendered pages (the comic's
  /// learned glossary is kept, other chapters still rely on it) and drops its
  /// recorded pre-translation status so the "translated" marker goes away. No
  /// new job is started — use "Re-translate" for that.
  void _deleteChapterTranslation(int index) {
    var eid = widget.entries[index].$1;
    var title = widget.entries[index].$2;
    showConfirmDialog(
      context: context,
      title: "删除该章节的翻译？".tl,
      content: "将删除「@title」已存的翻译和嵌字页面，原图不受影响。".tlParams({'title': title}),
      onConfirm: () async {
        await ImageTranslationService.instance.retranslate(
          widget.cid,
          widget.sourceKey,
          eid: eid,
        );
        PreTranslationTaskManager.instance.resetChapterStatus(
          widget.cid,
          widget.sourceKey,
          {eid},
        );
        if (mounted) {
          App.globalContext!.showMessage(
            message: "翻译结果已清除".tl,
          );
          if (widget.translatedView) {
            setState(() {
              selected.remove(index);
              _removedChapterIds.add(eid);
            });
            if (_visibleIndices.isEmpty && mounted) context.pop();
          } else {
            setState(() {});
          }
        }
      },
    );
  }

  /// Clears this chapter's translation and immediately queues a fresh job for
  /// just this chapter (the glossary is kept so it stays consistent with the
  /// rest of the comic).
  void _reTranslateChapter(int index) {
    if (!ImageTranslationService.isReadyForComic(
      widget.cid,
      widget.sourceKey,
    )) {
      App.globalContext!.showMessage(message: '请先配置 AI 翻译'.tl);
      return;
    }
    var eid = widget.entries[index].$1;
    var title = widget.entries[index].$2;
    showConfirmDialog(
      context: context,
      title: "重新翻译该章节？".tl,
      content: "将清除「@title」的翻译，然后重新翻译。".tlParams({'title': title}),
      onConfirm: () async {
        await ImageTranslationService.instance.retranslate(
          widget.cid,
          widget.sourceKey,
          eid: eid,
        );
        PreTranslationTaskManager.instance.resetChapterStatus(
          widget.cid,
          widget.sourceKey,
          {eid},
        );
        widget.finishSelect([index]);
        if (mounted) setState(() {});
      },
    );
  }

  PreTranslationTask? _currentTaskFor(String eid) {
    final comicKey = '${widget.cid}@${widget.sourceKey}';
    for (final task in PreTranslationTaskManager.instance.currentTasks) {
      if (task.comicKey != comicKey) continue;
      if (task.chapters
          .any((chapter) => chapter.eid == eid && !chapter.canceled)) {
        return task;
      }
    }
    return null;
  }

  void _pauseOrResumeChapter(int index) {
    final eid = widget.entries[index].$1;
    final task = _currentTaskFor(eid);
    final chapter = task?.chapters
        .where((chapter) => chapter.eid == eid && !chapter.canceled)
        .firstOrNull;
    if (task == null || chapter == null) return;
    final manager = PreTranslationTaskManager.instance;
    if (chapter.paused) {
      manager.resumeChapter(task.id, eid);
    } else {
      manager.pauseChapter(task.id, eid);
    }
  }

  void _retryChapter(int index) {
    if (!ImageTranslationService.isReadyForComic(
      widget.cid,
      widget.sourceKey,
    )) {
      context.showMessage(message: '请先配置 AI 翻译'.tl);
      return;
    }
    final row = _filterStatus(index);
    final manager = PreTranslationTaskManager.instance;
    final chapter = manager.chapterProgressFor(
      widget.cid,
      widget.sourceKey,
      widget.entries[index].$1,
    );
    if (chapter == null || row.failed == 0) return;
    showConfirmDialog(
      context: context,
      title: '重试失败页面'.tl,
      content: '将重试 @count 个失败页面，已完成页面会保留。付费服务可能产生费用。'
          .tlParams({'count': row.failed.toString()}),
      onConfirm: () {
        final current = row.task;
        if (current != null && manager.currentTasks.contains(current)) {
          manager.retryChapter(current.id, chapter.eid);
          return;
        }
        final task = manager.start(
          cid: widget.cid,
          sourceKey: widget.sourceKey,
          comicType: widget.comicType,
          title: widget.title,
          cover: widget.cover,
          chapters: [
            PreTranslationChapter.fromJson(chapter.toJson())
              ..paused = false
              ..canceled = false,
          ],
        );
        if (task == null) {
          context.showMessage(message: '无法开始重试，请检查 AI 翻译配置'.tl);
        }
      },
    );
  }

  /// Cancels just this chapter's slice of a running pre-translation job,
  /// leaving the rest of the job going. Only meaningful while the chapter is
  /// active (queued or translating).
  void _cancelChapter(int index) {
    var eid = widget.entries[index].$1;
    var manager = PreTranslationTaskManager.instance;
    var task = _currentTaskFor(eid);
    if (task == null) return;
    manager.cancelChapter(task.id, eid);
    if (mounted) {
      setState(() {});
      App.globalContext!.showMessage(message: "已取消该章节翻译".tl);
    }
  }

  void _readChapter(int index) {
    final entries = widget.entries;
    final chapters = widget.groups == null
        ? ComicChapters({for (final entry in entries) entry.$1: entry.$2})
        : ComicChapters.grouped({
            for (final group in widget.groups!)
              group.$1: {
                for (final i in group.$2) entries[i].$1: entries[i].$2,
              },
          });
    final eid = entries[index].$1;
    final initialEp = chapters.allChapters.keys.toList().indexOf(eid) + 1;
    App.globalTo(
      () => ComicReadingPage(
        CustomReadingData(
          widget.cid,
          widget.title,
          ComicSource.find(widget.sourceKey),
          chapters,
          historyCover: widget.cover,
          sourceKey: widget.sourceKey,
        ),
        0,
        initialEp,
      ),
    );
  }

  String _edition(int index) =>
      widget.groups
          ?.where((group) => group.$2.contains(index))
          .firstOrNull
          ?.$1 ??
      '';

  void _showChapterDetails(int index) {
    final edition = _edition(index);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: widget.entries[index].$2,
        content: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            [
              if (edition.isNotEmpty) edition,
              _status(_filterStatus(index)),
            ].join('\n'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('关闭'.tl),
          ),
        ],
      ),
    );
  }

  void _showChapterEdition(int index) {
    _statusTabController.index = 0;
    _search.clear();
    selected.clear();
    _resetGroupTabController();
    final group = _displayGroups.indexWhere(
      (group) => group.$2.contains(index),
    );
    if (group >= 0) _groupTabController?.index = group;
    setState(() {});
  }

  void _chapterMenu(int index, Offset offset) {
    final row = _filterStatus(index);
    final task = row.task;
    final edition = _edition(index);
    showMenuX(
      context,
      offset,
      [
        if (row.saved > 0)
          MenuEntry(
            icon: Icons.menu_book_outlined,
            text: '阅读章节（已保存 @count 页）'.tlParams({
              'count': row.saved.toString(),
            }),
            onClick: () => _readChapter(index),
          ),
        if (row.active)
          MenuEntry(
            icon: row.state == _ChapterTranslationState.paused
                ? Icons.play_arrow
                : Icons.pause,
            text: row.state == _ChapterTranslationState.paused
                ? '继续本章节'.tl
                : '暂停本章节'.tl,
            onClick: () => _pauseOrResumeChapter(index),
          )
        else if (row.failed > 0)
          MenuEntry(
            icon: Icons.refresh_rounded,
            text: '重试失败页面'.tl,
            onClick: () => _retryChapter(index),
          )
        else
          MenuEntry(
            icon: Icons.info_outline,
            text: '章节进度'.tl,
            onClick: () => _showChapterDetails(index),
          ),
        MenuEntry(
          icon: Icons.schedule,
          text: row.state == _ChapterTranslationState.pending
              ? '预翻译本章节'.tl
              : '查看任务'.tl,
          onClick: () => row.state == _ChapterTranslationState.pending
              ? _startChapter(index)
              : _openTasks(task?.id),
        ),
        MenuEntry(
          icon: Icons.info_outline,
          text: '章节详情'.tl,
          onClick: () => _showChapterDetails(index),
        ),
        if (!_fetchingPageCounts)
          MenuEntry(
            icon: Icons.format_list_numbered,
            text: row.total > 0 ? '刷新页数'.tl : '获取页数'.tl,
            onClick: () => _fetchPageCounts([index]),
          ),
        if (!_isChapterActive(index))
          MenuEntry(
            icon: Icons.refresh_rounded,
            text: '重新翻译本章节'.tl,
            onClick: () => _reTranslateChapter(index),
          ),
        MenuEntry(
          icon: Icons.library_books_outlined,
          text: '查看该版本的章节'.tl,
          onClick: () => _showChapterEdition(index),
        ),
        if (_isChapterActive(index) && task != null)
          MenuEntry(
            icon: Icons.close,
            text: '取消翻译'.tl,
            color: context.colorScheme.error,
            onClick: () => _cancelChapter(index),
          ),
        if (row.saved > 0 && !_isChapterActive(index))
          MenuEntry(
            icon: Icons.delete_outline,
            text: '删除本章节翻译'.tl,
            color: context.colorScheme.error,
            onClick: () => _deleteChapterTranslation(index),
          ),
      ],
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.entries[index].$2,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            [widget.title, edition]
                .where((text) => text.isNotEmpty)
                .join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ts.s12.withColor(context.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String _taskStatus(PreTranslationTaskStatus status) => switch (status) {
        PreTranslationTaskStatus.running => '翻译中'.tl,
        PreTranslationTaskStatus.paused => '已暂停'.tl,
        PreTranslationTaskStatus.completed => '已完成'.tl,
        PreTranslationTaskStatus.canceled => '已取消'.tl,
        PreTranslationTaskStatus.failed => '失败'.tl,
      };

  void _openTasks([String? taskId]) {
    final manager = PreTranslationTaskManager.instance;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: '预翻译任务'.tl,
        content: SizedBox(
          width: 560,
          height: math.min(520, context.height * 0.65),
          child: AnimatedBuilder(
            animation: manager,
            builder: (context, _) {
              final tasks = [
                ...manager.currentTasks,
                ...manager.historyTasks,
              ]
                  .where(
                    (task) =>
                        task.comicKey == '${widget.cid}@${widget.sourceKey}',
                  )
                  .toList();
              if (taskId != null) {
                tasks.sort((a, b) {
                  if (a.id == taskId) return -1;
                  if (b.id == taskId) return 1;
                  return 0;
                });
              }
              if (tasks.isEmpty) {
                return Center(child: Text('暂无预翻译任务'.tl));
              }
              return ListView(
                children: [
                  for (final task in tasks)
                    ExpansionTile(
                      initiallyExpanded: task.id == taskId || tasks.length == 1,
                      title: Text(
                        task.title.isEmpty ? widget.title : task.title,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_taskStatus(task.status)} · ${task.done + task.failed}/${task.total} · '
                            '${'@count 页失败'.tlParams({
                                  'count': task.failed.toString()
                                })}',
                          ),
                          if (manager.currentTasks.contains(task))
                            LinearProgressIndicator(
                              value: manager.activityOf(task.id)?.liveProgress(
                                        task,
                                      ) ??
                                  task.progress,
                            ),
                        ],
                      ),
                      children: [
                        for (final chapter in task.chapters)
                          Builder(
                            builder: (context) {
                              final index = widget.entries.indexWhere(
                                (entry) => entry.$1 == chapter.eid,
                              );
                              final active = manager.currentTasks.contains(
                                    task,
                                  ) &&
                                  !chapter.canceled;
                              return ListTile(
                                dense: true,
                                title: Text(chapter.title),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${chapter.canceled ? '${'已取消'.tl} · ' : chapter.paused ? '${'已暂停'.tl} · ' : ''}'
                                      '${chapter.done + chapter.failed}/${chapter.total} · '
                                      '${'@count 页失败'.tlParams({
                                            'count': chapter.failed.toString()
                                          })}',
                                    ),
                                    if (active ||
                                        (chapter.failed > 0 && index >= 0))
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          if (active)
                                            TextButton(
                                              onPressed: () => chapter.paused
                                                  ? manager.resumeChapter(
                                                      task.id,
                                                      chapter.eid,
                                                    )
                                                  : manager.pauseChapter(
                                                      task.id,
                                                      chapter.eid,
                                                    ),
                                              child: Text(
                                                chapter.paused
                                                    ? '继续'.tl
                                                    : '暂停'.tl,
                                              ),
                                            ),
                                          if (chapter.failed > 0 && index >= 0)
                                            TextButton(
                                              onPressed: () =>
                                                  _retryChapter(index),
                                              child: Text('重试失败页面'.tl),
                                            ),
                                          if (active)
                                            TextButton(
                                              onPressed: () =>
                                                  manager.cancelChapter(
                                                task.id,
                                                chapter.eid,
                                              ),
                                              child: Text('取消'.tl),
                                            ),
                                        ],
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        if (manager.currentTasks.contains(task))
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => manager.cancel(task.id),
                              child: Text(
                                '取消整个任务'.tl,
                                style: TextStyle(
                                  color: context.colorScheme.error,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('关闭'.tl),
          ),
        ],
      ),
    );
  }

  void _openGlossary() {
    showDialog<void>(
      context: context,
      builder: (_) => _GlossaryDialog(
        cid: widget.cid,
        sourceKey: widget.sourceKey,
        title: widget.title,
      ),
    );
  }

  /// Clears every stored translation and rendered page of this whole comic
  /// (the learned glossary too, matching the detail page's whole-comic
  /// re-translate) without starting a new job. Reached from the picker's menu.
  void _deleteComicTranslation() {
    showConfirmDialog(
      context: context,
      title: "删除本漫画的全部翻译？".tl,
      content: "将删除本漫画所有已存的翻译和嵌字页面，原图不受影响。".tl,
      onConfirm: () async {
        // Stop any running job for this comic first, so it doesn't keep
        // repopulating the cache we're about to clear.
        var running = PreTranslationTaskManager.instance.runningTaskFor(
          widget.cid,
          widget.sourceKey,
        );
        if (running != null) {
          PreTranslationTaskManager.instance.cancel(running.id);
        }
        await ImageTranslationService.instance.retranslate(
          widget.cid,
          widget.sourceKey,
        );
        PreTranslationTaskManager.instance.resetComicStatus(
          widget.cid,
          widget.sourceKey,
        );
        if (mounted) {
          App.globalContext!.showMessage(
            message: "翻译结果已清除".tl,
          );
          if (widget.translatedView) {
            context.pop();
          } else {
            setState(() {});
          }
        }
      },
    );
  }

  Offset _menuAnchor(BuildContext target) {
    final box = target.findRenderObject() as RenderBox?;
    return box?.localToGlobal(Offset(box.size.width, box.size.height)) ??
        Offset.zero;
  }

  /// One checkbox row for the flat chapter index [i].
  Widget _buildChapterTile(int i) {
    final title = widget.entries[i].$2;
    final eid = widget.entries[i].$1;
    final isActive = _isChapterActive(i);
    final activeChapter = _currentTaskFor(eid)
        ?.chapters
        .where((chapter) => chapter.eid == eid && !chapter.canceled)
        .firstOrNull;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) => _chapterMenu(i, details.globalPosition),
      onSecondaryTapUp: (details) => _chapterMenu(i, details.globalPosition),
      child: CheckboxListTile(
        title: Row(
          children: [
            Expanded(child: Text(title)),
            if (activeChapter != null)
              IconButton(
                icon: Icon(
                  activeChapter.paused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                ),
                iconSize: 20,
                tooltip: activeChapter.paused ? '继续翻译'.tl : '暂停翻译'.tl,
                onPressed: () => _pauseOrResumeChapter(i),
              ),
            if (activeChapter != null && activeChapter.failed > 0)
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                iconSize: 20,
                tooltip: '重试失败页面'.tl,
                onPressed: () => _retryChapter(i),
              ),
            if (isActive)
              IconButton(
                icon: const Icon(Icons.close_rounded),
                iconSize: 20,
                tooltip: '取消翻译'.tl,
                color: context.colorScheme.error,
                onPressed: () => _cancelChapter(i),
              ),
            Builder(
              builder: (menuContext) => IconButton(
                icon: const Icon(Icons.more_horiz),
                iconSize: 20,
                tooltip: '章节操作'.tl,
                onPressed: () => _chapterMenu(i, _menuAnchor(menuContext)),
              ),
            ),
          ],
        ),
        subtitle: _buildChapterStatus(i),
        value: selected.contains(i),
        onChanged: (v) {
          setState(() {
            if (selected.contains(i)) {
              selected.remove(i);
            } else {
              selected.add(i);
            }
          });
        },
      ),
    );
  }

  /// The chapter list. When the source groups chapters (e.g. comick's
  /// English/Latin editions) it becomes a set of tabs, one per group, so the
  /// user can find the edition they want instead of scrolling one merged list.
  Widget _buildChapterList() {
    final groups = _displayGroups;
    final visible = _visibleIndices;
    if (widget.groups == null || groups.isEmpty) {
      if (widget.groups != null && visible.isEmpty) {
        return _emptyChapterMessage();
      }
      return ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: visible.length,
        itemBuilder: (context, i) => _buildChapterTile(visible[i]),
      );
    }
    return Column(
      children: [
        AppTabBar(
          key: ValueKey(_groupTabController),
          controller: _groupTabController,
          tabs: groups.map((g) => Tab(text: g.$1)).toList(),
        ),
        Expanded(
          child: TabViewBody(
            key: ValueKey(_groupTabController),
            controller: _groupTabController,
            children: [
              for (var g in groups)
                Builder(
                  builder: (context) {
                    var visible = g.$2.where(_isVisible).toList();
                    return visible.isEmpty
                        ? _emptyChapterMessage()
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: visible.length,
                            itemBuilder: (context, index) =>
                                _buildChapterTile(visible[index]),
                          );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyChapterMessage() {
    if (_search.text.trim().isNotEmpty) {
      return Center(child: Text('未找到匹配章节'.tl, style: ts.s16));
    }
    final message = switch (_currentFilter) {
      _TranslationFilter.all => '暂无章节'.tl,
      _TranslationFilter.pending => '暂无待翻译章节'.tl,
      _TranslationFilter.translating => '暂无翻译中章节'.tl,
      _TranslationFilter.stored => '暂无已翻译章节'.tl,
      _TranslationFilter.attention => '暂无需处理的章节'.tl,
    };
    return Center(
      child: Text(message, style: ts.s16),
    );
  }

  Widget _searchField() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _search,
          builder: (context, value, _) => TextField(
            key: const ValueKey('translation-search'),
            controller: _search,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '搜索章节名称或编号'.tl,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清除搜索'.tl,
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _search.clear();
                        _onSearchChanged('');
                      },
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
      );

  Widget _buildStatusTabs() {
    return Material(
      color: context.colorScheme.surfaceContainerLow,
      child: PageStorage(
        bucket: _tabStorage,
        child: AppTabBar(
          key: const ValueKey('translation-filters'),
          controller: _statusTabController,
          tabs: [
            for (final filter in _availableFilters)
              Tab(
                key: ValueKey('translation-filter-${filter.name}'),
                text: switch (filter) {
                  _TranslationFilter.all => '全部'.tl,
                  _TranslationFilter.pending => '待翻译'.tl,
                  _TranslationFilter.translating => '翻译中'.tl,
                  _TranslationFilter.stored => '已翻译'.tl,
                  _TranslationFilter.attention => '需处理'.tl,
                },
              ),
          ],
        ),
      ),
    );
  }

  List<MenuEntry> _menuEntries() {
    return [
      if (selected.isNotEmpty)
        MenuEntry(
          icon: _showTranslated
              ? Icons.refresh_rounded
              : Icons.play_arrow_rounded,
          text: _showTranslated ? '重新翻译所选'.tl : '开始'.tl,
          onClick: _showTranslated ? _reTranslate : _confirmAndStart,
        ),
      if (!_fetchingPageCounts)
        MenuEntry(
          icon: Icons.format_list_numbered,
          text: '补齐缺失页数'.tl,
          onClick: () => _fetchPageCounts(
            _visibleIndices
                .where((index) => _filterStatus(index).total <= 0)
                .toList(),
          ),
        ),
      MenuEntry(
        icon: Icons.info_outline,
        text: '打开漫画详情'.tl,
        onClick: _openComicInfoData,
      ),
      MenuEntry(
        icon: Icons.menu_book_outlined,
        text: '词汇表'.tl,
        onClick: _openGlossary,
      ),
      MenuEntry(
        icon: Icons.delete_outline_rounded,
        text: '删除全部翻译'.tl,
        color: context.colorScheme.error,
        onClick: _deleteComicTranslation,
      ),
    ];
  }

  void _pageMenu(Offset offset) => showMenuX(
        context,
        offset,
        _menuEntries(),
        title: Text(
          widget.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      );

  void _openComicInfoData() {
    context.to(
      () => ComicPage(
        id: widget.cid,
        sourceKey: widget.sourceKey,
        cover: widget.cover,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canStart = selected.isNotEmpty;
    final usesRetranslate = widget.translatedView && _showTranslated;
    return Scaffold(
      appBar: Appbar(
        title: Text(
          widget.translatedView ? '漫画翻译'.tl : "预翻译".tl,
        ),
        backgroundColor: context.colorScheme.surfaceContainerLow,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: '打开漫画详情'.tl,
            onPressed: _openComicInfoData,
          ),
          Builder(
            builder: (menuContext) => IconButton(
              icon: const Icon(Icons.more_horiz),
              tooltip: '更多'.tl,
              onPressed: () => _pageMenu(_menuAnchor(menuContext)),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _searchField(),
          _buildStatusTabs(),
          if (_fetchingPageCounts)
            LinearProgressIndicator(semanticsLabel: '正在获取页数'.tl),
          Expanded(child: _buildChapterList()),
          Container(
            height: 50,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: context.colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: TextButton(
                    onPressed: _toggleSelectVisible,
                    child: Text(
                      _allVisibleSelected ? "取消全选".tl : "全选".tl,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: canStart
                        ? (usesRetranslate ? _reTranslate : _confirmAndStart)
                        : null,
                    child: Text(
                      usesRetranslate ? '重新翻译'.tl : "开始".tl,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _GlossaryDialog extends StatefulWidget {
  const _GlossaryDialog({
    required this.cid,
    required this.sourceKey,
    required this.title,
  });

  final String cid;
  final String sourceKey;
  final String title;

  @override
  State<_GlossaryDialog> createState() => _GlossaryDialogState();
}

class _GlossaryDialogState extends State<_GlossaryDialog> {
  late List<MapEntry<String, String>> _entries;
  late List<String> _blocked;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final service = ImageTranslationService.instance;
    _entries =
        service.glossaryOf(widget.cid, widget.sourceKey).entries.toList();
    _blocked = service.blockedTermsOf(widget.cid, widget.sourceKey);
  }

  Future<void> _editEntry({String? source, String? translation}) async {
    final sourceController = TextEditingController(text: source ?? '');
    final translationController =
        TextEditingController(text: translation ?? '');
    final isNew = source == null;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: isNew ? '添加词汇'.tl : '编辑词汇'.tl,
        content: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: sourceController,
                enabled: isNew,
                decoration: InputDecoration(
                  labelText: '原文'.tl,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: translationController,
                decoration: InputDecoration(
                  labelText: '译文'.tl,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              final src = sourceController.text.trim();
              final dst = translationController.text.trim();
              if (src.isEmpty || dst.isEmpty) {
                dialogContext.showMessage(message: '原文和译文均不能为空'.tl);
                return;
              }
              final ok = ImageTranslationService.instance.setGlossaryEntry(
                widget.cid,
                widget.sourceKey,
                src,
                dst,
              );
              if (!ok) {
                dialogContext.showMessage(
                  message: '词汇无效：内容过长，或词汇表已满'.tl,
                );
                return;
              }
              dialogContext.pop();
              if (mounted) setState(_reload);
            },
            child: Text('保存'.tl),
          ),
        ],
      ),
    );
    sourceController.dispose();
    translationController.dispose();
  }

  void _removeEntry(String source, {bool block = false}) {
    ImageTranslationService.instance.removeGlossaryEntry(
      widget.cid,
      widget.sourceKey,
      source,
      block: block,
    );
    if (mounted) setState(_reload);
  }

  Future<void> _confirmRemove(String source) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: '移除词汇'.tl,
        content: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('仅删除，还是屏蔽并阻止以后再次添加？'.tl),
        ),
        actions: [
          TextButton(
            onPressed: () {
              dialogContext.pop();
              _removeEntry(source);
            },
            child: Text('仅删除'.tl),
          ),
          FilledButton(
            onPressed: () {
              dialogContext.pop();
              _removeEntry(source, block: true);
            },
            child: Text('屏蔽'.tl),
          ),
        ],
      ),
    );
  }

  void _unblock(String source) {
    ImageTranslationService.instance.unblockTerm(
      widget.cid,
      widget.sourceKey,
      source,
    );
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final empty = _entries.isEmpty && _blocked.isEmpty;
    final publicFreeHint = 'Google Translate 不使用词汇表。切换到 AI 模型可保持名称翻译一致。'.tl;
    return ContentDialog(
      title: '${'词汇表'.tl} · ${widget.title}',
      content: SizedBox(
        width: 560,
        height: math.min(520, context.height * 0.65),
        child: Column(
          children: [
            if (LlmTranslator.activeIsPublicFree)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  publicFreeHint,
                  style: ts.s14.withColor(context.colorScheme.outline),
                ),
              ),
            Expanded(
              child: empty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          LlmTranslator.activeIsPublicFree
                              ? publicFreeHint
                              : '暂无词汇'.tl,
                          style: ts.s16.withColor(context.colorScheme.outline),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView(
                      children: [
                        for (final entry in _entries)
                          ListTile(
                            title: Text(entry.key),
                            subtitle: Text(entry.value),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: '编辑'.tl,
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _editEntry(
                                    source: entry.key,
                                    translation: entry.value,
                                  ),
                                ),
                                IconButton(
                                  tooltip: '删除或屏蔽'.tl,
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _confirmRemove(entry.key),
                                ),
                              ],
                            ),
                          ),
                        if (_blocked.isNotEmpty) ...[
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: Text(
                              '已屏蔽词汇'.tl,
                              style: ts.s14.withColor(
                                context.colorScheme.outline,
                              ),
                            ),
                          ),
                          for (final term in _blocked)
                            ListTile(
                              leading: Icon(
                                Icons.block,
                                size: 20,
                                color: context.colorScheme.outline,
                              ),
                              title: Text(term),
                              trailing: TextButton(
                                onPressed: () => _unblock(term),
                                child: Text('解除屏蔽'.tl),
                              ),
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _editEntry,
          icon: const Icon(Icons.add),
          label: Text('添加词汇'.tl),
        ),
        TextButton(
          onPressed: context.pop,
          child: Text('关闭'.tl),
        ),
      ],
    );
  }
}
