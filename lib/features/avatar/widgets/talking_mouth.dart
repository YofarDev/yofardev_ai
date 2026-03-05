import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../talking/bloc/talking_cubit.dart';
import '../../talking/bloc/talking_state.dart';
import '../../../core/res/app_constants.dart';
import '../../../core/utils/app_utils.dart';
import 'scaled_avatar_item.dart';

class TalkingMouth extends StatefulWidget {
  const TalkingMouth({super.key});

  @override
  State<TalkingMouth> createState() => _TalkingMouthState();
}

class _TalkingMouthState extends State<TalkingMouth> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TalkingCubit, TalkingState>(
      builder: (BuildContext context, TalkingState state) {
        // Show thinking only when generating, NOT waiting
        if (state.shouldShowTalking) {
          return const ThinkingAnimation();
        }

        // For now, show idle mouth for all states
        // In future, will integrate with actual TTS playback to animate mouth
        return ScaledAvatarItem(
          path: _getMouthPath(MouthState.closed),
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

// Placeholder for thinking animation widget
class ThinkingAnimation extends StatelessWidget {
  const ThinkingAnimation({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaledAvatarItem(
      path: AppUtils.fixAssetsPath('assets/avatar/mouth/mouth_closed.png'),
      itemX: AppConstants.mouthX,
      itemY: AppConstants.mouthY,
    );
  }
}

enum MouthState { closed, semi, open }

// TODO: Remove these after full migration - keeping for compilation compatibility
// These will be replaced with proper imports from the new architecture
