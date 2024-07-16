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
          .copyWith(specials: <AvatarSpecials>[AvatarSpecials.onScreen]),
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
    // if animation of both leaving and coming back
    if (avatarConfig.specials.contains(AvatarSpecials.outOfScreen) &&
        avatarConfig.specials.contains(AvatarSpecials.onScreen)) {
      _goAndComeBack(chatId, avatarConfig);
    } else {
      // if only one of the animation
      if (avatarConfig.specials.isNotEmpty &&
          avatarConfig.specials.first != state.avatar.specials) {
        onAnimationStatusChanged(
          state.avatar.specials == AvatarSpecials.onScreen,
        );
        // we wait it's out of screen before to update appearance
        if (avatarConfig.specials.contains(AvatarSpecials.outOfScreen)) {
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
      top: avatarConfig.top.lastOrNull,
      bottom: avatarConfig.bottom.lastOrNull,
      glasses: avatarConfig.glasses.lastOrNull,
      specials: avatarConfig.specials.lastOrNull,
      background: avatarConfig.backgrounds.lastOrNull,
      costume: avatarConfig.costume.lastOrNull,
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

  AvatarConfig setAvatarConfigFromNewAnswer(List<String> annotations) {
    final AvatarConfig avatarConfig = annotations.getAvatarConfig();
    emit(state.copyWith(avatarConfig: avatarConfig));
    return avatarConfig;
  }
}
