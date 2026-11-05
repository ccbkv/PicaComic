import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/image_translation/hf_tokenizer.dart';
import 'package:pica_comic/foundation/image_translation/ort_ffi.dart';
import 'package:pica_comic/foundation/image_translation/translation_types.dart';
import 'package:pica_comic/foundation/image_translation/translation_performance_config.dart';
import 'package:pica_comic/foundation/image_translation/worker_pool_selection.dart';
import 'package:pica_comic/utils/io.dart';

/// Model file paths handed to the worker with each request; the worker has no
/// access to appdata/settings singletons.
class WorkerModelPaths {
  WorkerModelPaths({
    required this.detector,
    this.jaEncoder,
    this.jaDecoder,
    this.jaVocab,
    this.recModels = const {},
    this.recDicts = const {},
    this.recHeights = const {},
    this.recLanguages = const {},
    this.engines = const [],
  });

  final String detector;
  final String? jaEncoder;
  final String? jaDecoder;
  final String? jaVocab;

  /// engine -> rec model path ('zh5', 'zh', 'en', 'ko', or `custom_` + hash).
  final Map<String, String> recModels;
  final Map<String, String> recDicts;
  final Map<String, int> recHeights;

  /// engine -> language its text is labeled with when the script alone does
  /// not decide.
  final Map<String, String> recLanguages;

  /// Engines to try, in order. For 'auto' only line engines; 'ja' is placed
  /// by text direction.
  final List<String> engines;
}

/// Why a user-supplied model was rejected after download.
enum ModelCheckFailure {
  cannotRun,
  notRecognizer,
  notDetector,
  dictionaryMismatch,
}

class ModelCheckException implements Exception {
  const ModelCheckException(this.failure, {this.classes = 0, this.entries = 0});

  final ModelCheckFailure failure;
  final int classes;
  final int entries;

  @override
  String toString() => 'ModelCheckException($failure, $classes, $entries)';
}

/// Runs a PP-OCR recognition model once on a blank line and checks its output
/// against the dictionary. Off the main isolate: loading a model takes long.
Future<void> checkRecognitionModel(String model, String dict, int height) {
  return Isolate.run(() {
    var entries = File(dict).readAsLinesSync().length;
    OrtFfiSession session;
    OrtOutput output;
    try {
      session = OrtFfiSession.open(model, intraOpThreads: 1);
    } catch (_) {
      throw const ModelCheckException(ModelCheckFailure.cannotRun);
    }
    try {
      output = session.run({
        session.inputNames.first: OrtInput.float32(
          Float32List(3 * height * 160),
          [1, 3, height, 160],
        ),
      }).values.first;
    } catch (_) {
      throw const ModelCheckException(ModelCheckFailure.cannotRun);
    } finally {
      session.close();
    }
    if (output.shape.length != 3) {
      throw const ModelCheckException(ModelCheckFailure.notRecognizer);
    }
    // Classes are blank + dictionary, plus a space class on most models.
    var classes = output.shape.last;
    if (classes != entries + 1 && classes != entries + 2) {
      throw ModelCheckException(
        ModelCheckFailure.dictionaryMismatch,
        classes: classes,
        entries: entries,
      );
    }
  });
}

/// Runs a detection model once and checks it returns a DBNet probability map
/// the size of its input.
Future<void> checkDetectionModel(String model) {
  return Isolate.run(() {
    OrtFfiSession session;
    OrtOutput output;
    try {
      session = OrtFfiSession.open(model, intraOpThreads: 1);
    } catch (_) {
      throw const ModelCheckException(ModelCheckFailure.cannotRun);
    }
    try {
      output = session.run({
        session.inputNames.first: OrtInput.float32(
          Float32List(3 * 64 * 64),
          const [1, 3, 64, 64],
        ),
      }).values.first;
    } catch (_) {
      throw const ModelCheckException(ModelCheckFailure.cannotRun);
    } finally {
      session.close();
    }
    var s = output.shape;
    if (s.length != 4 || s[1] != 1 || s[2] != 64 || s[3] != 64) {
      throw const ModelCheckException(ModelCheckFailure.notDetector);
    }
  });
}

final _letter = RegExp(r'[\p{L}\p{M}]', unicode: true);

/// Whether [rune] is a letter of any script. Lets recognition and the
/// translatable-text filter accept Cyrillic, Thai, Arabic and the like, not
/// only CJK and ASCII.
bool isScriptLetter(int rune) => _letter.hasMatch(String.fromCharCode(rune));

/// Language of an OCR block from its script. Kana and Hangul decide on their
/// own; Han follows a Chinese or Japanese engine; Latin is English for the
/// built-in engines and the user's language for a custom one; any other
/// script takes the engine's language.
String detectBlockLanguage(String text, String engineLang) {
  var kana = 0, hangul = 0, han = 0, latin = 0;
  for (var r in text.runes) {
    if ((r >= 0x3040 && r <= 0x30FF) || (r >= 0x31F0 && r <= 0x31FF)) {
      kana++;
    } else if ((r >= 0xAC00 && r <= 0xD7AF) || (r >= 0x1100 && r <= 0x11FF)) {
      hangul++;
    } else if ((r >= 0x4E00 && r <= 0x9FFF) || (r >= 0x3400 && r <= 0x4DBF)) {
      han++;
    } else if ((r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A)) {
      latin++;
    }
  }
  const builtIn = {'ja', 'zh', 'en', 'ko'};
  if (kana > 0) return 'ja';
  if (hangul > 0) return 'ko';
  if (han > 0) {
    if (engineLang == 'ja' || engineLang.startsWith('zh')) return engineLang;
    return 'zh';
  }
  if (latin > 0) return builtIn.contains(engineLang) ? 'en' : engineLang;
  return engineLang;
}

class _OcrPageRequest {
  _OcrPageRequest(
    this.id,
    this.pixels,
    this.width,
    this.height,
    this.sourceLang,
    this.paths,
    this.intraThreads,
  );

  final int id;
  final TransferableTypedData pixels;
  final int width;
  final int height;

