import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/avatar.dart';
import '../../models/chat.dart';
import '../../models/sound_effects.dart';
import '../../res/app_constants.dart';
import '../../services/chat_history_service.dart';
import '../../services/sound_service.dart';
import 'avatar_state.dart';

class AvatarCubit extends Cubit<AvatarState> {
  AvatarCubit() : super(const AvatarState());

  void setValuesBasedOnScreenWidth({
    required double screenWidth,
  }) {
    final double scaleFactor = screenWidth / AppConstants.avatarWidth;
    emit(
      state.copyWith(
        status: AvatarStatus.ready,
        baseOriginalWidth: AppConstants.avatarWidth,
        baseOriginalHeight: AppConstants.avatarHeight,
        scaleFactor: scaleFactor,
      ),
    );
  }

  void onScreenSizeChanged(double screenWidth) {
    final double scaleFactor = screenWidth / state.baseOriginalWidth;
    emit(
      state.copyWith(
        scaleFactor: scaleFactor,
      ),
    );
  }

  void loadAvatar(String chatId) async {
    emit(state.copyWith(status: AvatarStatus.loading));
    final Chat chat = await ChatHistoryService().getChat(chatId) ??
        await ChatHistoryService().createNewChat();
    emit(
      state.copyWith(
        avatar: chat.avatar,
        status: AvatarStatus.ready,
      ),
    );
  }

  // Horizontal animation (location changes) - avatar goes left and comes back
  void _goAndComeBack(String chatId, AvatarConfig avatarConfig) async {
    // Wait 1 second before starting the animation
    await Future<dynamic>.delayed(const Duration(seconds: 1));

    // Start leaving animation
    emit(
      state.copyWith(
        statusAnimation: AvatarStatusAnimation.leaving,
        avatar: state.avatar.copyWith(specials: AvatarSpecials.outOfScreen),
      ),
    );

    await Future<dynamic>.delayed(
      Duration(seconds: AppConstants.movingAvatarDuration),
    );

    // Update avatar while off-screen
    _updateAvatar(chatId, avatarConfig);

    // Start coming back animation
    emit(
      state.copyWith(
        statusAnimation: AvatarStatusAnimation.coming,
        avatar: state.avatar.copyWith(specials: AvatarSpecials.onScreen),
      ),
    );

    // Reset animation state after transition completes
    await Future<dynamic>.delayed(
      Duration(seconds: AppConstants.movingAvatarDuration),
    );
    emit(state.copyWith(statusAnimation: AvatarStatusAnimation.initial));
  }

  // Vertical animation (clothes changes) - avatar drops down and comes back up
  void _dropAndComeBack(String chatId, AvatarConfig avatarConfig) async {
    // Play whoosh sound effect when dropping starts
    SoundService().playSoundEffect(SoundEffects.whoosh, volume: 0.4);

    // Start dropping animation
    emit(
      state.copyWith(
        statusAnimation: AvatarStatusAnimation.dropping,
        avatar: state.avatar.copyWith(specials: AvatarSpecials.outOfScreen),
      ),
    );

    await Future<dynamic>.delayed(const Duration(milliseconds: 600));

    // Update avatar while off-screen
    _updateAvatar(chatId, avatarConfig);

    // Start rising animation
    emit(
      state.copyWith(
        statusAnimation: AvatarStatusAnimation.rising,
        avatar: state.avatar.copyWith(specials: AvatarSpecials.onScreen),
      ),
    );

    // Reset animation state after transition completes
    await Future<dynamic>.delayed(const Duration(milliseconds: 600));
    emit(state.copyWith(statusAnimation: AvatarStatusAnimation.initial));
  }

  void onAnimationStatusChanged(bool leaving) {
    emit(
      state.copyWith(
        statusAnimation: leaving
            ? AvatarStatusAnimation.leaving
            : AvatarStatusAnimation.coming,
        avatar: state.avatar.copyWith(
          specials:
              leaving ? AvatarSpecials.outOfScreen : AvatarSpecials.onScreen,
        ),
      ),
    );
  }

  void onNewAvatarConfig(String chatId, AvatarConfig avatarConfig) async {
    emit(state.copyWith(statusAnimation: AvatarStatusAnimation.initial));

    // Check what type of change we have
    final _AnimationType animationType = _getAnimationType(avatarConfig);

    switch (animationType) {
      case _AnimationType.locationChange:
        // Use horizontal animation for location changes
        _goAndComeBack(chatId, avatarConfig);
      case _AnimationType.clothesChange:
        // Use vertical animation for clothes changes
        _dropAndComeBack(chatId, avatarConfig);
      case _AnimationType.none:
        // No animation needed, just update
        if (avatarConfig.specials != null &&
            avatarConfig.specials != state.previousSpecialsState) {
          onAnimationStatusChanged(
            state.avatar.specials == AvatarSpecials.onScreen,
          );
          // we wait it's out of screen before to update appearance
          if (avatarConfig.specials == AvatarSpecials.outOfScreen) {
            await Future<dynamic>.delayed(
              Duration(seconds: AppConstants.movingAvatarDuration),
            );
          }
        }
        _updateAvatar(chatId, avatarConfig);
    }
  }

  /// Determines the type of animation based on what changed.
  _AnimationType _getAnimationType(AvatarConfig avatarConfig) {
    // Check for background change (location) -> horizontal animation
    if (avatarConfig.background != null &&
        avatarConfig.background != state.avatar.background) {
      return _AnimationType.locationChange;
    }

    // Check for clothes/costume change (hat, top, or costume) -> vertical animation
    if ((avatarConfig.hat != null && avatarConfig.hat != state.avatar.hat) ||
        (avatarConfig.top != null && avatarConfig.top != state.avatar.top) ||
        (avatarConfig.costume != null && avatarConfig.costume != state.avatar.costume)) {
      return _AnimationType.clothesChange;
    }

    return _AnimationType.none;
  }

  void _updateAvatar(String chatId, AvatarConfig avatarConfig) {
    final Avatar avatar = state.avatar.copyWith(
      hat: avatarConfig.hat,
      top: avatarConfig.top,
      glasses: avatarConfig.glasses,
      specials: avatarConfig.specials,
      background: avatarConfig.background,
      costume: avatarConfig.costume,
    );
    emit(
      state.copyWith(
        avatar: avatar,
        previousSpecialsState: avatarConfig.specials,
      ),
    );
    ChatHistoryService().updateAvatar(chatId, avatar);
  }

  void toggleGlasses() {
    final AvatarGlasses glasses = state.avatar.glasses == AvatarGlasses.glasses
        ? AvatarGlasses.sunglasses
        : AvatarGlasses.glasses;
    emit(
      state.copyWith(
        avatar: state.avatar.copyWith(glasses: glasses),
      ),
    );
  }
}

enum _AnimationType {
  locationChange,  // Background changed -> horizontal slide
  clothesChange,   // Hat/Top changed -> vertical drop
  none,            // No animation needed
}
