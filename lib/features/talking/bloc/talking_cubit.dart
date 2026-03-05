import 'package:flutter_bloc/flutter_bloc.dart';
import 'talking_state.dart';
import '../../../core/services/audio/tts_service.dart';

class TalkingCubit extends Cubit<TalkingState> {
  TalkingCubit(this._ttsService) : super(const TalkingState.idle());

  final TtsService _ttsService;

  /// Initialize the cubit
  Future<void> init() async {
    // Initialization logic if needed
    emit(const TalkingState.idle());
  }

  /// Play a waiting sentence - does NOT show thinking animation
  Future<void> playWaitingSentence(String sentence) async {
    emit(const TalkingState.waiting()); // NOT loading!
    await _ttsService.playWaitingSentence(sentence);
  }

  /// Generate TTS for speech - SHOWS thinking animation
  Future<void> generateSpeech(String text) async {
    emit(const TalkingState.generating()); // Separate state!

    try {
      // Generate TTS...
      await _ttsService.speak(text);
      emit(const TalkingState.speaking());
    } catch (e) {
      emit(TalkingState.error(e.toString()));
    }
  }

  /// Stop all TTS playback
  Future<void> stop() async {
    await _ttsService.stop();
    emit(const TalkingState.idle());
  }

  /// Legacy methods for backward compatibility (will be removed in future refactor)
  @Deprecated('Use generateSpeech() instead')
  void setLoadingStatus(bool isLoading) {
    if (isLoading) {
      emit(const TalkingState.generating());
    } else {
      emit(const TalkingState.idle());
    }
  }

  @Deprecated('Use stop() instead')
  void stopTalking({
    bool removeFile = true,
    bool soundEffectsEnabled = false,
    bool updateStatus = true,
  }) {
    stop();
  }
}