  /// 'auto' enables the vertical heuristic + fallback OCR chain.
  final String sourceLang;
  final WorkerModelPaths paths;
  final int intraThreads;
}

class _ReleaseRequest {
  const _ReleaseRequest();
}

class _WorkerResponse {
  _WorkerResponse(this.id, this.result, this.error);

  final int id;
  final Object? result;
  final String? error;
}

/// Resolves the OCR worker count without touching platform or settings state.
/// Kept public so the mobile memory policy can be covered by a pure unit test.
int resolveOcrPoolSize({
  required int requested,
  required int processorCount,
  required bool isMobile,
  required bool isDesktop,
  required String sourceLang,
  required bool hasJapaneseModel,
}) {
  if (isMobile &&
      (sourceLang == 'ja' || (sourceLang == 'auto' && hasJapaneseModel))) {
    return 1;
  }
  if (requested > 0) {
    return requested.clamp(1, isMobile ? 2 : 6);
  }
  var automatic = processorCount ~/ 2;
  return automatic.clamp(1, isDesktop ? 3 : 2);
}

/// Conservative page-local hint for auto OCR. Only the first two blocks with
/// unambiguous script evidence participate; a disagreement disables the hint.
/// Han-only text is deliberately not evidence, except vertical Japanese text.
class OcrPageEngineHint {
  String? _candidate;
  var _evidenceCount = 0;
  var _settled = false;

  String? get preferredEngine => _evidenceCount >= 2 ? _candidate : null;

  void observe({
    required String text,
    required String language,
    required String engine,
    required bool isVertical,
  }) {
    if (_settled) return;
    var signal = strongOcrEngineSignal(
      text: text,
      language: language,
      engine: engine,
      isVertical: isVertical,
    );
    if (signal == null) return;
    if (_candidate == null) {
      _candidate = signal;
      _evidenceCount = 1;
      return;
    }
    _settled = true;
    if (_candidate == signal) {
      _evidenceCount = 2;
    } else {
      _candidate = null;
      _evidenceCount = 0;
    }
  }
}

String? strongOcrEngineSignal({
  required String text,
  required String language,
  required String engine,
  required bool isVertical,
}) {
  if (language != engine) return null;
  var hasKana = false;
  var hasHangul = false;
  var hasHan = false;
  var hasLatin = false;
  for (var rune in text.runes) {
    if ((rune >= 0x3040 && rune <= 0x30FF) ||
        (rune >= 0x31F0 && rune <= 0x31FF)) {
      hasKana = true;
    } else if ((rune >= 0xAC00 && rune <= 0xD7AF) ||
        (rune >= 0x1100 && rune <= 0x11FF)) {
      hasHangul = true;
    } else if ((rune >= 0x4E00 && rune <= 0x9FFF) ||
        (rune >= 0x3400 && rune <= 0x4DBF)) {
      hasHan = true;
    } else if ((rune >= 0x41 && rune <= 0x5A) ||
        (rune >= 0x61 && rune <= 0x7A)) {
      hasLatin = true;
    }
  }
  if (language == 'ja' && (hasKana || (engine == 'ja' && isVertical))) {
    return engine;
  }
  if (language == 'ko' && hasHangul) return engine;
  if (language == 'en' && hasLatin && !hasHan) return engine;
  return null;
}

// ===========================================================================
// Main-isolate client
// ===========================================================================

/// Handle to the translation worker isolate. All heavy work — preprocessing,
/// ONNX inference (via the FFI binding), decoding loops — runs inside the
/// worker, so nothing here can jank the UI.
/// Pool of OCR worker isolates. All heavy work — preprocessing, ONNX inference,
/// decoding — runs inside a worker, so nothing here janks the UI. Concurrent
/// [ocrPage] calls fan out across workers instead of queuing on one, so the
/// reader's two in-flight pages and the pre-translation pipeline's overlapped
/// groups get real parallelism on multi-core devices.
class TranslationWorker {
  TranslationWorker._();

  static final instance = TranslationWorker._();

  final _workers = <_IsolateWorker>[];

  bool _isWarm = false;

  /// Whether a recognition request has already come back. Until it has, the
  /// next one also pays for loading the ONNX models into a fresh isolate —
  /// seconds on mobile — which the task list shows as its own stage rather
  /// than as a recognition step that appears to hang.
  bool get isWarm => _isWarm;

  int _poolSize(String sourceLang, WorkerModelPaths paths) {
    var n = TranslationPerformanceConfig.effective.ocrWorkers;
    return resolveOcrPoolSize(
      requested: n,
      processorCount: Platform.numberOfProcessors,
      isMobile: App.isMobile,
      isDesktop: App.isDesktop,
      sourceLang: sourceLang,
      hasJapaneseModel: paths.jaEncoder != null,
    );
  }

  Future<List<OcrBlock>> ocrPage(
    RgbaImage image, {
    required String sourceLang,
    required WorkerModelPaths paths,
  }) {
    var poolSize = _poolSize(sourceLang, paths);
    _trimIdleWorkers(poolSize);
    // Keep total ONNX intra-op threads ~= cores: dividing by the pool size
    // avoids oversubscribing the CPU (which would make more workers slower).
    var intraThreads = (Platform.numberOfProcessors ~/ poolSize).clamp(1, 4);
    var worker = _pickWorker(poolSize);
    return worker
        .ocrPage(
          image,
          sourceLang: sourceLang,
          paths: paths,
          intraThreads: intraThreads,
        )
        .whenComplete(() => _isWarm = true);
  }

  _IsolateWorker _pickWorker(int poolSize) {
    var eligibleCount = math.min(poolSize, _workers.length);
    // Prefer an idle existing worker — avoids spawning (and re-loading models
    // into) a new isolate when load is low.
    for (var w in _workers.take(eligibleCount)) {
      if (w.pendingCount == 0) return w;
    }
    // Under capacity and all busy: add a worker for more parallelism.
    if (eligibleCount < poolSize) {
      var worker = _IsolateWorker();
      _workers.insert(eligibleCount, worker);
      return worker;
    }
    // At capacity: dispatch to the least-busy worker.
    var idx = pickLeastBusyIndex([
      for (var w in _workers.take(poolSize)) w.pendingCount,
    ]);
    return _workers[idx];
  }

