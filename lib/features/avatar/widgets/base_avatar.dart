import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/avatar_cubit.dart';
import '../../../features/avatar/bloc/avatar_state.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/res/app_constants.dart';
import '../../../core/utils/app_utils.dart';

class BaseAvatar extends StatelessWidget {
  const BaseAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AvatarCubit, AvatarState>(
      builder: (BuildContext context, AvatarState state) {
        if (state.status == AvatarStatus.initial) return Container();
        return Positioned.fill(
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                top: null,
                child: GestureDetector(
                  onTap: () {
                    //   context.read<AvatarCubit>().changeBottomAvatar();
                  },
                  child: state.avatar.costume == AvatarCostume.none
                      ? Image.asset(
                          AppUtils.fixAssetsPath(
                            'assets/avatar/bottom/${state.avatar.top == AvatarTop.underwear ? AvatarTop.swimsuit.name : state.avatar.top.name}.png',
                          ),
                        )
                      : Image.asset(
                          AppUtils.fixAssetsPath(
                            'assets/avatar/bottom/emptyBot.png',
                          ),
                        ),
                ),
              ),
              Positioned.fill(
                top: null,
                bottom: AppConstants.topAvatarInvertedY * state.scaleFactor,
                child: GestureDetector(
                  onTap: () {
                    //    context.read<AvatarCubit>().changeTopAvatar();
                  },
                  child: state.avatar.costume == AvatarCostume.none
                      ? Image.asset(
                          AppUtils.fixAssetsPath(
                            'assets/avatar/top/${state.avatar.hat.name}.png',
                          ),
                        )
                      : Image.asset(
                          AppUtils.fixAssetsPath(
                            'assets/avatar/top/emptyTop.png',
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
