import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';

import '../../logic/talking/talking_cubit.dart';
import '../../models/answer.dart';

class TalkingMouth extends StatelessWidget {
  final double mouthX;
  final double mouthY;
  final double mouthWidth;
  final double mouthHeight;
  const TalkingMouth({
    super.key,
    required this.mouthX,
    required this.mouthY,
    required this.mouthWidth,
    required this.mouthHeight,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<TalkingCubit, TalkingState>(
      listenWhen: (TalkingState previous, TalkingState current) =>
          previous.status != current.status,
      listener: (BuildContext context, TalkingState state) {
        if (state.status == TalkingStatus.success &&
            state.answer.audioPath.isNotEmpty) {
          _startTalking(context, state.answer);
        }
      },
      child: BlocBuilder<TalkingCubit, TalkingState>(
        builder: (BuildContext context, TalkingState state) {
          return Positioned(
            left: mouthX,
            bottom: mouthY,
            child: Image.asset(
              _getMouthPath(state.mouthState),
              fit: BoxFit.cover,
              width: mouthWidth,
              height: mouthHeight,
            ),
          );
        },
      ),
    );
  }

  void _startTalking(BuildContext context, Answer answer) async {
    final AudioPlayer player = AudioPlayer();
    await player.setFilePath(answer.audioPath, initialPosition: Duration.zero);
    final int totalFrames = answer.amplitudes.length;
    final int updateInterval =
        (player.duration!.inMilliseconds / totalFrames).round();
    int currentIndex = 0;
    player.play();
    Timer.periodic(Duration(milliseconds: updateInterval), (Timer timer) {
      if (currentIndex >= totalFrames) {
        timer.cancel();
        player.dispose();
        context.read<TalkingCubit>().stopTalking();
        return;
      } else {
        context.read<TalkingCubit>().updateMouthState(
              _getMouthState(answer.amplitudes[currentIndex]),
            );
        currentIndex++;
      }
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
    return 'assets/mouth_${mouthState.name}.png';
  }
}