  void _trimIdleWorkers(int poolSize) {
    for (var i = _workers.length - 1; i >= poolSize; i--) {
      if (_workers[i].pendingCount != 0) continue;
      _workers.removeAt(i).dispose();
    }
  }

  /// Frees model memory in every worker (sessions re-create lazily).
  void release() {
    for (var w in _workers) {
      w.release();
    }
    // Sessions re-create lazily, so the next request pays the load again.
    _isWarm = false;
  }

  /// Kills all worker isolates; they restart lazily on the next request.
  void dispose() {
    for (var w in _workers) {
      w.dispose();
    }
    _workers.clear();
  }
}

/// A single OCR worker isolate. Owns its ONNX sessions (lazily loaded on first
/// request, so an unused worker costs no model memory).
class _IsolateWorker {
  Isolate? _isolate;
  SendPort? _sendPort;
  Future<void>? _starting;
  ReceivePort? _receivePort;
  final _pending = <int, Completer<Object?>>{};
  int _nextId = 0;

  int get pendingCount => _pending.length;

  Future<void> _ensureStarted() async {
    if (_sendPort != null) return;
    if (_starting != null) return _starting;
    var completer = Completer<void>();
    _starting = completer.future;
    var port = ReceivePort();
    _receivePort = port;
    port.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
        completer.complete();
      } else if (message is _WorkerResponse) {
        var pending = _pending.remove(message.id);
        if (pending == null) return;
        if (message.error != null) {
          pending.completeError(Exception(message.error));
        } else {
          pending.complete(message.result);
        }
      }
    });
    try {
      _isolate = await Isolate.spawn(
        _workerMain,
        port.sendPort,
        debugName: 'imageTranslationWorker',
      );
    } catch (e) {
      _starting = null;
      completer.completeError(e);
      rethrow;
    }
    await completer.future;
    _starting = null;
  }

  Future<T> _request<T>(Object Function(int id) build) async {
    await _ensureStarted();
    var id = _nextId++;
    var completer = Completer<Object?>();
    _pending[id] = completer;
    _sendPort!.send(build(id));
    return await completer.future as T;
  }

  Future<List<OcrBlock>> ocrPage(
    RgbaImage image, {
    required String sourceLang,
    required WorkerModelPaths paths,
    required int intraThreads,
  }) {
    return _request<List<OcrBlock>>(
      (id) => _OcrPageRequest(
        id,
        TransferableTypedData.fromList([image.pixels]),
        image.width,
        image.height,
        sourceLang,
        paths,
        intraThreads,
      ),
    );
  }

  void release() {
    _sendPort?.send(const _ReleaseRequest());
  }

  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _starting = null;
    _receivePort?.close();
    _receivePort = null;
    for (var pending in _pending.values) {
      pending.completeError(Exception('Translation worker disposed'));
    }
    _pending.clear();
  }
}

// ===========================================================================
// Worker isolate
// ===========================================================================

void _workerMain(SendPort mainPort) {
  var port = ReceivePort();
  mainPort.send(port.sendPort);
  var state = _WorkerState();
  port.listen((message) {
    if (message is _OcrPageRequest) {
      try {
        var blocks = state.ocrPage(message);
        mainPort.send(_WorkerResponse(message.id, blocks, null));
      } catch (e, s) {
        mainPort.send(_WorkerResponse(message.id, null, '$e\n$s'));
      }
    } else if (message is _ReleaseRequest) {
      state.release();
    }
  });
}

class _WorkerState {
  final _sessions = <String, OrtFfiSession>{};
  final _charsets = <String, List<String>>{};
  WordPieceVocab? _jaVocab;
  int _intraThreads = 2;

  OrtFfiSession _session(String path) {
    return _sessions.putIfAbsent(
      path,
      () => OrtFfiSession.open(path, intraOpThreads: _intraThreads),
    );
  }

  void release() {
    for (var session in _sessions.values) {
      session.close();
    }
    _sessions.clear();
    _jaVocab = null;
  }

  // -------------------------------------------------------------------------
  // OCR page
  // -------------------------------------------------------------------------

  List<OcrBlock> ocrPage(_OcrPageRequest req) {
    _intraThreads = req.intraThreads;
    var image = RgbaImage(
      req.width,
      req.height,
      req.pixels.materialize().asUint8List(),
    );
    var boxes = _detectBoxes(image, req.paths);
    if (boxes.isEmpty) return const [];
    var clusters = clusterOcrBoxes(boxes, image.width, image.height);
    clusters.sort((a, b) => _boundsOf(a).top.compareTo(_boundsOf(b).top));
    const maxBlocks = 32;
    if (clusters.length > maxBlocks) {
      clusters = clusters.sublist(0, maxBlocks);
    }

    var blocks = <OcrBlock>[];
    var pageHint = OcrPageEngineHint();
    for (var cluster in clusters) {
      var detectedBounds = _boundsOf(cluster);
      var eraseBounds = detectedBounds.inflated(
        2,
        2,
        image.width,
        image.height,
      );
      // DBNet already expands each component in post-processing. Keep the
      // individual line boxes tight; the inpainter adds its own tiny glyph
      // guard and must not reach into artwork between lines.
      var eraseLines = [
        for (var line in cluster)
          line.inflated(0, 0, image.width, image.height),
      ];
      var bounds = detectedBounds.inflated(4, 4, image.width, image.height);
      if (bounds.width < 8 || bounds.height < 8) continue;
      var colors = _sampleColors(image, bounds);
      var recognized = _recognizeBlock(
        image,
        cluster,
        bounds,
        req,
        preferredEngine: pageHint.preferredEngine,
      );
      var text = recognized.text;
      var lang = recognized.language;
      text = text.trim();
      if (text.isEmpty) continue;
      if (req.sourceLang == 'auto') {
        pageHint.observe(
          text: text,
          language: lang,
          engine: recognized.engine,
          isVertical: bounds.height > bounds.width * 1.3,
        );
      }
      // Median line height across the cluster's line boxes ≈ the original
      // glyph height, so the renderer can size the translation to match the
      // source text instead of stretching it to fill the (often much taller)
      // detected block box — a short line in a tall box otherwise ballooned.
      var lineHeight = _medianLineHeight(cluster);
      blocks.add(
        OcrBlock(
          rect: bounds,
          eraseRect: eraseBounds,
          eraseRects: eraseLines,
          text: text,
          language: lang,
          backgroundColor: colors.$1,
          textColor: colors.$2,
          lineHeight: lineHeight,
        ),
      );
    }
    return blocks;
  }

