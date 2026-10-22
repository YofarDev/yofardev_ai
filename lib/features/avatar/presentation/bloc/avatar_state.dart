import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/models/avatar_config.dart';
import '../../../../core/models/avatar_status_animation.dart';
import '../../domain/models/background_transition.dart';

export '../../../../core/models/avatar_status_animation.dart';
export '../../domain/models/background_transition.dart';

part 'avatar_state.freezed.dart';

enum AvatarStatus { initial, ready, loading }

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
    @Default(BackgroundTransition.none)
    BackgroundTransition backgroundTransition,
  }) = _AvatarState;
}
