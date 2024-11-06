import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';

import '../../../logic/avatar/avatar_cubit.dart';
import '../../../logic/chat/chats_cubit.dart';
import '../../../logic/talking/talking_cubit.dart';
import '../../../models/answer.dart';
import '../../../res/app_constants.dart';
import '../../../utils/platform_utils.dart';
import 'scaled_avatar_item.dart';

class TalkingMouth extends StatelessWidget {
  const TalkingMouth({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<TalkingCubit, TalkingState>(
      listenWhen: (TalkingState previous, TalkingState current) =>
          previous.status != current.status,
      listener: (BuildContext context, TalkingState state) {
        if (state.status == TalkingStatus.success) {
          if (context.read<AvatarCubit>().state.avatar.hideTalkingMouth) return;
          if (checkPlatform() == 'Web') {
            _fakeTalking(context);
          } else {
            _startTalking(context, state.answer);
          }
        }
      },
      child: BlocBuilder<TalkingCubit, TalkingState>(
        builder: (BuildContext context, TalkingState state) {
          return ScaledAvatarItem(
            path: state.isTalking
                ? _getMouthPath(state.mouthState)
                : _getMouthPath(MouthState.closed),
            itemX: AppConstants.mouthX,
            itemY: AppConstants.mouthY,
          );
        },
      ),
    );
  }

  void _startTalking(BuildContext context, Answer answer) async {
    if (answer.amplitudes.isEmpty) {
      return context.read<TalkingCubit>().stopTalking(
            noFile: true,
            soundEffectsEnabled:
                context.read<ChatsCubit>().state.soundEffectsEnabled,
          );
    }
    final AudioPlayer player = AudioPlayer();
    await player.setFilePath(answer.audioPath, initialPosition: Duration.zero);
    final int totalFrames = answer.amplitudes.length;
    final int updateInterval =
        (player.duration!.inMilliseconds / totalFrames).round();
    int currentIndex = 0;
    Timer.periodic(Duration(milliseconds: updateInterval), (Timer timer) {
      if (currentIndex >= totalFrames) {
        timer.cancel();
        player.dispose();
        return;
      } else {
        try {
          context.read<TalkingCubit>().updateMouthState(
                _getMouthState(answer.amplitudes[currentIndex]),
              );
          currentIndex++;
        } catch (e) {
          timer.cancel();
          player.dispose();
          debugPrint('talking mouth error: $e');
        }
      }
    });
  }

  void _fakeTalking(BuildContext context) async {
    final int amplitude = Random().nextInt(25);
    if (!context.read<TalkingCubit>().state.isTalking) return;
    context.read<TalkingCubit>().updateMouthState(
          _getMouthState(amplitude),
        );
    await Future<dynamic>.delayed(
      const Duration(milliseconds: 100),
    ).then((_) {
      _fakeTalking(context);
    });
  }

  MouthState _getMouthState(int amplitude) {
    if (amplitude == 0) return MouthState.closed;
    if (amplitude <= 5) return MouthState.slightly;
    if (amplitude <= 12) return MouthState.semi;
    if (amplitude <= 18) return MouthState.open;
    return MouthState.wide;
  }

  String _getMouthPath(MouthState mouthState) {
    return 'assets/avatar/mouth/mouth_${mouthState.name}.png';
  }
}
