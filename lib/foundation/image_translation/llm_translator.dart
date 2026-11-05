import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:pica_comic/foundation/appdata.dart';
import 'package:pica_comic/foundation/image_translation/public_translator.dart';
import 'package:pica_comic/foundation/image_translation/script_translator.dart';
import 'package:pica_comic/foundation/image_translation/rate_limiter.dart';
import 'package:pica_comic/foundation/image_translation/translation_performance_config.dart';
import 'package:pica_comic/foundation/image_translation/translation_targets.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/network/app_dio.dart';

/// One page's translation outcome: the per-bubble texts (aligned with the
/// input, empty where the model refused/failed) plus any proper-noun
/// renderings the model reported for this page, which the caller folds back
/// into the comic's glossary so later pages/chapters stay consistent.
class LlmTranslationResult {
  const LlmTranslationResult(this.texts, this.glossary);

  final List<String> texts;

  /// source term -> agreed translation, discovered on this page.
  final Map<String, String> glossary;
}

/// Which translation engine a provider entry stands for.
enum LlmProviderKind {
  /// A user-supplied OpenAI-compatible chat endpoint. Needs URL + model.
  openai('openai'),

  /// Google Translate's free endpoint. Needs no configuration at all, so its
  /// URL/key/model stay empty.
  publicFree('public'),

  customScript('script');

  const LlmProviderKind(this.token);

  final String token;

  static LlmProviderKind fromToken(dynamic token) {
    for (var kind in values) {
      if (kind.token == token) return kind;
    }
    // Entries written before this field existed are all OpenAI-compatible.
    return openai;
  }
}

/// One configured translation service: a stable [id], a display [name], and —
/// for an OpenAI-compatible entry — the endpoint/credential/model triple that
/// used to be the app's single global config. Users keep several of these and
/// pick which one is active, so they can switch between vendors (or a paid
/// account and a LAN gateway) without re-typing settings each time.
///
/// A [LlmProviderKind.publicFree] entry is the exception: it carries no
/// endpoint, key or model, because that service needs none.
class LlmProvider {
  LlmProvider({
    required this.id,
    required this.name,
    required this.url,
    required this.key,
    required this.model,
    this.kind = LlmProviderKind.openai,
    this.script = '',
  });

  final String id;
  final String name;
  final String url;
  final String key;
  final String model;
  final LlmProviderKind kind;
  // Stored separately by LlmProviderStore; never included in synced metadata.
  final String script;

  bool get isPublicFree => kind == LlmProviderKind.publicFree;
  bool get isCustomScript => kind == LlmProviderKind.customScript;

  LlmProvider copyWith({
    String? name,
    String? url,
    String? key,
    String? model,
    LlmProviderKind? kind,
    String? script,
  }) {
    return LlmProvider(
      id: id,
      name: name ?? this.name,
      url: url ?? this.url,
      key: key ?? this.key,
      model: model ?? this.model,
      kind: kind ?? this.kind,
      script: script ?? this.script,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'key': key,
        'model': model,
        'kind': kind.token,
      };

  static LlmProvider? fromJson(dynamic json) {
    if (json is! Map) return null;
    var id = json['id'];
    if (id is! String || id.isEmpty) return null;
    return LlmProvider(
      id: id,
      name: (json['name'] as String?)?.trim() ?? '',
      url: (json['url'] as String?)?.trim() ?? '',
      key: (json['key'] as String?)?.trim() ?? '',
      model: (json['model'] as String?)?.trim() ?? '',
      kind: LlmProviderKind.fromToken(json['kind']),
    );
  }
}

/// Reads and writes the user's list of LLM providers and which one is active.
///
/// The list is stored in settings (and synced across devices as a whole), so
/// this is the single source of truth the translator reads from. All mutating
/// helpers persist via [appdata.saveData] and notify listeners so open
/// settings pages refresh.
abstract class LlmProviderStore {
  static const _listKey = 'imageTranslationProviders';
  static const _activeKey = 'imageTranslationActiveProviderId';
  // Executable scripts stay on the device, like custom image processing.
  static const scriptsKey = 'imageTranslationScripts';

