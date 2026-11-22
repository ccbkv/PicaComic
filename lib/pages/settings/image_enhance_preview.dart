import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pica_comic/foundation/image_enhance_shader.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/pages/reader/shader_image.dart';
import 'package:pica_comic/utils/translations.dart';

const double _previewAspect = 4 / 3;

const Size _sampleSize = Size(480, 360);

/// Live before/after view of the image enhancement settings.
///
/// Shows the page open in the reader when [pageImage] provides one, otherwise a
/// built-in sample. The enhanced half goes through the reader's own shader
/// path and re-renders on every settings change, so slider drags show live.
class ImageEnhancePreview extends StatefulWidget {
  const ImageEnhancePreview({
    super.key,
    this.pageImage,
    this.settingsVersion = 0,
  });

  /// Returns a copy of the page open in the reader, owned by the preview from
  /// then on. Null, or a null result, falls back to the sample.
  final ImageInfo? Function()? pageImage;

  /// Changes whenever an enhancement parameter changes, triggering a rebuild.
  final int settingsVersion;

  @override
  State<ImageEnhancePreview> createState() => _ImageEnhancePreviewState();
}

class _ImageEnhancePreviewState extends State<ImageEnhancePreview> {
  ui.Image? _image;
  bool _isSample = false;
  bool _started = false;
  bool _failed = false;
  bool _unsupported = false;
  double _split = 0.5;
  TextStyle _textStyle = const TextStyle();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _textStyle = DefaultTextStyle.of(context).style;
    if (_started) return;
    _started = true;
    // The snapshot reads the reader's layout; wait until this frame is done.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    // Deferred init may still be compiling the shader right after launch.
    await ImageEnhanceShader.instance.preload();
    if (!mounted) return;
    if (!ImageEnhanceShader.instance.isAvailable) {
      setState(() => _unsupported = true);
      return;
    }
    ui.Image? image;
    var isSample = false;
    try {
      final page = widget.pageImage?.call();
      if (page != null) {
        try {
          image = await cropPreviewBand(page.image);
        } finally {
          page.dispose();
        }
      } else {
        image = await renderEnhanceSample(_textStyle);
        isSample = true;
      }
    } catch (e, s) {
      image?.dispose();
      image = null;
      Log.error("ImageEnhancePreview", "Failed to prepare preview: $e\n$s");
    }
    if (!mounted) {
      image?.dispose();
      return;
    }
    setState(() {
      _image = image;
      _isSample = isSample;
      _failed = image == null;
    });
  }

  @override
  void dispose() {
    _image?.dispose();
    _image = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final captionStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        );
    if (_unsupported) {
      return Text(
        "此设备不支持图像增强".tl,
        style: captionStyle,
      );
    }
    if (_failed) return const SizedBox.shrink();
    final image = _image;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: AspectRatio(
            aspectRatio: _previewAspect,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: image == null
                  ? ColoredBox(color: colorScheme.surfaceContainerHighest)
                  : _CompareView(
                      image: image,
                      split: _split,
                      onSplitChanged: (v) => setState(() => _split = v),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Empty until loaded: keeps the line's height so nothing jumps, and
        // only then is it known whether the reader had a page to show.
        Text(
          image == null
              ? ''
              : _isSample
                  ? "示例图片，可拖动对比增强效果".tl
                  : "拖动对比".tl,
          style: captionStyle,
        ),
      ],
    );
  }
}

class _CompareView extends StatelessWidget {
  const _CompareView({
    required this.image,
    required this.split,
    required this.onSplitChanged,
  });

  final ui.Image image;

  /// Divider position as a fraction of the width; original on the left.
  final double split;

  final ValueChanged<double> onSplitChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void moveTo(double dx) {
          if (width > 0) onSplitChanged((dx / width).clamp(0.0, 1.0));
        }

