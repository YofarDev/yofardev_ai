import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/res/app_constants.dart';
import '../presentation/bloc/avatar_cubit.dart';
import '../presentation/bloc/avatar_state.dart';
import '../../../../core/models/avatar_config.dart';

class BackgroundAvatar extends StatelessWidget {
  const BackgroundAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AvatarCubit, AvatarState>(
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
                  child: Image.asset(
                    state.avatar.background.getPath(),
                    fit: BoxFit.cover,
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