  static List<LlmProvider> get providers {
    var raw = appdata.translationSettings[_listKey];
    if (raw is! List) return <LlmProvider>[];
    var result = <LlmProvider>[];
    for (var item in raw) {
      var provider = LlmProvider.fromJson(item);
      if (provider != null) {
        final scripts = appdata.translationSettings[scriptsKey];
        final script = scripts is Map ? scripts[provider.id] : null;
        result.add(provider.copyWith(script: script is String ? script : ''));
      }
    }
    return result;
  }

  static String get activeId =>
      (appdata.translationSettings[_activeKey] as String? ?? '').trim();

  /// The active provider, or the first configured one as a fallback so a list
  /// that lost its active pointer still translates. Null when the list is empty.
  static LlmProvider? get active {
    var all = providers;
    if (all.isEmpty) return null;
    var id = activeId;
    for (var p in all) {
      if (p.id == id) return p;
    }
    return all.first;
  }

  static void _persist(List<LlmProvider> list) {
    appdata.translationSettings[_listKey] = [for (var p in list) p.toJson()];
    appdata.translationSettings[scriptsKey] = {
      for (var p in list)
        if (p.script.isNotEmpty) p.id: p.script,
    };
  }

  /// Adds [provider] and returns it. Becomes active if none was set.
  static void add(LlmProvider provider) {
    var list = providers..add(provider);
    _persist(list);
    if (active == null || activeId.isEmpty) {
      appdata.translationSettings[_activeKey] = provider.id;
    }
    appdata.saveData();
  }

  static void update(LlmProvider provider) {
    var list = providers;
    var index = list.indexWhere((p) => p.id == provider.id);
    if (index == -1) return;
    list[index] = provider;
    _persist(list);
    appdata.saveData();
  }

  static void remove(String id) {
    var list = providers..removeWhere((p) => p.id == id);
    _persist(list);
    // Reassign the active pointer if the removed provider was selected.
    if (activeId == id) {
      appdata.translationSettings[_activeKey] =
          list.isEmpty ? '' : list.first.id;
    }
    appdata.saveData();
  }

  static void setActive(String id) {
    appdata.translationSettings[_activeKey] = id;
    appdata.saveData();
  }

  /// One-time migration from the legacy single-config keys
  /// (imageTranslationLlmUrl/Key/Model) to the provider list. Runs at startup;
  /// only fires when no providers exist yet and a legacy URL is present. The
  /// legacy keys are left untouched so an older app version can still read them.
  static void migrateLegacyIfNeeded() {
    if (providers.isNotEmpty) return;
    var url =
        (appdata.translationSettings['imageTranslationLlmUrl'] as String? ?? '')
            .trim();
    if (url.isEmpty) return;
    var provider = LlmProvider(
      id: const Uuid().v4(),
      name: 'LLM',
      url: url,
      key: (appdata.translationSettings['imageTranslationLlmKey'] as String? ??
              '')
          .trim(),
      model:
          (appdata.translationSettings['imageTranslationLlmModel'] as String? ??
                  '')
              .trim(),
    );
    _persist([provider]);
    appdata.translationSettings[_activeKey] = provider.id;
    // sync:false — this runs during init before the sync layer is ready, and
    // a migration is not a user edit that should trigger an upload.
    appdata.saveData(false);
  }
}

/// The system message sent with every translation request.
///
/// The built-in text asks for natural dialogue, glossary reuse and a report of
/// new proper nouns — input tokens a small self-hosted model may not afford, so
/// users can substitute a shorter one and accept the weaker result.
///
/// Only the user's own text is stored; empty means "use [builtIn]", so later
/// edits to the built-in text still reach everyone who never customized theirs.
abstract class LlmPromptStore {
  static const settingKey = 'imageTranslationPrompt';

