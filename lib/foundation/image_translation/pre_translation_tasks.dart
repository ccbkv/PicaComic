import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/appdata.dart';
import 'package:pica_comic/foundation/comic_source/comic_source.dart';
import 'package:pica_comic/foundation/image_translation/ordered_group_committer.dart';
import 'package:pica_comic/foundation/image_translation/rate_limiter.dart';
import 'package:pica_comic/foundation/image_translation/translation_config.dart';
import 'package:pica_comic/foundation/image_translation/translation_models.dart';
import 'package:pica_comic/foundation/image_translation/translation_performance_config.dart';
import 'package:pica_comic/foundation/image_translation/translation_service.dart';
import 'package:pica_comic/foundation/image_translation/translation_types.dart';
import 'package:pica_comic/foundation/image_manager.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/network/custom_download_model.dart';
import 'package:pica_comic/network/download.dart';

enum PreTranslationTaskStatus { running, paused, completed, canceled, failed }

/// One chapter queued for background pre-translation.
class PreTranslationChapter {
  PreTranslationChapter({
    required this.eid,
    required this.title,
    this.total = 0,
    this.done = 0,
    this.failed = 0,
    this.canceled = false,
    Set<int>? failedPages,
  }) : failedPages = failedPages ?? <int>{};

  /// Source chapter id (the eid passed to loadComicPages / image keys). For a
  /// comic without chapters this is '0'.
  final String eid;
  final String title;

  /// Page count, resolved lazily when the chapter starts.
  int total;
  int done;
  int failed;

  /// Set when the user cancels just this chapter of a still-running job. The
  /// worker loop skips a canceled chapter (both the forward pass and the retry
  /// pass), so the rest of the job keeps going. Not persisted as "running": a
  /// canceled chapter is simply left where it stopped and never resumed.
  bool canceled;

  /// Indices (into the resolved page-key list) of the pages that failed this
  /// run, so a retry can re-run exactly those and leave the succeeded pages
  /// alone. Kept in lockstep with [failed]: a page enters here when it fails
  /// and leaves when a retry succeeds, so `failedPages.length == failed` for a
  /// chapter recorded by the current version. Persisted so a retry survives a
  /// restart. Older persisted tasks lack it (empty set) — a retry then falls
  /// back to re-scanning the whole chapter, which is cheap because rendered
  /// pages skip via hasRenderedPage.
  final Set<int> failedPages;

  Map<String, dynamic> toJson() => {
        'eid': eid,
        'title': title,
        'total': total,
        'done': done,
        'failed': failed,
        'canceled': canceled,
        'failedPages': failedPages.toList(),
      };

  factory PreTranslationChapter.fromJson(Map<String, dynamic> json) {
    return PreTranslationChapter(
      eid: json['eid']?.toString() ?? '0',
      title: json['title']?.toString() ?? '',
      total: json['total'] ?? 0,
      done: json['done'] ?? 0,
      failed: json['failed'] ?? 0,
      canceled: json['canceled'] == true,
      failedPages: (json['failedPages'] as List? ?? [])
          .map((e) => e is int ? e : int.tryParse('$e'))
          .whereType<int>()
          .toSet(),
    );
  }
}

/// A background job that pre-translates selected chapters of one comic so the
/// rendered pages are cached before the user opens the reader.
///
/// It reuses [ImageTranslationService.translateOne] and therefore writes to
/// the exact cache keys the reader reads from — a pre-translated page shows
/// instantly with no in-reader wait.
class PreTranslationTask {
  PreTranslationTask({
    required this.id,
    required this.cid,
    required this.sourceKey,
    required this.comicType,
    required this.title,
    required this.chapters,
    required this.createdAt,
    this.cover = '',
    this.status = PreTranslationTaskStatus.running,
    this.finishedAt,
  });

  final String id;
  final String cid;
  final String sourceKey;
  final ComicType comicType;
  final String title;
  final String cover;
  final List<PreTranslationChapter> chapters;
  final DateTime createdAt;
  PreTranslationTaskStatus status;
  DateTime? finishedAt;

  String get comicKey => '$cid@$sourceKey';

  /// This comic's own language pair + text-removal mode. Resolved live, exactly
  /// like [ImageTranslationService.cacheKeyFor] does, so the config and the
  /// cache keys a job writes to always describe the same generation.
  TranslationConfig get config => TranslationConfig.of(cid, sourceKey);

  bool get isRunning => status == PreTranslationTaskStatus.running;

  int get total => chapters.fold(0, (sum, c) => sum + c.total);
  int get done => chapters.fold(0, (sum, c) => sum + c.done);
  int get failed => chapters.fold(0, (sum, c) => sum + c.failed);

  /// Whether any chapter has failed pages that could be retried. A canceled
  /// chapter is excluded: both the forward loop and the retry sweep skip it, so
  /// its failures are unreachable and offering a retry for them would do
  /// nothing. Re-running such a chapter goes through the picker's re-translate.
  bool get hasFailures => chapters.any((c) => !c.canceled && c.failed > 0);

  /// Overall progress across the whole job, weighted by chapters rather than
  /// pages. Each chapter contributes an equal 1/N slice; a chapter whose page
  /// count is not resolved yet (total == 0) counts as 0% until it starts, and a
  /// fully processed chapter counts as 100%. This keeps the percentage
  /// representative of the entire comic (all selected chapters), and monotonic,
  /// instead of tracking only the page counts of chapters that have already
  /// begun — which made the earlier page-based ratio jump around as new
  /// chapters resolved their totals.
  double get progress {
    if (chapters.isEmpty) return 0;
    var sum = 0.0;
    for (var c in chapters) {
      if (c.total <= 0) continue;
      sum += ((c.done + c.failed) / c.total).clamp(0.0, 1.0);
    }
    return sum / chapters.length;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'cid': cid,
        'sourceKey': sourceKey,
        'comicType': comicType.index,
        'title': title,
        'cover': cover,
        'createdAt': createdAt.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
        'status': status.name,
        'chapters': chapters.map((c) => c.toJson()).toList(),
      };

