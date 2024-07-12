import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/avatar.dart';
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

  void resetAvatar(){
    emit(state.copyWith(avatar: const Avatar()));
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

  void changeOutOfScreenStatus() {
    final AvatarSpecials specials =
        state.avatar.specials == AvatarSpecials.onScreen
            ? AvatarSpecials.outOfScreen
            : AvatarSpecials.onScreen;
    emit(
      state.copyWith(
        avatar: state.avatar.copyWith(specials: specials),
      ),
    );
  }

  void onNewAvatarConfig(AvatarConfig avatarConfig) {
    if (avatarConfig.specials.contains(AvatarSpecials.outOfScreen) &&
        avatarConfig.specials.contains(AvatarSpecials.onScreen)) {
      _outAndInAnimation(avatarConfig);
    } else {
      if (avatarConfig.specials.isNotEmpty) {
        changeOutOfScreenStatus();
      }
      _updateAvatar(avatarConfig);
    }
  }

  void _updateAvatar(AvatarConfig avatarConfig) {
    final Avatar avatar = state.avatar.copyWith(
      top: avatarConfig.top.lastOrNull,
      bottom: avatarConfig.bottom.lastOrNull,
      glasses: avatarConfig.glasses.lastOrNull,
      specials: avatarConfig.specials.lastOrNull,
    );
    emit(state.copyWith(avatar: avatar));
  }

  void _outAndInAnimation(AvatarConfig avatarConfig) async {
    changeOutOfScreenStatus();
    _updateAvatar(avatarConfig);
    await Future<dynamic>.delayed(const Duration(seconds: 4));
    changeOutOfScreenStatus();
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