  /// `$target` is substituted with the target language's own name.
  static const builtIn = '你是资深的二次元漫画本地化译者，热爱 ACGN 文化。将用户提供的 JSON 对象中 lines '
      '数组里每个元素的 text 字段翻译成\$target。要求：像真人说话一样自然口语化，'
      '贴合二次元漫画的语气和氛围，避免生硬的机翻腔；'
      '在符合角色人设和场景的前提下，可以适度使用当下流行的二次元/网络用语，'
      '但不要硬凑或滥用，宁可平实也不要出戏；'
      '语气词、拟声词按含义和情绪意译；OCR 造成的少量错字请按上下文推断原意。\n'
      '同一部漫画跨页阅读，人名、地名、招式名等专有名词的译法必须前后一致：'
      'glossary 字段给出的是已确定的译法（键为原文，值为译文），出现时必须沿用。\n'
      '同时，请把本次新出现（glossary 中没有）的人名、地名、招式/组织名等专有名词，'
      '连同你采用的译法，收集到 names 字段返回，供后续页面保持一致。'
      'names 只收录简短的专有名词（通常不超过 8 个字），'
      '不要收录整句对白、拟声词、普通词组、数字或网址。\n'
      '只输出一个 JSON 对象，格式为 '
      '{"lines":[{"id":0,"text":"译文"}],"names":{"原文":"译文"}}，'
      'lines 中每个 id 恰好出现一次，不要输出任何其他内容。';

  /// The user's text, or '' when the built-in one is in use.
  static String get custom =>
      (appdata.translationSettings[settingKey] as String? ?? '').trim();

  static bool get isCustom => custom.isNotEmpty;

  /// The template actually sent, with `$target` still unsubstituted.
  static String get template => isCustom ? custom : builtIn;

  /// The system message for [targetName], with `$target` substituted.
  static String resolve(String targetName) =>
      template.replaceAll(r'$target', targetName);

  /// What [save] would store for [value]: '' when it is blank or identical to
  /// the built-in text, so neither case pins the device to this release's
  /// wording. Split out from [save] to keep the decision free of file IO.
  static String normalize(String value) {
    var text = value.trim();
    return text == builtIn.trim() ? '' : text;
  }

  /// Stores [value], or clears back to the built-in text when it is blank.
  static void save(String value) {
    appdata.translationSettings[settingKey] = normalize(value);
    appdata.saveData();
  }

  /// Whether [value] still tells the model which language to translate into.
  /// Without the placeholder the request carries no target at all, so the model
  /// guesses — worth warning about, but the user's text is still honored.
  static bool hasTargetPlaceholder(String value) => value.contains(r'$target');
}

/// Translates recognized bubble texts through a user-configured
/// OpenAI-compatible chat endpoint.
///
/// The app ships with no endpoint, key or vendor — everything is supplied by
/// the user in settings, so translation quality is whatever model they point
/// it at. All bubbles of a page go out as ONE request, together with the
/// comic's running glossary so names stay consistent across pages/chapters.
abstract class LlmTranslator {
  /// Shared, per-provider concurrency limiter. Both the reader's inline
  /// translation and background pre-translation call [translateBatch], so they
  /// share this gate — neither path can overrun the endpoint on its own. The
  /// effective limit is min(user setting, AIMD estimate); AIMD backs off on a
  /// 429/503 and recovers on success.
  static final _aimd = AimdController(min: 1, max: 4);
  static final _gate = ConcurrencyGate((bucket) {
    var userMax = TranslationPerformanceConfig.effective.llmConcurrency.clamp(
      1,
      4,
    );
    return math.min(userMax, _aimd.limitFor(bucket));
  });

  /// Hard ceiling for one translation request, transport level included.
  ///
  /// A slow model on a long batch legitimately needs a minute or two, so this is
  /// generous — but it must exist. The request holds a [_gate] slot while in
  /// flight, so an unbounded one does not just lose its own page: it permanently
  /// removes a concurrency slot, and once every slot is held by a stalled request
  /// no further page can start. Background pre-translation, which commits page
  /// counts in strict order, then freezes at zero visible progress (#176).
  static const requestTimeout = Duration(minutes: 3);

