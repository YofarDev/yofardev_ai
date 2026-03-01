import '../models/demo_script.dart';
import '../services/demo_controller.dart';

/// Demo state
class DemoState {
  final DemoStatus status;
  final int countdownValue;
  final DemoScript? currentScript;
  final int remainingResponses;

  const DemoState({
    this.status = DemoStatus.idle,
    this.countdownValue = 0,
    this.currentScript,
    this.remainingResponses = 0,
  });

  DemoState copyWith({
    DemoStatus? status,
    int? countdownValue,
    DemoScript? currentScript,
    int? remainingResponses,
  }) {
    return DemoState(
      status: status ?? this.status,
      countdownValue: countdownValue ?? this.countdownValue,
      currentScript: currentScript ?? this.currentScript,
      remainingResponses: remainingResponses ?? this.remainingResponses,
    );
  }

  bool get isIdle => status == DemoStatus.idle;
  bool get isCountingDown => status == DemoStatus.countdown;
  bool get isActive => status == DemoStatus.active;
  bool get isCompleted => status == DemoStatus.completed;
}
