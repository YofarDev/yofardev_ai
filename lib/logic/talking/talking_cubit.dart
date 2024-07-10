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
    ) async {
    emit(state.copyWith(status: TalkingStatus.loading));        
    final String answerText = responseMap['text'] as String? ?? '';
    final String audioPath =
        await TtsService().textToFrenchMaleVoice(answerText);
    final List<int> amplitudes = await AudioAnalyzer().getAmplitudes(audioPath);
    emit(
      state.copyWith(
        status: TalkingStatus.success,
        answer: Answer(
          answerText: answerText,
          audioPath: audioPath,
          amplitudes: amplitudes,
          annotations:
              responseMap['annotations'] as List<String>? ?? <String>[],
        ),
      ),
    );
  }

  void isLoading(){
    emit(state.copyWith(status: TalkingStatus.loading));
  }

  void updateMouthState(MouthState mouthState) {
    emit(
      state.copyWith(
        mouthState: mouthState,
        isTalking: true,
      ),
    );
  }

  void stopTalking() async {
    emit(
      state.copyWith(
        isTalking: false,
        mouthState: MouthState.closed,
        status: TalkingStatus.initial,
      ),
    );
    if (state.answer.annotations.isNotEmpty) {
      for (final String annotation in state.answer.annotations) {
        final SoundEffects? soundEffect = annotation.getSoundEffectFromString();
        if (soundEffect != null) {
          final AudioPlayer player = AudioPlayer();
          await player.setAsset(soundEffect.getPath());
          await player.play();
          player.dispose();
        }
      }
    }
  }
}
