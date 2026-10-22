import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';

import '../presentation/bloc/avatar_cubit.dart';
import '../presentation/bloc/avatar_state.dart';
import '../../../core/res/app_constants.dart';
import '../../../core/utils/app_utils.dart';

class ThinkingAnimation extends StatelessWidget {
  const ThinkingAnimation({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AvatarCubit, AvatarState>(
      builder: (BuildContext context, AvatarState state) {
        return Positioned(
          bottom:
              MediaQuery.of(context).viewInsets.bottom +
              AppConstants.loadingInvertedY * state.scaleFactor,
          left: AppConstants.loadingX * state.scaleFactor,
          child: Lottie.asset(
            AppUtils.fixAssetsPath('assets/lotties/typing.json'),
            height: 60,
          ),
        );
      },
    );
  }
}
