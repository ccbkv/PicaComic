import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:pica_comic/foundation/appdata.dart';
import 'package:pica_comic/foundation/cache_manager.dart';
import 'package:pica_comic/foundation/image_translation/llm_translator.dart';
import 'package:pica_comic/foundation/image_translation/translation_config.dart';
import 'package:pica_comic/foundation/image_translation/translation_models.dart';
import 'package:pica_comic/foundation/image_translation/translation_pipeline.dart';
import 'package:pica_comic/foundation/image_translation/translation_store.dart';
import 'package:pica_comic/foundation/image_translation/translation_types.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/utils/io.dart';

/// Per-page translation state exposed to the reader UI for status feedback.
enum PageTranslationStatus {
  /// Not queued, not done — nothing to show.
  idle,

  /// Queued or actively being translated.
  translating,

  /// A translated page is cached and shown.
  translated,

  /// The page has no translatable text (shown as-is).
  noContent,

  /// Translation failed; the reader offers a retry.
  failed,
}

/// Result of the shared translation core [_translateToCache].
enum _TranslateOutcome {
  /// A rendered translated page was already in the cache.
  alreadyCached,

  /// A translated page was produced and written to the cache this call.
  translated,

  /// The page has no translatable text; an empty text-result was cached.
  noContent,
}

class _TranslationTask {
  _TranslationTask(
    this.cacheKey,
    this.cid,
    this.sourceKey,
    this.imageBytes,
    this.config,
    this.chapter,
    this.legacyCacheKey,
  );

  final String cacheKey;

  /// Pre-#287 transport-derived key for the same page, when the scheduling path
  /// could still address it. Lets a queued page adopt an older stored result
  /// instead of paying for OCR and a translation request again.
  final String? legacyCacheKey;

  final String cid;
  final String? sourceKey;

  /// Identifies the comic for the per-comic language lock and glossary.
  String get comicKey => '$cid@$sourceKey';

  final Uint8List imageBytes;

  /// The comic's own language pair + render mode, captured when queued so a
  /// settings change mid-queue can't translate the page with another comic's
  /// languages.
  final TranslationConfig config;
  final TranslationChapterIdentity chapter;
  final listeners = <VoidCallback>[];
}

/// Schedules page translations, caches results and notifies the reader when
/// a page is ready so it can swap the displayed image.
///
/// Two cache levels keep repeat reads free:
/// - the rendered page image (30 days, large, may be LRU-evicted), and
/// - the text-level result (regions + translations, ~KB, 90 days): when only
///   the image was evicted the page is re-rendered locally without paying
///   for OCR or another translation request.
class ImageTranslationService with ChangeNotifier {
  ImageTranslationService._();

  static final instance = ImageTranslationService._();

  static const _imageCacheDuration = 30 * 24 * 60 * 60 * 1000;
  static const _maxQueueLength = 16;
  static const _failureRetryDelay = Duration(minutes: 5);
  static const _idleReleaseDelay = Duration(seconds: 90);

  final _queue = <_TranslationTask>[];
  final _active = <_TranslationTask>{};

  /// The done/failed markers describe a *rendered* image, so they key on the
  /// rendered key (page key + render-mode token) rather than the raw page key.
  /// Two comics reading with different text-removal modes therefore keep
  /// independent markers, and a mode change addresses different entries instead
  /// of needing the whole set cleared.
  final _failures = <String, DateTime>{};
  final _completed = <String>{};

  /// Last error message per failed page, for the reader's retry affordance.
  final _errors = <String, String>{};

  /// Pages known (via the text cache) to contain nothing translatable. Mode
  /// independent, so this one keys on the raw page key.
  final _noContent = <String>{};
  PageTranslationPipeline? _pipeline;
  Timer? _releaseTimer;

  /// Whether a translated page is known to exist for [cacheKey] under [mode].
  /// Feeds the provider identity so a finished background translation produces
  /// a new provider and the visible image swaps in place.
  bool isTranslated(String cacheKey, InpaintMode mode) {
    return _completed.contains(renderedKey(cacheKey, mode));
  }

  void markTranslated(String cacheKey, InpaintMode mode) =>
      _completed.add(renderedKey(cacheKey, mode));

  /// Current per-page translation state, for the reader status badge.
  PageTranslationStatus statusOf(String cacheKey, InpaintMode mode) {
    var renderKey = renderedKey(cacheKey, mode);
    if (_completed.contains(renderKey)) return PageTranslationStatus.translated;
    if (_noContent.contains(cacheKey)) return PageTranslationStatus.noContent;
    if (_active.any((t) => t.cacheKey == cacheKey)) {
      return PageTranslationStatus.translating;
    }
    if (_failures.containsKey(renderKey)) return PageTranslationStatus.failed;
    if (_queue.any((t) => t.cacheKey == cacheKey)) {
      return PageTranslationStatus.translating;
    }
    return PageTranslationStatus.idle;
  }

  /// Last failure message for [cacheKey], if the page failed to translate.
  String? errorOf(String cacheKey, InpaintMode mode) =>
      _errors[renderedKey(cacheKey, mode)];

  /// Clears the failure back-off for [cacheKey] so the reader can retry it
  /// immediately instead of waiting out [_failureRetryDelay].
  void clearFailure(String cacheKey, InpaintMode mode) {
    var renderKey = renderedKey(cacheKey, mode);
    _failures.remove(renderKey);
    _errors.remove(renderKey);
  }

