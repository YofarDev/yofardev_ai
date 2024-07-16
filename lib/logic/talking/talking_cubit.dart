import 'dart:io';

import 'package:audio_analyzer/audio_analyzer.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

import '../../models/answer.dart';
import '../../models/sound_effects.dart';
import '../../services/tts_service.dart';

part 'talking_state.dart';

class TalkingCubit extends Cubit<TalkingState> {
  TalkingCubit() : super(const TalkingState());

  void init() {
    emit(
      state.copyWith(
        status: TalkingStatus.initial,
        isTalking: false,
        mouthState: MouthState.closed,
        answer: const Answer(),
      ),
    );
  }

  Future<void> prepareToSpeak(Map<String, dynamic> responseMap, String language,
      VoiceEffect voiceEffect,) async {
    emit(state.copyWith(status: TalkingStatus.loading));
    final String answerText = responseMap['text'] as String? ?? '';
    final String textToSay =
        answerText.replaceAll('...', '').replaceAll('*', '');
    final String audioPath = textToSay.isEmpty
        ? ''
        : await TtsService().textToFrenchMaleVoice(
            text: textToSay,
            language: language,
            voiceEffect: voiceEffect,
          );
    final List<int> amplitudes = (textToSay.isEmpty || audioPath.isEmpty)
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

  void speakForWeb(
    Map<String, dynamic> responseMap,
    String language,
    VoiceEffect voiceEffect,
  ) async {
    emit(state.copyWith(status: TalkingStatus.loading));
    final String answerText = responseMap['text'] as String? ?? '';
    final String textToSay =
        answerText.replaceAll('...', '').replaceAll('*', '');
    final FlutterTts tts = await TtsService().getFlutterTts(
      text: textToSay,
      language: language,
      voiceEffect: voiceEffect,
    );
    tts.setCompletionHandler(() {
      stopTalking(noFile: true);
    });
    emit(
      state.copyWith(
        status: TalkingStatus.success,
        isTalking: true,
        answer: Answer(
          chatId: responseMap['chatId'] as String? ?? '',
          answerText: answerText,
          annotations:
              responseMap['annotations'] as List<String>? ?? <String>[],
        ),
      ),
    );

    tts.speak(textToSay);
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
