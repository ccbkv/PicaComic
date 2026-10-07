import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:image/image.dart' as img;

Future<void> _pendingModification = Future.value();

/// Serialize decoding to limit the number of expanded pages held in memory.
Future<Uint8List> modifyImageWithScript(Uint8List data, String script) {
  final task = _pendingModification.then((_) async {
    final initScript = await rootBundle.loadString('assets/init.js');
    final codec = await ui.instantiateImageCodec(data);
    late final _ScriptImage image;
    try {
      final frame = await codec.getNextFrame();
      try {
        final bytes = await frame.image
            .toByteData(format: ui.ImageByteFormat.rawStraightRgba);
        if (bytes == null) throw StateError('Failed to decode image');
        image = _ScriptImage(
          frame.image.width,
          frame.image.height,
          bytes.buffer
              .asUint32List(bytes.offsetInBytes, bytes.lengthInBytes ~/ 4),
        );
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
    return compute(_modifyImage, (image, script, initScript));
  });
  _pendingModification =
      task.then<void>((_) {}, onError: (Object _, StackTrace __) {});
  return task;
}

class _ScriptImage {
  _ScriptImage(this.width, this.height, this.pixels);

  final int width;
  final int height;
  final Uint32List pixels;

  factory _ScriptImage.empty(int width, int height) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Image dimensions must be positive');
    }
    return _ScriptImage(width, height, Uint32List(width * height));
  }

  void checkRange(int x, int y, int w, int h) {
    if (x < 0 || y < 0 || w < 0 || h < 0 || x + w > width || y + h > height) {
      throw RangeError('Image range is out of bounds');
    }
  }

  void fill(int x, int y, _ScriptImage source, int sx, int sy, int w, int h) {
    checkRange(x, y, w, h);
    source.checkRange(sx, sy, w, h);
    for (var row = 0; row < h; row++) {
      final start = (y + row) * width + x;
      pixels.setRange(
          start, start + w, source.pixels, (sy + row) * source.width + sx);
    }
  }
}

Uint8List _modifyImage((_ScriptImage, String, String) task) {
  final (image, script, initScript) = task;
  final engine = FlutterQjs();
  final images = <int, _ScriptImage>{0: image};
  var nextKey = 1;
  int store(_ScriptImage value) {
    final key = nextKey++;
    images[key] = value;
    return key;
  }

  Object? receive(dynamic message) {
    if (message is! Map || message['method'] != 'image') {
      throw UnsupportedError('Only the Image API is available in modifyImage');
    }
    int number(String name) => (message[name] as num).toInt();
    if (message['function'] == 'emptyImage') {
      return store(_ScriptImage.empty(number('width'), number('height')));
    }
    final target = images[message['key']];
    if (target == null) throw StateError('Invalid image reference');
    switch (message['function']) {
      case 'getWidth':
        return target.width;
      case 'getHeight':
        return target.height;
      case 'copyRange':
        final copy = _ScriptImage.empty(number('width'), number('height'));
        copy.fill(
            0, 0, target, number('x'), number('y'), copy.width, copy.height);
        return store(copy);
      case 'copyAndRotate90':
        final copy = _ScriptImage.empty(target.height, target.width);
        for (var y = 0; y < target.height; y++) {
          for (var x = 0; x < target.width; x++) {
            copy.pixels[x * copy.width + target.height - y - 1] =
                target.pixels[y * target.width + x];
          }
        }
        return store(copy);
      case 'fillImageAt':
      case 'fillImageRangeAt':
        final source = images[message['image']];
        if (source == null) throw StateError('Invalid source image reference');
        final full = message['function'] == 'fillImageAt';
        target.fill(
          number('x'),
          number('y'),
          source,
          full ? 0 : number('srcX'),
          full ? 0 : number('srcY'),
          full ? source.width : number('width'),
          full ? source.height : number('height'),
        );
        return null;
      default:
        throw UnsupportedError(
            'Unknown image operation: ${message['function']}');
    }
  }

  try {
    engine.dispatch();
    final setGlobal =
        engine.evaluate('(value) => { globalThis.sendMessage = value; }')
            as JSInvokable;
    try {
      setGlobal([receive]);
    } finally {
      setGlobal.free();
    }
    engine.evaluate(initScript);
    final key = engine.evaluate('''
      (() => {
        $script
        return modifyImage(new Image(0)).key;
      })()
    ''');
    final result = images[key];
    if (result == null) throw StateError('modifyImage must return an Image');
    final output = img.Image.fromBytes(
      width: result.width,
      height: result.height,
      bytes: result.pixels.buffer,
      bytesOffset: result.pixels.offsetInBytes,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    return img.encodePng(output);
  } finally {
    images.clear();
    engine.close();
    engine.port.close();
  }
}
