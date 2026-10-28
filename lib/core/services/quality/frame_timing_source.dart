import 'dart:async';

import 'dart:ui' show FlutterView, FrameTiming;

import 'package:flutter/scheduler.dart';

import '../../utils/logger.dart';

/// Source of frame timings plus the display refresh rate; abstracted so the
/// quality-tier probe can be tested with a fake clock.
abstract interface class FrameTimingSource {
  /// Batches of frame timings as reported by the platform.
  Stream<List<FrameTiming>> get timings;

  /// Refresh rate of the primary display in Hz.
  double get refreshRate;
}

/// Production [FrameTimingSource] backed by
/// `SchedulerBinding.instance.addTimingsCallback`.
class SchedulerFrameTimingSource implements FrameTimingSource {
  SchedulerFrameTimingSource() {
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  final StreamController<List<FrameTiming>> _controller =
      StreamController<List<FrameTiming>>.broadcast();

  void _onTimings(List<FrameTiming> timings) {
    _controller.add(timings);
  }

  @override
  Stream<List<FrameTiming>> get timings => _controller.stream;

  @override
  double get refreshRate {
    final Iterable<FlutterView> views =
        SchedulerBinding.instance.platformDispatcher.views;
    if (views.isEmpty) {
      return 60;
    }
    return views.first.display.refreshRate;
  }

  /// Removes the timings callback and closes the stream.
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _controller.close();
    AppLogger.debug('SchedulerFrameTimingSource disposed', tag: 'QualityTier');
  }
}
