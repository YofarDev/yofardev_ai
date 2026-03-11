import 'package:freezed_annotation/freezed_annotation.dart';

// ignore: unused_import
import '../../../../core/models/avatar_config.dart';
// ignore: unused_import
import '../../presentation/bloc/avatar_state.dart';

part 'avatar_animation.freezed.dart';

/// Events that trigger avatar animations.
///
/// These events are emitted by [AvatarAnimationService] and consumed
/// by [AvatarCubit] to coordinate avatar animations across features.
@freezed
sealed class AvatarAnimation with _$AvatarAnimation {
  /// Trigger clothes dropping/rising animation.
  ///
  /// [goingDown] - true for dropping, false for rising
  const factory AvatarAnimation.clothes(bool goingDown) =
      AvatarAnimationClothes;

  /// Trigger background transition animation.
  ///
  /// [transition] - the type of background transition
  const factory AvatarAnimation.background(BackgroundTransition transition) =
      AvatarAnimationBackground;

  /// Update the avatar configuration.
  ///
  /// [chatId] - the ID of the chat
  /// [avatarConfig] - the new avatar configuration to apply
  const factory AvatarAnimation.updateConfig(
    String chatId,
    AvatarConfig avatarConfig,
  ) = AvatarAnimationUpdateConfig;
}
