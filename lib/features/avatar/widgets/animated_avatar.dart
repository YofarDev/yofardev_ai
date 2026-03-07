import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../../../core/models/avatar_config.dart';
import '../../../features/avatar/bloc/avatar_state.dart';
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
    return SlideTransition(
      position: animation,
      child: Stack(
        children: <Widget>[
          if (!state.avatar.hideBaseAvatar) const BaseAvatar(),
          if (!state.avatar.hideBlinkingEyes) const BlinkingEyes(),
          if (state.avatar.displaySunglasses) const Clothes(name: 'sunglasses'),
          if (!state.avatar.hideTalkingMouth) const TalkingMouth(),
          if (state.avatar.costume != AvatarCostume.none) const CostumeWidget(),
        ],
      ),
    );
  }
}
