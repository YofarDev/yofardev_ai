import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../logic/avatar/avatar_cubit.dart';
import '../../../logic/avatar/avatar_state.dart';
import '../../../models/avatar.dart';
import '../../../res/app_constants.dart';

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
                          'assets/avatar/bottom/${state.avatar.bottom.name}.png',
                        )
                      : Image.asset(
                          'assets/avatar/costumes/emptyBot.png',
                        ),
                ),
              ),
              Positioned.fill(
                top: null,
                bottom: AppConstants().topAvatarInvertedY * state.scaleFactor,
                child: GestureDetector(
                  onTap: () {
                //    context.read<AvatarCubit>().changeTopAvatar();
                  },
                  child: state.avatar.costume == AvatarCostume.none
                      ? Image.asset(
                          'assets/avatar/top/${state.avatar.top.name}.png',
                        )
                      : Image.asset(
                          'assets/avatar/costumes/emptyTop.png',
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
