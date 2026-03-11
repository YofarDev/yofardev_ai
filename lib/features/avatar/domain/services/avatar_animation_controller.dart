import '../../../../core/models/avatar_config.dart';
import '../../presentation/bloc/avatar_state.dart';

/// Interface for controlling avatar animations.
///
/// This interface abstracts the animation control methods, allowing
/// services to trigger animations without directly depending on the cubit.
abstract class AvatarAnimationController {
  /// Trigger clothes animation (dropping/rising).
  ///
  /// [goingDown] - true for dropping animation, false for rising
  void onClothesAnimationChanged(bool goingDown);

  /// Trigger background transition animation.
  ///
  /// [transition] - the type of background transition to apply
  void onBackgroundTransitionChanged(BackgroundTransition transition);

  /// Update the avatar configuration.
  ///
  /// [chatId] - the ID of the chat
  /// [avatarConfig] - the new avatar configuration to apply
  void updateAvatarConfig(String chatId, AvatarConfig avatarConfig);
}
