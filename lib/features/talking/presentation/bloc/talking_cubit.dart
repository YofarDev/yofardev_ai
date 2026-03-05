import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/talking_repository.dart';
import 'talking_state.dart';

/// Cubit responsible for managing TTS playback state
///
/// This cubit abstracts the TTS service through a repository,
/// allowing for proper separation of concerns and testability.
class TalkingCubit extends Cubit<TalkingState> {
  TalkingCubit(this._repository) : super(const TalkingState.idle());

  final TalkingRepository _repository;

  /// Initialize the cubit
  Future<void> init() async {
    // Initialization logic if needed
    emit(const TalkingState.idle());
  }

  /// Play a waiting sentence - does NOT show thinking animation
  Future<void> playWaitingSentence(String sentence) async {
    emit(const TalkingState.waiting()); // NOT loading!
    await _repository.playWaitingSentence(sentence);
  }

  /// Generate TTS for speech - SHOWS thinking animation
  Future<void> generateSpeech(String text) async {
    emit(const TalkingState.generating()); // Separate state!

    try {
      // Generate TTS...
      await _repository.generateSpeech(text);
      emit(const TalkingState.speaking());
    } catch (e) {
      emit(TalkingState.error(e.toString()));
    }
  }

  /// Set speaking state directly without generating TTS
  /// Used when TTS is already generated externally
  void setSpeakingState() {
    emit(const TalkingState.speaking());
  }

  /// Stop all TTS playback
  Future<void> stop() async {
    await _repository.stop();
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
