import 'dart:async';

import '../../../../core/models/avatar_gesture.dart';
import '../../../../core/models/avatar_mood.dart';
import '../../../../core/models/performance/performance.dart';
import '../../../../core/utils/logger.dart';
import '../models/performance_intent.dart';
import 'auto_acting_rules.dart';

/// Where a gesture request came from.
enum GestureSource { llm, auto }

class _QueuedGesture {
  const _QueuedGesture(this.gesture, this.source);

  final AvatarGesture gesture;
  final GestureSource source;
}

/// Central gesture arbiter and intent snapshot holder (v1).
///
/// At most one gesture plays at a time. Requests that arrive while one is
/// playing are queued, at most 2 deep; when the queue is full the oldest
/// `auto` request is dropped first. `onGestureDone()` (or a 4 s safety
/// timeout) plays the next request once the cooldown since the last start
/// has elapsed. An LLM gesture always outranks an auto gesture.
class PerformanceDirector {
  PerformanceDirector({
    required DateTime Function() now,
    this.gestureCooldown = const Duration(milliseconds: 1500),
  }) : _now = now;

  final DateTime Function() _now;
  final Duration gestureCooldown;

  static const Duration _safetyTimeout = Duration(seconds: 4);
  static const int _maxQueueDepth = 2;

  AvatarMood? _mood;
  bool _speaking = false;
  String? _activeTool;

  AvatarGesture? _playing;
  int _serial = 0;
  DateTime? _lastStartAt;
  final List<_QueuedGesture> _queue = <_QueuedGesture>[];
  Timer? _safetyTimer;
  Timer? _cooldownTimer;

  final StreamController<PerformanceIntent> _controller =
      StreamController<PerformanceIntent>.broadcast();

  /// Emits every intent snapshot change.
  Stream<PerformanceIntent> get intents => _controller.stream;

  /// Latest intent snapshot.
  PerformanceIntent get current => _buildIntent();

  /// Arms the director's mood (emotion + face presets follow it).
  void setMood(AvatarMood? mood) {
    _mood = mood;
    _emit();
  }

  void setSpeaking(bool speaking) {
    _speaking = speaking;
    _emit();
  }

  void setActiveTool(String? toolName) {
    _activeTool = toolName;
    _emit();
  }

  /// Requests a gesture: plays immediately when idle and past the cooldown,
  /// otherwise joins the queue (dropping the oldest auto request when full).
  void requestGesture(
    AvatarGesture gesture, {
    GestureSource source = GestureSource.llm,
  }) {
    if (_playing == null && _cooldownElapsed) {
      _start(gesture);
      return;
    }
    if (_queue.length >= _maxQueueDepth) {
      final int dropIndex = _queue.indexWhere(
        (_QueuedGesture q) => q.source == GestureSource.auto,
      );
      // An auto request never evicts an LLM one: with no auto queued, the
      // incoming auto request is the one dropped.
      if (dropIndex == -1 && source == GestureSource.auto) {
        AppLogger.debug(
          'PerformanceDirector: queue full of LLM gestures, dropped auto '
          '${gesture.name}',
          tag: 'PerformanceDirector',
        );
        return;
      }
      final _QueuedGesture dropped = _queue.removeAt(
        dropIndex == -1 ? 0 : dropIndex,
      );
      AppLogger.debug(
        'PerformanceDirector: queue full, dropped $dropped',
        tag: 'PerformanceDirector',
      );
    }
    _queue.add(_QueuedGesture(gesture, source));
    _armCooldownTimer();
  }

  /// The playing gesture finished: clears it and plays the next queued
  /// request once the cooldown has elapsed.
  void onGestureDone() {
    _safetyTimer?.cancel();
    _safetyTimer = null;
    if (_playing == null) {
      return;
    }
    _playing = null;
    _emit();
    _playNext();
  }

  /// Auto-acting entry point: derives gestures from the sentence and
  /// requests them as `auto`.
  void onSentence(String text) {
    for (final AvatarGesture gesture in gesturesFor(text)) {
      requestGesture(gesture, source: GestureSource.auto);
    }
  }

  /// Closes the intents stream and cancels all timers.
  Future<void> dispose() async {
    _safetyTimer?.cancel();
    _cooldownTimer?.cancel();
    await _controller.close();
  }

  // — internals —

  bool get _cooldownElapsed {
    final DateTime? last = _lastStartAt;
    if (last == null) {
      return true;
    }
    return _now().difference(last) >= gestureCooldown;
  }

  Duration get _cooldownRemaining {
    final DateTime? last = _lastStartAt;
    if (last == null) {
      return Duration.zero;
    }
    final Duration elapsed = _now().difference(last);
    return elapsed >= gestureCooldown
        ? Duration.zero
        : gestureCooldown - elapsed;
  }

  void _start(AvatarGesture gesture) {
    _safetyTimer?.cancel();
    _playing = gesture;
    _serial++;
    _lastStartAt = _now();
    _safetyTimer = Timer(_safetyTimeout, onGestureDone);
    _emit();
    AppLogger.debug(
      'PerformanceDirector: gesture ${gesture.name} started (serial $_serial)',
      tag: 'PerformanceDirector',
    );
  }

  void _playNext() {
    if (_playing != null || _queue.isEmpty) {
      return;
    }
    final Duration remaining = _cooldownRemaining;
    if (remaining > Duration.zero) {
      _armCooldownTimer();
      return;
    }
    // LLM gestures outrank auto gestures: pick the first LLM request,
    // otherwise the oldest request.
    final int index = _queue.indexWhere(
      (_QueuedGesture q) => q.source == GestureSource.llm,
    );
    final _QueuedGesture next = _queue.removeAt(index == -1 ? 0 : index);
    _start(next.gesture);
  }

  void _armCooldownTimer() {
    if (_cooldownTimer != null || _queue.isEmpty) {
      return;
    }
    final Duration remaining = _cooldownRemaining;
    _cooldownTimer = Timer(
      remaining <= Duration.zero ? const Duration(milliseconds: 1) : remaining,
      () {
        _cooldownTimer = null;
        _playNext();
      },
    );
  }

  PerformanceIntent _buildIntent() {
    final AvatarMood mood = _mood ?? AvatarMood.neutral;
    final GazeTarget gaze;
    if (_speaking) {
      gaze = const GazeTarget.user();
    } else if (_activeTool != null) {
      gaze = const GazeTarget.away(0.6);
    } else {
      gaze = const GazeTarget.user();
    }
    return PerformanceIntent(
      emotion: emotionForMood(mood),
      face: actionUnitsForMood(mood),
      gaze: gaze,
      speaking: _speaking,
      pendingGesture: _playing,
      gestureSerial: _serial,
      activeTool: _activeTool,
    );
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_buildIntent());
    }
  }
}
