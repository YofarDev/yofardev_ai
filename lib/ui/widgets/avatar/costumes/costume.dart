import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../logic/avatar/avatar_cubit.dart';
import '../../../../logic/avatar/avatar_state.dart';
import '../../../../models/avatar.dart';
import 'robocop_animated_eyes.dart';
import 'soubrette_feather_duster.dart';

class Costume extends StatelessWidget {
  const Costume({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AvatarCubit, AvatarState>(
      builder: (BuildContext context, AvatarState state) {
        return Stack(
          children: <Widget>[
            Positioned.fill(
              top: null,
              child: Image.asset(
                'assets/avatar/costumes/${state.avatar.costume.name}.png',
                fit: BoxFit.fitWidth,
              ),
            ),
            if (state.avatar.costume == AvatarCostume.robocop)
              const RobocopAnimatedEyes(),
            if (state.avatar.costume == AvatarCostume.soubrette)
              const SoubretteFeatherDuster(),
          ],
        );
      },
    );
  }
}
