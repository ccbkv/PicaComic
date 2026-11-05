import 'dart:convert';

import 'package:unorm_dart/unorm_dart.dart' as unorm;
import 'package:pica_comic/utils/io.dart';

/// Minimal reader for HuggingFace `tokenizer.json` files, covering the
/// SentencePiece-style models used by the offline translation pipeline
/// (Metaspace pre-tokenization with either BPE merges or Unigram pieces).
///
/// Only what the pipeline needs is implemented: encode to ids, decode ids to
/// text, and lookup of special/added tokens (language codes, eos, ...).
class HfTokenizer {
  HfTokenizer._({
    required Map<String, int> vocab,
    required Map<String, int> mergeRanks,
    required List<double> scores,
    required Map<String, int> addedTokens,
    required Set<int> specialIds,
    required this.unkId,
    required bool isUnigram,
  }) : _vocab = vocab,
       _mergeRanks = mergeRanks,
       _scores = scores,
       _addedTokens = addedTokens,
       _specialIds = specialIds,
       _isUnigram = isUnigram {
    _idToToken = <int, String>{};
    _vocab.forEach((token, id) => _idToToken[id] = token);
    _addedTokens.forEach((token, id) => _idToToken[id] = token);
  }

  final Map<String, int> _vocab;
  final Map<String, int> _mergeRanks;
  final List<double> _scores;
  final Map<String, int> _addedTokens;
  final Set<int> _specialIds;
  final int unkId;
  final bool _isUnigram;
  late final Map<int, String> _idToToken;

  static const _metaspace = '▁';

  /// Synchronous load, meant to run inside a background isolate (the
  /// translator's tokenizer.json is ~17MB; parsing it on the UI isolate
  /// would freeze the app for a second or more).
  static HfTokenizer loadSync(String path) {
    var json = jsonDecode(File(path).readAsStringSync());
    var model = json['model'] as Map<String, dynamic>;
    var type = model['type'] as String? ?? 'BPE';

    var vocab = <String, int>{};
    var scores = <double>[];
    var isUnigram = type == 'Unigram';
    if (isUnigram) {
      var pieces = model['vocab'] as List;
      for (var i = 0; i < pieces.length; i++) {
        var piece = pieces[i] as List;
        vocab[piece[0] as String] = i;
        scores.add((piece[1] as num).toDouble());
      }
    } else {
      (model['vocab'] as Map<String, dynamic>).forEach((token, id) {
        vocab[token] = id as int;
      });
    }

    var mergeRanks = <String, int>{};
    var merges = model['merges'];
    if (merges is List) {
      for (var i = 0; i < merges.length; i++) {
        var merge = merges[i];
        // Both historical formats: "a b" strings and ["a", "b"] pairs.
        var key = merge is List ? '${merge[0]} ${merge[1]}' : merge as String;
        mergeRanks[key] = i;
      }
    }

    var addedTokens = <String, int>{};
    var specialIds = <int>{};
    for (var token in (json['added_tokens'] as List? ?? const [])) {
      addedTokens[token['content'] as String] = token['id'] as int;
      if (token['special'] == true) {
        specialIds.add(token['id'] as int);
      }
    }

    var unkId =
        (model['unk_id'] as int?) ??
        vocab['<unk>'] ??
        addedTokens['<unk>'] ??
        0;

    return HfTokenizer._(
      vocab: vocab,
      mergeRanks: mergeRanks,
      scores: scores,
      addedTokens: addedTokens,
      specialIds: specialIds,
      unkId: unkId,
      isUnigram: isUnigram,
    );
  }

  /// Id of an added/special token such as `__zh__` or `</s>`.
  int? tokenId(String token) => _addedTokens[token] ?? _vocab[token];

