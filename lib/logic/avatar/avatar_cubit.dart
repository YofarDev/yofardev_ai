import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/avatar.dart';
import '../../models/chat.dart';
import '../../res/app_constants.dart';
import '../../services/chat_history_service.dart';
import 'avatar_state.dart';

class AvatarCubit extends Cubit<AvatarState> {
  AvatarCubit() : super(const AvatarState());

  void initBaseValues({
    required double originalWidth,
    required double originalHeight,
    required double screenWidth,
  }) {
    final double scaleFactor = screenWidth / originalWidth;
    emit(
      state.copyWith(
        status: AvatarStatus.ready,
        baseOriginalWidth: originalWidth,
        baseOriginalHeight: originalHeight,
        scaleFactor: scaleFactor,
      ),
    );
  }

  void loadAvatar(String chatId) async {
    emit(state.copyWith(status: AvatarStatus.loading));
    final Chat chat = await ChatHistoryService().getChat(chatId) ??
        await ChatHistoryService().createNewChat();
    emit(state.copyWith(avatar: chat.avatar, status: AvatarStatus.ready));
  }

  void changeTopAvatar() {
    final AvatarTop current = state.avatar.top;
    const List<AvatarTop> topAvatars = AvatarTop.values;
    final int index = topAvatars.indexOf(current);
    final int newIndex = index != topAvatars.length - 1 ? index + 1 : 0;
    emit(
      state.copyWith(
        avatar: state.avatar.copyWith(top: topAvatars[newIndex]),
      ),
    );
  }

  void changeBottomAvatar() {
    final AvatarBottom current = state.avatar.bottom;
    const List<AvatarBottom> bottomAvatars = AvatarBottom.values;
    final int index = bottomAvatars.indexOf(current);
    final int newIndex = index != bottomAvatars.length - 1 ? index + 1 : 0;
    emit(
      state.copyWith(
        avatar: state.avatar.copyWith(bottom: bottomAvatars[newIndex]),
      ),
    );
  }

  void _goAndComeBack(String chatId, AvatarConfig avatarConfig) async {
    onAnimationStatusChanged(true);
    await Future<dynamic>.delayed(
      Duration(seconds: AppConstants().movingAvatarDuration),
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

  void onNewAvatarConfig(String chatId, AvatarConfig avatarConfig) {
    emit(state.copyWith(statusAnimation: AvatarStatusAnimation.initial));
    if (avatarConfig.specials.contains(AvatarSpecials.outOfScreen) &&
        avatarConfig.specials.contains(AvatarSpecials.onScreen)) {
      _goAndComeBack(chatId, avatarConfig);
    } else {
      if (avatarConfig.specials.isNotEmpty &&
          avatarConfig.specials.first != state.avatar.specials) {
        onAnimationStatusChanged(
            state.avatar.specials == AvatarSpecials.onScreen);
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
