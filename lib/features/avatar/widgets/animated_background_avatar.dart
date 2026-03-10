import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/avatar_config.dart';
import '../../../../core/res/app_constants.dart';
import '../presentation/bloc/avatar_cubit.dart';
import '../presentation/bloc/avatar_state.dart';

class AnimatedBackgroundAvatar extends StatelessWidget {
  const AnimatedBackgroundAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AvatarCubit, AvatarState>(
      buildWhen: (AvatarState previous, AvatarState current) =>
          previous.avatar.background != current.avatar.background ||
          previous.backgroundTransition != current.backgroundTransition,
      builder: (BuildContext context, AvatarState state) {
        final double computedAvatarWidth =
            AppConstants.avatarWidth * state.scaleFactor;
        final double scaledAvatarWidth =
            computedAvatarWidth.isFinite && computedAvatarWidth > 0
            ? computedAvatarWidth
            : AppConstants.avatarWidth;

        return Positioned.fill(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: scaledAvatarWidth,
                  height: constraints.maxHeight,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return SlideTransition(
                            position:
                                Tween<Offset>(
                                  begin: const Offset(-1.0, 0.0),
                                  end: Offset.zero,
                                ).animate(
                                  CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeInOut,
                                  ),
                                ),
                            child: child,
                          );
                        },
                    child: Image.asset(
                      state.avatar.background.getPath(),
                      key: ValueKey<AvatarBackgrounds>(state.avatar.background),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
