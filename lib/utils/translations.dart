import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:pica_comic/foundation/app.dart';

extension AppTranslation on String {
  String _translate() {
    var locale = App.locale;
    var key = "${locale.languageCode}_${locale.countryCode}";
    if (locale.languageCode == "en") {
      key = "en_US";
    }
    return (_translations[key]?[this]) ?? this;
  }

  String get tl => _translate();

  String get tlEN => _translations["en_US"]?[this] ?? this;

  static Map<String, String>? _enToZhCache;

  /// Reverse index: lowercase English translation -> Chinese source string.
  /// PicaComic stores Chinese source strings and translates them to English in
  /// the "en_US" section, so this lets the settings search match Chinese
  /// queries against the (English) search index titles.
  static Map<String, String> get _enToZh {
    if (_enToZhCache != null) return _enToZhCache!;
    final en = _translations["en_US"];
    final map = <String, String>{};
    if (en != null) {
      for (final entry in en.entries) {
        map.putIfAbsent(entry.value.toLowerCase(), () => entry.key);
      }
    }
    _enToZhCache = map;
    return map;
  }

  /// Returns the Chinese source string whose English translation is [english],
  /// or null when there is no such entry.
  static String? zhSource(String english) => _enToZh[english.toLowerCase()];

  String tlParams(Map<String, String> values) {
    var res = _translate();
    for (var entry in values.entries) {
      res = res.replaceFirst("@${entry.key}", entry.value);
    }
    return res;
  }

  static bool _initialized = false;
  static Map<String, Map<String, String>> _translations = const {};

  static Future<void> init() async {
    if (_initialized) {
      return;
    }
    var data = await rootBundle.load("assets/translation.json");
    var json = jsonDecode(utf8.decode(data.buffer.asUint8List()));
    _translations = {
      for (var e in json.entries) e.key: Map<String, String>.from(e.value)
    };
    _initialized = true;
  }
}

extension ListTranslation on List<String> {
  List<String> _translate() {
    return List.generate(length, (index) => this[index].tl);
  }

  List<String> get tl => _translate();
}
