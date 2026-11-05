import 'package:pica_comic/foundation/appdata.dart';

/// A target language the user added on top of the built-in list.
class CustomTargetLanguage {
  const CustomTargetLanguage({required this.code, required this.name});

  /// Language code handed to translation services and scripts, and embedded in
  /// translation keys. Canonical form, see [TranslationTargets.normalizeCode].
  final String code;

  /// Language name the AI model is asked to translate into.
  final String name;

  Map<String, dynamic> toJson() => {'code': code, 'name': name};
}

/// Translation target languages: the built-in set plus the user's own.
///
/// A code is part of every stored translation key, so the built-in codes and
/// their prompt names must never change; new languages are added as entries,
/// never by renaming one.
abstract class TranslationTargets {
  static const settingKey = 'imageTranslationCustomTargets';

  /// code -> (English UI label, name sent to the AI model).
  static const builtIn = <String, ({String label, String promptName})>{
    'zh': (label: '简体中文', promptName: '简体中文'),
    'zh-TW': (label: '繁体中文', promptName: '繁体中文（台湾用语习惯）'),
    'en': (label: '英文', promptName: 'English'),
    'ja': (label: '日语', promptName: '日本語'),
    'ko': (label: '韩语', promptName: '한국어'),
    'fr': (label: '法语', promptName: 'Français'),
    'de': (label: '德语', promptName: 'Deutsch'),
    'es': (label: '西班牙语', promptName: 'Español'),
    'ru': (label: '俄语', promptName: 'Русский'),
    'vi': (label: '越南语', promptName: 'Tiếng Việt'),
  };

  /// The user's languages in the order added. Malformed or duplicate entries
  /// (e.g. from a hand-edited backup) are skipped rather than failing.
  static List<CustomTargetLanguage> get custom {
    var raw = appdata.translationSettings[settingKey];
    var result = <CustomTargetLanguage>[];
    if (raw is! List) return result;
    var seen = <String>{};
    for (var item in raw) {
      if (item is! Map) continue;
      var code = normalizeCode('${item['code'] ?? ''}');
      var name = '${item['name'] ?? ''}'.trim();
      if (code == null || name.isEmpty) continue;
      if (builtIn.containsKey(code) || !seen.add(code)) continue;
      result.add(CustomTargetLanguage(code: code, name: name));
    }
    return result;
  }

  /// The language name for [code] in the AI prompt. A code no longer in either
  /// list (a removed custom language still selected somewhere) falls back to
  /// the code itself, so translation keeps working.
  static String promptName(String code) {
    var builtInName = builtIn[code]?.promptName;
    if (builtInName != null) return builtInName;
    for (var entry in custom) {
      if (entry.code == code) return entry.name;
    }
    return code;
  }

  static bool isTaken(String code) =>
      builtIn.containsKey(code) || custom.any((e) => e.code == code);

  static final _codePattern = RegExp(r'^[a-z]{2,3}(-[a-z0-9]{2,8})*$');
  static final _letters = RegExp(r'^[a-z]+$');

  /// Canonical form of a typed code (`PT_br` -> `pt-BR`, `zh-hant` ->
  /// `zh-Hant`), or null when it is not a language tag. The pattern also keeps
  /// out `@` and `>`, which delimit translation keys.
  static String? normalizeCode(String input) {
    var value = input.trim().replaceAll('_', '-').toLowerCase();
    if (value.length > 35 || !_codePattern.hasMatch(value)) return null;
    var parts = value.split('-');
    for (var i = 1; i < parts.length; i++) {
      var part = parts[i];
      if (!_letters.hasMatch(part)) continue;
      if (part.length == 2) {
        parts[i] = part.toUpperCase();
      } else if (part.length == 4) {
        parts[i] = part[0].toUpperCase() + part.substring(1);
      }
    }
    return parts.join('-');
  }

  /// Adds [language], or renames the existing entry with the same code.
  static void save(CustomTargetLanguage language) {
    var list = custom;
    var index = list.indexWhere((e) => e.code == language.code);
    if (index == -1) {
      list.add(language);
    } else {
      list[index] = language;
    }
    _persist(list);
  }

  /// Removes the entry only. Pages already translated into [code] stay stored
  /// and show again if the same code is added back.
  static void remove(String code) {
    _persist(custom..removeWhere((e) => e.code == code));
  }

  static void _persist(List<CustomTargetLanguage> list) {
    appdata.translationSettings[settingKey] = [for (var e in list) e.toJson()];
    appdata.saveData();
  }
}
