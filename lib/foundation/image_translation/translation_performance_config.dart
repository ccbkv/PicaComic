import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/appdata.dart';

enum TranslationPerformancePreset { saver, balanced, fast, custom }

class TranslationPerformanceValues {
  const TranslationPerformanceValues({
    required this.batchPages,
    required this.ocrWorkers,
    required this.imageConcurrency,
    required this.llmConcurrency,
  });

  final int batchPages;
  final int ocrWorkers;
  final int imageConcurrency;
  final int llmConcurrency;
}

abstract final class TranslationPerformanceConfig {
  static const settingKey = 'imageTranslationPerformancePreset';

  static TranslationPerformancePreset get current =>
      fromSetting(appdata.translationSettings[settingKey]);

  static TranslationPerformanceValues get effective =>
      valuesFor(current, isDesktop: App.isDesktop);

  static TranslationPerformancePreset fromSetting(Object? value) =>
      switch (value) {
        'saver' => TranslationPerformancePreset.saver,
        'fast' => TranslationPerformancePreset.fast,
        'custom' => TranslationPerformancePreset.custom,
        _ => TranslationPerformancePreset.balanced,
      };

  static TranslationPerformanceValues valuesFor(
    TranslationPerformancePreset preset, {
    required bool isDesktop,
  }) =>
      switch (preset) {
        TranslationPerformancePreset.saver =>
          const TranslationPerformanceValues(
            batchPages: 1,
            ocrWorkers: 1,
            imageConcurrency: 1,
            llmConcurrency: 1,
          ),
        TranslationPerformancePreset.balanced => TranslationPerformanceValues(
            batchPages: isDesktop ? 4 : 2,
            ocrWorkers: 0,
            imageConcurrency: isDesktop ? 3 : 2,
            llmConcurrency: 2,
          ),
        TranslationPerformancePreset.fast => TranslationPerformanceValues(
            batchPages: isDesktop ? 8 : 4,
            ocrWorkers: isDesktop ? 3 : 2,
            imageConcurrency: isDesktop ? 6 : 3,
            llmConcurrency: isDesktop ? 4 : 3,
          ),
        TranslationPerformancePreset.custom => TranslationPerformanceValues(
            batchPages: _intSetting(
              'imageTranslationPreBatchPages',
              1,
            ).clamp(1, isDesktop ? 20 : 8),
            ocrWorkers: _intSetting(
              'imageTranslationOcrWorkers',
              0,
            ).clamp(0, isDesktop ? 6 : 2),
            imageConcurrency: _intSetting(
              'imageTranslationImageConcurrency',
              3,
            ).clamp(1, isDesktop ? 6 : 3),
            llmConcurrency: _intSetting(
              'imageTranslationLlmConcurrency',
              2,
            ).clamp(1, isDesktop ? 4 : 3),
          ),
      };

  static void apply(TranslationPerformancePreset preset) {
    appdata.translationSettings[settingKey] = preset.name;
    if (preset != TranslationPerformancePreset.custom) {
      var values = valuesFor(preset, isDesktop: App.isDesktop);
      appdata.translationSettings['imageTranslationPreBatchPages'] =
          values.batchPages;
      appdata.translationSettings['imageTranslationOcrWorkers'] =
          values.ocrWorkers;
      appdata.translationSettings['imageTranslationImageConcurrency'] =
          values.imageConcurrency;
      appdata.translationSettings['imageTranslationLlmConcurrency'] =
          values.llmConcurrency;
    }
    appdata.saveData();
  }

  static void markCustom({bool save = true}) {
    appdata.translationSettings[settingKey] =
        TranslationPerformancePreset.custom.name;
    if (save) appdata.saveData();
  }

  static int _intSetting(String key, int fallback) {
    var value = appdata.translationSettings[key];
    return value is int ? value : int.tryParse('$value') ?? fallback;
  }
}
