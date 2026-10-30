import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

/// Grabs the app's render view as raw RGBA every [interval] (M6 ruling 1):
/// `OffsetLayer.toImage` includes the Rive textures, so this is the stage the
/// window shows. A grab still in flight skips the next tick. Frames go to
/// [dir] as `NNNN.rgba`; [frames] lists their capture times.
class FrameGrabber {
  FrameGrabber(
    this.view,
    this.dir, {
    this.interval = const Duration(milliseconds: 66),
    this.pixelRatio = 1,
  });

  final RenderView view;
  final Directory dir;
  final Duration interval;
  final double pixelRatio;

  final List<({int index, int ms})> frames = <({int index, int ms})>[];
  final List<Future<void>> _writes = <Future<void>>[];
  ui.Size? size;
  Timer? _timer;
  bool _busy = false;
  late Stopwatch _clock;

  /// Starts grabbing; times are milliseconds on [clock].
  void start(Stopwatch clock) {
    _clock = clock;
    _timer = Timer.periodic(interval, (_) => _grab());
  }

  Future<void> _grab() async {
    if (_busy) {
      return;
    }
    final Layer? layer = view.debugLayer;
    if (layer is! OffsetLayer) {
      return;
    }
    _busy = true;
    try {
      final int ms = _clock.elapsedMilliseconds;
      final ui.Image image = await layer.toImage(
        Offset.zero & view.size,
        pixelRatio: pixelRatio,
      );
      final ByteData? data = await image.toByteData();
      size = ui.Size(image.width.toDouble(), image.height.toDouble());
      image.dispose();
      if (data == null) {
        return;
      }
      final int index = frames.length;
      frames.add((index: index, ms: ms));
      _writes.add(
        File(
          '${dir.path}/${index.toString().padLeft(4, '0')}.rgba',
        ).writeAsBytes(data.buffer.asUint8List()),
      );
    } finally {
      _busy = false;
    }
  }

  /// One frame now, written to [dir]'s parent as `<name>.rgba` (references
  /// such as the wet / dry pair).
  Future<void> grabOnce(String name) async {
    final Layer? layer = view.debugLayer;
    if (layer is! OffsetLayer) {
      return;
    }
    final ui.Image image = await layer.toImage(
      Offset.zero & view.size,
      pixelRatio: pixelRatio,
    );
    final ByteData? data = await image.toByteData();
    image.dispose();
    if (data != null) {
      await File(
        '${dir.parent.path}/$name.rgba',
      ).writeAsBytes(data.buffer.asUint8List());
    }
  }

  /// Stops grabbing and waits for every frame to reach the disk.
  Future<void> stop() async {
    _timer?.cancel();
    while (_busy) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await Future.wait(_writes);
  }
}
