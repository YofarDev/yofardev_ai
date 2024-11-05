import 'dart:convert';
import 'dart:io';

import 'package:audio_analyzer/audio_analyzer.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

import '../../models/answer.dart';
import '../../models/chat_entry.dart';
import '../../models/sound_effects.dart';
import '../../services/tts_service.dart';
import '../../utils/extensions.dart';

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

  Future<void> prepareToSpeak({
    required String chatId,
    required ChatEntry entry,
    required String language,
    required VoiceEffect voiceEffect,
  }) async {
    emit(state.copyWith(status: TalkingStatus.loading));
    final Map<String, dynamic> map =
        json.decode(entry.body) as Map<String, dynamic>;
    final String answerText = map['message'] as String? ?? '';
    final String textToSay = answerText
        .replaceAll('...', '')
        .replaceAll('*', '')
        .removeEmojis()
        .trim();
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
          chatId: chatId,
          answerText: answerText,
          audioPath: audioPath,
          amplitudes: amplitudes,
          avatarConfig: entry.getAvatarConfig(),
        ),
      ),
    );
  }

  void speakForWeb(
    ChatEntry entry,
    String language,
    VoiceEffect voiceEffect,
  ) async {
    emit(state.copyWith(status: TalkingStatus.loading));
    final Map<String, dynamic> map =
        json.decode(entry.body) as Map<String, dynamic>;
    final String answerText = map['message'] as String? ?? '';
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
          answerText: answerText,
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

  void stopTalking({
    bool noFile = false,
    bool soundEffectsEnabled = false,
  }) async {
    emit(
      state.copyWith(
        isTalking: false,
        mouthState: MouthState.closed,
        status: TalkingStatus.initial,
      ),
    );
    if (!noFile) await File(state.answer.audioPath).delete();
    if (!soundEffectsEnabled) return;
    if (state.answer.avatarConfig.soundEffect == null) return;
    final AudioPlayer player = AudioPlayer();
    await player.setAsset(state.answer.avatarConfig.soundEffect!.getPath());
    await player.play();
    player.dispose();
  }
}
