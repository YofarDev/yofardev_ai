import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';

import '../../../logic/avatar/avatar_cubit.dart';
import '../../../logic/chat/chats_cubit.dart';
import '../../../logic/talking/talking_cubit.dart';
import '../../../res/app_constants.dart';
import '../../../utils/app_utils.dart';
import '../../../utils/platform_utils.dart';
import 'scaled_avatar_item.dart';

class TalkingMouth extends StatefulWidget {
  const TalkingMouth({
    super.key,
  });

  @override
  State<TalkingMouth> createState() => _TalkingMouthState();
}

class _TalkingMouthState extends State<TalkingMouth> {
  bool _waitingTalking = false;

  @override
  Widget build(BuildContext context) {
    return BlocListener<TalkingCubit, TalkingState>(
      listenWhen: (TalkingState previous, TalkingState current) =>
          previous.status != current.status,
      listener: (BuildContext context, TalkingState state) {
        _waitingTalking = state.status == TalkingStatus.loading;
        if (_waitingTalking && PlatformUtils.checkPlatform() != 'Web') {
          _startWaitingTalking();
        }
        if (state.status == TalkingStatus.success) {
          if (context.read<AvatarCubit>().state.avatar.hideTalkingMouth) return;
          if (PlatformUtils.checkPlatform() == 'Web') {
            _fakeTalking(context);
          } else {
            final String audioPath = state.answer.audioPath;
            final List<int> amplitudes = state.answer.amplitudes;
            _startTalking(
              context,
              audioPath,
              amplitudes,
            );
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

  Future<void> _startWaitingTalking() async {
    int i = 0;
    while (_waitingTalking) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final String audioPath = context
          .read<ChatsCubit>()
          .state
          .audioPathsWaitingSentences[i]['audioPath'] as String;
      final List<int> amplitudes = context
          .read<ChatsCubit>()
          .state
          .audioPathsWaitingSentences[i]['amplitudes'] as List<int>;
      final int duration = await _startTalking(
        context,
        audioPath,
        amplitudes,
      );
      await Future<dynamic>.delayed(Duration(milliseconds: duration));
      i++;
      if (i >=
          context.read<ChatsCubit>().state.audioPathsWaitingSentences.length) {
        i = 0;
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  Future<int> _startTalking(
    BuildContext context,
    String audioPath,
    List<int> amplitudes,
  ) async {
    if (amplitudes.isEmpty) {
      context.read<TalkingCubit>().stopTalking(
            soundEffectsEnabled:
                context.read<ChatsCubit>().state.soundEffectsEnabled,
          );
      return 0;
    }
    final AudioPlayer player =
        AudioPlayer(); // player only used to get the duration here
    await player.setFilePath(audioPath, initialPosition: Duration.zero);
    final int totalFrames = amplitudes.length;
    final int updateInterval =
        (player.duration!.inMilliseconds / totalFrames).round();
    int currentIndex = 0;
    Timer.periodic(Duration(milliseconds: updateInterval), (Timer timer) async {
      if (currentIndex >= totalFrames) {
        timer.cancel();
        await player.dispose();
        return;
      } else {
        try {
          context.read<TalkingCubit>().updateMouthState(
                _getMouthState(amplitudes[currentIndex]),
              );
          currentIndex++;
        } catch (e) {
          timer.cancel();
          await player.dispose();
          debugPrint('talking mouth error: $e');
        }
      }
    });
    return player.duration!.inMilliseconds;
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
    return AppUtils.fixAssetsPath(
      'assets/avatar/mouth/mouth_${mouthState.name}.png',
    );
  }
}
