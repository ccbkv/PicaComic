import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:pica_comic/foundation/image_enhance_shader.dart';

/// Displays a [ui.Image] with the render-time enhancement shader applied.
///
/// The shader is run exactly once per (image, strength) into an offscreen
/// [ui.Image] which is then handed to [builder] to paint as usual (a
/// [RawImage], or several sharing it). This keeps all of the reader's existing
/// fit / alignment / zoom (PhotoView) behaviour intact and correct, while
/// costing nothing per frame after the one-time GPU pass.
///
/// If the shader is unavailable or disabled, the original image is drawn
/// unchanged — the reader never breaks because of this optional effect.
class EnhancedComicImage extends StatefulWidget {
  const EnhancedComicImage({
    super.key,
    required this.image,
    required this.builder,
  });

  final ui.Image image;

  /// Paints the enhanced image, or [image] itself until that is ready.
  final Widget Function(ui.Image image) builder;

  @override
  State<EnhancedComicImage> createState() => _EnhancedComicImageState();
}

class _EnhancedComicImageState extends State<EnhancedComicImage> {
  /// The processed image to display, or null until ready / when disabled.
  ui.Image? _enhanced;

  /// Token guarding against stale async results when inputs change rapidly.
  int _token = 0;

  /// The (image, strength) signature the current [_enhanced] was built for.
  Object? _builtSignature;

  Object _signature() => Object.hash(
        identityHashCode(widget.image),
        ImageEnhanceShader.instance.strength,
        ImageEnhanceShader.instance.clarity,
        ImageEnhanceShader.instance.contrast,
        ImageEnhanceShader.instance.vibrance,
      );

  @override
  void initState() {
    super.initState();
    _maybeEnhance();
  }

  @override
  void didUpdateWidget(EnhancedComicImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.image, widget.image) ||
        _builtSignature != _signature()) {
      _maybeEnhance();
    }
  }

  void _maybeEnhance() {
    final shaderManager = ImageEnhanceShader.instance;
    if (!shaderManager.isEnabled) {
      _disposeEnhanced();
      return;
    }
    final signature = _signature();
    if (_builtSignature == signature && _enhanced != null) {
      return;
    }
    final myToken = ++_token;
    _runShader(widget.image, shaderManager).then((result) {
      if (!mounted || myToken != _token) {
        result?.dispose();
        return;
      }
      setState(() {
        _disposeEnhanced();
        _enhanced = result;
        _builtSignature = signature;
      });
    });
  }

  Future<ui.Image?> _runShader(
    ui.Image source,
    ImageEnhanceShader shaderManager,
  ) async {
    final shader = shaderManager.shaderFor(source);
    if (shader == null) return null;
    ui.Picture? picture;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      // Draw at native origin/size: FlutterFragCoord() then matches the
      // sampler's texel grid exactly (uv = FlutterFragCoord / uSize).
      final paint = Paint()..shader = shader;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
        paint,
      );
      picture = recorder.endRecording();
      return await picture.toImage(source.width, source.height);
    } catch (_) {
      return null;
    } finally {
      // Both must be released even if toImage() throws, to avoid leaking
      // native resources.
      picture?.dispose();
      shader.dispose();
    }
  }

  void _disposeEnhanced() {
    _enhanced?.dispose();
    _enhanced = null;
    _builtSignature = null;
  }

  @override
  void dispose() {
    _disposeEnhanced();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(_enhanced ?? widget.image);
}
