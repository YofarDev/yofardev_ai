import 'dart:async';

import 'package:flutter/foundation.dart';

/// Demo status enum
enum DemoStatus {
  /// Demo mode is idle/not active
  idle,

  /// Countdown in progress (3-2-1)
  countdown,

  /// Demo is active and running
  active,

  /// Demo completed
  completed,
}

/// Controller for demo mode state management
///
/// Manages the countdown timer and demo status for UI updates
class DemoController extends ChangeNotifier {
  static final DemoController _instance = DemoController._internal();
  factory DemoController() => _instance;
  DemoController._internal();

  DemoStatus _status = DemoStatus.idle;
  DemoStatus get status => _status;
  bool get isIdle => _status == DemoStatus.idle;
  bool get isCountingDown => _status == DemoStatus.countdown;
  bool get isActive => _status == DemoStatus.active;
  bool get isCompleted => _status == DemoStatus.completed;

  int _countdownValue = 0;
  int get countdownValue => _countdownValue;

  final StreamController<DemoStatus> _statusController =
      StreamController<DemoStatus>.broadcast();
  Stream<DemoStatus> get statusStream => _statusController.stream;

  void _setStatus(DemoStatus status) {
    _status = status;
    notifyListeners();
    _statusController.add(status);
  }

  /// Start the countdown (3-2-1) before demo begins
  Future<void> startCountdown() async {
    _setStatus(DemoStatus.countdown);
    for (int i = 3; i > 0; i--) {
      _countdownValue = i;
      notifyListeners();
      debugPrint('Demo countdown: $i');
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    _countdownValue = 0;
    notifyListeners();
  }

  /// Mark demo as active
  void activate() {
    _setStatus(DemoStatus.active);
    debugPrint('Demo activated');
  }

  /// Mark demo as completed
  void complete() {
    _setStatus(DemoStatus.completed);
    debugPrint('Demo completed');
  }

  /// Reset demo state to idle
  void reset() {
    _setStatus(DemoStatus.idle);
    _countdownValue = 0;
    debugPrint('Demo reset');
  }

  @override
  void dispose() {
    _statusController.close();
    super.dispose();
  }
}
