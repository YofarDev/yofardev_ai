import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../talking/presentation/bloc/talking_cubit.dart';
import '../../talking/presentation/bloc/talking_state.dart';
import '../../../core/res/app_constants.dart';
import '../../../core/utils/app_utils.dart';
import '../../../core/utils/logger.dart';
import 'scaled_avatar_item.dart';

class TalkingMouth extends StatelessWidget {
  const TalkingMouth({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TalkingCubit, TalkingState>(
      builder: (BuildContext context, TalkingState state) {
        final String mouthPath = _getMouthPath(state.mouthState);

        // Debug logging to verify rebuilds
        AppLogger.debug(
          'TalkingMouth: Rebuilding with state: ${state.runtimeType}, mouthState: ${state.mouthState.name}, path: ${mouthPath.split('/').last}',
          tag: 'TalkingMouth',
        );

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
