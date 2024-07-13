import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../logic/avatar/avatar_cubit.dart';
import '../../../logic/avatar/avatar_state.dart';

class Costume extends StatelessWidget {
  const Costume({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AvatarCubit, AvatarState>(
      builder: (BuildContext context, AvatarState state) {
        return Positioned.fill(
          top: null,
          child: Image.asset(
            'assets/avatar/costumes/${state.avatar.costume.name}.png',
          ),
        );
      },
    );
  }
}