  /// Median height of a cluster's line boxes — an estimate of the original
  /// glyph height, used to size the translation to the source text.
  int _medianLineHeight(List<IntRect> lines) {
    if (lines.isEmpty) return 0;
    var heights = [for (var l in lines) l.height]..sort();
    return heights[heights.length ~/ 2];
  }

  /// OCR one block. In 'auto' mode a vertical block prefers the Japanese
  /// engine and horizontal blocks try the installed engines in order until
  /// one produces plausible text; the language is then derived from the
  /// recognized script.
  ({String text, String language, String engine}) _recognizeBlock(
    RgbaImage image,
    List<IntRect> lines,
    IntRect bounds,
    _OcrPageRequest req, {
    String? preferredEngine,
  }) {
    var paths = req.paths;
    var hasJa = paths.jaEncoder != null;

    List<String> engineOrder;
    if (req.sourceLang != 'auto') {
      engineOrder = paths.engines;
    } else {
      var vertical = bounds.height > bounds.width * 1.3;
      engineOrder = <String>{
        if (preferredEngine != null) preferredEngine,
        if (vertical && hasJa) 'ja',
        ...paths.engines,
        if (!vertical && hasJa) 'ja',
      }.toList();
    }

    for (var engine in engineOrder) {
      String text;
      if (engine == 'ja') {
        if (!hasJa) continue;
        text = _mangaOcr(image, bounds, paths);
      } else {
        if (!paths.recModels.containsKey(engine)) continue;
        text = _recognizeLines(image, lines, engine, paths);
      }
      text = text.trim();
      if (_isPlausible(text)) {
        var engineLang = engine == 'ja'
            ? 'ja'
            : paths.recLanguages[engine] ?? engine;
        return (
          text: text,
          language: detectBlockLanguage(text, engineLang),
          engine: engine,
        );
      }
    }
    // No engine produced plausible text: return empty so the block is dropped
    // rather than emitting garbled OCR — that region then shows the original
    // art untouched (no erase, no lettering) instead of a mistranslation.
    return (text: '', language: 'unknown', engine: 'unknown');
  }

  bool _isPlausible(String text) {
    if (text.length < 2) return false;
    var meaningful = text.runes
        .where(
          (r) => r > 0x2E80 || (r >= 0x30 && r <= 0x7A) || isScriptLetter(r),
        )
        .length;
    return meaningful >= math.max(2, text.length ~/ 2);
  }

  // ----- detection -----

  List<IntRect> _detectBoxes(RgbaImage image, WorkerModelPaths paths) {
    var session = _session(paths.detector);
    var boxes = <IntRect>[];
    const tileHeight = 1280;
    const tileOverlap = 128;
    var top = 0;
    while (top < image.height) {
      var bottom = math.min(image.height, top + tileHeight);
      var tile = RgbaImage(
        image.width,
        bottom - top,
        Uint8List.sublistView(
          image.pixels,
          top * image.width * 4,
          bottom * image.width * 4,
        ),
      );
      var input = _detPreprocess(tile);
      var output = session
          .run({
            session.inputNames.first: OrtInput.float32(input.tensor, [
              1,
              3,
              input.height,
              input.width,
            ]),
          })
          .values
          .first;
      var tileBoxes = _detPostprocess(
        output.data,
        input.width,
        input.height,
        tile.width,
        tile.height,
      );
      for (var box in tileBoxes) {
        box.top += top;
        box.bottom += top;
        if (!boxes.any((b) => _iou(b, box) > 0.5)) {
          boxes.add(box);
        }
      }
      if (bottom >= image.height) break;
      top = bottom - tileOverlap;
    }
    return boxes;
  }

  // ----- Japanese OCR (manga-ocr) -----

  String _mangaOcr(RgbaImage image, IntRect bounds, WorkerModelPaths paths) {
    _jaVocab ??= WordPieceVocab.fromFileSync(paths.jaVocab!);
    var encoder = _session(paths.jaEncoder!);
    var decoder = _session(paths.jaDecoder!);
    var pixels = _cropNormalized(image, bounds, 224, 224);
    var hidden = encoder
        .run({
          encoder.inputNames.first: OrtInput.float32(pixels, const [
            1,
            3,
            224,
            224,
          ]),
        })
        .values
        .first;

    const startToken = 2;
    const eosToken = 3;
    const maxTokens = 80;
    var ids = <int>[startToken];
    while (ids.length < maxTokens) {
      var next = decoder.runArgmaxLastRow({
        'input_ids': OrtInput.int64(Int64List.fromList(ids), [1, ids.length]),
        'encoder_hidden_states': OrtInput.float32(hidden.data, hidden.shape),
      }, decoder.outputNames.first);
      if (next == eosToken) break;
      ids.add(next);
      // Greedy decoding can fall into repetition loops on hard crops
      // (stylized fonts, screentone backgrounds), which came out as garbage
      // strings. Cut the sequence when the tail starts repeating.
      if (_hasRepetitionLoop(ids)) {
        ids.removeRange(ids.length - 3, ids.length);
        break;
      }
    }
    return _jaVocab!.decode(ids.sublist(1));
  }

