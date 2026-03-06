import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/res/app_constants.dart';
import '../../../core/utils/app_utils.dart';
import '../../talking/presentation/bloc/talking_cubit.dart';
import '../../talking/presentation/bloc/talking_state.dart';
import 'scaled_avatar_item.dart';

class TalkingMouth extends StatelessWidget {
  const TalkingMouth({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TalkingCubit, TalkingState>(
      builder: (BuildContext context, TalkingState state) {
        final String mouthPath = _getMouthPath(state.mouthState);

        return ScaledAvatarItem(
          path: mouthPath,
          itemX: AppConstants.mouthX,
          itemY: AppConstants.mouthY,
        );
      },
    );
  }

  String _getMouthPath(MouthState mouthState) {
    return AppUtils.fixAssetsPath(
      'assets/avatar/mouth/mouth_${mouthState.name}.png',
    );
  }
}
