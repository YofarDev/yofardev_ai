import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/audio/audio_amplitude_service.dart';
import '../../../core/services/audio/audio_player_service.dart';
import '../../../core/utils/logger.dart';
import '../../sound/domain/tts_queue_manager.dart';
import '../../talking/presentation/bloc/talking_cubit.dart';
import 'chat_tts_state.dart';

/// Cubit responsible for managing TTS audio state
///
/// Handles:
/// - TTS audio queue state
/// - Audio amplitude extraction
/// - TTS audio playback
/// - TTS stream subscriptions
class ChatTtsCubit extends Cubit<ChatTtsState> {
  ChatTtsCubit({
    required TtsQueueManager ttsQueueManager,
    required AudioAmplitudeService audioAmplitudeService,
    required AudioPlayerService audioPlayerService,
    required TalkingCubit talkingCubit,
  }) : _ttsQueueManager = ttsQueueManager,
       _audioAmplitudeService = audioAmplitudeService,
       _audioPlayerService = audioPlayerService,
       _talkingCubit = talkingCubit,
       super(ChatTtsState.initial()) {
    _subscribeToTtsStream();
  }

  final TtsQueueManager _ttsQueueManager;
  final AudioAmplitudeService _audioAmplitudeService;
  final AudioPlayerService _audioPlayerService;
  final TalkingCubit _talkingCubit;
  StreamSubscription<String>? _ttsAudioSubscription;
  StreamSubscription<void>? _playbackSubscription;

  /// Subscribe to TTS audio stream to play audio and extract amplitudes
  void _subscribeToTtsStream() {
    _ttsAudioSubscription?.cancel();
    AppLogger.debug('Subscribing to TTS audio stream', tag: 'ChatTtsCubit');
    _ttsAudioSubscription = _ttsQueueManager.audioStream.listen(
      (String audioPath) {
        AppLogger.debug(
          'Received TTS audio path: $audioPath',
          tag: 'ChatTtsCubit',
        );
        _playAndExtractAmplitudes(audioPath);
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

  /// Play audio and extract amplitudes
  Future<void> _playAndExtractAmplitudes(String audioPath) async {
    try {
      // Update TalkingCubit to show speaking state
      _talkingCubit.setLoadingStatus(false); // First, stop loading state
      
      // Play the audio
      await _audioPlayerService.play(audioPath);
      
      // Update TalkingCubit to speaking state
      _talkingCubit.generateSpeech(''); // Trigger speaking state
      
      // Extract amplitudes for animation
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
      
      // Wait for playback to complete, then return to idle
      _playbackSubscription?.cancel();
      _playbackSubscription = _audioPlayerService.onPlaybackComplete.listen(
        (_) {
          AppLogger.debug('Audio playback completed', tag: 'ChatTtsCubit');
          _talkingCubit.stop(); // Return to idle state
        },
      );
    } catch (e) {
      AppLogger.error(
        'Failed to play/extract amplitudes for $audioPath',
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
    await _playbackSubscription?.cancel();
    await super.close();
  }
}
