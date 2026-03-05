import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/audio/audio_amplitude_service.dart';
import '../../../core/utils/logger.dart';
import '../../sound/domain/tts_queue_manager.dart';
import 'chat_tts_state.dart';

/// Cubit responsible for managing TTS audio state
///
/// Handles:
/// - TTS audio queue state
/// - Audio amplitude extraction
/// - TTS stream subscriptions
class ChatTtsCubit extends Cubit<ChatTtsState> {
  ChatTtsCubit({
    required TtsQueueManager ttsQueueManager,
    required AudioAmplitudeService audioAmplitudeService,
  }) : _ttsQueueManager = ttsQueueManager,
       _audioAmplitudeService = audioAmplitudeService,
       super(ChatTtsState.initial()) {
    _subscribeToTtsStream();
  }

  final TtsQueueManager _ttsQueueManager;
  final AudioAmplitudeService _audioAmplitudeService;
  StreamSubscription<String>? _ttsAudioSubscription;

  /// Subscribe to TTS audio stream to update audio paths with amplitudes
  void _subscribeToTtsStream() {
    _ttsAudioSubscription?.cancel();
    AppLogger.debug('Subscribing to TTS audio stream', tag: 'ChatTtsCubit');
    _ttsAudioSubscription = _ttsQueueManager.audioStream.listen(
      (String audioPath) {
        AppLogger.debug(
          'Received TTS audio path: $audioPath',
          tag: 'ChatTtsCubit',
        );
        _extractAmplitudes(audioPath);
      },
      onError: (Object e) {
        AppLogger.error(
          'TTS audio stream error',
          tag: 'ChatTtsCubit',
          error: e,
        );
      },
    );
  }

  /// Extract amplitudes from audio file and add to state
  Future<void> _extractAmplitudes(String audioPath) async {
    try {
      final List<int> amplitudes = await _audioAmplitudeService
          .extractAmplitudes(audioPath);
      AppLogger.debug(
        'Extracted ${amplitudes.length} amplitudes for $audioPath',
        tag: 'ChatTtsCubit',
      );
      final List<Map<String, dynamic>> currentList =
          List<Map<String, dynamic>>.from(state.audioPathsWaitingSentences);
      currentList.add(<String, dynamic>{
        'audioPath': audioPath,
        'amplitudes': amplitudes,
      });
      emit(state.copyWith(audioPathsWaitingSentences: currentList));
    } catch (e) {
      AppLogger.error(
        'Failed to extract amplitudes for $audioPath',
        tag: 'ChatTtsCubit',
        error: e,
      );
    }
  }

  /// Clear the audio paths list (e.g., when starting a new message)
  void clearAudioPaths() {
    emit(state.copyWith(audioPathsWaitingSentences: <Map<String, dynamic>>[]));
  }

  /// Remove a sentence from the queue after it has been played
  void removeWaitingSentence(String audioPath) {
    final List<Map<String, dynamic>> currentList =
        List<Map<String, dynamic>>.from(state.audioPathsWaitingSentences);
    currentList.removeWhere(
      (Map<String, dynamic> element) => element['audioPath'] == audioPath,
    );
    emit(state.copyWith(audioPathsWaitingSentences: currentList));
  }

  /// Shuffle the waiting sentences queue
  void shuffleWaitingSentences() {
    final List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(
      state.audioPathsWaitingSentences,
    );
    list.shuffle();
    emit(state.copyWith(audioPathsWaitingSentences: list));
  }

  /// Initialize TTS state (load cached sentences if available)
  Future<void> initialize(String language) async {
    try {
      // This will be implemented by the caller if needed
      emit(state.copyWith(isInitialized: true));
    } catch (e) {
      AppLogger.error(
        'Failed to initialize TTS state',
        tag: 'ChatTtsCubit',
        error: e,
      );
      emit(state.copyWith(isInitialized: true));
    }
  }

  @override
  Future<void> close() async {
    await _ttsAudioSubscription?.cancel();
    await super.close();
  }
}
