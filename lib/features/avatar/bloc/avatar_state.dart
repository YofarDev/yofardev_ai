import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/models/avatar_config.dart';

part 'avatar_state.freezed.dart';

enum AvatarStatus { initial, ready, loading }

enum AvatarStatusAnimation {
  initial,
  leaving, // Horizontal slide out (left)
  coming, // Horizontal slide in (from left)
  transition, // General transition
  dropping, // Vertical slide down (for clothes change)
  rising, // Vertical slide up (return after clothes change)
}

@freezed
sealed class AvatarState with _$AvatarState {
  const AvatarState._();

  const factory AvatarState({
    @Default(AvatarStatus.initial) AvatarStatus status,
    @Default(AvatarStatusAnimation.initial)
    AvatarStatusAnimation statusAnimation,
    @Default(0.0) double baseOriginalWidth,
    @Default(0.0) double baseOriginalHeight,
    @Default(1.0) double scaleFactor,
    required Avatar avatar,
    required AvatarConfig avatarConfig,
    @Default(AvatarSpecials.onScreen) AvatarSpecials previousSpecialsState,
  }) = _AvatarState;
}
