import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../../../core/models/avatar_config.dart';
import '../../../core/res/app_constants.dart';
import '../presentation/bloc/avatar_state.dart';
import 'base_avatar.dart';
import 'blinking_eyes.dart';
import 'clothes.dart';
import 'costumes/costume_widget.dart';
import 'talking_mouth.dart';

/// Widget that displays the avatar with slide animations
class AnimatedAvatar extends StatelessWidget {
  const AnimatedAvatar({
    super.key,
    required this.state,
    required this.animation,
  });

  final AvatarState state;
  final Animation<Offset> animation;

  @override
  Widget build(BuildContext context) {
    // Give the Stack an explicit size based on scaled avatar dimensions
    // This ensures consistent positioning across all platforms
    final double computedWidth = AppConstants.avatarWidth * state.scaleFactor;
    final double computedHeight = AppConstants.avatarHeight * state.scaleFactor;
    final double scaledWidth = computedWidth.isFinite && computedWidth > 0
        ? computedWidth
        : AppConstants.avatarWidth;
    final double scaledHeight = computedHeight.isFinite && computedHeight > 0
        ? computedHeight
        : AppConstants.avatarHeight;
    assert(() {
      debugPrint(
        '[AvatarDebug] Avatar on-screen width: ${scaledWidth.toStringAsFixed(2)}',
      );
      return true;
    }());

    return SlideTransition(
      position: animation,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: scaledWidth,
          height: scaledHeight,
          child: Stack(
            children: <Widget>[
              if (!state.avatar.hideBaseAvatar) const BaseAvatar(),
              if (!state.avatar.hideBlinkingEyes) const BlinkingEyes(),
              if (state.avatar.displaySunglasses) const Clothes(name: 'sunglasses'),
              if (!state.avatar.hideTalkingMouth) const TalkingMouth(),
              if (state.avatar.costume != AvatarCostume.none) const CostumeWidget(),
            ],
          ),
        ),
      ),
    );
  }
}