  /// True when the tail of [ids] repeats: the same trigram twice in a row,
  /// or four identical tokens.
  bool _hasRepetitionLoop(List<int> ids) {
    var n = ids.length;
    if (n >= 4 &&
        ids[n - 1] == ids[n - 2] &&
        ids[n - 2] == ids[n - 3] &&
        ids[n - 3] == ids[n - 4]) {
      return true;
    }
    if (n >= 6) {
      var repeated = true;
      for (var i = 0; i < 3; i++) {
        if (ids[n - 1 - i] != ids[n - 4 - i]) {
          repeated = false;
          break;
        }
      }
      if (repeated) return true;
    }
    return false;
  }

  // ----- Line OCR (PP-OCR CTC) -----

  String _recognizeLines(
    RgbaImage image,
    List<IntRect> lines,
    String lang,
    WorkerModelPaths paths,
  ) {
    var modelPath = paths.recModels[lang]!;
    var session = _session(modelPath);
    var charset = _charsets.putIfAbsent(lang, () {
      var dict = File(paths.recDicts[lang]!).readAsLinesSync();
      return ['', ...dict.map((line) => line.isEmpty ? ' ' : line), ' '];
    });
    var height = paths.recHeights[lang] ?? 48;
    // Vertical columns read right to left; horizontal lines top to bottom.
    var vertical = lines.any(_isVerticalLine);
    var sorted = [...lines]
      ..sort(
        (a, b) => vertical
            ? b.right.compareTo(a.right)
            : a.top.compareTo(b.top),
      );
    var parts = <String>[];
    for (var line in sorted) {
      var rect = line.inflated(2, 2, image.width, image.height);
      if (rect.width < 8 || rect.height < 8) continue;
      // The line models read left to right only: a column squeezed to one
      // line height came out empty. Turned 90° counter-clockwise, its top
      // glyph lands on the left, the way PP-OCR itself feeds vertical text.
      var rotate = _isVerticalLine(rect);
      var runLength = rotate ? rect.height : rect.width;
      var thickness = rotate ? rect.width : rect.height;
      var outW = (runLength * height / math.max(1, thickness)).round().clamp(
        16,
        960,
      );
      outW = (outW / 8).ceil() * 8;
      var tensor = _normalize(
        resizeTextLine(image, rect, outW, height, rotate: rotate),
        outW,
        height,
      );
      var output = session
          .run({
            session.inputNames.first: OrtInput.float32(tensor, [
              1,
              3,
              height,
              outW,
            ]),
          })
          .values
          .first;
      var text = _ctcDecode(output.data, output.shape.last, charset);
      if (text.trim().isNotEmpty) {
        parts.add(text.trim());
      }
    }
    return parts.join(' ');
  }

  String _ctcDecode(Float32List probs, int classes, List<String> charset) {
    var steps = probs.length ~/ classes;
    var buffer = StringBuffer();
    var prev = 0;
    for (var t = 0; t < steps; t++) {
      var best = 0;
      var bestScore = probs[t * classes];
      for (var c = 1; c < classes; c++) {
        var score = probs[t * classes + c];
        if (score > bestScore) {
          bestScore = score;
          best = c;
        }
      }
      if (best != 0 && best != prev && best < charset.length) {
        buffer.write(charset[best]);
      }
      prev = best;
    }
    return buffer.toString().trim();
  }
}

// ===========================================================================
// Pure image math (worker side)
// ===========================================================================

class _DetInput {
  _DetInput(this.tensor, this.width, this.height);

  final Float32List tensor;
  final int width;
  final int height;
}

Uint8List _resizeRegion(RgbaImage src, IntRect region, int outW, int outH) {
  var out = Uint8List(outW * outH * 4);
  var srcW = region.width;
  var srcH = region.height;
  for (var y = 0; y < outH; y++) {
    var fy = (y + 0.5) * srcH / outH - 0.5;
    var y0 = fy.floor().clamp(0, srcH - 1);
    var y1 = (y0 + 1).clamp(0, srcH - 1);
    var wy = fy - fy.floor();
    for (var x = 0; x < outW; x++) {
      var fx = (x + 0.5) * srcW / outW - 0.5;
      var x0 = fx.floor().clamp(0, srcW - 1);
      var x1 = (x0 + 1).clamp(0, srcW - 1);
      var wx = fx - fx.floor();
      var outIndex = (y * outW + x) * 4;
      for (var c = 0; c < 4; c++) {
        var p00 = src
            .pixels[((region.top + y0) * src.width + region.left + x0) * 4 + c];
        var p01 = src
            .pixels[((region.top + y0) * src.width + region.left + x1) * 4 + c];
        var p10 = src
            .pixels[((region.top + y1) * src.width + region.left + x0) * 4 + c];
        var p11 = src
            .pixels[((region.top + y1) * src.width + region.left + x1) * 4 + c];
        var top = p00 + (p01 - p00) * wx;
        var bottom = p10 + (p11 - p10) * wx;
        out[outIndex + c] = (top + (bottom - top) * wy).round().clamp(0, 255);
      }
    }
  }
  return out;
}

/// PP-OCR DBNet preprocessing: long side <= 1280 (small/stylized lettering
/// survives better than at the stock 960), multiple of 32, ImageNet
/// normalization.
_DetInput _detPreprocess(RgbaImage tile) {
  const maxSide = 1280.0;
  var scale = math.min(1.0, maxSide / math.max(tile.width, tile.height));
  int round32(double v) => math.max(32, (v / 32).round() * 32);
  var inW = round32(tile.width * scale);
  var inH = round32(tile.height * scale);
  var resized = _resizeRegion(
    tile,
    IntRect(0, 0, tile.width, tile.height),
    inW,
    inH,
  );
  const mean = [0.485, 0.456, 0.406];
  const std = [0.229, 0.224, 0.225];
  var tensor = Float32List(3 * inH * inW);
  var plane = inH * inW;
  for (var i = 0; i < plane; i++) {
    for (var c = 0; c < 3; c++) {
      tensor[c * plane + i] = (resized[i * 4 + c] / 255.0 - mean[c]) / std[c];
    }
  }
  return _DetInput(tensor, inW, inH);
}

