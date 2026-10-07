import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pica_comic/foundation/image_loader/cached_image.dart';

/// Prime's @x=...&y=... suffix describes a local crop, not a server URL.
class EhPrimeThumbnail extends StatefulWidget {
  const EhPrimeThumbnail({super.key, required this.url, required this.crop});

  final String url;
  final Rect crop;

  @override
  State<EhPrimeThumbnail> createState() => _EhPrimeThumbnailState();
}

class _EhPrimeThumbnailState extends State<EhPrimeThumbnail> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _image;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(EhPrimeThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _load();
  }

  void _load() {
    _detach();
    _image?.dispose();
    _image = null;
    _failed = false;
    _stream = CachedImageProvider(widget.url, sourceKey: 'ehentai')
        .resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener((image, _) {
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _image?.dispose();
        _image = image;
        _failed = false;
      });
    }, onError: (Object error, StackTrace? stack) {
      if (mounted) setState(() => _failed = true);
    });
    _stream!.addListener(_listener!);
  }

  void _detach() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
  }

  @override
  void dispose() {
    _detach();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const Center(child: Icon(Icons.error));
    if (_image == null) return const SizedBox.expand();
    return CustomPaint(
      painter: _EhPrimeThumbnailPainter(_image!.image, widget.crop),
      child: const SizedBox.expand(),
    );
  }
}

class _EhPrimeThumbnailPainter extends CustomPainter {
  const _EhPrimeThumbnailPainter(this.image, this.crop);

  final ui.Image image;
  final Rect crop;

  @override
  void paint(Canvas canvas, Size size) {
    final source = crop.intersect(
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()));
    if (source.isEmpty || size.isEmpty) return;
    final fitted = applyBoxFit(BoxFit.contain, source.size, size).destination;
    final destination = Alignment.center.inscribe(fitted, Offset.zero & size);
    canvas.drawImageRect(image, source, destination, Paint());
  }

  @override
  bool shouldRepaint(_EhPrimeThumbnailPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.crop != crop;
}
