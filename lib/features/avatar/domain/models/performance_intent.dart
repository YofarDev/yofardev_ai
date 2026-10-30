import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/models/avatar_gesture.dart';
import '../../../../core/models/performance/performance.dart';

part 'performance_intent.freezed.dart';

/// A brief face reaction to a typed punctuation mark.
enum PresenceReaction {
  /// A `?`: both brows up and a small head tilt.
  question,

  /// A `!`: the outer brows and the upper lids lift.
  exclaim,
}

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

    /// The prop held (a state, not a gesture): gestures wait while it is out.
    @Default(AvatarProp.none) AvatarProp prop,

    /// Target of the listening lean, 0..1 (0.6 while the user types).
    @Default(0) double lean,

    /// Increments once per backchannel nod the user's typing earns.
    @Default(0) int nodSerial,

    /// The latest typed-punctuation reaction and its counter.
    PresenceReaction? reaction,
    @Default(0) int reactionSerial,

    /// Idle ladder stage, 0 (active) to 3 (long idle).
    @Default(0) int idleStage,

    /// The tablet's weather card (M8 ruling 14): the looked-up city's glyph
    /// and rounded °C while the tablet is out for a weather lookup, else
    /// `none` / 0 (the generic card).
    @Default(TabletWeather.none) TabletWeather tabletWeather,
    @Default(0) int tabletTemp,
  }) = _PerformanceIntent;
}
