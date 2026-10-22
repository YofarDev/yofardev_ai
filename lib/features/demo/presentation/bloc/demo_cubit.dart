import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/demo_script.dart';
import '../../domain/services/demo_controller.dart';
import '../../domain/services/demo_service.dart';
import 'demo_state.dart';

/// Demo cubit for managing demo mode state
class DemoCubit extends Cubit<DemoState> {
  DemoCubit({
    required DemoController demoController,
    required DemoService demoService,
  }) : _demoController = demoController,
       _demoService = demoService,
       super(const DemoState()) {
    _demoController.addListener(_onControllerChanged);
  }

  final DemoController _demoController;
  final DemoService _demoService;

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

  /// Activate demo mode on the service, then reflect it in state.
  Future<void> startDemoMode({
    required String chatId,
    required DemoScript script,
  }) async {
    await _demoService.activateDemo(chatId: chatId, script: script);
    startDemo(script);
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
