import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/models/demo_script.dart';
import '../data/datasources/demo_controller.dart';

part 'demo_state.freezed.dart';

@freezed
sealed class DemoState with _$DemoState {
  const DemoState._();

  const factory DemoState({
    @Default(DemoStatus.idle) DemoStatus status,
    @Default(0) int countdownValue,
    DemoScript? currentScript,
    @Default(0) int remainingResponses,
  }) = _DemoState;

  bool get isIdle => status == DemoStatus.idle;
  bool get isCountingDown => status == DemoStatus.countdown;
  bool get isActive => status == DemoStatus.active;
  bool get isCompleted => status == DemoStatus.completed;
}
