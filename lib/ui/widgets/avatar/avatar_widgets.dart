import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../logic/avatar/avatar_cubit.dart';
import '../../../logic/avatar/avatar_state.dart';
import '../../../models/avatar.dart';
import '../../../res/app_constants.dart';
import 'base_avatar.dart';
import 'blinking_eyes.dart';
import 'clothes.dart';
import 'costume.dart';
import 'talking_mouth.dart';

class AvatarWidgets extends StatefulWidget {
  const AvatarWidgets({super.key});

  @override
  _AvatarWidgetsState createState() => _AvatarWidgetsState();
}

class _AvatarWidgetsState extends State<AvatarWidgets>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _positionAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: AppConstants().movingAvatarDuration),
      vsync: this,
    );

    _positionAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.5, 0),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.linear,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AvatarCubit, AvatarState>(
      builder: (BuildContext context, AvatarState state) {
        return BlocListener<AvatarCubit, AvatarState>(
          listenWhen: (AvatarState previous, AvatarState current) =>
              previous.avatar.specials != current.avatar.specials,
          listener: (BuildContext context, AvatarState state) {
            if (state.avatar.specials == AvatarSpecials.outOfScreen) {
              _controller.forward();
            } else {
              _controller.reverse();
            }
          },
          child: SlideTransition(
            position: _positionAnimation,
            child: Stack(
              children: <Widget>[
                const BaseAvatar(),
                const BlinkingEyes(),
                if (state.avatar.glasses == AvatarGlasses.sunglasses && state.avatar.costume == AvatarCostume.none)
                  const Clothes(name: 'sunglasses'),
                const TalkingMouth(),
                if (state.avatar.costume != AvatarCostume.none) const Costume(),
              ],
            ),
          ),
        );
      },
    );
  }
}