/// DBNet postprocessing: binarize, connected components, filter, dilate.
List<IntRect> _detPostprocess(
  Float32List probs,
  int w,
  int h,
  int tileWidth,
  int tileHeight,
) {
  const binaryThreshold = 0.3;
  const scoreThreshold = 0.5;
  const unclipRatio = 1.8;
  var labels = Int32List(w * h);
  var boxes = <IntRect>[];
  var stack = <int>[];
  var nextLabel = 0;
  for (var start = 0; start < w * h; start++) {
    if (labels[start] != 0 || probs[start] < binaryThreshold) {
      continue;
    }
    nextLabel++;
    var minX = w, minY = h, maxX = 0, maxY = 0;
    var count = 0;
    var scoreSum = 0.0;
    stack.add(start);
    labels[start] = nextLabel;
    while (stack.isNotEmpty) {
      var index = stack.removeLast();
      var x = index % w;
      var y = index ~/ w;
      count++;
      scoreSum += probs[index];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
      for (var d = 0; d < 4; d++) {
        var nx = x + const [1, -1, 0, 0][d];
        var ny = y + const [0, 0, 1, -1][d];
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        var ni = ny * w + nx;
        if (labels[ni] == 0 && probs[ni] >= binaryThreshold) {
          labels[ni] = nextLabel;
          stack.add(ni);
        }
      }
    }
    if (count < 12 || scoreSum / count < scoreThreshold) {
      continue;
    }
    var boxW = maxX - minX + 1;
    var boxH = maxY - minY + 1;
    if (boxW < 3 || boxH < 3) continue;
    var offset = boxW * boxH * unclipRatio / (2 * (boxW + boxH));
    var scaleX = tileWidth / w;
    var scaleY = tileHeight / h;
    boxes.add(
      IntRect(
        ((minX - offset) * scaleX).round(),
        ((minY - offset) * scaleY).round(),
        ((maxX + 1 + offset) * scaleX).round(),
        ((minY - offset) * scaleY).round() +
            ((boxH + 2 * offset) * scaleY).round(),
      ),
    );
  }
  return boxes;
}

/// Groups detector line boxes into OCR blocks without joining incompatible
/// neighbouring captions or speech bubbles.
List<List<IntRect>> clusterOcrBoxes(
  List<IntRect> boxes,
  int width,
  int height,
) {
  var parents = List<int>.generate(boxes.length, (i) => i);
  var minThickness = [for (var box in boxes) math.min(box.width, box.height)];
  var maxThickness = [...minThickness];
  var hasHorizontal = [for (var box in boxes) _lineDirection(box) > 0];
  var hasVertical = [for (var box in boxes) _lineDirection(box) < 0];
  var members = [
    for (var i = 0; i < boxes.length; i++) <int>[i],
  ];
  int find(int i) {
    while (parents[i] != i) {
      parents[i] = parents[parents[i]];
      i = parents[i];
    }
    return i;
  }

  var inflated = [
    for (var box in boxes)
      // Inflation controls when neighbouring lines merge into one block.
      // Too generous and two adjacent speech bubbles fuse — the combined
      // crop then squashes both into one OCR input and recognition degrades
      // badly. 0.55 of the short side still bridges the gaps between lines
      // and vertical columns inside one bubble.
      box.inflated(
        (math.min(box.width, box.height) * 0.55).round().clamp(3, 32),
        (math.min(box.width, box.height) * 0.55).round().clamp(3, 32),
        width,
        height,
      ),
  ];
  for (var i = 0; i < boxes.length; i++) {
    for (var j = i + 1; j < boxes.length; j++) {
      if (inflated[i].intersects(inflated[j]) &&
          _compatibleTextLines(boxes[i], boxes[j])) {
        var rootI = find(i);
        var rootJ = find(j);
        if (rootI == rootJ) continue;
        var mergedHorizontal = hasHorizontal[rootI] || hasHorizontal[rootJ];
        var mergedVertical = hasVertical[rootI] || hasVertical[rootJ];
        var mergedMin = math.min(minThickness[rootI], minThickness[rootJ]);
        var mergedMax = math.max(maxThickness[rootI], maxThickness[rootJ]);
        if ((mergedHorizontal && mergedVertical) ||
            mergedMax > math.max(1, mergedMin) * 2.2) {
          continue;
        }
        var direction = mergedHorizontal
            ? 1
            : mergedVertical
            ? -1
            : 0;
        if (!_compatibleTextGroups(
          members[rootI],
          members[rootJ],
          boxes,
          direction,
        )) {
          continue;
        }
        parents[rootJ] = rootI;
        members[rootI].addAll(members[rootJ]);
        minThickness[rootI] = mergedMin;
        maxThickness[rootI] = mergedMax;
        hasHorizontal[rootI] = mergedHorizontal;
        hasVertical[rootI] = mergedVertical;
      }
    }
  }
  var groups = <int, List<IntRect>>{};
  for (var i = 0; i < boxes.length; i++) {
    groups.putIfAbsent(find(i), () => []).add(boxes[i]);
  }
  return groups.values.toList();
}

int _lineDirection(IntRect box) {
  if (box.width >= box.height * 1.25) return 1;
  if (box.height >= box.width * 1.25) return -1;
  return 0;
}

bool _compatibleTextLines(IntRect a, IntRect b) {
  var directionA = _lineDirection(a);
  var directionB = _lineDirection(b);
  if (directionA != 0 && directionB != 0 && directionA != directionB) {
    return false;
  }

  var thicknessA = math.min(a.width, a.height);
  var thicknessB = math.min(b.width, b.height);
  if (math.max(thicknessA, thicknessB) >
      math.max(1, math.min(thicknessA, thicknessB)) * 2.2) {
    return false;
  }

  var direction = directionA != 0 ? directionA : directionB;
  if (direction > 0) {
    var stacked =
        _axisOverlap(a.left, a.right, b.left, b.right) >=
        math.min(a.width, b.width) * 0.25;
    var shortFragments =
        a.width <= thicknessA * 12 && b.width <= thicknessB * 12;
    var sameLine =
        shortFragments &&
        _axisOverlap(a.top, a.bottom, b.top, b.bottom) >=
            math.min(a.height, b.height) * 0.6 &&
        _axisGap(a.left, a.right, b.left, b.right) <=
            _sameLineGap(thicknessA, thicknessB);
    return stacked || sameLine;
  }
  if (direction < 0) {
    var adjacentColumns =
        _axisOverlap(a.top, a.bottom, b.top, b.bottom) >=
        math.min(a.height, b.height) * 0.25;
    var shortFragments =
        a.height <= thicknessA * 12 && b.height <= thicknessB * 12;
    var sameColumn =
        shortFragments &&
        _axisOverlap(a.left, a.right, b.left, b.right) >=
            math.min(a.width, b.width) * 0.6 &&
        _axisGap(a.top, a.bottom, b.top, b.bottom) <=
            _sameLineGap(thicknessA, thicknessB);
    return adjacentColumns || sameColumn;
  }
  return true;
}