  /// Trims an exception to a short, single-line message for display.
  static String _briefError(Object e) {
    var text = e.toString().replaceAll('\n', ' ').trim();
    const prefix = 'Exception: ';
    if (text.startsWith(prefix)) {
      text = text.substring(prefix.length);
    }
    return text.length > 160 ? '${text.substring(0, 160)}…' : text;
  }

  /// Rendered-image cache key: the page's durable text [cacheKey] plus the
  /// render-mode token. The rendered image depends on the mode, the stored text
  /// does not — so switching modes serves a different image re-derived from the
  /// same stored text, and switching back reuses the earlier render. The token
  /// is a suffix, so the comic/chapter scope prefixes still match it for
  /// deletion.
  static String renderedKey(String cacheKey, InpaintMode mode) =>
      '$cacheKey#${mode.token}';

  /// LLM translation is network-bound, so a second page's OCR can run in the
  /// worker while the first waits for its response.
  int get _maxConcurrent => 2;

  /// Whether detection/OCR models AND the user's LLM endpoint are usable for
  /// [sourceLang]. The source language is per-comic, so readiness is too: a
  /// comic set to Korean needs the Korean model even if another comic reads fine
  /// with Japanese.
  static bool isReadyForLang(String sourceLang) {
    if (!TranslationModels.isReadyFor(sourceLang)) {
      return false;
    }
    return LlmTranslator.isConfigured;
  }

  /// Whether translation can run for one comic, using that comic's own source
  /// language.
  static bool isReadyForComic(String cid, String? sourceKey) {
    return isReadyForLang(TranslationConfig.of(cid, sourceKey).sourceLang);
  }

  /// The implicitData keys holding per-comic translation preferences: the
  /// per-comic enable switch, the learned language locks, the glossary and the
  /// blocked terms. These are serialized into the backup explicitly (they live
  /// in implicitData, which is not part of appdata.json) and merged back on
  /// import — see the export/import paths in utils/data.dart.
  static const syncedPrefKeys = [
    _enabledComicsKey,
    _comicLangsKey,
    _comicGlossaryKey,
    _blockedTermsKey,
  ];

  /// Drops the lazy in-memory caches of the per-comic preference maps so the
  /// next access re-reads implicitData. Called after an import replaces those
  /// maps underneath us — without it the service would keep serving the
  /// pre-import glossary / language locks / blocked terms.
  void reloadSyncedPrefs() {
    _comicLangs = null;
    _glossaries = null;
    _blockedTerms = null;
    notifyListeners();
  }

  /// Comics the user explicitly turned translation on for. This is a dedicated
  /// per-comic store — NOT the reader-settings channel, which falls back to a
  /// single global value when a comic has no per-comic override. Translation
  /// spends tokens, so it must never be globally "on": enabling it for one
  /// comic must not translate every other comic the user opens.
  static const _enabledComicsKey = 'imageTranslationEnabledComics';

  /// Whether the user turned translation on for this specific comic.
  static bool isEnabledForComic(String cid, String sourceKey) {
    var stored = appdata.translationImplicitData[_enabledComicsKey];
    if (stored is! Map) return false;
    return stored['$cid@$sourceKey'] == true;
  }

