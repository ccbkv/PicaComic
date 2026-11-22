import 'dart:ui' as ui;

import 'package:pica_comic/foundation/appdata.dart';
import 'package:pica_comic/foundation/log.dart';

/// Loads and owns the render-time image enhancement [ui.FragmentShader].
///
/// The shader is compiled once, lazily, and reused for every painted frame.
/// If compilation fails (e.g. an old Android device without a working Vulkan
/// backend) the enhancer permanently disables itself and callers fall back to
/// drawing the original image unchanged — the reader must never break because
/// of this optional effect.
class ImageEnhanceShader {
  ImageEnhanceShader._();

  static final ImageEnhanceShader instance = ImageEnhanceShader._();

  /// Upper bound for the user-facing enhancement strength.
  static const double maxStrength = 10.0;

  static const enabledSettingIndex = 107;
  static const strengthSettingIndex = 108;
  static const claritySettingIndex = 109;
  static const contrastSettingIndex = 110;
  static const vibranceSettingIndex = 111;

  ui.FragmentProgram? _program;

  /// `null` = not attempted yet, `true`/`false` = compile result.
  bool? _available;

  bool get isAvailable => _available == true;

  /// Whether the effect should be applied right now: the asset compiled
  /// successfully and the user enabled it.
  bool get isEnabled =>
      isAvailable &&
      appdata.settings.length > enabledSettingIndex &&
      appdata.settings[enabledSettingIndex] == '1';

  double _setting(int index, double fallback) {
    if (appdata.settings.length <= index) return fallback;
    return double.tryParse(appdata.settings[index]) ?? fallback;
  }

  /// Current strength from settings, clamped to [0, maxStrength].
  double get strength => _setting(strengthSettingIndex, 0.5).clamp(
        0.0,
        maxStrength,
      );

  /// Level-stretch (contrast) amount, clamped to [0, 1].
  double get contrast => _setting(contrastSettingIndex, 0.0).clamp(0.0, 1.0);

  /// Clarity (mid-radius local contrast) amount, clamped to [0, 1].
  double get clarity => _setting(claritySettingIndex, 0.0).clamp(0.0, 1.0);

  /// Vibrance (colour-page saturation lift), clamped to [0, 1].
  double get vibrance => _setting(vibranceSettingIndex, 0.0).clamp(0.0, 1.0);

  /// Compile the shader program. Safe to call multiple times; only the first
  /// call does work. Errors are swallowed and disable the feature.
  Future<void> preload() async {
    if (_available != null) return;
    try {
      _program = await ui.FragmentProgram.fromAsset(
        'shaders/image_enhance.frag',
      );
      _available = true;
    } catch (e, s) {
      _program = null;
      _available = false;
      Log.error("ImageEnhanceShader", "Failed to load shader: $e\n$s");
    }
  }

  /// Build a configured [ui.FragmentShader] for an image of [size], or `null`
  /// if the effect is unavailable/disabled.
  ui.FragmentShader? shaderFor(ui.Image image, {double? strengthOverride}) {
    if (!isEnabled || _program == null) return null;
    final s = (strengthOverride ?? strength).clamp(0.0, maxStrength);
    final cl = clarity;
    final c = contrast;
    final v = vibrance;
    // Nothing to do if every effect is at zero.
    if (s <= 0.0 && cl <= 0.0 && c <= 0.0 && v <= 0.0) return null;
    final shader = _program!.fragmentShader();
    // Uniform layout must match image_enhance.frag:
    //   uSize (vec2 -> 0,1), uStrength (2), uClarity (3), uContrast (4),
    //   uVibrance (5), uTexture (sampler 0)
    shader.setFloat(0, image.width.toDouble());
    shader.setFloat(1, image.height.toDouble());
    shader.setFloat(2, s);
    shader.setFloat(3, cl);
    shader.setFloat(4, c);
    shader.setFloat(5, v);
    shader.setImageSampler(0, image);
    return shader;
  }
}

/// Convenience wrapper used by callers that just want a notifier-free check.
bool readerImageEnhanceEnabled() => ImageEnhanceShader.instance.isEnabled;
