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
    var source = ComicSource.find(comic.sourceKey);
    if (source?.loadComicInfo != null) {
      try {
        var res = await source!.loadComicInfo!(comic.comicId);
        if (!res.error) {
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

class _SelectPreTranslateChapterState extends State<_SelectPreTranslateChapter>
    with TickerProviderStateMixin {
  List<int> selected = [];
  final Set<String> _removedChapterIds = {};
  late final Set<String> _translatedChapterIds;

  late final TabController? _statusTabController;
  TabController? _groupTabController;

  bool get _hasStatusTabs => widget.translatedView;

  bool get _showTranslated =>
      !_hasStatusTabs || _statusTabController!.index == 0;

  /// Whether entry [index] is offered to the user at all: not deleted this
  /// session, not hidden as a duplicate, and matching the active status tab.
  bool _isVisible(int index) =>
      !_removedChapterIds.contains(widget.entries[index].$1) &&
      _matchesStatus(index);

  @override
  void initState() {
    super.initState();
    _translatedChapterIds = {...widget.translatedChapterIds};
    _statusTabController = _hasStatusTabs
        ? (TabController(length: 2, vsync: this)
          ..addListener(_onStatusTabChanged))
        : null;
    _resetGroupTabController();
    PreTranslationTaskManager.instance.addListener(_onTaskUpdate);
    TranslationStore().addListener(_onStoreUpdate);
  }

  @override
  void dispose() {
    _statusTabController
      ?..removeListener(_onStatusTabChanged)
      ..dispose();
    _groupTabController
      ?..removeListener(_onGroupTabChanged)
      ..dispose();
    PreTranslationTaskManager.instance.removeListener(_onTaskUpdate);
    TranslationStore().removeListener(_onStoreUpdate);
    super.dispose();
  }

  void _onStatusTabChanged() {
    if (!mounted || _statusTabController!.indexIsChanging) return;
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

  bool _matchesStatus(int index) {
    if (!_hasStatusTabs) return true;
    final isTranslated = _translatedChapterIds.contains(
      widget.entries[index].$1,
    );
    return isTranslated == _showTranslated;
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
    if (mounted) setState(() {});
  }

  void _onStoreUpdate() {
    if (!mounted) return;
    final config = TranslationConfig.of(widget.cid, widget.sourceKey);
    final current = TranslationStore()
        .chaptersFor(
          widget.sourceKey,
          widget.cid,
          sourceLang: config.sourceLang,
          targetLang: config.targetLang,
        )
        .map((chapter) => chapter.identity.chapterId)
        .toSet();
    setState(() {
      _translatedChapterIds
        ..clear()
        ..addAll(current);
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
      App.globalContext!
          .showMessage(message: '请先配置 AI 翻译'.tl);
      return;
    }
    var picked = List<int>.from(selected)..sort();
    showConfirmDialog(
      context: context,
      title: "重新翻译所选章节？".tl,
      content:
          "将清除所选 @count 个章节的翻译，然后重新翻译。"
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

  /// The trailing status widget for chapter [index]: nothing when idle, a
  /// "waiting" chip when queued but not started, a live progress bar while
  /// translating, or a "translated" tick when done. Distinguishes an active
  /// (running-job) chapter from one merely finished in history.
  Widget? _buildChapterStatus(int index) {
    var eid = widget.entries[index].$1;
    var manager = PreTranslationTaskManager.instance;
    var chapter = manager.chapterProgressFor(widget.cid, widget.sourceKey, eid);

    // No task record for this chapter on THIS device — but its translations may
    // have arrived from another device over WebDAV. Task records are per-device
    // and deliberately not synced (#106), so fall back to the durable, synced
    // translation store: any stored page means the chapter was translated
    // somewhere. Show a "translated" tick with the page count so the user sees
    // it needn't be re-run. Total page count is not stored, so this reports how
    // many pages carry a result rather than a percentage.
    if (chapter == null) {
      var stored = ImageTranslationService.storedPageCount(
        widget.cid,
        widget.sourceKey,
        eid,
        comicTitle: widget.title,
        comicCover: widget.cover,
        chapterTitle: widget.entries[index].$2,
      );
      if (stored <= 0) return null;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: context.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            "@count 页".tlParams({'count': stored.toString()}),
            style: ts.s12.withColor(context.colorScheme.primary),
          ),
        ],
      );
    }

    var active = manager.isChapterActive(widget.cid, widget.sourceKey, eid);
    // Live counts: committed pages plus the running job's finished-but-buffered
    // groups, so the bar tracks work actually done instead of the deliberately
    // conservative resume cursor. Processed (success + failed) keeps the number
    // in step with the bar when a page fails.
    var processed =
        manager.livePagesOf(widget.cid, widget.sourceKey, chapter).processed;
    var isCompleted = chapter.total > 0 && processed >= chapter.total;

    if (isCompleted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: context.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            "已翻译".tl,
            style: ts.s12.withColor(context.colorScheme.primary),
          ),
        ],
      );
    }

    if (!active) return null;

    // Active but nothing processed yet (page count unknown or not started):
    // show a "waiting" state so the user knows it is queued.
    if (chapter.total == 0 || processed == 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 6),
          Text(
            "等待中".tl,
            style: ts.s12.withColor(context.colorScheme.onSurfaceVariant),
          ),
        ],
      );
    }

    var pct = (processed / chapter.total).clamp(0.0, 1.0);
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$processed/${chapter.total}',
            style: ts.s12.withColor(context.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          LinearProgressIndicator(value: pct),
        ],
      ),
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

  /// Whether chapter [index] has translation content the user could delete or
  /// re-run, and is NOT currently being translated. Any stored page (including
  /// an empty "no text" result) counts as translated content — this catches
  /// both fully translated and partially translated chapters, while excluding
  /// an active chapter so a per-chapter action can't collide with a live job.
  bool _chapterHasIdleTranslation(int index) {
    var eid = widget.entries[index].$1;
    var manager = PreTranslationTaskManager.instance;
    if (manager.isChapterActive(widget.cid, widget.sourceKey, eid)) {
      return false;
    }
    return ImageTranslationService.storedPageCount(
          widget.cid,
          widget.sourceKey,
          eid,
          comicTitle: widget.title,
          comicCover: widget.cover,
          chapterTitle: widget.entries[index].$2,
        ) >
        0;
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
      content:
          "将删除「@title」已存的翻译和嵌字页面，原图不受影响。"
              .tlParams({'title': title}),
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
      App.globalContext!
          .showMessage(message: '请先配置 AI 翻译'.tl);
      return;
    }
    var eid = widget.entries[index].$1;
    var title = widget.entries[index].$2;
    showConfirmDialog(
      context: context,
      title: "重新翻译该章节？".tl,
      content:
          "将清除「@title」的翻译，然后重新翻译。"
              .tlParams({'title': title}),
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

  /// Cancels just this chapter's slice of a running pre-translation job,
  /// leaving the rest of the job going. Only meaningful while the chapter is
  /// active (queued or translating).
  void _cancelChapter(int index) {
    var eid = widget.entries[index].$1;
    var manager = PreTranslationTaskManager.instance;
    var task = manager.runningTaskFor(widget.cid, widget.sourceKey);
    if (task == null) return;
    manager.cancelChapter(task.id, eid);
    if (mounted) {
      setState(() {});
      App.globalContext!
          .showMessage(message: "已取消该章节翻译".tl);
    }
  }

  /// Clears every stored translation and rendered page of this whole comic
  /// (the learned glossary too, matching the detail page's whole-comic
  /// re-translate) without starting a new job. Reached from the picker's menu.
  void _deleteComicTranslation() {
    showConfirmDialog(
      context: context,
      title: "删除本漫画的全部翻译？".tl,
      content:
          "将删除本漫画所有已存的翻译和嵌字页面，原图不受影响。"
              .tl,
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

  /// One checkbox row for the flat chapter index [i].
  Widget _buildChapterTile(int i) {
    var title = widget.entries[i].$2;
    var eid = widget.entries[i].$1;
    var progress = _buildChapterStatus(i);
    var isActive = PreTranslationTaskManager.instance.isChapterActive(
      widget.cid,
      widget.sourceKey,
      eid,
    );
    var hasIdleTranslation = _chapterHasIdleTranslation(i);
    return CheckboxListTile(
      title: Row(
        children: [
          Expanded(child: Text(title)),
          if (progress != null) ...[const SizedBox(width: 8), progress],
          if (isActive)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              iconSize: 20,
              tooltip: "取消翻译".tl,
              color: context.colorScheme.error,
              onPressed: () => _cancelChapter(i),
            )
          else if (hasIdleTranslation)
            MenuButton(
              entries: [
                MenuEntry(
                  icon: Icons.refresh_rounded,
                  text: "重新翻译".tl,
                  onClick: () => _reTranslateChapter(i),
                ),
                MenuEntry(
                  icon: Icons.delete_outline_rounded,
                  text: "删除翻译".tl,
                  color: context.colorScheme.error,
                  onClick: () => _deleteChapterTranslation(i),
                ),
              ],
            ),
        ],
      ),
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
    return Center(
      child: Text(
        _showTranslated
            ? '暂无已翻译章节'.tl
            : '暂无待翻译章节'.tl,
        style: ts.s16,
      ),
    );
  }

  Widget _buildStatusTabs() {
    if (!_hasStatusTabs) return const SizedBox.shrink();
    return Material(
      color: context.colorScheme.surfaceContainerLow,
      child: AppTabBar(
        controller: _statusTabController,
        tabs: [
          Tab(text: '已翻译'.tl),
          Tab(text: '待翻译'.tl),
        ],
      ),
    );
  }

  List<MenuEntry> _menuEntries() {
    return [
      MenuEntry(
        icon:
            _showTranslated ? Icons.refresh_rounded : Icons.play_arrow_rounded,
        text: _showTranslated ? "重新翻译所选".tl : "开始".tl,
        onClick: _showTranslated ? _reTranslate : _confirmAndStart,
      ),
      MenuEntry(
        icon: Icons.delete_outline_rounded,
        text: "删除本漫画翻译".tl,
        color: context.colorScheme.error,
        onClick: _deleteComicTranslation,
      ),
    ];
  }

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
          MenuButton(entries: _menuEntries()),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusTabs(),
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