  factory PreTranslationTask.fromJson(Map<String, dynamic> json) {
    return PreTranslationTask(
      id: json['id']?.toString() ?? '',
      cid: json['cid']?.toString() ?? '',
      sourceKey: json['sourceKey']?.toString() ?? '',
      comicType: ComicType.values[json['comicType'] ?? 0],
      title: json['title']?.toString() ?? '',
      cover: json['cover']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      finishedAt: DateTime.tryParse(json['finishedAt'] ?? ''),
      status: PreTranslationTaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PreTranslationTaskStatus.completed,
      ),
      chapters: (json['chapters'] as List? ?? [])
          .whereType<Map>()
          .map(
            (e) => PreTranslationChapter.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
    );
  }
}

/// Live view of one in-flight page group.
///
/// Never persisted and never folded into [PreTranslationChapter.done] /
/// `failed`: the resume cursor is `done + failed` and requires those to stay a
/// contiguous *committed* prefix, so a per-page stage change must not touch
/// them. This is the parallel, display-only channel instead.
class PreTranslationGroupActivity {
  PreTranslationGroupActivity({required this.index, required this.pageCount});

  /// Group order within the chapter, which is also its commit order.
  final int index;
  final int pageCount;
  TranslationStage stage = TranslationStage.fetching;

  /// Pages of this group already accounted for, in page units and weighted by
  /// the phase each page has reached — so a group that is minutes from
  /// committing still reads as partial progress rather than as nothing.
  double completedPages = 0;
}

/// What a running job is doing right now, beyond its committed counters.
class PreTranslationActivity {
  /// 1-based index of the chapter being processed; 0 before the first starts.
  int chapterIndex = 0;
  String chapterTitle = '';

  /// eid of the chapter being processed, so a per-chapter display can tell
  /// whether [bufferedPages] belongs to it.
  String chapterEid = '';

  final Map<int, PreTranslationGroupActivity> groups = {};

  /// Pages of groups that finished and handed their counts to the committer,
  /// but which are still buffered behind an earlier, slower group.
  ///
  /// These pages are genuinely rendered and cached; only the resume cursor
  /// cannot move past them yet, because `done + failed` has to stay a
  /// contiguous prefix. Keeping them here lets the display credit real work
  /// without touching the chapter counters. Reset per chapter, since each
  /// chapter gets its own committer.
  int bufferedDone = 0;
  int bufferedFailed = 0;

  int get bufferedPages => bufferedDone + bufferedFailed;

  /// Pages settled for display: committed plus buffered. Never write this back
  /// into [PreTranslationChapter.done] — that would break the resume cursor.
  int liveDone(PreTranslationTask task) => task.done + bufferedDone;

  int liveFailed(PreTranslationTask task) => task.failed + bufferedFailed;

  /// Pages the job is finished with, successes and failures alike — the same
  /// set [PreTranslationTask.progress] counts. Page counters must report this
  /// rather than [liveDone], or a failed page freezes the number while the bar
  /// keeps advancing.
  int liveProcessed(PreTranslationTask task) =>
      liveDone(task) + liveFailed(task);

  /// Stage of the lowest-numbered live group. Counts commit in group order, so
  /// that group is the one holding the cursor — it answers "why hasn't the
  /// number moved" better than whichever group changed stage most recently.
  TranslationStage? get headStage {
    PreTranslationGroupActivity? head;
    for (var g in groups.values) {
      if (head == null || g.index < head.index) head = g;
    }
    return head?.stage;
  }

  /// How many live groups sit in each stage, for the expanded breakdown.
  Map<TranslationStage, int> get stageCounts {
    var counts = <TranslationStage, int>{};
    for (var g in groups.values) {
      counts[g.stage] = (counts[g.stage] ?? 0) + 1;
    }
    return counts;
  }

  /// Pages finished inside groups that have not committed yet, weighted by how
  /// far each in-flight page has got, plus whole groups already waiting on the
  /// committer.
  double get uncommittedPages =>
      bufferedPages +
      groups.values.fold(0.0, (sum, g) => sum + g.completedPages);

  /// [PreTranslationTask.progress] plus those uncommitted pages. A group of
  /// 4-8 pages commits its counts at once, so the committed value can sit
  /// still for minutes — long enough to read as a stalled job. Falls back to
  /// the committed value whenever the running chapter is unknown or its page
  /// count is not resolved yet.
  double liveProgress(PreTranslationTask task) {
    var base = task.progress;
    var index = chapterIndex - 1;
    if (index < 0 || index >= task.chapters.length) return base;
    var chapter = task.chapters[index];
    if (chapter.total <= 0) return base;
    var extra = (uncommittedPages / chapter.total).clamp(0.0, 1.0);
    return (base + extra / task.chapters.length).clamp(0.0, 1.0);
  }
}

/// Manages background pre-translation jobs. Mirrors the structure of the
/// other task managers (currentTasks / historyTasks / persistence) so the
/// tasks page can render it the same way.
class PreTranslationTaskManager with ChangeNotifier {
  PreTranslationTaskManager._() {
    _load();
  }

  static final PreTranslationTaskManager instance =
      PreTranslationTaskManager._();

  final currentTasks = <PreTranslationTask>[];
  final historyTasks = <PreTranslationTask>[];
  final _canceledIds = <String>{};
  final _runningIds = <String>{};
  final _activities = <String, PreTranslationActivity>{};

  /// Live stage detail for a running job; null once it stops. Not persisted —
  /// a restart resumes from the committed counters, not from mid-group state.
  PreTranslationActivity? activityOf(String taskId) => _activities[taskId];

  Timer? _activityNotifyTimer;
  DateTime _lastActivityNotify = DateTime.fromMillisecondsSinceEpoch(0);

  /// Stage changes land per page across up to four concurrent groups, and each
  /// one rebuilds the whole task list. Coalesce them to a few frames a second;
  /// the trailing timer makes sure the final change is not swallowed.
  void _notifyActivity() {
    var now = DateTime.now();
    const window = Duration(milliseconds: 400);
    if (now.difference(_lastActivityNotify) >= window) {
      _lastActivityNotify = now;
      _activityNotifyTimer?.cancel();
      _activityNotifyTimer = null;
      notifyListeners();
      return;
    }
    _activityNotifyTimer ??= Timer(window, () {
      _activityNotifyTimer = null;
      _lastActivityNotify = DateTime.now();
      notifyListeners();
    });
  }

