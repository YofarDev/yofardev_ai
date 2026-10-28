import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/models/avatar_gesture.dart';
import '../../../../core/models/performance/performance.dart';

part 'performance_intent.freezed.dart';

/// Snapshot of everything the avatar view needs to render the current
/// performance state.
@freezed
sealed class PerformanceIntent with _$PerformanceIntent {
  const factory PerformanceIntent({
    @Default(EmotionVector()) EmotionVector emotion,
    @Default(ActionUnits.neutral) ActionUnits face,
    @Default(GazeTarget.user()) GazeTarget gaze,
    @Default(false) bool speaking,
    AvatarGesture? pendingGesture,
    @Default(0) int gestureSerial,
    String? activeTool,
  }) = _PerformanceIntent;
}
