import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../logic/avatar/avatar_cubit.dart';
import '../../../../logic/avatar/avatar_state.dart';
import '../../../../models/avatar.dart';
import 'robocop_animated_eyes.dart';
import 'singularity_costume.dart';
import 'soubrette_feather_duster.dart';

class CostumeWidget extends StatelessWidget {
  const CostumeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AvatarCubit, AvatarState>(
      builder: (BuildContext context, AvatarState state) {
        return Stack(
          children: <Widget>[
            if (state.avatar.costume != AvatarCostume.singularity)
              Positioned.fill(
                top: null,
                child: Image.asset(
                  'assets/avatar/costumes/${state.avatar.costume.name}.png',
                  fit: BoxFit.fitWidth,
                ),
              )
            else
              const Positioned.fill(
                top: null,
                child: SingularityCostume(),
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
