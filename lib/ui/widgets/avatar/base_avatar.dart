import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../logic/avatar/avatar_cubit.dart';
import '../../../logic/avatar/avatar_state.dart';
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
                    context.read<AvatarCubit>().changeBottomAvatar();
                  },
                  child: Image.asset(
                    'assets/avatar/${state.avatar.bottom.name}.png',
                  ),
                ),
              ),
              Positioned.fill(
                top: null,
                bottom: AppConstants().topAvatarInvertedY * state.scaleFactor,
                child: GestureDetector(
                  onTap: () {
                    context.read<AvatarCubit>().changeTopAvatar();
                  },
                  child: Image.asset(
                    'assets/avatar/${state.avatar.top.name}.png',
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
