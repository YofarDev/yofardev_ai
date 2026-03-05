import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../core/models/avatar_config.dart';
import '../../../core/res/app_constants.dart';
import '../../chat/domain/models/chat.dart';
import '../domain/repositories/avatar_repository.dart';
import 'avatar_state.dart';

class AvatarCubit extends Cubit<AvatarState> {
  AvatarCubit(this._avatarRepository)
    : super(const AvatarState(avatar: Avatar(), avatarConfig: AvatarConfig()));

  final AvatarRepository _avatarRepository;

  void setValuesBasedOnScreenWidth({required double screenWidth}) {
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
    emit(state.copyWith(scaleFactor: scaleFactor));
  }

  void loadAvatar(String chatId) async {
    emit(state.copyWith(status: AvatarStatus.loading));
    final Either<Exception, Chat> result = await _avatarRepository.getChat(
      chatId,
    );
    result.fold(
      (Exception error) {
        // This is expected for new chats - no custom avatar saved yet
        // Keep status as 'ready' to show default avatar on error
        // 'initial' would hide the avatar completely
        emit(state.copyWith(status: AvatarStatus.ready));
      },
      (Chat chat) {
        emit(state.copyWith(avatar: chat.avatar, status: AvatarStatus.ready));
      },
    );
  }

  void _goAndComeBack(String chatId, AvatarConfig avatarConfig) async {
    onAnimationStatusChanged(true);
    await Future<dynamic>.delayed(
      Duration(seconds: AppConstants.movingAvatarDuration),
    );
    _updateAvatar(chatId, avatarConfig);
    emit(state.copyWith(statusAnimation: AvatarStatusAnimation.initial));
    onAnimationStatusChanged(false);
    _updateAvatar(
      chatId,
      avatarConfig.copyWith(specials: AvatarSpecials.onScreen),
    );
  }

  void onAnimationStatusChanged(bool leaving) {
    emit(
      state.copyWith(
        statusAnimation: leaving
            ? AvatarStatusAnimation.leaving
            : AvatarStatusAnimation.coming,
        avatar: state.avatar.copyWith(
          specials: leaving
              ? AvatarSpecials.outOfScreen
              : AvatarSpecials.onScreen,
        ),
      ),
    );
  }

  void onNewAvatarConfig(String chatId, AvatarConfig avatarConfig) async {
    emit(state.copyWith(statusAnimation: AvatarStatusAnimation.initial));
    if (avatarConfig.specials == AvatarSpecials.leaveAndComeBack) {
      _goAndComeBack(chatId, avatarConfig);
    } else {
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

  void _updateAvatar(String chatId, AvatarConfig avatarConfig) {
    final Avatar avatar = state.avatar.copyWith(
      hat: avatarConfig.hat ?? state.avatar.hat,
      top: avatarConfig.top ?? state.avatar.top,
      glasses: avatarConfig.glasses ?? state.avatar.glasses,
      specials: avatarConfig.specials ?? state.avatar.specials,
      background: avatarConfig.background ?? state.avatar.background,
      costume: avatarConfig.costume ?? state.avatar.costume,
    );
    emit(
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
