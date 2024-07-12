import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../logic/avatar/avatar_cubit.dart';
import '../../../logic/avatar/avatar_state.dart';
import '../../../models/avatar.dart';

class BackgroundAvatar extends StatelessWidget {
  const BackgroundAvatar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AvatarCubit, AvatarState>(
      builder: (BuildContext context, AvatarState state) {
        return Positioned.fill(
          child: Image.asset(
            state.avatar.background.getPath(),
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }
}
