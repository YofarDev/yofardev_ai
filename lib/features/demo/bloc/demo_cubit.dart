import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/datasources/demo_controller.dart';
import '../domain/models/demo_script.dart';
import 'demo_state.dart';

/// Demo cubit for managing demo mode state
class DemoCubit extends Cubit<DemoState> {
  DemoCubit(this._demoController) : super(const DemoState()) {
    _demoController.addListener(_onControllerChanged);
  }

  final DemoController _demoController;

  void _onControllerChanged() {
    emit(
      state.copyWith(
        status: _demoController.status,
        countdownValue: _demoController.countdownValue,
      ),
    );
  }

  /// Start a demo with the given script
  void startDemo(DemoScript script) {
    emit(
      state.copyWith(
        currentScript: script,
        remainingResponses: script.responses.length,
      ),
    );
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
