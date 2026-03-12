import 'package:flutter/material.dart';

import '../../../core/res/app_constants.dart';
import '../../../core/utils/app_utils.dart';
import '../../talking/presentation/bloc/talking_state.dart';
import 'scaled_avatar_item.dart';

class TalkingMouth extends StatelessWidget {
  const TalkingMouth({super.key, this.mouthState});

  final MouthState? mouthState;

  @override
  Widget build(BuildContext context) {
    if (mouthState == null) return const SizedBox.shrink();

    final String mouthPath = _getMouthPath(mouthState!);

    return ScaledAvatarItem(
      path: mouthPath,
      itemX: AppConstants.mouthX,
      itemY: AppConstants.mouthY,
    );
  }

  String _getMouthPath(MouthState state) {
    return AppUtils.fixAssetsPath(
      'assets/avatar/mouth/mouth_${state.name}.png',
    );
  }
}
