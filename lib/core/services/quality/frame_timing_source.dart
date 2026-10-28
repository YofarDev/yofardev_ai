import 'dart:async';

import 'dart:ui' show FlutterView, FrameTiming;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;

import '../../utils/logger.dart';

/// Source of frame timings plus the display refresh rate; abstracted so the
/// quality-tier probe can be tested with a fake clock.
abstract interface class FrameTimingSource {
  /// Batches of frame timings as reported by the platform.
  Stream<List<FrameTiming>> get timings;

  /// Refresh rate of the primary display in Hz.
  double get refreshRate;

  /// Completes once the app has drawn its first frame; a probe started
  /// earlier would measure startup work instead of steady-state frames.
  Future<void> get firstFrameDrawn;
}

/// Production [FrameTimingSource] backed by
/// `SchedulerBinding.instance.addTimingsCallback`; the callback is registered
/// only while the [timings] stream has listeners.
class SchedulerFrameTimingSource implements FrameTimingSource {
  SchedulerFrameTimingSource() {
    _controller = StreamController<List<FrameTiming>>.broadcast(
      onListen: () => SchedulerBinding.instance.addTimingsCallback(_onTimings),
      onCancel: () =>
          SchedulerBinding.instance.removeTimingsCallback(_onTimings),
    );
  }

  late final StreamController<List<FrameTiming>> _controller;

  void _onTimings(List<FrameTiming> timings) {
    _controller.add(timings);
  }

  @override
  Stream<List<FrameTiming>> get timings => _controller.stream;

  @override
  Future<void> get firstFrameDrawn =>
      WidgetsBinding.instance.waitUntilFirstFrameRasterized;

  @override
  double get refreshRate {
    final Iterable<FlutterView> views =
        SchedulerBinding.instance.platformDispatcher.views;
    if (views.isEmpty) {
      return 60;
    }
    return views.first.display.refreshRate;
  }

  /// Closes the stream (which removes the timings callback).
  void dispose() {
    _controller.close();
    AppLogger.debug('SchedulerFrameTimingSource disposed', tag: 'QualityTier');
  }
}