  void Function(PreTranslationTask task)? onTaskFinished;

  /// Starts pre-translating [chapters] (source chapter ids) of a comic. Returns
  /// null when translation is not usable (models/endpoint not configured) or a
  /// job for the comic is already running.
  PreTranslationTask? start({
    required String cid,
    required String sourceKey,
    required ComicType comicType,
    required String title,
    required List<PreTranslationChapter> chapters,
    String cover = '',
  }) {
    if (!ImageTranslationService.isReadyForComic(cid, sourceKey) ||
        chapters.isEmpty) {
      return null;
    }
    var existing = currentTasks
        .where((t) => t.comicKey == '$cid@$sourceKey' && t.isRunning)
        .firstOrNull;
    if (existing != null) {
      return existing;
    }
    var task = PreTranslationTask(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      cid: cid,
      sourceKey: sourceKey,
      comicType: comicType,
      title: title,
      cover: cover,
      chapters: chapters,
      createdAt: DateTime.now(),
    );
    currentTasks.insert(0, task);
    _saveActive();
    notifyListeners();
    unawaited(_run(task));
    return task;
  }

  /// Whether a running job exists for the comic (detail page badge).
  PreTranslationTask? runningTaskFor(String cid, String sourceKey) {
    return currentTasks
        .where((t) => t.comicKey == '$cid@$sourceKey' && t.isRunning)
        .firstOrNull;
  }

  /// Best-known progress of a chapter for a comic, looking first at a running
  /// job and then at the most recent finished job. Lets the chapter picker show
  /// a "translated" / progress marker even after the app restarts or the task
  /// moved to history, so already-done chapters are obvious and not re-queued
  /// blindly.
  PreTranslationChapter? chapterProgressFor(
    String cid,
    String sourceKey,
    String eid,
  ) {
    var comicKey = '$cid@$sourceKey';
    // A running/paused job owns the chapter: return it even before its page
    // count is known (total == 0) so the picker can show a "waiting" state for
    // queued-but-not-started chapters, not just active ones.
    for (var task in currentTasks) {
      if (task.comicKey != comicKey) continue;
      var chapter = task.chapters.where((c) => c.eid == eid).firstOrNull;
      // A per-chapter cancel leaves the chapter in the running job but no longer
      // being worked; fall through so the history/stored-text lookup can still
      // surface a "translated" marker if some pages were done before the cancel.
      if (chapter != null && !chapter.canceled) return chapter;
    }
    // Otherwise only report a finished chapter (all pages accounted for) so a
    // canceled/failed run does not masquerade as in-progress after restart.
    for (var task in historyTasks) {
      if (task.comicKey != comicKey) continue;
      var chapter = task.chapters.where((c) => c.eid == eid).firstOrNull;
      if (chapter != null &&
          chapter.total > 0 &&
          chapter.done + chapter.failed >= chapter.total) {
        return chapter;
      }
    }
    return null;
  }

  /// Live page counts for [chapter] of a comic: the committed counters plus a
  /// running job's finished-but-buffered groups.
  ({int done, int processed}) livePagesOf(
    String cid,
    String sourceKey,
    PreTranslationChapter chapter,
  ) {
    var task = runningTaskFor(cid, sourceKey);
    // Identity check, not eid: a per-chapter cancel makes chapterProgressFor
    // fall through to a history record for the same eid, and that record must
    // not be credited with the running job's buffered pages.
    if (task == null || !task.chapters.contains(chapter)) {
      return livePagesFor(chapter, null);
    }
    return livePagesFor(chapter, _activities[task.id]);
  }

  /// Credits [activity]'s buffered groups to [chapter] for display, when they
  /// belong to this chapter.
  ///
  /// Buffered pages cannot advance `done + failed` (that must stay a contiguous
  /// prefix for the resume cursor), but they are rendered and cached, so
  /// leaving them out makes the number sit still while work is plainly
  /// happening — which is what a slow head group looks like from the outside.
  /// Display only: never write these back into the chapter.
  @visibleForTesting
  static ({int done, int processed}) livePagesFor(
    PreTranslationChapter chapter,
    PreTranslationActivity? activity,
  ) {
    var committed = (
      done: chapter.done,
      processed: chapter.done + chapter.failed,
    );
    if (activity == null || activity.chapterEid != chapter.eid) {
      return committed;
    }
    return (
      done: committed.done + activity.bufferedDone,
      processed: committed.processed + activity.bufferedPages,
    );
  }

  /// Whether a chapter belongs to a currently running/paused job (so the picker
  /// can distinguish "queued/among this run" from a finished-in-history one).
  bool isChapterActive(String cid, String sourceKey, String eid) {
    var comicKey = '$cid@$sourceKey';
    for (var task in currentTasks) {
      if (task.comicKey != comicKey) continue;
      if (task.chapters.any((c) => c.eid == eid && !c.canceled)) return true;
    }
    return false;
  }

  void cancel(String id) {
    _canceledIds.add(id);
    var task = currentTasks.where((t) => t.id == id).firstOrNull;
    if (task == null) {
      notifyListeners();
      return;
    }
    task.status = PreTranslationTaskStatus.canceled;
    _moveToHistory(task);
    if (!_runningIds.contains(id)) {
      _canceledIds.remove(id);
    }
    notifyListeners();
  }

