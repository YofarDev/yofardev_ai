import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:yofardev_ai/features/demo/models/demo_script.dart';
import 'package:yofardev_ai/features/demo/services/demo_controller.dart';

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

/// Demo cubit for managing demo mode state
class DemoCubit extends Cubit<DemoState> {
  DemoCubit(this._demoController) : super(const DemoState()) {
    _demoController.addListener(_onControllerChanged);
  }

  final DemoController _demoController;

  void _onControllerChanged() {
    emit(state.copyWith(
      status: _demoController.status,
      countdownValue: _demoController.countdownValue,
    ));
  }

  /// Start a demo with the given script
  void startDemo(DemoScript script) {
    emit(state.copyWith(
      currentScript: script,
      remainingResponses: script.responses.length,
    ));
  }

  /// Update the remaining responses count
  void updateRemainingResponses(int count) {
    emit(state.copyWith(remainingResponses: count));
  }

  /// Reset demo state
  void resetDemo() {
    emit(const DemoState());
  }

  @override
  Future<void> close() {
    _demoController.removeListener(_onControllerChanged);
    return super.close();
  }
}
