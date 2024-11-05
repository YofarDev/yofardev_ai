import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/avatar.dart';
import '../../models/chat.dart';
import '../../res/app_constants.dart';
import '../../services/chat_history_service.dart';
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
      avatarConfig
          .copyWith(specials: AvatarSpecials.onScreen),
    );
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
    if (avatarConfig.specials == AvatarSpecials.leaveAndComeBack) {
      _goAndComeBack(chatId, avatarConfig);
    } else {
      if (avatarConfig.specials != null) {
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
      hat: avatarConfig.hat,
      top: avatarConfig.top,
      glasses: avatarConfig.glasses,
      specials: avatarConfig.specials,
      background: avatarConfig.background,
      costume: avatarConfig.costume,
    );
    emit(state.copyWith(avatar: avatar));
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
