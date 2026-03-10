import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/models/avatar_config.dart';
import '../../../../core/res/app_constants.dart';
import '../../../../core/utils/logger.dart';
import '../../../chat/domain/models/chat.dart';
import '../../domain/repositories/avatar_repository.dart';
import 'avatar_state.dart';

class AvatarCubit extends Cubit<AvatarState> {
  AvatarCubit(this._avatarRepository)
    : super(const AvatarState(avatar: Avatar(), avatarConfig: AvatarConfig()));

  final AvatarRepository _avatarRepository;

  void _emitIfOpen(AvatarState newState) {
    if (isClosed) return;
    emit(newState);
  }

  void setValuesBasedOnScreenWidth({required double screenWidth}) {
    if (!screenWidth.isFinite || screenWidth <= 0) return;
    final double scaleFactor = screenWidth / AppConstants.avatarWidth;
    _emitIfOpen(
      state.copyWith(
        status: AvatarStatus.ready,
        baseOriginalWidth: AppConstants.avatarWidth,
        baseOriginalHeight: AppConstants.avatarHeight,
        scaleFactor: scaleFactor,
      ),
    );
  }

  void onScreenSizeChanged(double screenWidth) {
    if (!screenWidth.isFinite || screenWidth <= 0) return;
    if (!state.baseOriginalWidth.isFinite || state.baseOriginalWidth <= 0) {
      setValuesBasedOnScreenWidth(screenWidth: screenWidth);
      return;
    }
    final double scaleFactor = screenWidth / state.baseOriginalWidth;
    if (!scaleFactor.isFinite || scaleFactor <= 0) {
      setValuesBasedOnScreenWidth(screenWidth: screenWidth);
      return;
    }
    _emitIfOpen(state.copyWith(scaleFactor: scaleFactor));
  }

  void loadAvatar(String chatId) async {
    _emitIfOpen(state.copyWith(status: AvatarStatus.loading));
    final Either<Exception, Chat> result = await _avatarRepository.getChat(
      chatId,
    );
    if (isClosed) return;
    result.fold(
      (Exception error) {
        // This is expected for new chats - no custom avatar saved yet
        // Only set status to ready if dimensions are initialized
        if (state.baseOriginalHeight > 0) {
          _emitIfOpen(state.copyWith(status: AvatarStatus.ready));
        }
      },
      (Chat chat) {
        // Only set status to ready if dimensions are initialized
        if (state.baseOriginalHeight > 0) {
          _emitIfOpen(
            state.copyWith(avatar: chat.avatar, status: AvatarStatus.ready),
          );
        } else {
          _emitIfOpen(state.copyWith(avatar: chat.avatar));
        }
      },
    );
  }

  void _goAndComeBack(String chatId, AvatarConfig avatarConfig) async {
    onAnimationStatusChanged(true);
    await Future<dynamic>.delayed(
      Duration(seconds: AppConstants.movingAvatarDuration),
    );
    if (isClosed) return;

    // Set animation to "coming" FIRST, then update avatar
    // This ensures background changes while avatar is coming back
    onAnimationStatusChanged(false);
    _updateAvatar(chatId, avatarConfig);
  }

  void onAnimationStatusChanged(bool leaving) {
    _emitIfOpen(
      state.copyWith(
        statusAnimation: leaving
            ? AvatarStatusAnimation.leaving
            : AvatarStatusAnimation.coming,
        avatar: state.avatar.copyWith(
          specials: leaving
              ? AvatarSpecials.outOfScreen
              : AvatarSpecials.onScreen,
        ),
        previousSpecialsState: leaving
            ? AvatarSpecials.outOfScreen
            : AvatarSpecials.onScreen,
      ),
    );
  }

  void onClothesAnimationChanged(bool goingDown) {
    _emitIfOpen(
      state.copyWith(
        statusAnimation: goingDown
            ? AvatarStatusAnimation.dropping
            : AvatarStatusAnimation.rising,
        avatar: state.avatar.copyWith(
          specials: goingDown
              ? AvatarSpecials.outOfScreen
              : AvatarSpecials.onScreen,
        ),
        previousSpecialsState: goingDown
            ? AvatarSpecials.outOfScreen
            : AvatarSpecials.onScreen,
      ),
    );
  }

  void _goDownAndUp(String chatId, AvatarConfig avatarConfig) async {
    onClothesAnimationChanged(true); // dropping
    AudioPlayer player = AudioPlayer();
    player.play(AssetSource("assets/sound_effects/whoosh.wav"));
    await Future<dynamic>.delayed(
      Duration(seconds: AppConstants.changingAvatarDuration),
    );
    if (isClosed) return;
    _updateAvatar(chatId, avatarConfig);
    onClothesAnimationChanged(false); // rising
  }

  void onNewAvatarConfig(String chatId, AvatarConfig avatarConfig) async {
    AppLogger.debug(
      'onNewAvatarConfig called with specials: ${avatarConfig.specials}',
      tag: 'AvatarCubit',
    );

    _emitIfOpen(state.copyWith(statusAnimation: AvatarStatusAnimation.initial));

    if (avatarConfig.specials == AvatarSpecials.leaveAndComeBack) {
      AppLogger.debug('Using leaveAndComeBack animation', tag: 'AvatarCubit');
      _goAndComeBack(chatId, avatarConfig);
    } else if (avatarConfig.specials == AvatarSpecials.outOfScreen) {
      AppLogger.debug('Using goDownAndUp animation', tag: 'AvatarCubit');
      // Clothes change: use dropping/rising animation
      _goDownAndUp(chatId, avatarConfig);
    } else {
      AppLogger.debug(
        'No special animation, updating directly',
        tag: 'AvatarCubit',
      );
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
          if (isClosed) return;
        }
      }
      _updateAvatar(chatId, avatarConfig);
    }
  }

  void _updateAvatar(String chatId, AvatarConfig avatarConfig) {
    final Avatar avatar = state.avatar.copyWith(
      hat: avatarConfig.hat ?? state.avatar.hat,
      top: avatarConfig.top ?? state.avatar.top,
      glasses: avatarConfig.glasses ?? state.avatar.glasses,
      specials: avatarConfig.specials ?? state.avatar.specials,
      background: avatarConfig.background ?? state.avatar.background,
      costume: avatarConfig.costume ?? state.avatar.costume,
    );
    _emitIfOpen(
      state.copyWith(
        avatar: avatar,
        previousSpecialsState:
            avatarConfig.specials ?? state.previousSpecialsState,
      ),
    );
    _avatarRepository.updateAvatar(chatId, avatar);
  }

  void toggleGlasses() {
    final AvatarGlasses glasses = state.avatar.glasses == AvatarGlasses.glasses
        ? AvatarGlasses.sunglasses
        : AvatarGlasses.glasses;
    emit(state.copyWith(avatar: state.avatar.copyWith(glasses: glasses)));
  }
}
