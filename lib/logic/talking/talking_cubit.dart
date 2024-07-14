import 'dart:io';

import 'package:audio_analyzer/audio_analyzer.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';

import '../../models/answer.dart';
import '../../models/sound_effects.dart';
import '../../services/tts_service.dart';

part 'talking_state.dart';

class TalkingCubit extends Cubit<TalkingState> {
  TalkingCubit() : super(const TalkingState());

  Future<void> prepareToSpeak(
    Map<String, dynamic> responseMap,
    String language,
  ) async {
    emit(state.copyWith(status: TalkingStatus.loading));
    final String answerText = responseMap['text'] as String? ?? '';
    final String textToAudio =
        answerText.replaceAll('...', '').replaceAll('*', '');
    final String audioPath = textToAudio.isEmpty
        ? ''
        : await TtsService().textToFrenchMaleVoice(
            text: textToAudio,
            language: language,
          );
    final List<int> amplitudes = textToAudio.isEmpty
        ? <int>[]
        : await AudioAnalyzer().getAmplitudes(audioPath);        
    emit(
      state.copyWith(
        status: TalkingStatus.success,
        answer: Answer(
          chatId: responseMap['chatId'] as String? ?? '',
          answerText: answerText,
          audioPath: audioPath,
          amplitudes: amplitudes,
          annotations:
              responseMap['annotations'] as List<String>? ?? <String>[],
        ),
      ),
    );
  }

  void setLoadingStatus(bool isLoading) {
    emit(
      state.copyWith(
        status: isLoading ? TalkingStatus.loading : TalkingStatus.initial,
      ),
    );
  }

  void updateMouthState(MouthState mouthState) {
    emit(
      state.copyWith(
        mouthState: mouthState,
        isTalking: true,
      ),
    );
  }

  void stopTalking({bool noFile = false, bool noSoundEffects = false}) async {
    emit(
      state.copyWith(
        isTalking: false,
        mouthState: MouthState.closed,
        status: TalkingStatus.initial,
      ),
    );
    if (!noFile) await File(state.answer.audioPath).delete();
    if (!noSoundEffects || state.answer.annotations.isEmpty) return;
    final List<SoundEffects> soundEffects = <SoundEffects>[];
    for (final String annotation in state.answer.annotations) {
      final SoundEffects? soundEffect = annotation.getSoundEffectFromString();
      if (soundEffect != null) soundEffects.add(soundEffect);
    }
    if (soundEffects.isNotEmpty) {
      final AudioPlayer player = AudioPlayer();
      await player.setAsset(soundEffects.last.getPath());
      await player.play();
      player.dispose();
    }
  }
}