        final x = width * split;
        return Semantics(
          label: "预览".tl,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) => moveTo(d.localPosition.dx),
            onTapUp: (d) => moveTo(d.localPosition.dx),
            child: Stack(
              fit: StackFit.expand,
              children: [
                RawImage(image: image, fit: BoxFit.cover),
                ClipRect(
                  clipper: _RightOfSplit(split),
                  child: EnhancedComicImage(
                    image: image,
                    builder: (enhanced) =>
                        RawImage(image: enhanced, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  left: x - 1,
                  top: 0,
                  bottom: 0,
                  width: 2,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(blurRadius: 3)],
                    ),
                  ),
                ),
                Positioned(
                  left: (x - 14).clamp(0.0, math.max(0.0, width - 28)),
                  top: 0,
                  bottom: 0,
                  child: const Center(child: _Handle()),
                ),
                if (split > 0.2)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: _Tag("原图".tl),
                  ),
                if (split < 0.8)
                  Positioned(right: 8, top: 8, child: _Tag("增强后".tl)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black38)],
      ),
      child: const Icon(Icons.compare_arrows, size: 18, color: Colors.black87),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(140),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
    );
  }
}

class _RightOfSplit extends CustomClipper<Rect> {
  const _RightOfSplit(this.split);

  final double split;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(size.width * split, 0, size.width, size.height);

  @override
  bool shouldReclip(_RightOfSplit oldClipper) => oldClipper.split != split;
}

/// The centred, pixel-aligned region of a [width] x [height] page that fills a
/// preview box with [aspect] ratio.
@visibleForTesting
Rect previewBandRect(int width, int height, {double aspect = _previewAspect}) {
  final bandWidth = math.min(width.toDouble(), height * aspect).roundToDouble();
  final bandHeight =
      math.min(height.toDouble(), width / aspect).roundToDouble();
  final w = math.max(1.0, bandWidth);
  final h = math.max(1.0, bandHeight);
  final left = ((width - w) / 2).floorToDouble();
  final top = ((height - h) / 2).floorToDouble();
  return Rect.fromLTWH(left, top, w, h);
}

/// Copies the visible band of [source] at native resolution, so a long strip
/// costs the shader a box-sized pass per settings change, not the whole page.
@visibleForTesting
Future<ui.Image> cropPreviewBand(ui.Image source) async {
  final band = previewBandRect(source.width, source.height);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImageRect(
    source,
    band,
    Offset.zero & band.size,
    Paint()..filterQuality = FilterQuality.none,
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(band.width.toInt(), band.height.toInt());
  } finally {
    picture.dispose();
  }
}