  /// Wall-clock ceiling for one [translateBatch] call including all its retries.
  /// Bounds the total time a single call can occupy a concurrency slot.
  static const totalRetryBudget = Duration(minutes: 6);

  /// Attempts allowed when the endpoint answered but its reply could not be
  /// used (no JSON of the requested shape, or an empty message). Much smaller
  /// than the transport retry count on purpose: every retry re-sends the whole
  /// prompt and the page's lines at full token cost, and a model that ignored
  /// the output format once rarely honors it on the next try.
  static const maxContentAttempts = 2;

  /// How long a caller may wait for a free concurrency slot before giving up.
  /// Deliberately much larger than [totalRetryBudget] so a normal queue never
  /// trips it; it exists purely to break a slot that was never released.
  static const _slotWaitBackstop = Duration(minutes: 30);

  static String get _rawUrl => (LlmProviderStore.active?.url ?? '').trim();

  static String get _apiKey => (LlmProviderStore.active?.key ?? '').trim();

  static String get _model => (LlmProviderStore.active?.model ?? '').trim();

  /// Whether the active provider can translate right now. The keyless service
  /// needs nothing configured; an OpenAI-compatible one needs a URL and model.
  /// A key is optional on purpose: local gateways (ollama, lm-studio, one-api
  /// instances on LAN) often run without authentication.
  static bool get isConfigured {
    var active = LlmProviderStore.active;
    if (active == null) return false;
    if (active.isPublicFree) return true;
    if (active.isCustomScript) return active.script.trim().isNotEmpty;
    return _rawUrl.isNotEmpty && _model.isNotEmpty;
  }

  /// Whether the active provider translates line-by-line with no model context.
  /// The glossary and the reported-names round trip only mean something for an
  /// LLM, so callers skip both when this is true.
  static bool get activeIsPublicFree =>
      LlmProviderStore.active?.isPublicFree ?? false;

  /// Whether just the URL is set — enough to try fetching the model list
  /// before the user has picked a model.
  static bool get baseUrlConfigured => _rawUrl.isNotEmpty;

  /// Accepts either a base URL ("https://host/v1") or a full chat-completions
  /// URL; normalizes to the latter.
  static String get _endpoint {
    var url = _rawUrl;
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.endsWith('/chat/completions')) {
      return url;
    }
    return '$url/chat/completions';
  }