  /// Encodes plain text (no special tokens added).
  List<int> encode(String text) {
    // SentencePiece models are exported with an NFKC-style normalizer;
    // NFKC + whitespace collapsing is a close, dependency-light match.
    text = unorm.nfkc(text).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return const [];
    var ids = <int>[];
    // Metaspace: spaces become the marker and the first word gets a prefix.
    var words = text.split(' ');
    for (var word in words) {
      if (word.isEmpty) continue;
      var piece = '$_metaspace$word';
      if (_isUnigram) {
        ids.addAll(_encodeUnigram(piece));
      } else {
        ids.addAll(_encodeBpe(piece));
      }
    }
    return ids;
  }

  List<int> _encodeBpe(String word) {
    var chars = word.runes.map(String.fromCharCode).toList();
    if (chars.isEmpty) return const [];
    // Repeatedly apply the lowest-ranked merge until none applies.
    while (chars.length > 1) {
      var bestRank = -1;
      var bestIndex = -1;
      for (var i = 0; i < chars.length - 1; i++) {
        var rank = _mergeRanks['${chars[i]} ${chars[i + 1]}'];
        if (rank != null && (bestRank == -1 || rank < bestRank)) {
          bestRank = rank;
          bestIndex = i;
        }
      }
      if (bestIndex == -1) break;
      chars[bestIndex] = chars[bestIndex] + chars[bestIndex + 1];
      chars.removeAt(bestIndex + 1);
    }
    return [for (var token in chars) _vocab[token] ?? unkId];
  }

  List<int> _encodeUnigram(String word) {
    var chars = word.runes.map(String.fromCharCode).toList();
    var n = chars.length;
    if (n == 0) return const [];
    const unkScore = -100.0;
    var bestScore = List<double>.filled(n + 1, double.negativeInfinity);
    var bestStart = List<int>.filled(n + 1, -1);
    var bestId = List<int>.filled(n + 1, unkId);
    bestScore[0] = 0;
    for (var end = 1; end <= n; end++) {
      // Pieces are rarely longer than 16 chars; bounding the window keeps
      // this O(n) in practice.
      var minStart = end - 16 < 0 ? 0 : end - 16;
      for (var start = minStart; start < end; start++) {
        if (bestScore[start] == double.negativeInfinity) continue;
        var piece = chars.sublist(start, end).join();
        var id = _vocab[piece];
        double score;
        if (id != null) {
          score = bestScore[start] + _scores[id];
        } else if (end - start == 1) {
          score = bestScore[start] + unkScore;
        } else {
          continue;
        }
        if (score > bestScore[end]) {
          bestScore[end] = score;
          bestStart[end] = start;
          bestId[end] = id ?? unkId;
        }
      }
    }
    var ids = <int>[];
    var pos = n;
    while (pos > 0) {
      ids.add(bestId[pos]);
      pos = bestStart[pos];
      if (pos < 0) break;
    }
    return ids.reversed.toList();
  }

  /// Decodes ids to text, dropping special tokens.
  String decode(List<int> ids) {
    var buffer = StringBuffer();
    for (var id in ids) {
      if (_specialIds.contains(id)) continue;
      var token = _idToToken[id];
      if (token == null) continue;
      buffer.write(token);
    }
    return buffer.toString().replaceAll(_metaspace, ' ').trim();
  }
}

/// WordPiece vocabulary decoder for manga-ocr output ids (BERT-style
/// `vocab.txt`, one token per line).
class WordPieceVocab {
  WordPieceVocab._(this._tokens);

  final List<String> _tokens;

  static Future<WordPieceVocab> fromFile(String path) async {
    var lines = await File(path).readAsLines();
    return WordPieceVocab._(lines);
  }

  /// Synchronous variant for use inside worker isolates.
  static WordPieceVocab fromFileSync(String path) {
    return WordPieceVocab._(File(path).readAsLinesSync());
  }

  String decode(List<int> ids) {
    var buffer = StringBuffer();
    for (var id in ids) {
      if (id < 0 || id >= _tokens.length) continue;
      var token = _tokens[id];
      if (token.startsWith('[') && token.endsWith(']')) continue;
      buffer.write(token.startsWith('##') ? token.substring(2) : token);
    }
    // manga-ocr output is Japanese; inter-token spaces are artifacts.
    return buffer.toString().replaceAll(' ', '');
  }
}