/// A small faded two-panel page with soft ink, hatching, screentone and muted
/// colour, so every slider has something visible to act on. [textStyle] only
/// supplies the font and its CJK fallback.
@visibleForTesting
Future<ui.Image> renderEnhanceSample(TextStyle textStyle) async {
  const paper = Color(0xFFE6E1D3);
  const ink = Color(0xFF353535);
  const focusPanel = Rect.fromLTWH(12, 12, 222, 336);
  const tonePanel = Rect.fromLTWH(244, 12, 224, 218);
  const colorPanel = Rect.fromLTWH(244, 240, 224, 108);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Offset.zero & _sampleSize, Paint()..color = paper);
  // A slight blur stands in for a soft scan, which is what sharpening is for.
  canvas.saveLayer(
    null,
    Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 0.6, sigmaY: 0.6),
  );
  final stroke = Paint()
    ..color = ink
    ..style = PaintingStyle.stroke;
  final fill = Paint()..color = ink;

  // Focus lines around a speech bubble.
  final focus = focusPanel.center;
  canvas.save();
  canvas.clipRect(focusPanel);
  for (var i = 0; i < 72; i++) {
    final angle = i * math.pi / 36;
    final dir = Offset(math.cos(angle), math.sin(angle));
    stroke.strokeWidth = i.isEven ? 1.4 : 0.8;
    canvas.drawLine(focus + dir * 70, focus + dir * 260, stroke);
  }
  canvas.restore();
  final bubble = Path.combine(
    ui.PathOperation.union,
    Path()..addOval(Rect.fromCenter(center: focus, width: 140, height: 96)),
    Path()
      ..moveTo(focus.dx - 16, focus.dy + 38)
      ..lineTo(focus.dx - 28, focus.dy + 78)
      ..lineTo(focus.dx + 8, focus.dy + 42)
      ..close(),
  );
  canvas.drawPath(bubble, Paint()..color = const Color(0xFFF4F1E8));
  canvas.drawPath(bubble, stroke..strokeWidth = 2);
  final text = TextPainter(
    text: TextSpan(
      style: textStyle.copyWith(color: ink, height: 1.15),
      children: const [
        TextSpan(
          text: '永',
          style: TextStyle(fontSize: 40, fontWeight: FontWeight.w600),
        ),
        TextSpan(text: '\nAa Bb 123', style: TextStyle(fontSize: 14)),
      ],
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout();
  text.paint(canvas, focus - Offset(text.width / 2, text.height / 2));
  text.dispose();

  // Screentone ramp behind a hatched sphere.
  canvas.save();
  canvas.clipRect(tonePanel);
  for (var y = tonePanel.top + 3; y < tonePanel.bottom; y += 6) {
    for (var x = tonePanel.left + 3; x < tonePanel.right; x += 6) {
      final t = (x - tonePanel.left) / tonePanel.width;
      canvas.drawCircle(Offset(x, y), 0.5 + 1.8 * t, fill);
    }
  }
  final sphereCenter = tonePanel.center;
  final sphere = Path()
    ..addOval(Rect.fromCircle(center: sphereCenter, radius: 62));
  canvas.drawPath(sphere, Paint()..color = paper);
  final shadow = Path.combine(
    ui.PathOperation.difference,
    sphere,
    Path()
      ..addOval(
        Rect.fromCircle(
          center: sphereCenter - const Offset(18, 18),
          radius: 62,
        ),
      ),
  );
  canvas.save();
  canvas.clipPath(shadow);
  stroke.strokeWidth = 1;
  for (var d = -140.0; d < 140; d += 5) {
    canvas.drawLine(
      sphereCenter + Offset(d - 70, -70),
      sphereCenter + Offset(d + 70, 70),
      stroke,
    );
  }
  canvas.restore();
  canvas.drawPath(sphere, stroke..strokeWidth = 2);
  canvas.restore();

  // Grey ramp for contrast, muted swatches for vibrance.
  final ramp = Rect.fromLTWH(
    colorPanel.left + 10,
    colorPanel.top + 10,
    colorPanel.width - 20,
    34,
  );
  canvas.drawRect(
    ramp,
    Paint()
      ..shader = ui.Gradient.linear(ramp.centerLeft, ramp.centerRight, const [
        Color(0xFF474747),
        Color(0xFFD2CEC4),
      ]),
  );
  const swatches = [
    Color(0xFFA0706A),
    Color(0xFF7D9278),
    Color(0xFF6E7F98),
    Color(0xFFB4A06E),
  ];
  final swatchWidth = (ramp.width - 3 * 8) / swatches.length;
  for (var i = 0; i < swatches.length; i++) {
    final swatch = Rect.fromLTWH(
      ramp.left + i * (swatchWidth + 8),
      ramp.bottom + 10,
      swatchWidth,
      34,
    );
    canvas.drawRect(swatch, Paint()..color = swatches[i]);
    canvas.drawRect(swatch, stroke..strokeWidth = 1);
  }

  stroke.strokeWidth = 3;
  for (final panel in const [focusPanel, tonePanel, colorPanel]) {
    canvas.drawRect(panel, stroke);
  }
  canvas.restore();

  final picture = recorder.endRecording();
  try {
    return await picture.toImage(
      _sampleSize.width.toInt(),
      _sampleSize.height.toInt(),
    );
  } finally {
    picture.dispose();
  }
}