  /// Strips trailing slashes and a trailing '/chat/completions' from [rawUrl]
  /// so sibling endpoints (e.g. '/models') can be derived from any accepted
  /// URL shape. Shared by the active-provider getter and the ad-hoc fetch used
  /// while editing a not-yet-active provider.
  static String baseUrlOf(String rawUrl) {
    var url = rawUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.endsWith('/chat/completions')) {
      url = url.substring(0, url.length - '/chat/completions'.length);
    }
    return url;
  }

  static bool isValidBaseUrl(String rawUrl) {
    var uri = Uri.tryParse(rawUrl.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  /// Fetches the model id list from the endpoint's `/models` (OpenAI-style).
  /// Returns the ids; throws with a readable message on failure so the UI can
  /// fall back to manual entry.
  ///
  /// [url]/[key] default to the active provider's, but the provider-editing UI
  /// passes the values being edited so the model list matches the provider the
  /// user is configuring, not whichever one is currently active.
  static Future<List<String>> fetchModels({String? url, String? key}) async {
    var rawUrl = (url ?? _rawUrl).trim();
    var apiKey = (key ?? _apiKey).trim();
    if (rawUrl.isEmpty) {
      throw Exception('LLM API URL not configured');
    }
    var baseUrl = baseUrlOf(rawUrl);
    const probeTimeout = Duration(seconds: 30);
    var dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: probeTimeout,
        headers: {if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey'},
        validateStatus: (status) => status != null && status < 500,
      ),
    )..httpClientAdapter = AppHttpAdapter(false);
    try {
      var response = await dio.get('$baseUrl/models');
      if (response.statusCode != 200) {
        throw Exception(
          'Endpoint returned ${response.statusCode}: '
          '${_briefBody(response.data)}',
        );
      }
      var data = response.data;
      // OpenAI shape: {data: [{id: ...}, ...]}. Some gateways return a bare
      // list or {models:[...]} (ollama); tolerate all three.
      List<dynamic>? list;
      if (data is Map && data['data'] is List) {
        list = data['data'] as List;
      } else if (data is Map && data['models'] is List) {
        list = data['models'] as List;
      } else if (data is List) {
        list = data;
      }
      if (list == null) {
        throw Exception('Unexpected /models response');
      }
      var ids = <String>[];
      for (var item in list) {
        if (item is Map) {
          var id = item['id'] ?? item['name'] ?? item['model'];
          if (id is String && id.isNotEmpty) ids.add(id);
        } else if (item is String && item.isNotEmpty) {
          ids.add(item);
        }
      }
      ids.sort();
      return ids;
    } finally {
      dio.close();
    }
  }

  /// Translates [texts] into [targetLang]. [glossary] carries agreed
  /// translations of names/proper nouns established on earlier pages of the
  /// same comic; it is sent to the model as a must-follow reference so a
  /// character's name is rendered the same way across pages and chapters.
  ///
  /// The returned [LlmTranslationResult] holds the aligned translations plus
  /// any new name/proper-noun pairs the model reported for this page, which
  /// the caller merges back into the comic's glossary.
  static Future<LlmTranslationResult> translateBatch(
    List<String> texts,
    String targetLang, {
    Map<String, String> glossary = const {},
    String sourceLang = 'auto',
  }) async {
    if (texts.isEmpty) {
      return const LlmTranslationResult([], {});
    }
    final provider = LlmProviderStore.active;
    if (provider?.isCustomScript ?? false) {
      await _gate.acquire(provider!.id, maxWait: _slotWaitBackstop);
      try {
        return await ScriptTranslator.translate(
          provider,
          texts,
          sourceLang,
          targetLang,
          glossary: glossary,
        );
      } finally {
        _gate.release(provider.id);
      }
    }
    if (activeIsPublicFree) {
      return _translateBatchPublic(texts, targetLang);
    }
    var target = TranslationTargets.promptName(targetLang);
    var systemPrompt = LlmPromptStore.resolve(target);
    var payload = jsonEncode({
      if (glossary.isNotEmpty) 'glossary': glossary,
      'lines': [
        for (var i = 0; i < texts.length; i++) {'id': i, 'text': texts[i]},
      ],
    });

    var dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: requestTimeout,
        headers: {
          'Content-Type': 'application/json',
          if (_apiKey.isNotEmpty) 'Authorization': 'Bearer $_apiKey',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    )..httpClientAdapter = AppHttpAdapter(false);
    var bucket = LlmProviderStore.active?.id ?? 'default';
    // Backstop for a leaked slot, NOT a congestion limit. Queueing behind other
    // pages is normal and must be allowed to wait: with the limit backed off to
    // 1, several queued callers each taking up to [totalRetryBudget] can add up,
    // so this is set far above any legitimate wait. It only ever fires if a slot
    // is never released at all, and then fails one page instead of silently
    // freezing every page behind it forever.
    await _gate.acquire(bucket, maxWait: _slotWaitBackstop);
    try {
      const maxAttempts = 6;
      // Retries share one wall-clock budget. Per-attempt bounds alone are not
      // enough: 6 attempts each allowed [requestTimeout] would let a dead
      // endpoint hold a concurrency slot for the better part of an hour, which
      // is the stall this fix is meant to remove. Whichever limit is hit first
      // wins, and the page is reported failed so a later retry pass can redo it.
      var giveUpAt = DateTime.now().add(totalRetryBudget);
      Object? lastError;
      // Counted separately from [attempt]: a 200 whose body is unusable is
      // charged for at full token price, so it gets [maxContentAttempts], not
      // the transport allowance.
      var contentAttempts = 0;
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        HttpErrorClass? cls;
        Duration? retryAfter;
        var contentFailure = false;
        try {
          var response = await dio.post(
            _endpoint,
            data: {
              'model': _model,
              // No sampling params: some endpoints only accept their model's
              // fixed values (e.g. "only 1 is allowed") and reject the request
              // outright; the server-side default works everywhere.
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                {'role': 'user', 'content': payload},
              ],
            },
          );
          var status = response.statusCode ?? 0;
          if (status == 200) {
            // The endpoint answered and was billed; anything wrong from here on
            // is the reply's content, not the transport.
            contentFailure = true;
            var content =
                response.data['choices']?[0]?['message']?['content'] as String?;
            if (content == null || content.isEmpty) {
              throw Exception('LLM response has no content');
            }
            _aimd.onSuccess(bucket);
            return _parse(content, texts.length);
          }
          lastError = Exception(
            'LLM endpoint returned $status: ${_briefBody(response.data)}',
          );
          cls = classifyStatus(status);
          retryAfter = parseRetryAfter(response.headers.value('retry-after'));
        } on DioException catch (e) {
          lastError = e;
          var status = e.response?.statusCode;
          cls = status != null
              ? classifyStatus(status)
              : HttpErrorClass.transient;
          retryAfter = parseRetryAfter(
            e.response?.headers.value('retry-after'),
          );
          Log.warning('Image Translation', 'LLM request failed: $e');
        } catch (e) {
          // Parse/other unexpected error: allow a couple of retries.
          lastError = e;
          cls = HttpErrorClass.transient;
          Log.warning('Image Translation', 'LLM request failed: $e');
        }
        // Decide retry vs fail OUTSIDE the try, so a fast-fail doesn't get
        // swallowed by the catch above.
        if (cls == HttpErrorClass.clientError || cls == HttpErrorClass.fatal) {
          break; // bad model/auth: retrying won't help
        }
        if (contentFailure && ++contentAttempts >= maxContentAttempts) {
          // The model keeps replying with something unusable. Further tries
          // would re-send the whole prompt for the same outcome.
          break;
        }
        if (cls == HttpErrorClass.rateLimited) {
          _aimd.onRateLimited(bucket);
        }
        var wait = backoff(attempt, retryAfter: retryAfter);
        // Stop if the budget is already spent, or if sleeping would overrun it.
        if (DateTime.now().add(wait).isAfter(giveUpAt)) {
          break;
        }
        await Future.delayed(wait);
      }
      throw Exception('LLM translation failed: $lastError');
    } finally {
      _gate.release(bucket);
    }
  }

  /// [translateBatch] for a [LlmProviderKind.publicFree] provider.
  ///
  /// Goes through the same [_gate] as the LLM path so the reader and background
  /// pre-translation still cannot overrun the endpoint between them, and feeds
  /// the same AIMD estimator so a rate-limited endpoint backs off too.
  /// Returns no glossary entries: this engine translates each line in isolation
  /// and reports no proper nouns.
  static Future<LlmTranslationResult> _translateBatchPublic(
    List<String> texts,
    String targetLang,
  ) async {
    var bucket = LlmProviderStore.active?.id ?? 'public';
    await _gate.acquire(bucket, maxWait: _slotWaitBackstop);
    try {
      var translated = await PublicTranslator.translate(
        texts,
        targetLang,
        onSuccess: () => _aimd.onSuccess(bucket),
        onRateLimited: () => _aimd.onRateLimited(bucket),
      );
      return LlmTranslationResult(translated, const {});
    } finally {
      _gate.release(bucket);
    }
  }

  /// Parses the model output into aligned translations plus reported names.
  ///
  /// The prompt asks for a JSON object
  /// `{"lines":[{"id,"text"}],"names":{...}}`, but models sometimes return a
  /// bare `[{"id","text"}]` array (ignoring the wrapper). Both shapes are
  /// accepted so a slightly non-compliant model still works; a bare array
  /// simply yields no new glossary entries.
  static LlmTranslationResult _parse(String content, int count) {
    var object = _extractJsonObject(content);
    List<dynamic>? lines;
    var names = <String, String>{};
    if (object is Map) {
      if (object['lines'] is List) {
        lines = object['lines'] as List;
      }
      if (object['names'] is Map) {
        (object['names'] as Map).forEach((k, v) {
          if (k is String && v is String) {
            var key = k.trim();
            var value = v.trim();
            if (isValidGlossaryTerm(key, value)) {
              names[key] = value;
            }
          }
        });
      }
    } else if (object is List) {
      lines = object;
    }
    if (lines == null) {
      throw Exception('LLM response is not in the expected JSON shape');
    }
    var results = List.filled(count, '');
    for (var item in lines) {
      if (item is! Map) continue;
      var id = item['id'];
      var text = item['text'];
      if (id is int && id >= 0 && id < count && text is String) {
        results[id] = text.trim();
      }
    }
    return LlmTranslationResult(results, names);
  }

  /// Whether a reported name/translation pair is worth keeping in the glossary.
  /// The glossary exists only for short proper nouns (names, places, techniques)
  /// that must stay consistent across pages; it is sent with every request, so
  /// it must stay small. Models occasionally return whole sentences, URLs or
  /// numbers as "names" — those bloat the prompt without helping consistency,
  /// so they are rejected here as a backstop to the prompt's own instruction.
  /// Also used by the service to sanitize a glossary loaded from an earlier
  /// version that had no such filtering.
  static bool isValidGlossaryTerm(String source, String translation) {
    if (source.isEmpty || translation.isEmpty) return false;
    // Proper nouns are short. Anything long is almost certainly a sentence.
    if (source.length > 16 || translation.length > 16) return false;
    for (var s in [source, translation]) {
      // URLs / emails / paths — never proper nouns, and long enough to bloat.
      if (_urlLike.hasMatch(s)) return false;
      // Sentence-like: contains terminal/comma punctuation or whitespace runs
      // typical of a clause rather than a single term.
      if (_sentenceLike.hasMatch(s)) return false;
    }
    // Pure numbers (page numbers, counts) carry no naming to keep consistent.
    if (_numericOnly.hasMatch(source)) return false;
    return true;
  }

  static final _urlLike = RegExp(
    r'https?://|www\.|@|[./\\][a-zA-Z]{2,}|\.(com|net|org|io|cn|jp)\b',
    caseSensitive: false,
  );

  static final _sentenceLike = RegExp(r'[。！？.!?、,，；;]|\s{1,}\S+\s');

  static final _numericOnly = RegExp(r'^[0-9\s.,]+$');

  /// Pulls the first JSON object or array out of [content], tolerating code
  /// fences and surrounding prose. Prefers an object (the requested shape);
  /// falls back to an array.
  static dynamic _extractJsonObject(String content) {
    var objStart = content.indexOf('{');
    var objEnd = content.lastIndexOf('}');
    var arrStart = content.indexOf('[');
    var arrEnd = content.lastIndexOf(']');
    // An object wrapping the array has its '{' before the '['.
    if (objStart != -1 &&
        objEnd > objStart &&
        (arrStart == -1 || objStart < arrStart)) {
      try {
        return jsonDecode(content.substring(objStart, objEnd + 1));
      } catch (_) {
        // fall through to array
      }
    }
    if (arrStart != -1 && arrEnd > arrStart) {
      return jsonDecode(content.substring(arrStart, arrEnd + 1));
    }
    throw Exception('LLM response has no JSON payload');
  }

  static String _briefBody(Object? body) {
    var text = body.toString();
    return text.length > 200 ? text.substring(0, 200) : text;
  }
}