bool _compatibleTextGroups(
  List<int> groupA,
  List<int> groupB,
  List<IntRect> boxes,
  int direction,
) {
  for (var indexA in groupA) {
    for (var indexB in groupB) {
      var a = boxes[indexA];
      var b = boxes[indexB];
      if (direction > 0) {
        var sameLine =
            _axisOverlap(a.top, a.bottom, b.top, b.bottom) >=
            math.min(a.height, b.height) * 0.6;
        if (!sameLine &&
            _axisOverlap(a.left, a.right, b.left, b.right) <
                math.min(a.width, b.width) * 0.25) {
          return false;
        }
      } else if (direction < 0) {
        var sameColumn =
            _axisOverlap(a.left, a.right, b.left, b.right) >=
            math.min(a.width, b.width) * 0.6;
        if (!sameColumn &&
            _axisOverlap(a.top, a.bottom, b.top, b.bottom) <
                math.min(a.height, b.height) * 0.25) {
          return false;
        }
      } else if (!_compatibleTextLines(a, b)) {
        return false;
      }
    }
  }
  return true;
}

int _axisOverlap(int startA, int endA, int startB, int endB) =>
    math.max(0, math.min(endA, endB) - math.max(startA, startB));

int _axisGap(int startA, int endA, int startB, int endB) =>
    math.max(0, math.max(startA, startB) - math.min(endA, endB));

/// Largest run-direction gap two fragments of one line may have. Word spacing
/// and detector splits routinely leave most of a glyph height between pieces,
/// so this sits close to the line thickness rather than well below it.
double _sameLineGap(int thicknessA, int thicknessB) =>
    math.max(thicknessA, thicknessB) * 0.8;

IntRect _boundsOf(List<IntRect> boxes) {
  var result = IntRect(
    boxes[0].left,
    boxes[0].top,
    boxes[0].right,
    boxes[0].bottom,
  );
  for (var box in boxes.skip(1)) {
    result.left = math.min(result.left, box.left);
    result.top = math.min(result.top, box.top);
    result.right = math.max(result.right, box.right);
    result.bottom = math.max(result.bottom, box.bottom);
  }
  return result;
}

/// A detected line taller than wide by PP-OCR's own margin: a vertical column.
bool _isVerticalLine(IntRect r) => r.height >= r.width * 1.5;

/// Resamples [region] to [outW]x[outH] RGBA. With [rotate] the region is
/// turned 90° counter-clockwise first, so a vertical column reads left to
/// right with its top glyph first.
@visibleForTesting
Uint8List resizeTextLine(
  RgbaImage src,
  IntRect region,
  int outW,
  int outH, {
  bool rotate = false,
}) {
  if (!rotate) return _resizeRegion(src, region, outW, outH);
  var out = Uint8List(outW * outH * 4);
  var srcW = region.width;
  var srcH = region.height;
  for (var y = 0; y < outH; y++) {
    // Output rows walk the source columns from right to left.
    var fx = srcW - 0.5 - (y + 0.5) * srcW / outH;
    var x0 = fx.floor().clamp(0, srcW - 1);
    var x1 = (x0 + 1).clamp(0, srcW - 1);
    var wx = fx - fx.floor();
    for (var x = 0; x < outW; x++) {
      // Output columns walk the source rows from top to bottom.
      var fy = (x + 0.5) * srcH / outW - 0.5;
      var y0 = fy.floor().clamp(0, srcH - 1);
      var y1 = (y0 + 1).clamp(0, srcH - 1);
      var wy = fy - fy.floor();
      var outIndex = (y * outW + x) * 4;
      for (var c = 0; c < 4; c++) {
        int px(int sy, int sx) =>
            src.pixels[((region.top + sy) * src.width + region.left + sx) * 4 +
                c];
        var top = px(y0, x0) + (px(y0, x1) - px(y0, x0)) * wx;
        var bottom = px(y1, x0) + (px(y1, x1) - px(y1, x0)) * wx;
        out[outIndex + c] = (top + (bottom - top) * wy).round().clamp(0, 255);
      }
    }
  }
  return out;
}

/// Crops a region and normalizes to (x/255 - 0.5) / 0.5, CHW.
Float32List _cropNormalized(RgbaImage image, IntRect rect, int outW, int outH) {
  return _normalize(_resizeRegion(image, rect, outW, outH), outW, outH);
}

Float32List _normalize(Uint8List resized, int outW, int outH) {
  var tensor = Float32List(3 * outH * outW);
  var plane = outH * outW;
  for (var i = 0; i < plane; i++) {
    for (var c = 0; c < 3; c++) {
      tensor[c * plane + i] = (resized[i * 4 + c] / 255.0 - 0.5) / 0.5;
    }
  }
  return tensor;
}