  /// Stable keys for comics whose per-comic translation switch is on.
  /// The list is intentionally exposed without titles: titles and covers are
  /// not part of the preference store and are resolved by the UI when known.
  static Set<String> get enabledComicKeys {
    var stored = appdata.translationImplicitData[_enabledComicsKey];
    if (stored is! Map) return const {};
    return stored.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key.toString())
        .toSet();
  }

  /// Turns translation on/off for one comic only.
  static void setEnabledForComic(String cid, String sourceKey, bool enabled) {
    var stored = appdata.translationImplicitData[_enabledComicsKey];
    var map =
        stored is Map ? Map<String, dynamic>.from(stored) : <String, dynamic>{};
    var comicKey = '$cid@$sourceKey';
    if (enabled) {
      map[comicKey] = true;
    } else {
      map.remove(comicKey);
    }
    appdata.translationImplicitData[_enabledComicsKey] = map;
    appdata.writeImplicitData();
    instance.notifyListeners();
  }

  /// Whether translation should run for a comic right now (per-comic switch +
  /// usable engine for that comic's language).
  static bool enabledFor(String cid, String sourceKey) {
    return isEnabledForComic(cid, sourceKey) && isReadyForComic(cid, sourceKey);
  }

  /// Prefix covering every cached page of one comic, for that comic's own
  /// language pair. The comic/chapter identity comes BEFORE the per-image part
  /// so a whole comic — or a single chapter — can be invalidated with one prefix
  /// delete (see [CacheManager.deleteByPrefix]).
  static String comicScopePrefix(String? sourceKey, String cid) {
    var prefix = TranslationConfig.of(cid, sourceKey).cachePrefix;
    return '$prefix$sourceKey@$cid@';
  }

  /// Prefix covering every cached page of one chapter.
  static String chapterScopePrefix(String? sourceKey, String cid, String eid) {
    return '${comicScopePrefix(sourceKey, cid)}$eid@';
  }

  static TranslationChapterIdentity chapterIdentity({
    required String cid,
    required String? sourceKey,
    required String eid,
    required TranslationConfig config,
    String comicTitle = '',
    String comicCover = '',
    String chapterTitle = '',
  }) {
    return TranslationChapterIdentity(
      scopePrefix: chapterScopePrefix(sourceKey, cid, eid),
      sourceKey: sourceKey ?? localTranslationSourceKey,
      comicId: cid,
      chapterId: eid,
      sourceLang: config.sourceLang,
      targetLang: config.targetLang,
      comicTitle: comicTitle,
      comicCover: comicCover,
      chapterTitle: chapterTitle,
    );
  }

  /// Cache key of the translated variant of one page. It embeds the comic's
  /// language pair so changing that comic's languages re-translates instead of
  /// serving pages in the old language. Scope (source/comic/chapter) comes
  /// first, page identity last, so a comic or chapter forms a deletable key
  /// prefix.
  ///
  /// The last segment is the page's 1-based position in its chapter, NOT the
  /// image key. How a page's bytes are obtained changes with circumstance — a
  /// source url while reading online, an absolute `file://` path once the
  /// chapter is downloaded, a different absolute path on another device — so
  /// keying on that gave one page several identities: pages translated before a
  /// download read as untranslated after it, and stored text could never be
  /// reused across devices for a downloaded comic (#287). The ordinal is the
  /// same in every path.
  ///
  /// The page segment is terminated with `@` like every other segment, so no
  /// page's key is a prefix of another's (`p1@` vs `p10@`) — prefix-scoped
  /// counts and deletes stay exact if one is ever aimed at a single page.
  static String cacheKeyFor(
    String? sourceKey,
    String cid,
    String eid,
    int page,
  ) {
    return '${chapterScopePrefix(sourceKey, cid, eid)}p$page@';
  }

  /// The key a page was stored under before [cacheKeyFor] switched to the page
  /// ordinal. Passed alongside the current key when reading so an existing
  /// translation is still found — and moved to the stable key — as long as the
  /// caller can address it, i.e. it holds the same image key that wrote it.
  static String legacyCacheKeyFor(
    String imageKey,
    String? sourceKey,
    String cid,
    String eid,
  ) {
    return '${chapterScopePrefix(sourceKey, cid, eid)}$imageKey';
  }

  /// Stored regions for a page, adopting a legacy transport-keyed row when the
  /// stable key has none. Null means never translated, empty means "no text".
  static List<TranslatedRegion>? _storedRegions(
    String cacheKey,
    String? legacyCacheKey,
  ) {
    var regions = TranslationStore().get(cacheKey);
    if (regions != null || legacyCacheKey == null) return regions;
    return TranslationStore().adoptLegacyKey(legacyCacheKey, cacheKey);
  }

  /// Removes the rendered-image cache AND the durable stored text for every
  /// page under [scopePrefix], so the next view/pre-translate re-runs from
  /// scratch. Also clears the in-memory "done/empty/failed" markers for those
  /// keys. The store keys on the same prefix, so one call drops both levels.
  Future<int> invalidateScope(String scopePrefix) async {
    var removed = await CacheManager().deleteByPrefix(scopePrefix);
    TranslationStore().deleteByPrefix(scopePrefix);
    _completed.removeWhere((k) => k.startsWith(scopePrefix));
    _noContent.removeWhere((k) => k.startsWith(scopePrefix));
    _failures.removeWhere((k, _) => k.startsWith(scopePrefix));
    return removed;
  }

  /// Re-translates a whole comic: drops every stored page + rendered image for
  /// the current language pair AND the comic's learned glossary, so the next
  /// read / pre-translate starts clean. [eid] limits it to one chapter, in
  /// which case the glossary is kept (other chapters still rely on it).
  Future<void> retranslate(String cid, String sourceKey, {String? eid}) async {
    if (eid != null) {
      await invalidateScope(chapterScopePrefix(sourceKey, cid, eid));
    } else {
      await invalidateScope(comicScopePrefix(sourceKey, cid));
      _clearGlossary('$cid@$sourceKey');
    }
    notifyListeners();
  }

  /// Clears every translated page across all comics: the rendered-image cache
  /// and the durable stored text both go. The learned per-comic language locks
  /// and glossaries are left intact. Returns the rendered-image count removed.
  Future<int> clearAllTranslationCache() async {
    var removed = await CacheManager().deleteByPrefix('pageTranslation@');
    TranslationStore().clearAll();
    _completed.clear();
    _noContent.clear();
    _failures.clear();
    notifyListeners();
    return removed;
  }

  Future<File?> findTranslated(String cacheKey, InpaintMode mode) async {
    var path = await CacheManager().findCache(renderedKey(cacheKey, mode));
    return path == null ? null : File(path);
  }

  /// Whether a fully rendered translated page (not just the text result) is
  /// already cached. Used by the pre-translation task manager to skip pages
  /// that were done in an earlier run or read online.
  Future<bool> hasRenderedPage(String cacheKey, InpaintMode mode) async {
    return await CacheManager().findCache(renderedKey(cacheKey, mode)) != null;
  }

  /// How many pages of one chapter already have a stored text result — the
  /// durable, WebDAV-synced source of truth (empty-result "no text" pages count
  /// too). This is what lets a device show a chapter as already translated after
  /// receiving another device's translations, without needing that device's
  /// (non-synced) task records. Language-pair scoped, same as every cache key.
  static int storedPageCount(
    String cid,
    String sourceKey,
    String eid, {
    String comicTitle = '',
    String comicCover = '',
    String chapterTitle = '',
  }) {
    var config = TranslationConfig.of(cid, sourceKey);
    return TranslationStore().recordExistingChapter(
      chapterIdentity(
        cid: cid,
        sourceKey: sourceKey,
        eid: eid,
        config: config,
        comicTitle: comicTitle,
        comicCover: comicCover,
        chapterTitle: chapterTitle,
      ),
    );
  }

  /// Indexed translated comics whose language pair still matches the comic's
  /// current reader settings. Older language generations remain stored, but
  /// are not presented as directly usable results for the current config.
  static List<StoredTranslationComic> get translatedComics {
    return TranslationStore().comics.where((comic) {
      var config = TranslationConfig.of(comic.comicId, comic.sourceKey);
      return comic.sourceLang == config.sourceLang &&
          comic.targetLang == config.targetLang;
    }).toList();
  }

  /// Renders a page purely from an already-stored text result — no OCR, no LLM,
  /// no models. This is what lets a device that received another device's
  /// translations over WebDAV show them even without any translation models
  /// installed: the durable [TranslationStore] rows synced across, and the
  /// renderer only needs the page bytes + regions + the app font.
  ///
  /// Returns the rendered PNG bytes when a stored result produced a visible
  /// page (and caches it), or null when there is no stored result for this page
  /// or the stored result is empty (the page has no translatable text) — in
  /// both null cases the caller should show the original image. Never triggers
  /// a translation; a page missing from the store stays untranslated here.
  Future<Uint8List?> renderStoredPage(
    String cacheKey,
    Uint8List imageBytes,
    InpaintMode mode, {
    required TranslationChapterIdentity chapter,
    String? legacyCacheKey,
  }) async {
    TranslationStore().recordExistingChapter(chapter);
    var renderKey = renderedKey(cacheKey, mode);
    var cachedPath = await CacheManager().findCache(renderKey);
    if (cachedPath != null) {
      _completed.add(renderKey);
      return await File(cachedPath).readAsBytes();
    }
    var regions = _storedRegions(cacheKey, legacyCacheKey);
    if (regions == null) {
      // Never translated on any device that synced here; show the original.
      return null;
    }
    if (regions.isEmpty) {
      // Stored "no translatable text" result; nothing to render.
      _noContent.add(cacheKey);
      return null;
    }
    var pipeline = _pipeline ??= PageTranslationPipeline();
    var rendered = await pipeline.renderPage(imageBytes, regions, mode: mode);
    await CacheManager().writeCache(renderKey, rendered, _imageCacheDuration);
    _completed.add(renderKey);
    return rendered;
  }

  /// Translates one page synchronously (awaitable), writing both cache levels,
  /// and returns whether a translated page was produced. Unlike [schedule]
  /// this does not go through the reader's bounded/LRU queue — the
  /// pre-translation task manager drives its own pacing and needs to await
  /// each page. Reuses the shared pipeline and language lock.
  ///
  /// Returns true when a translated page image is now cached (or already was),
  /// false when the page has no translatable text.
  Future<bool> translateOne(
    String cacheKey,
    String comicKey,
    Uint8List imageBytes,
    TranslationConfig config, {
    required TranslationChapterIdentity chapter,
    String? legacyCacheKey,
    bool Function()? shouldCancel,
  }) async {
    var outcome = await _translateToCache(
      cacheKey,
      comicKey,
      imageBytes,
      config,
      chapter: chapter,
      legacyCacheKey: legacyCacheKey,
      shouldCancel: shouldCancel,
    );
    if (outcome == _TranslateOutcome.noContent) {
      return false;
    }
    _completed.add(renderedKey(cacheKey, config.mode));
    return true;
  }

  /// The shared translation core used by both the awaitable [translateOne]
  /// (pre-translation manager) and the queued [_process] (reader). It performs
  /// the cache probe, OCR/translation analysis (with the text-level cache),
  /// language lock + glossary updates and the final render, writing both cache
  /// levels. Callers layer their own bookkeeping (queue management, listener
  /// notification, failure tracking) on top of the returned outcome.
  Future<_TranslateOutcome> _translateToCache(
    String cacheKey,
    String comicKey,
    Uint8List imageBytes,
    TranslationConfig config, {
    required TranslationChapterIdentity chapter,
    String? legacyCacheKey,
    bool Function()? shouldCancel,
  }) async {
    TranslationStore().recordExistingChapter(chapter);
    var renderKey = renderedKey(cacheKey, config.mode);
    if (await CacheManager().findCache(renderKey) != null) {
      return _TranslateOutcome.alreadyCached;
    }
    var pipeline = _pipeline ??= PageTranslationPipeline();
    // The store is the durable source of truth: a hit (local, or merged from
    // another device via WebDAV) skips OCR and the paid LLM request entirely.
    var regions = _storedRegions(cacheKey, legacyCacheKey);
    if (regions == null) {
      var analysis = await pipeline.analyzePage(
        imageBytes,
        sourceLang: _effectiveSourceFor(comicKey, config),
        targetLang: config.targetLang,
        glossary: _glossaryFor(comicKey),
      );
      _updateLanguageLock(comicKey, analysis.languageVotes, config);
      _mergeGlossary(comicKey, analysis.newGlossary);
      regions = analysis.regions;
      TranslationStore().put(cacheKey, regions, chapter: chapter);
    }
    if (shouldCancel?.call() ?? false) {
      throw const PipelineCanceled();
    }
    if (regions.isEmpty) {
      // Nothing translatable; the cached empty result keeps this page from
      // being re-analyzed, even across restarts.
      _noContent.add(cacheKey);
      return _TranslateOutcome.noContent;
    }
    var rendered = await pipeline.renderPage(
      imageBytes,
      regions,
      mode: config.mode,
    );
    await CacheManager().writeCache(renderKey, rendered, _imageCacheDuration);
    return _TranslateOutcome.translated;
  }

  /// Translates a group of pages with ONE shared LLM request — used only by
  /// the background pre-translation manager (the reader keeps its per-page
  /// queue in [schedule]/[_process]). Pages already rendered, served from the
  /// text cache, or found to hold no translatable text need no request; the
  /// rest have their recognized bubbles concatenated into a single
  /// [LlmTranslator.translateBatch] call, so the model sees cross-page context
  /// and the comic spends one request per group instead of one per page.
  ///
  /// OCR, rendering and both cache levels stay per-page (only the translation
  /// request is grouped), so a partially finished group resumes cleanly. If the
  /// shared request fails, every page that needed it is reported failed for
  /// this run (to retry later) while pages resolved from cache still succeed.
  ///
  /// Returns a success flag per input page, aligned with [pages]; it only
  /// throws [PipelineCanceled] when [shouldCancel] fires between pages.
  Future<List<bool>> translatePageGroup(
    List<({String cacheKey, String? legacyCacheKey, Uint8List imageBytes})>
        pages,
    String comicKey,
    TranslationConfig config, {
    required TranslationChapterIdentity chapter,
    bool Function()? shouldCancel,
    void Function(TranslationStage stage, double completedPages)? onStage,
  }) async {
    var success = List.filled(pages.length, false);
    if (pages.isEmpty) return success;
    TranslationStore().recordExistingChapter(chapter);
    var pipeline = _pipeline ??= PageTranslationPipeline();
    var sourceLang = _effectiveSourceFor(comicKey, config);

    // Final regions per page once known; null = a fresh-OCR page still awaiting
    // the LLM (composed in stage 2) or a page that failed and is skipped.
    var regionsOf = List<List<TranslatedRegion>?>.filled(pages.length, null);
    // Freshly OCR'd pages awaiting translation; null = resolved from cache,
    // already rendered, or failed during OCR.
    var pendingOcr = List<PageOcr?>.filled(pages.length, null);
    // Text cache is (re)written only for freshly OCR'd pages, matching
    // [_translateToCache]; cache-sourced regions are never rewritten.
    var freshOcr = List<bool>.filled(pages.length, false);
    // Pages needing no further work (rendered-cache hit or OCR failure).
    var settled = List<bool>.filled(pages.length, false);

    // How much of this group is done, in page units, weighted by the phase each
    // page has reached. Derived from the state above rather than counted up
    // separately so it cannot drift out of step with it. The caller's progress
    // bar needs this because a group's real counters commit all at once — with
    // 4-8 pages a group that is minutes from committing would otherwise read as
    // no progress at all.
    double completedPages() {
      var total = 0.0;
      for (var i = 0; i < pages.length; i++) {
        if (settled[i] || success[i]) {
          total += 1;
        } else if (regionsOf[i] != null) {
          total += 0.8; // translated, waiting to be drawn
        } else if (pendingOcr[i] != null) {
          total += 0.55; // recognized, waiting on the request
        } else {
          total += fetchedPageWeight; // downloaded, not recognized yet
        }
      }
      return total;
    }

    // Stage 1 — resolve each page as far as possible without the LLM.
    for (var i = 0; i < pages.length; i++) {
      if (shouldCancel?.call() ?? false) throw const PipelineCanceled();
      var p = pages[i];
      try {
        var renderKey = renderedKey(p.cacheKey, config.mode);
        if (await CacheManager().findCache(renderKey) != null) {
          _completed.add(renderKey);
          success[i] = true;
          settled[i] = true;
          continue;
        }
        var stored = _storedRegions(p.cacheKey, p.legacyCacheKey);
        if (stored != null) {
          regionsOf[i] = stored;
          continue;
        }
        onStage?.call(
          pipeline.ocrIsWarm
              ? TranslationStage.recognizing
              : TranslationStage.loadingModel,
          completedPages(),
        );
        pendingOcr[i] = await pipeline.ocrPage(
          p.imageBytes,
          sourceLang: sourceLang,
          targetLang: config.targetLang,
        );
        freshOcr[i] = true;
      } catch (e, s) {
        Log.warning('Image Translation', 'Batch OCR failed: $e\n$s');
        settled[i] = true; // failed; success[i] stays false
      }
    }

    // Stage 2 — one request for the whole group's pending bubbles. Language
    // votes and glossary updates fold across the group, then results are
    // sliced back to each page.
    var votes = <String, int>{};
    for (var po in pendingOcr) {
      po?.languageVotes.forEach((k, v) => votes[k] = (votes[k] ?? 0) + v);
    }
    _updateLanguageLock(comicKey, votes, config);

    var texts = <String>[];
    var sliceAt = List<int>.filled(pages.length, 0);
    for (var i = 0; i < pages.length; i++) {
      var po = pendingOcr[i];
      if (po == null) continue;
      sliceAt[i] = texts.length;
      texts.addAll(po.pending.map((b) => b.text));
    }

    var batchOk = true;
    var translated = const <String>[];
    if (texts.isNotEmpty) {
      if (shouldCancel?.call() ?? false) throw const PipelineCanceled();
      onStage?.call(TranslationStage.translating, completedPages());
      try {
        var result = await LlmTranslator.translateBatch(
          texts,
          config.targetLang,
          glossary: _glossaryFor(comicKey),
          sourceLang: _effectiveSourceFor(comicKey, config),
        );
        _mergeGlossary(comicKey, result.glossary);
        translated = result.texts;
      } catch (e, s) {
        Log.warning('Image Translation', 'Batch translate failed: $e\n$s');
        batchOk = false;
      }
    }

    for (var i = 0; i < pages.length; i++) {
      var po = pendingOcr[i];
      if (po == null) continue;
      if (!batchOk && po.pending.isNotEmpty) {
        settled[i] = true; // request failed; retry this page on a later run
        continue;
      }
      var slice = po.pending.isEmpty || !batchOk
          ? const <String>[]
          : translated.sublist(
              sliceAt[i].clamp(0, translated.length),
              (sliceAt[i] + po.pending.length).clamp(0, translated.length),
            );
      regionsOf[i] = [
        ...po.ready,
        ...pipeline.regionsFromTranslation(po.pending, slice),
      ];
    }

    // Stage 3 — render + cache each resolved page.
    for (var i = 0; i < pages.length; i++) {
      if (settled[i]) continue;
      var regions = regionsOf[i];
      if (regions == null) continue;
      if (shouldCancel?.call() ?? false) throw const PipelineCanceled();
      var p = pages[i];
      onStage?.call(TranslationStage.rendering, completedPages());
      try {
        if (freshOcr[i]) {
          TranslationStore().put(p.cacheKey, regions, chapter: chapter);
        }
        if (regions.isEmpty) {
          _noContent.add(p.cacheKey);
          success[i] = true; // no translatable text still counts as handled
          continue;
        }
        var rendered = await pipeline.renderPage(
          p.imageBytes,
          regions,
          mode: config.mode,
        );
        var renderKey = renderedKey(p.cacheKey, config.mode);
        await CacheManager().writeCache(
          renderKey,
          rendered,
          _imageCacheDuration,
        );
        _completed.add(renderKey);
        success[i] = true;
      } catch (e, s) {
        Log.warning('Image Translation', 'Batch render failed: $e\n$s');
        // success[i] stays false; mark it resolved so the group's reported
        // completion does not stall at this page's partial weight.
        settled[i] = true;
      }
    }
    onStage?.call(TranslationStage.rendering, completedPages());
    return success;
  }

  /// Releases pipeline/model memory when no reader is scheduling and the
  /// pre-translation manager has finished a batch. Safe to call any time.
  void releaseIfIdle() {
    if (_active.isEmpty && _queue.isEmpty) {
      _scheduleRelease();
    }
  }

  /// Queues a page for translation. [onTranslated] fires (once per caller)
  /// after the translated page is cached, right before listeners are
  /// notified — providers use it to evict their stale image cache entry.
  void schedule(
    String cacheKey,
    String cid,
    String? sourceKey,
    Uint8List imageBytes,
    TranslationConfig config,
    VoidCallback onTranslated, {
    required TranslationChapterIdentity chapter,
    String? legacyCacheKey,
  }) {
    if (_noContent.contains(cacheKey)) {
      return;
    }
    var renderKey = renderedKey(cacheKey, config.mode);
    var failedAt = _failures[renderKey];
    if (failedAt != null) {
      if (DateTime.now().difference(failedAt) < _failureRetryDelay) {
        return;
      }
      _failures.remove(renderKey);
    }
    var existing = _queue.where((t) => t.cacheKey == cacheKey).firstOrNull;
    if (existing != null) {
      existing.listeners.add(onTranslated);
      return;
    }
    if (_queue.length >= _maxQueueLength) {
      // Prefer recent requests: the reader schedules pages in reading order,
      // so the oldest not-yet-started page is the one furthest behind.
      var oldest = _queue.where((t) => !_active.contains(t)).firstOrNull;
      if (oldest == null) {
        return;
      }
      _queue.remove(oldest);
    }
    _queue.add(
      _TranslationTask(
        cacheKey,
        cid,
        sourceKey,
        imageBytes,
        config,
        chapter,
        legacyCacheKey,
      )..listeners.add(onTranslated),
    );
    _releaseTimer?.cancel();
    _pump();
  }

  void _pump() {
    while (_active.length < _maxConcurrent) {
      var next = _queue.where((t) => !_active.contains(t)).firstOrNull;
      if (next == null) break;
      _active.add(next);
      unawaited(_process(next));
    }
  }

  Future<void> _process(_TranslationTask task) async {
    var renderKey = renderedKey(task.cacheKey, task.config.mode);
    try {
      // The comic's translation settings may have changed while this page sat
      // in the queue; its key then belongs to a superseded language pair, so
      // drop it rather than paying for a translation nothing will read.
      var current = TranslationConfig.of(task.cid, task.sourceKey);
      if (!task.cacheKey.startsWith(current.cachePrefix) ||
          current.mode != task.config.mode) {
        return;
      }
      var outcome = await _translateToCache(
        task.cacheKey,
        task.comicKey,
        task.imageBytes,
        task.config,
        chapter: task.chapter,
        legacyCacheKey: task.legacyCacheKey,
      );
      _errors.remove(renderKey);
      if (outcome != _TranslateOutcome.noContent) {
        _notifyDone(task);
      }
    } on PipelineCanceled {
      // ignore
    } catch (e, s) {
      _failures[renderKey] = DateTime.now();
      _errors[renderKey] = _briefError(e);
      Log.error('Image Translation', 'Failed to translate page: $e\n$s');
      // Let the reader surface a failure badge instead of silently showing the
      // untranslated page forever.
      notifyListeners();
    } finally {
      _queue.remove(task);
      _active.remove(task);
      if (_queue.isEmpty && _active.isEmpty) {
        _scheduleRelease();
      } else {
        _pump();
      }
    }
  }

  // ---------------------------------------------------------------------
  // Per-comic language lock
  // ---------------------------------------------------------------------

  /// A comic is almost always written in a single language. Once enough
  /// blocks agree, the detected language is remembered for the comic so
  /// later pages skip the multi-engine fallback chain entirely.
  static const _comicLangsKey = 'imageTranslationComicLangs';
  Map<String, String>? _comicLangs;

  Map<String, String> get _langLocks {
    if (_comicLangs == null) {
      var stored = appdata.translationImplicitData[_comicLangsKey];
      _comicLangs = stored is Map
          ? stored.map((k, v) => MapEntry(k.toString(), v.toString()))
          : <String, String>{};
    }
    return _comicLangs!;
  }

  String _effectiveSourceFor(String comicKey, TranslationConfig config) {
    if (config.sourceLang != 'auto') {
      return config.sourceLang;
    }
    return _langLocks[comicKey] ?? 'auto';
  }

  void _updateLanguageLock(
    String comicKey,
    Map<String, int> votes,
    TranslationConfig config,
  ) {
    if (config.sourceLang != 'auto' || _langLocks.containsKey(comicKey)) {
      return;
    }
    var total = votes.values.fold(0, (a, b) => a + b);
    if (total < 4) return;
    var dominant = votes.entries.reduce((a, b) => a.value >= b.value ? a : b);
    if (dominant.value / total < 0.75) return;
    var locks = _langLocks;
    locks[comicKey] = dominant.key;
    // Bound the persisted map; entries are tiny but unbounded growth in
    // implicitData is never OK.
    while (locks.length > 300) {
      locks.remove(locks.keys.first);
    }
    appdata.translationImplicitData[_comicLangsKey] = locks;
    appdata.writeImplicitData();
    Log.info(
      'Image Translation',
      'Locked language "${dominant.key}" for $comicKey',
    );
  }

  // ---------------------------------------------------------------------
  // Per-comic glossary
  // ---------------------------------------------------------------------

  /// Agreed name/proper-noun translations per comic ('cid@sourceKey' ->
  /// {source term -> translation}). Sent to the LLM on every page so a
  /// character's name renders identically across pages and chapters, and
  /// grown with the terms the model reports back. Persisted so a later
  /// reading session — or the pre-translation of a different chapter —
  /// inherits the same names.
  static const _comicGlossaryKey = 'imageTranslationComicGlossary';

  /// Cap per comic. The glossary is sent verbatim with every page request, so
  /// an oversized one both wastes tokens and risks overflowing the model's
  /// context. It only holds short proper nouns, so a modest cap is plenty;
  /// once full, the oldest entries are dropped.
  static const _maxGlossaryEntries = 80;
  Map<String, Map<String, String>>? _glossaries;

  Map<String, Map<String, String>> get _allGlossaries {
    if (_glossaries == null) {
      var stored = appdata.translationImplicitData[_comicGlossaryKey];
      _glossaries = <String, Map<String, String>>{};
      var cleaned = false;
      if (stored is Map) {
        stored.forEach((k, v) {
          if (v is! Map) return;
          var glossary = <String, String>{};
          v.forEach((ik, iv) {
            var source = ik.toString();
            var translation = iv.toString();
            // Drop entries an earlier version stored before the term filter
            // existed (whole sentences, URLs, numbers) so they stop being fed
            // back to the model and inflating the prompt.
            if (LlmTranslator.isValidGlossaryTerm(source, translation)) {
              glossary[source] = translation;
            } else {
              cleaned = true;
            }
          });
          if (glossary.length > _maxGlossaryEntries) {
            var keys = glossary.keys.toList();
            for (var key in keys.take(glossary.length - _maxGlossaryEntries)) {
              glossary.remove(key);
            }
            cleaned = true;
          }
          _glossaries![k.toString()] = glossary;
        });
      }
      // Persist the cleaned form once so the cost is paid a single time.
      if (cleaned) {
        appdata.translationImplicitData[_comicGlossaryKey] = _glossaries;
        appdata.writeImplicitData();
      }
    }
    return _glossaries!;
  }

  Map<String, String> _glossaryFor(String comicKey) {
    return _allGlossaries[comicKey] ?? const {};
  }

  /// The learned glossary of a comic ('cid@sourceKey'), as an unmodifiable copy
  /// for the per-comic glossary editor.
  Map<String, String> glossaryOf(String cid, String sourceKey) {
    return Map.unmodifiable(_glossaryFor('$cid@$sourceKey'));
  }

  /// Adds or updates one glossary entry for a comic, correcting or seeding a
  /// name translation by hand. Takes effect on the next page/chapter without a
  /// re-translate. Returns false if the term is rejected (too long / URL /
  /// sentence) or the cap is reached for a new key.
  bool setGlossaryEntry(
    String cid,
    String sourceKey,
    String source,
    String translation,
  ) {
    source = source.trim();
    translation = translation.trim();
    if (!LlmTranslator.isValidGlossaryTerm(source, translation)) {
      return false;
    }
    var comicKey = '$cid@$sourceKey';
    var all = _allGlossaries;
    var glossary = all.putIfAbsent(comicKey, () => <String, String>{});
    if (!glossary.containsKey(source) &&
        glossary.length >= _maxGlossaryEntries) {
      return false;
    }
    glossary[source] = translation;
    // Adding a term by hand means the user wants it, so lift any prior block.
    _allBlockedTerms[comicKey]?.remove(source);
    _persistBlockedTerms();
    appdata.translationImplicitData[_comicGlossaryKey] = all;
    appdata.writeImplicitData();
    notifyListeners();
    return true;
  }

  /// Removes one glossary entry for a comic. When [block] is true the source
  /// term is also added to the comic's block list so it will not be re-learned
  /// on later pages (a plain delete would just reappear next time the model
  /// reports it).
  void removeGlossaryEntry(
    String cid,
    String sourceKey,
    String source, {
    bool block = false,
  }) {
    var comicKey = '$cid@$sourceKey';
    var glossary = _allGlossaries[comicKey];
    var removed = glossary != null && glossary.remove(source) != null;
    if (removed) {
      appdata.translationImplicitData[_comicGlossaryKey] = _allGlossaries;
    }
    if (block) {
      _addBlockedTerm(comicKey, source);
    }
    if (removed || block) {
      appdata.writeImplicitData();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------
  // Per-comic blocked terms
  // ---------------------------------------------------------------------

  /// Source terms the user banned from a comic's glossary. Kept separate from
  /// the glossary so a deleted-and-blocked name is not silently re-learned the
  /// next time the model reports it.
  static const _blockedTermsKey = 'imageTranslationBlockedTerms';
  Map<String, Set<String>>? _blockedTerms;

  Map<String, Set<String>> get _allBlockedTerms {
    if (_blockedTerms == null) {
      var stored = appdata.translationImplicitData[_blockedTermsKey];
      _blockedTerms = <String, Set<String>>{};
      if (stored is Map) {
        stored.forEach((k, v) {
          if (v is List) {
            _blockedTerms![k.toString()] = v.map((e) => e.toString()).toSet();
          }
        });
      }
    }
    return _blockedTerms!;
  }

  void _addBlockedTerm(String comicKey, String source) {
    if (source.isEmpty) return;
    var set = _allBlockedTerms.putIfAbsent(comicKey, () => <String>{});
    set.add(source);
    _persistBlockedTerms();
  }

  void _persistBlockedTerms() {
    appdata.translationImplicitData[_blockedTermsKey] = _allBlockedTerms.map(
      (k, v) => MapEntry(k, v.toList()),
    );
  }

  /// The blocked source terms of a comic, for the glossary editor.
  List<String> blockedTermsOf(String cid, String sourceKey) {
    return _allBlockedTerms['$cid@$sourceKey']?.toList() ?? const [];
  }

  /// Lifts the block on a term so it can be learned/added again.
  void unblockTerm(String cid, String sourceKey, String source) {
    var comicKey = '$cid@$sourceKey';
    var set = _allBlockedTerms[comicKey];
    if (set == null || !set.remove(source)) return;
    _persistBlockedTerms();
    appdata.writeImplicitData();
    notifyListeners();
  }

  bool _isBlocked(String comicKey, String source) {
    return _allBlockedTerms[comicKey]?.contains(source) ?? false;
  }

  void _mergeGlossary(String comicKey, Map<String, String> discovered) {
    if (discovered.isEmpty) return;
    var all = _allGlossaries;
    var glossary = all.putIfAbsent(comicKey, () => <String, String>{});
    var changed = false;
    discovered.forEach((source, translation) {
      // First agreed translation wins: an established name is not overwritten
      // by a later page's rephrasing, which keeps it stable.
      // Validate here too: the parse-time filter is the primary guard, but a
      // future caller of _mergeGlossary must not be able to insert bloat.
      if (!LlmTranslator.isValidGlossaryTerm(source, translation)) return;
      // Blocked terms must never be re-learned, even if the model keeps
      // reporting them.
      if (_isBlocked(comicKey, source)) return;
      if (!glossary.containsKey(source)) {
        glossary[source] = translation;
        changed = true;
      }
    });
    if (!changed) return;
    while (glossary.length > _maxGlossaryEntries) {
      glossary.remove(glossary.keys.first);
    }
    appdata.translationImplicitData[_comicGlossaryKey] = all;
    appdata.writeImplicitData();
  }

  /// Drops a comic's learned glossary. Called on re-translate so a wrong name
  /// established on an earlier run does not get re-fed to the model and
  /// perpetuated.
  void _clearGlossary(String comicKey) {
    var all = _allGlossaries;
    if (all.remove(comicKey) == null) return;
    appdata.translationImplicitData[_comicGlossaryKey] = all;
    appdata.writeImplicitData();
  }

  void _notifyDone(_TranslationTask task) {
    _completed.add(renderedKey(task.cacheKey, task.config.mode));
    for (var listener in task.listeners) {
      try {
        listener();
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Frees model memory after the reader has been idle for a while.
  void _scheduleRelease() {
    _releaseTimer?.cancel();
    _releaseTimer = Timer(_idleReleaseDelay, () {
      if (_active.isNotEmpty || _queue.isNotEmpty) return;
      var pipeline = _pipeline;
      _pipeline = null;
      unawaited(pipeline?.release());
    });
  }

  /// Drops queued-but-not-started work (e.g. when leaving the reader).
  void clearQueue() {
    _queue.removeWhere((task) => !_active.contains(task));
    if (_queue.isEmpty && _active.isEmpty) {
      _scheduleRelease();
    }
  }

  /// Evicts a provider's stale image-cache entry so the next resolve loads
  /// the translated page.
  static void evictImage(ImageProvider provider) {
    scheduleMicrotask(() {
      PaintingBinding.instance.imageCache.evict(provider);
    });
  }
}
