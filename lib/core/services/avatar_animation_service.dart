import 'dart:async';

import '../../../core/res/app_constants.dart';
import '../../../core/models/avatar_config.dart';
import '../../features/avatar/presentation/bloc/avatar_cubit.dart';
import '../../features/avatar/presentation/bloc/avatar_state.dart';

/// Service for orchestrating avatar animations across features.
///
/// This service provides a centralized way to trigger avatar animations
/// without creating cross-feature dependencies.
class AvatarAnimationService {
  const AvatarAnimationService(this._avatarCubit);

  final AvatarCubit _avatarCubit;

  /// Plays the new chat creation animation sequence.
  ///
  /// Sequence:
  /// 1. Avatar drops down (off-screen)
  /// 2. Background slides horizontally
  /// 3. Avatar rises back up
  Future<void> playNewChatSequence(String chatId, AvatarConfig config) async {
    // 1. Avatar drops
    _avatarCubit.onClothesAnimationChanged(true);
    await Future<void>.delayed(
      Duration(seconds: AppConstants.changingAvatarDuration),
    );

    // 2. Background slides (while avatar is off-screen)
    _avatarCubit.onBackgroundTransitionChanged(BackgroundTransition.sliding);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _avatarCubit.updateAvatarConfig(chatId, config);

    // 3. Avatar rises
    _avatarCubit.onClothesAnimationChanged(false);
  }
}