/// Estimates (backgroundColor, textColor) for a region by separating the two
/// dominant colour classes inside it.
///
/// The block's pixels split into a background class (bubble fill, the larger
/// share) and a text class (the strokes). An Otsu luminance threshold labels
/// each pixel, then the mean colour of each class is taken — so the text colour
/// is the *actual* ink (a coloured SFX, a grey caption) rather than a flat
/// dark/light guess, and the background is the *actual* fill sampled from the
/// non-stroke pixels rather than a ring outside the box that may fall on
/// artwork. A ring sample still seeds the background when the split is
/// degenerate (near-uniform crop), and the returned text colour is nudged to
/// keep a minimum contrast against the background so it stays legible.
(int, int) _sampleColors(RgbaImage image, IntRect rect) {
  var w = image.width;
  var left = rect.left.clamp(0, w - 1);
  var top = rect.top.clamp(0, image.height - 1);
  var right = rect.right.clamp(1, w);
  var bottom = rect.bottom.clamp(1, image.height);
  var pixels = image.pixels;

  // Stride so a big block stays cheap; small blocks read every pixel.
  var stepX = math.max(1, (right - left) ~/ 48);
  var stepY = math.max(1, (bottom - top) ~/ 48);

  var lum = <int>[];
  var pr = <int>[], pg = <int>[], pb = <int>[];
  for (var y = top; y < bottom; y += stepY) {
    for (var x = left; x < right; x += stepX) {
      var i = (y * w + x) * 4;
      var r = pixels[i], g = pixels[i + 1], b = pixels[i + 2];
      pr.add(r);
      pg.add(g);
      pb.add(b);
      lum.add((0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255));
    }
  }

  int ringMedianColor() {
    var ring = rect.inflated(6, 6, w, image.height);
    var rs = <int>[], gs = <int>[], bs = <int>[];
    void s(int x, int y) {
      var i = (y * w + x) * 4;
      rs.add(pixels[i]);
      gs.add(pixels[i + 1]);
      bs.add(pixels[i + 2]);
    }

    for (var x = ring.left; x < ring.right; x += 3) {
      s(x, ring.top);
      s(x, ring.bottom - 1);
    }
    for (var y = ring.top; y < ring.bottom; y += 3) {
      s(ring.left, y);
      s(ring.right - 1, y);
    }
    int med(List<int> v) {
      if (v.isEmpty) return 255;
      v.sort();
      return v[v.length ~/ 2];
    }

    return 0xFF000000 | (med(rs) << 16) | (med(gs) << 8) | med(bs);
  }

  if (lum.length < 8) {
    var bg = ringMedianColor();
    var bgLum =
        0.299 * ((bg >> 16) & 0xFF) +
        0.587 * ((bg >> 8) & 0xFF) +
        0.114 * (bg & 0xFF);
    return (bg, bgLum < 128 ? 0xFFF5F5F5 : 0xFF202020);
  }

  var threshold = _otsuOf(lum);
  var loSumR = 0, loSumG = 0, loSumB = 0, loN = 0;
  var hiSumR = 0, hiSumG = 0, hiSumB = 0, hiN = 0;
  for (var i = 0; i < lum.length; i++) {
    if (lum[i] <= threshold) {
      loSumR += pr[i];
      loSumG += pg[i];
      loSumB += pb[i];
      loN++;
    } else {
      hiSumR += pr[i];
      hiSumG += pg[i];
      hiSumB += pb[i];
      hiN++;
    }
  }

  // The background is the larger class; text is the smaller. A block that is
  // almost entirely one class (no real strokes visible) falls back to the ring.
  if (loN == 0 || hiN == 0) {
    var bg = ringMedianColor();
    var bgLum =
        0.299 * ((bg >> 16) & 0xFF) +
        0.587 * ((bg >> 8) & 0xFF) +
        0.114 * (bg & 0xFF);
    return (bg, bgLum < 128 ? 0xFFF5F5F5 : 0xFF202020);
  }

  int packMean(int sr, int sg, int sb, int n) =>
      0xFF000000 | ((sr ~/ n) << 16) | ((sg ~/ n) << 8) | (sb ~/ n);
  var loColor = packMean(loSumR, loSumG, loSumB, loN);
  var hiColor = packMean(hiSumR, hiSumG, hiSumB, hiN);

  // Background = majority class, text = minority class.
  int bgColor, textColor;
  if (loN >= hiN) {
    bgColor = loColor;
    textColor = hiColor;
  } else {
    bgColor = hiColor;
    textColor = loColor;
  }

  textColor = _ensureContrast(textColor, bgColor);
  return (bgColor, textColor);
}

/// Otsu threshold over a luminance sample list (worker-side twin of the one in
/// inpaint.dart, which takes a Uint8List).
int _otsuOf(List<int> lum) {
  var hist = Int32List(256);
  for (var l in lum) {
    hist[l]++;
  }
  var total = lum.length;
  var sum = 0.0;
  for (var t = 0; t < 256; t++) {
    sum += t * hist[t];
  }
  var sumB = 0.0;
  var wB = 0;
  var maxVar = -1.0;
  var threshold = 127;
  for (var t = 0; t < 256; t++) {
    wB += hist[t];
    if (wB == 0) continue;
    var wF = total - wB;
    if (wF == 0) break;
    sumB += t * hist[t];
    var mB = sumB / wB;
    var mF = (sum - sumB) / wF;
    var between = wB * wF * (mB - mF) * (mB - mF);
    if (between > maxVar) {
      maxVar = between;
      threshold = t;
    }
  }
  return threshold;
}

/// Nudges [text] away from [bg] when their luminance is too close, so the drawn
/// text stays readable. Keeps [text]'s hue, only pushing it darker or lighter.
int _ensureContrast(int text, int bg) {
  double lumOf(int c) =>
      0.299 * ((c >> 16) & 0xFF) +
      0.587 * ((c >> 8) & 0xFF) +
      0.114 * (c & 0xFF);
  var tl = lumOf(text);
  var bl = lumOf(bg);
  if ((tl - bl).abs() >= 60) return text;
  // Too close: fall back to a high-contrast neutral against the background.
  return bl < 128 ? 0xFFF5F5F5 : 0xFF202020;
}

double _iou(IntRect a, IntRect b) {
  var left = math.max(a.left, b.left);
  var top = math.max(a.top, b.top);
  var right = math.min(a.right, b.right);
  var bottom = math.min(a.bottom, b.bottom);
  if (left >= right || top >= bottom) return 0;
  var inter = (right - left) * (bottom - top);
  return inter / (a.area + b.area - inter);
}
