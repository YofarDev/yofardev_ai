import 'dart:async';

import '../../../../core/services/power/power_saver_source.dart';

/// How long the user has been away, as a stage the avatar acts on.
///
/// 0 active; 1 after 30 s (glances around); 2 after 2 min (plays with the
/// tablet now and then); 3 after 10 min (the tablet stays out). Any
/// [onActivity] (typing, speech, a tool, a tap) starts over at 0. Battery
/// saver or reduce motion hold the ladder at 0.
///
/// The clock is injected; a periodic timer calls [tick] once a second, and
/// tests call [tick] themselves.
class IdleLadder {
  IdleLadder({
    required DateTime Function() now,
    required PowerSaverSource power,
    required bool Function() reduceMotion,
    this.checkInterval = const Duration(seconds: 1),
  }) : _now = now,
       _power = power,
       _reduceMotion = reduceMotion,
       _lastActivity = now();

  /// Idle time at which each stage 1..3 begins.
  static const List<Duration> thresholds = <Duration>[
    Duration(seconds: 30),
    Duration(minutes: 2),
    Duration(minutes: 10),
  ];

  final DateTime Function() _now;
  final PowerSaverSource _power;
  final bool Function() _reduceMotion;
  final Duration checkInterval;

  final StreamController<int> _controller = StreamController<int>.broadcast();
  StreamSubscription<bool>? _powerSub;
  Timer? _timer;
  DateTime _lastActivity;
  bool _powerSaver = false;
  int _stage = 0;
  bool _disposed = false;

  /// The stage now.
  int get stage => _stage;

  /// Emits the new stage whenever it changes.
  Stream<int> get stages => _controller.stream;

  /// Reads the power saver state, follows its changes and starts the
  /// periodic check. The idle time counts from now.
  Future<void> start() async {
    _lastActivity = _now();
    _powerSub ??= _power.changes.listen((bool on) {
      _powerSaver = on;
      tick();
    });
    _timer ??= Timer.periodic(checkInterval, (Timer _) => tick());
    final bool on = await _power.isOn;
    if (_disposed) {
      return;
    }
    _powerSaver = on;
    tick();
  }

  /// The user (or the avatar itself) did something: back to stage 0.
  void onActivity() {
    _lastActivity = _now();
    _set(0);
  }

  /// Recomputes the stage from the idle time.
  void tick() {
    if (_powerSaver || _reduceMotion()) {
      _set(0);
      return;
    }
    final Duration idle = _now().difference(_lastActivity);
    int next = 0;
    for (int i = 0; i < thresholds.length; i++) {
      if (idle >= thresholds[i]) {
        next = i + 1;
      }
    }
    _set(next);
  }

  void _set(int next) {
    if (next == _stage || _disposed) {
      return;
    }
    _stage = next;
    _controller.add(next);
  }

  /// Stops the timer and closes [stages].
  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    await _powerSub?.cancel();
    _powerSub = null;
    await _controller.close();
  }
}