  /// Cancels just one chapter of a still-running job, leaving the other
  /// chapters to keep translating. The chapter is flagged [PreTranslationChapter.canceled]
  /// so both the forward pass and the retry pass skip it; an in-flight chapter
  /// stops at the next group boundary. If every remaining chapter is now
  /// canceled (or already finished), the whole job is canceled so it doesn't
  /// linger as "running" with nothing left to do.
  void cancelChapter(String taskId, String eid) {
    var task = currentTasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null) return;
    var chapter = task.chapters.where((c) => c.eid == eid).firstOrNull;
    if (chapter == null || chapter.canceled) return;
    chapter.canceled = true;
    // If nothing is left to do, cancel the whole job. "Left to do" = a chapter
    // that isn't canceled and isn't already fully processed.
    var hasPending = task.chapters.any((c) {
      if (c.canceled) return false;
      return c.total <= 0 || (c.done + c.failed) < c.total;
    });
    if (!hasPending) {
      cancel(taskId);
      return;
    }
    _saveActive();
    notifyListeners();
  }

  /// Pauses a running pre-translation job. The worker loop checks this state
  /// between pages and waits until [resume] is called or the job is canceled.
  void pause(String id) {
    var task = currentTasks.where((t) => t.id == id).firstOrNull;
    if (task == null || !task.isRunning) return;
    task.status = PreTranslationTaskStatus.paused;
    _saveActive();
    notifyListeners();
  }

  /// Resumes a paused pre-translation job.
  void resume(String id) {
    var task = currentTasks.where((t) => t.id == id).firstOrNull;
    if (task == null || task.status != PreTranslationTaskStatus.paused) return;
    task.status = PreTranslationTaskStatus.running;
    _saveActive();
    notifyListeners();
    if (!_runningIds.contains(id)) {
      unawaited(_run(task));
    }
  }

  /// Manually re-runs the failed pages of a job. Works on a running job (the
  /// running loop's own auto-retry already covers it, so this is mainly for a
  /// finished one) or a finished/failed job in history: the job is moved back
  /// to the active list, set running, and re-driven — [_run]'s forward loop
  /// no-ops on already-processed chapters, then [_retryFailedPasses] re-runs
  /// just the failed pages. Succeeded pages are never re-requested (they skip
  /// via hasRenderedPage). Does nothing if the job has no failures.
  void retryFailed(String id) {
    var task = currentTasks.where((t) => t.id == id).firstOrNull ??
        historyTasks.where((t) => t.id == id).firstOrNull;
    if (task == null || !task.hasFailures) return;
    if (_runningIds.contains(task.id)) return;
    if (historyTasks.remove(task)) {
      currentTasks.insert(0, task);
    }
    task.status = PreTranslationTaskStatus.running;
    task.finishedAt = null;
    _canceledIds.remove(task.id);
    _saveActive();
    notifyListeners();
    unawaited(_run(task));
  }

  Future<void> _run(PreTranslationTask task) async {
    if (_runningIds.contains(task.id)) return;
    if (_canceledIds.contains(task.id) || !currentTasks.contains(task)) {
      return;
    }
    _runningIds.add(task.id);
    _activities[task.id] = PreTranslationActivity();
    try {
      for (var chapter in task.chapters) {
        if (_canceledIds.contains(task.id)) break;
        if (chapter.canceled) continue;
        await _waitWhilePaused(task);
        if (_canceledIds.contains(task.id)) break;
        await _runChapter(task, chapter);
      }
      // Auto-retry the failed pages once: a transient error (network blip, rate
      // limit) on the first pass is common, and one automatic sweep clears most
      // of them without the user noticing. Only the pages that actually failed
      // are re-run; succeeded pages are untouched.
      if (!_canceledIds.contains(task.id) &&
          task.status == PreTranslationTaskStatus.running) {
        await _retryFailedPasses(task);
      }
      if (task.status == PreTranslationTaskStatus.running) {
        task.status = task.failed > 0 && task.done == 0
            ? PreTranslationTaskStatus.failed
            : PreTranslationTaskStatus.completed;
      }
    } catch (e, s) {
      Log.error('Pre-translation', '$e\n$s');
      task.status = PreTranslationTaskStatus.failed;
    } finally {
      _canceledIds.remove(task.id);
      _runningIds.remove(task.id);
      // The coalescing timer is shared by every running job, so it is not this
      // job's to cancel; the notifyListeners below already flushes this one.
      _activities.remove(task.id);
      _moveToHistory(task);
      onTaskFinished?.call(task);
      notifyListeners();
    }
  }

  /// Suspends the loop while [task] is paused, returning as soon as it resumes
  /// or gets canceled. This keeps the running isolate alive without doing work.
  Future<void> _waitWhilePaused(PreTranslationTask task) async {
    while (task.status == PreTranslationTaskStatus.paused) {
      if (_canceledIds.contains(task.id)) return;
      // Poll every second. Resume() flips the status and the next iteration
      // exits immediately.
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<void> _runChapter(
    PreTranslationTask task,
    PreTranslationChapter chapter,
  ) async {
    var activity = _activities[task.id];
    activity
      ?..chapterIndex = task.chapters.indexOf(chapter) + 1
      ..chapterTitle = chapter.title
      ..chapterEid = chapter.eid
      ..bufferedDone = 0
      ..bufferedFailed = 0
      ..groups.clear();
    List<String> pageKeys;
    try {
      pageKeys = await _resolvePageKeys(task, chapter);
    } catch (e, s) {
      Log.error('Pre-translation', 'Failed to list pages: $e\n$s');
      chapter.failed = chapter.total == 0 ? 1 : chapter.total - chapter.done;
      _saveActiveThrottled();
      notifyListeners();
      return;
    }
    chapter.total = pageKeys.length;
    notifyListeners();

    // Resume across restart: pages already cached are skipped without any
    // network fetch or inference.
    var startIndex = chapter.done + chapter.failed;
    var groupSize = _batchPages;

    // Build the contiguous list of group [start,end) ranges to process.
    var ranges = <({int start, int end})>[];
    for (var i = startIndex; i < pageKeys.length; i += groupSize) {
      ranges.add((start: i, end: (i + groupSize).clamp(0, pageKeys.length)));
    }
    if (ranges.isEmpty) return;

    // Overlap groups so a group's image fetch + OCR can proceed while a prior
    // group waits on the LLM. Groups may finish out of order, but their counts
    // are applied via the committer in strict group order, preserving the
    // resume invariant that done+failed is always a contiguous prefix. The
    // committer starts at group 0 = the first range processed here (counts for
    // pages before startIndex are already in chapter.done/failed).
    var committer = OrderedGroupCommitter(0);
    var overlap = pipelineConcurrencyFor(
      TranslationPerformanceConfig.effective,
      isMobile: App.isMobile,
      sourceLang: task.config.sourceLang,
      hasJapaneseModel: TranslationModels.workerPaths().jaEncoder != null,
    );
    var next = 0;
    // Self-removing set: each launched future removes itself on completion, so
    // after `await Future.any(active)` the finished group is already gone and
    // the window slides forward by one. Earlier-registered listeners fire
    // first, so removal happens before Future.any's await returns.
    var active = <Future<void>>{};

    void commit(int groupIndex, GroupResult result) {
      applyGroupResult(committer, chapter, activity, groupIndex, result);
      _saveActiveThrottled();
      notifyListeners();
    }

    void launch(int groupIndex) {
      late Future<void> f;
      var range = ranges[groupIndex];
      // Registered before the work starts so the card shows the group the
      // moment it is queued, and dropped in whenComplete whether it committed,
      // was abandoned or threw — a leftover entry would keep counting pages
      // that no longer exist toward the live progress. A committed group has
      // already been removed (and re-credited as buffered) inside commit; the
      // removal here is idempotent and covers the abandoned/threw paths, where
      // dropping the credit is the correct outcome.
      var groupActivity = PreTranslationGroupActivity(
        index: groupIndex,
        pageCount: range.end - range.start,
      );
      activity?.groups[groupIndex] = groupActivity;
      _notifyActivity();
      f = () async {
        try {
          var result = await _processGroup(
            task,
            chapter,
            pageKeys,
            range.start,
            range.end,
            groupActivity,
          );
          // A canceled/paused-out group returns null; skip committing it so
          // counts stay at the group boundary and a resume redoes it.
          if (result != null) commit(groupIndex, result);
        } catch (e, s) {
          // Never let a group future complete with an error: with groups
          // overlapping, an errored future would make `Future.any` rethrow and
          // abandon the other in-flight groups (and a second error would become
          // an unhandled async error). An uncommitted group simply stays at the
          // prefix boundary and is redone on resume.
          Log.error('Pre-translation', 'Group task failed: $e\n$s');
        }
      }()
          .whenComplete(() {
        active.remove(f);
        activity?.groups.remove(groupIndex);
      });
      active.add(f);
    }

    while (next < ranges.length) {
      if (_canceledIds.contains(task.id) || chapter.canceled) break;
      await _waitWhilePaused(task);
      if (_canceledIds.contains(task.id) || chapter.canceled) break;
      launch(next++);
      if (active.length >= overlap) {
        await Future.any(active);
      }
    }
    await Future.wait(active);
  }

  /// Applies one finished group's counts, keeping the display channel in step.
  ///
  /// The group leaves [activity]'s in-flight map and its pages become buffered
  /// credit; when [committer] releases a contiguous run, those pages move out of
  /// the buffer and into the chapter counters. Every group's pages therefore
  /// enter the buffer exactly once and leave exactly once, so the live figures
  /// never double-count a group and never dip while one waits behind a slower
  /// predecessor. A group that is abandoned instead of committed never gets
  /// here, so its in-flight credit is simply dropped — which is correct, since
  /// a resume will redo it.
  @visibleForTesting
  static void applyGroupResult(
    OrderedGroupCommitter committer,
    PreTranslationChapter chapter,
    PreTranslationActivity? activity,
    int groupIndex,
    GroupResult result,
  ) {
    activity?.groups.remove(groupIndex);
    if (activity != null) {
      activity.bufferedDone += result.done;
      activity.bufferedFailed += result.failed;
    }
    for (var r in committer.record(groupIndex, result)) {
      chapter.done += r.done;
      chapter.failed += r.failed;
      chapter.failedPages.addAll(r.failedPages);
      if (activity != null) {
        activity.bufferedDone -= r.done;
        activity.bufferedFailed -= r.failed;
      }
    }
  }

  /// How many pre-translation groups may be in flight at once. Bounded by the
  /// LLM concurrency setting (the pipeline's scarcest shared resource); the
  /// per-source image gate and OCR worker pool further shape actual parallelism.
  @visibleForTesting
  static int pipelineConcurrencyFor(
    TranslationPerformanceValues performance, {
    required bool isMobile,
    required String sourceLang,
    required bool hasJapaneseModel,
  }) {
    if (isMobile &&
        (sourceLang == 'ja' || (sourceLang == 'auto' && hasJapaneseModel))) {
      return 1;
    }
    return performance.llmConcurrency.clamp(1, 4);
  }

  /// Re-runs only the pages that failed, across every chapter that has any.
  /// A success moves a page from failed→done (the chapter's failed count drops
  /// and its index leaves [PreTranslationChapter.failedPages]); a page that
  /// fails again stays recorded. Because this only shifts counts between failed
  /// and done — never changing done+failed — the forward resume cursor
  /// (startIndex = done + failed) stays valid.
  ///
  /// Called once automatically at the end of [_run], and again on each manual
  /// [retryFailed]. Chapters recorded before this feature existed have failures
  /// but no indices; those are re-scanned wholesale by zeroing their counters
  /// so the forward path redoes them (rendered pages skip cheaply).
  Future<void> _retryFailedPasses(PreTranslationTask task) async {
    var groupSize = _batchPages;
    for (var chapter in task.chapters) {
      if (_canceledIds.contains(task.id)) return;
      if (chapter.canceled) continue;
      if (chapter.failed <= 0) continue;

      // The retry sweep also walks one chapter at a time: point the activity at
      // it so the card names the right chapter, and clear any buffered credit
      // the forward pass left behind (an abandoned group can strand a later
      // group in the committer) so it cannot be attributed to this one.
      _activities[task.id]
        ?..chapterIndex = task.chapters.indexOf(chapter) + 1
        ..chapterTitle = chapter.title
        ..chapterEid = chapter.eid
        ..bufferedDone = 0
        ..bufferedFailed = 0;

      // Legacy task with failures but no recorded indices: reset the chapter so
      // the forward loop re-scans it. Cheap — already-rendered pages skip.
      if (chapter.failedPages.isEmpty) {
        chapter.done = 0;
        chapter.failed = 0;
        chapter.total = 0;
        await _runChapter(task, chapter);
        continue;
      }

      List<String> pageKeys;
      try {
        pageKeys = await _resolvePageKeys(task, chapter);
      } catch (e, s) {
        Log.error('Pre-translation', 'Retry failed to list pages: $e\n$s');
        continue;
      }

      // Only indices still in range and still marked failed. Sorted so grouping
      // is deterministic.
      var targets = chapter.failedPages
          .where((i) => i >= 0 && i < pageKeys.length)
          .toList()
        ..sort();
      for (var g = 0; g < targets.length; g += groupSize) {
        if (_canceledIds.contains(task.id)) return;
        await _waitWhilePaused(task);
        if (_canceledIds.contains(task.id)) return;
        var slice = targets.sublist(
          g,
          (g + groupSize).clamp(0, targets.length),
        );
        await _retryGroup(task, chapter, pageKeys, slice);
        _saveActiveThrottled();
        notifyListeners();
      }
    }
  }

  /// Re-translates the specific page [indices] of a chapter (a retry slice).
  /// Unlike [_runGroup] this operates on an explicit, possibly non-contiguous
  /// set and moves counts failed→done instead of appending to a prefix, so
  /// done+failed is preserved.
  Future<void> _retryGroup(
    PreTranslationTask task,
    PreTranslationChapter chapter,
    List<String> pageKeys,
    List<int> indices,
  ) async {
    // The retry sweep runs after the forward loop, so no other group holds a
    // slot; index 0 makes this the head one, and the card keeps naming a stage
    // instead of dropping back to a bare "running" for the whole sweep.
    var activity = _activities[task.id];
    var slot = PreTranslationGroupActivity(index: 0, pageCount: indices.length);
    activity?.groups[0] = slot;
    _notifyActivity();
    try {
      await _retrySlice(task, chapter, pageKeys, indices, slot);
    } finally {
      activity?.groups.remove(0);
      _notifyActivity();
    }
  }

  Future<void> _retrySlice(
    PreTranslationTask task,
    PreTranslationChapter chapter,
    List<String> pageKeys,
    List<int> indices,
    PreTranslationGroupActivity activity,
  ) async {
    var service = ImageTranslationService.instance;
    var settledBeforeBatch = 0;
    var pending = <({
      int index,
      String cacheKey,
      String legacyCacheKey,
      Uint8List imageBytes,
    })>[];
    void reportFetchPhase() {
      activity
        ..completedPages =
            settledBeforeBatch + pending.length * fetchedPageWeight
        ..stage = TranslationStage.fetching;
      _notifyActivity();
    }

    for (var i in indices) {
      if (_canceledIds.contains(task.id)) return;
      var imageKey = pageKeys[i];
      var cacheKey = ImageTranslationService.cacheKeyFor(
        task.sourceKey,
        task.cid,
        chapter.eid,
        i + 1,
      );
      var legacyCacheKey = ImageTranslationService.legacyCacheKeyFor(
        imageKey,
        task.sourceKey,
        task.cid,
        chapter.eid,
      );
      try {
        if (await service.hasRenderedPage(cacheKey, task.config.mode)) {
          _markRetrySuccess(chapter, i);
          settledBeforeBatch++;
          reportFetchPhase();
          continue;
        }
        var bytes = await _fetchPageBytes(task, chapter.eid, imageKey);
        pending.add((
          index: i,
          cacheKey: cacheKey,
          legacyCacheKey: legacyCacheKey,
          imageBytes: bytes,
        ));
        reportFetchPhase();
      } catch (e, s) {
        Log.warning('Pre-translation', 'Retry page failed: $e\n$s');
        // Still failed; leave it recorded.
        settledBeforeBatch++;
        reportFetchPhase();
      }
    }
    if (pending.isEmpty) return;
    try {
      var config = task.config;
      var results = await service.translatePageGroup(
        pending
            .map(
              (p) => (
                cacheKey: p.cacheKey,
                legacyCacheKey: p.legacyCacheKey,
                imageBytes: p.imageBytes,
              ),
            )
            .toList(),
        task.comicKey,
        config,
        chapter: ImageTranslationService.chapterIdentity(
          cid: task.cid,
          sourceKey: task.sourceKey,
          eid: chapter.eid,
          config: config,
          comicTitle: task.title,
          comicCover: task.cover,
          chapterTitle: chapter.title,
        ),
        shouldCancel: () => _canceledIds.contains(task.id),
        onStage: (stage, completed) {
          activity.stage = stage;
          // The service scores only the pages it was handed, on the same scale.
          activity.completedPages = settledBeforeBatch + completed;
          _notifyActivity();
        },
      );
      for (var j = 0; j < pending.length; j++) {
        if (results[j]) {
          _markRetrySuccess(chapter, pending[j].index);
        }
      }
    } on PipelineCanceled {
      return;
    } catch (e, s) {
      Log.warning('Pre-translation', 'Retry group failed: $e\n$s');
      // Whole group still failed; leave every index recorded.
    }
  }

  /// Moves one page from failed→done after a successful retry, keeping
  /// done+failed (and thus the forward resume cursor) invariant.
  void _markRetrySuccess(PreTranslationChapter chapter, int index) {
    if (!chapter.failedPages.remove(index)) return;
    chapter.done++;
    if (chapter.failed > 0) chapter.failed--;
  }

  /// How many pages' bubbles to merge into one LLM request. 1 (default) keeps
  /// the historic per-page path; larger gives the model cross-page context and
  /// cuts request count. Clamped to a sane range so a bad stored value can't
  /// break the loop or overflow the model's context.
  int get _batchPages {
    return TranslationPerformanceConfig.effective.batchPages.clamp(1, 20);
  }

  /// Translates pages [start, end) of a chapter. For a single page this is the
  /// original per-page path (one page = one request); for several it fetches
  /// each page's bytes then hands the group to [translatePageGroup] so their
  /// bubbles share one request. Pages already rendered are skipped up front.
  Future<GroupResult?> _processGroup(
    PreTranslationTask task,
    PreTranslationChapter chapter,
    List<String> pageKeys,
    int start,
    int end,
    PreTranslationGroupActivity activity,
  ) async {
    var service = ImageTranslationService.instance;
    var pending = <({
      int index,
      String cacheKey,
      String legacyCacheKey,
      Uint8List imageBytes,
    })>[];
    var done = 0;
    var failed = 0;
    // Page indices that failed this group, recorded so a later retry pass can
    // re-run exactly these. Collected locally and returned as a GroupResult so
    // the caller's committer merges them into the chapter in strict group
    // order (never mutating the chapter directly from here).
    var failedIndices = <int>{};
    // Pages this group settled before the batch call; the service reports its
    // own settled count relative to what it was handed, so the two add up.
    var preSettled = 0;
    activity.stage = TranslationStage.fetching;
    _notifyActivity();

    void reportFetchPhase() {
      activity.completedPages = preSettled + pending.length * fetchedPageWeight;
      _notifyActivity();
    }

    for (var i = start; i < end; i++) {
      // Cancel before the group is counted: return null so the caller leaves
      // the chapter counters at the group's start boundary and a resume redoes
      // the whole group. Every page is idempotent (rendered ones skip via
      // hasRenderedPage), so nothing is double-counted or skipped.
      if (_canceledIds.contains(task.id)) return null;
      var imageKey = pageKeys[i];
      var cacheKey = ImageTranslationService.cacheKeyFor(
        task.sourceKey,
        task.cid,
        chapter.eid,
        i + 1,
      );
      var legacyCacheKey = ImageTranslationService.legacyCacheKeyFor(
        imageKey,
        task.sourceKey,
        task.cid,
        chapter.eid,
      );
      try {
        if (await service.hasRenderedPage(cacheKey, task.config.mode)) {
          done++;
          preSettled++;
          reportFetchPhase();
          continue;
        }
        var bytes = await _fetchPageBytes(task, chapter.eid, imageKey);
        pending.add((
          index: i,
          cacheKey: cacheKey,
          legacyCacheKey: legacyCacheKey,
          imageBytes: bytes,
        ));
        reportFetchPhase();
      } catch (e, s) {
        Log.warning('Pre-translation', 'Page failed: $e\n$s');
        failed++;
        failedIndices.add(i);
        preSettled++;
        reportFetchPhase();
      }
    }
    if (pending.isNotEmpty) {
      try {
        var config = task.config;
        var results = await service.translatePageGroup(
          pending
              .map(
                (p) => (
                  cacheKey: p.cacheKey,
                  legacyCacheKey: p.legacyCacheKey,
                  imageBytes: p.imageBytes,
                ),
              )
              .toList(),
          task.comicKey,
          config,
          chapter: ImageTranslationService.chapterIdentity(
            cid: task.cid,
            sourceKey: task.sourceKey,
            eid: chapter.eid,
            config: config,
            comicTitle: task.title,
            comicCover: task.cover,
            chapterTitle: chapter.title,
          ),
          shouldCancel: () => _canceledIds.contains(task.id),
          onStage: (stage, completed) {
            activity.stage = stage;
            // The service scores only the pages it was handed, on the same
            // page-unit scale, so the two halves simply add up.
            activity.completedPages = preSettled + completed;
            _notifyActivity();
          },
        );
        for (var j = 0; j < pending.length; j++) {
          if (results[j]) {
            done++;
          } else {
            failed++;
            failedIndices.add(pending[j].index);
          }
        }
      } on PipelineCanceled {
        // Canceled mid-request: abandon this group's counts entirely (return
        // null). Pages rendered before the cancel are cached and get counted
        // (once) when the group is redone on resume.
        return null;
      } catch (e, s) {
        Log.warning('Pre-translation', 'Group failed: $e\n$s');
        for (var p in pending) {
          failed++;
          failedIndices.add(p.index);
        }
      }
    }
    // Return the whole contiguous group's counts so the caller applies them
    // atomically and in order, keeping done+failed a contiguous processed
    // prefix — the invariant the resume cursor (startIndex = done + failed)
    // relies on.
    return GroupResult(done, failed, failedIndices);
  }

  /// Resolves the ordered image keys of a chapter, from the local library when
  /// downloaded or from the comic source otherwise.
  Future<List<String>> _resolvePageKeys(
    PreTranslationTask task,
    PreTranslationChapter chapter,
  ) async {
    var manager = DownloadManager();
    var downloadId = manager.generateId(task.sourceKey, task.cid);
    var downloaded = await manager.getComicOrNull(downloadId);
    var ep = 0;
    if (downloaded != null && chapter.eid != '0') {
      var chapterIds = downloaded is CustomDownloadedItem
          ? downloaded.chapters?.ids.toList() ?? const <String>[]
          : downloaded.eps;
      var index = chapterIds.indexOf(chapter.eid);
      if (index < 0) index = chapterIds.indexOf(chapter.title);
      if (index >= 0 && downloaded.downloadedEps.contains(index)) {
        ep = index + 1;
      } else {
        downloaded = null;
      }
    }
    if (downloaded != null) {
      var length = ep == 0
          ? await manager.getComicLength(downloadId)
          : await manager.getEpLength(downloadId, ep);
      return [
        for (var i = 0; i < length; i++)
          manager.getImage(downloadId, ep, i).uri.toString(),
      ];
    }
    var source = ComicSource.find(task.sourceKey);
    if (source?.loadComicPages == null) {
      throw 'Comic source not found';
    }
    var res = await source!.loadComicPages!(
      task.cid,
      chapter.eid == '0' ? null : chapter.eid,
    );
    if (res.error) {
      throw res.errorMessage ?? 'Failed to load pages';
    }
    return res.data;
  }

  /// Ceiling for fetching one page's bytes. Generous enough for a large page on
  /// a slow connection, but finite so a stalled transfer fails the page instead
  /// of holding an image-concurrency slot forever.
  static const _pageFetchTimeout = Duration(minutes: 2);

  /// Backstop for waiting on an image slot, not a congestion limit — queueing
  /// behind other pages is normal. Set far above any legitimate wait so it only
  /// fires when a slot was genuinely never released.
  static const _slotWaitBackstop = Duration(minutes: 30);

  Future<Uint8List> _fetchPageBytes(
    PreTranslationTask task,
    String eid,
    String imageKey,
  ) async {
    if (imageKey.startsWith('file://')) {
      return await File.fromUri(Uri.parse(imageKey)).readAsBytes();
    }
    await _ImageRateLimit.gate.acquire(
      task.sourceKey,
      maxWait: _slotWaitBackstop,
    );
    try {
      DownloadProgress? result;
      // Bounded two ways, because the fetch holds an image-concurrency slot and
      // an unbounded one would retire that slot for good (#176):
      //   - stream.timeout catches a transfer that goes completely silent,
      //   - the deadline catches one that trickles bytes forever without ending.
      var deadline = DateTime.now().add(_pageFetchTimeout);
      var stream = ImageManager().getCustomImage(
        imageKey,
        task.cid,
        eid == '0' ? task.cid : eid,
        task.sourceKey,
      );
      await for (var event in stream.timeout(
        _pageFetchTimeout,
        onTimeout: (sink) => sink.addError(
          TimeoutException('Image fetch stalled', _pageFetchTimeout),
        ),
      )) {
        if (event.finished) {
          result = event;
        }
        if (DateTime.now().isAfter(deadline)) {
          throw TimeoutException('Image fetch too slow', _pageFetchTimeout);
        }
      }
      var completed = result;
      if (completed == null) {
        throw 'Empty image data';
      }
      return completed.data ?? await completed.getFile().readAsBytes();
    } finally {
      _ImageRateLimit.gate.release(task.sourceKey);
    }
  }

  void _moveToHistory(PreTranslationTask task) {
    if (!currentTasks.remove(task)) {
      return;
    }
    task.finishedAt ??= DateTime.now();
    historyTasks.insert(0, task);
    if (historyTasks.length > 50) {
      historyTasks.removeRange(50, historyTasks.length);
    }
    _saveActive();
    _saveHistory();
  }

  // -------------------------------------------------------------------------
  // Persistence
  // -------------------------------------------------------------------------

  static const _activeKey = 'pre_translation_active_tasks';
  static const _historyKey = 'pre_translation_task_history';

  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);

  void _saveActiveThrottled() {
    var now = DateTime.now();
    if (now.difference(_lastSave) < const Duration(seconds: 1)) {
      return;
    }
    _lastSave = now;
    _saveActive();
  }

  void _saveActive() {
    appdata.translationImplicitData[_activeKey] =
        currentTasks.where((t) => t.isRunning).map((t) => t.toJson()).toList();
    appdata.writeImplicitData();
  }

  void _saveHistory() {
    appdata.translationImplicitData[_historyKey] =
        historyTasks.map((t) => t.toJson()).toList();
    appdata.writeImplicitData();
  }

  void _load() {
    var active = appdata.translationImplicitData[_activeKey];
    if (active is List) {
      currentTasks
        ..clear()
        ..addAll(
          active.whereType<Map>().map((e) {
            var task = PreTranslationTask.fromJson(
              Map<String, dynamic>.from(e),
            );
            // Anything persisted as active is coerced back to running so it can
            // be resumed after a restart.
            task.status = PreTranslationTaskStatus.running;
            task.finishedAt = null;
            return task;
          }),
        );
    }
    var history = appdata.translationImplicitData[_historyKey];
    if (history is List) {
      historyTasks
        ..clear()
        ..addAll(
          history.whereType<Map>().map(
                (e) =>
                    PreTranslationTask.fromJson(Map<String, dynamic>.from(e)),
              ),
        );
    }
  }

  /// Resumes jobs interrupted by app termination. Called once at startup.
  void resumePendingTasks() {
    for (var task in currentTasks.toList()) {
      if (task.isRunning && !_runningIds.contains(task.id)) {
        unawaited(_run(task));
      }
    }
  }

  void clearHistory() {
    historyTasks.clear();
    _saveHistory();
    notifyListeners();
  }

  /// Resets the pre-translation status the chapter picker reads from, so that
  /// after the user clears all translation results the "translated" ticks and
  /// progress markers go away too. Finished/canceled/failed jobs (history) are
  /// dropped entirely; a still-running job keeps running but its counters are
  /// zeroed so its chapters re-count from scratch against the now-empty cache.
  void clearAllChapterStatus() {
    historyTasks.clear();
    for (var task in currentTasks) {
      for (var c in task.chapters) {
        c.done = 0;
        c.failed = 0;
        c.total = 0;
        c.canceled = false;
        c.failedPages.clear();
      }
    }
    _saveActive();
    _saveHistory();
    notifyListeners();
  }

  /// Resets the recorded pre-translation status of specific chapters of a comic
  /// (used by the picker's selection-based re-translate). Zeroes their counters
  /// in both history and any running job so the picker stops showing them as
  /// "translated" and a fresh run re-counts them from scratch against the now
  /// cleared cache.
  void resetChapterStatus(String cid, String sourceKey, Set<String> eids) {
    if (eids.isEmpty) return;
    var comicKey = '$cid@$sourceKey';
    for (var task in [...historyTasks, ...currentTasks]) {
      if (task.comicKey != comicKey) continue;
      for (var c in task.chapters) {
        if (eids.contains(c.eid)) {
          c.done = 0;
          c.failed = 0;
          c.total = 0;
          c.canceled = false;
          c.failedPages.clear();
        }
      }
    }
    _saveActive();
    _saveHistory();
    notifyListeners();
  }

  /// Resets the recorded pre-translation status of every chapter of one comic
  /// (used by the detail page's whole-comic re-translate). Drops that comic's
  /// finished history entries and zeroes any running job's counters so the
  /// picker's "translated" ticks for it clear, leaving other comics untouched.
  void resetComicStatus(String cid, String sourceKey) {
    var comicKey = '$cid@$sourceKey';
    historyTasks.removeWhere((t) => t.comicKey == comicKey);
    for (var task in currentTasks) {
      if (task.comicKey != comicKey) continue;
      for (var c in task.chapters) {
        c.done = 0;
        c.failed = 0;
        c.total = 0;
        c.canceled = false;
        c.failedPages.clear();
      }
    }
    _saveActive();
    _saveHistory();
    notifyListeners();
  }

  void removeTask(String id) {
    historyTasks.removeWhere((t) => t.id == id);
    _saveHistory();
    notifyListeners();
  }
}

/// Per-source image-fetch concurrency for pre-translation. The effective limit
/// is min(user setting, AIMD estimate); AIMD halves on a 429/503 from the image
/// host and grows back on success, so a rate-limiting host is backed off
/// automatically without the user tuning anything.
class _ImageRateLimit {
  static final aimd = AimdController(min: 1, max: 6);
  static final gate = ConcurrencyGate((bucket) {
    var userMax = TranslationPerformanceConfig.effective.imageConcurrency.clamp(
      1,
      6,
    );
    return math.min(userMax, aimd.limitFor(bucket));
  });
}
