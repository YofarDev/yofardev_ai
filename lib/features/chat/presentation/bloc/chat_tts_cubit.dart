import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/audio/audio_amplitude_service.dart';
import '../../../../core/services/audio/interruption_service.dart';
import '../../../../core/services/audio/audio_player_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../sound/data/tts_queue_manager.dart';
import '../../../talking/presentation/bloc/talking_cubit.dart';
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
    required InterruptionService interruptionService,
    required TalkingCubit talkingCubit,
  }) : _ttsQueueManager = ttsQueueManager,
       _audioAmplitudeService = audioAmplitudeService,
       _audioPlayerService = audioPlayerService,
       _interruptionService = interruptionService,
       _talkingCubit = talkingCubit,
       super(ChatTtsState.initial()) {
    _subscribeToTtsStream();
    _subscribeToInterruptions();
  }

  final TtsQueueManager _ttsQueueManager;
  final AudioAmplitudeService _audioAmplitudeService;
  final AudioPlayerService _audioPlayerService;
  final InterruptionService _interruptionService;
  final TalkingCubit _talkingCubit;
  StreamSubscription<String>? _ttsAudioSubscription;
  StreamSubscription<void>? _interruptionSubscription;
  final List<String> _pendingPlaybackQueue = <String>[];
  bool _isPlayingFromQueue = false;
  Completer<void>? _currentPlaybackStopSignal;

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
        _enqueueForPlayback(audioPath);
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

  void _subscribeToInterruptions() {
    _interruptionSubscription?.cancel();
    _interruptionSubscription = _interruptionService.interruptionStream.listen((
      _,
    ) async {
      AppLogger.debug('Interrupting active TTS playback', tag: 'ChatTtsCubit');
      _pendingPlaybackQueue.clear();
      if (!(_currentPlaybackStopSignal?.isCompleted ?? true)) {
        _currentPlaybackStopSignal!.complete();
      }
      await _audioPlayerService.stop();
      await _talkingCubit.stop();
    });
  }

  void _enqueueForPlayback(String audioPath) {
    _pendingPlaybackQueue.add(audioPath);

    if (_isPlayingFromQueue) {
      return;
    }

    unawaited(_processPlaybackQueue());
  }

  Future<void> _processPlaybackQueue() async {
    if (_isPlayingFromQueue) {
      return;
    }

    _isPlayingFromQueue = true;
    try {
      while (_pendingPlaybackQueue.isNotEmpty) {
        final String nextAudioPath = _pendingPlaybackQueue.removeAt(0);
        await _playAndExtractAmplitudes(nextAudioPath);
      }
    } finally {
      _isPlayingFromQueue = false;
      if (_pendingPlaybackQueue.isNotEmpty) {
        unawaited(_processPlaybackQueue());
      }
    }
  }

  /// Play audio and extract amplitudes
  Future<void> _playAndExtractAmplitudes(String audioPath) async {
    try {
      AppLogger.debug(
        'Starting TTS playback for $audioPath',
        tag: 'ChatTtsCubit',
      );

      // 1. Extract amplitudes FIRST (before playing!)
      final List<int> amplitudes = await _audioAmplitudeService
          .extractAmplitudes(audioPath);
      AppLogger.debug(
        'Extracted ${amplitudes.length} amplitudes for $audioPath',
        tag: 'ChatTtsCubit',
      );

      // 2. Add to state for history
      final List<Map<String, dynamic>> currentList =
          List<Map<String, dynamic>>.from(state.audioPathsWaitingSentences);
      currentList.add(<String, dynamic>{
        'audioPath': audioPath,
        'amplitudes': amplitudes,
      });
      emit(state.copyWith(audioPathsWaitingSentences: currentList));

      // 3. Play the audio and get its duration
      final Duration audioDuration = await _audioPlayerService.play(audioPath);
      AppLogger.debug(
        'Audio duration: ${audioDuration.inMilliseconds}ms, amplitudes: ${amplitudes.length}',
        tag: 'ChatTtsCubit',
      );

      // 4. Set speaking state
      _talkingCubit.setSpeakingState();

      // 5. Trigger the animation DIRECTLY on TalkingCubit with actual duration
      _talkingCubit.startAmplitudeAnimation(
        audioPath,
        amplitudes,
        audioDuration,
        () {
          // Animation completion callback
          // Note: We don't stop here because audio might still be playing
          // The real stop happens when onPlaybackComplete fires
        },
      );

      // 6. Wait for playback completion OR interruption before processing next.
      final Completer<void> stopSignal = Completer<void>();
      _currentPlaybackStopSignal = stopSignal;
      await Future.any(<Future<void>>[
        _audioPlayerService.onPlaybackComplete.first,
        stopSignal.future,
      ]);

      AppLogger.debug('Audio playback completed', tag: 'ChatTtsCubit');
      await _talkingCubit
          .stop(); // Return to idle state (also cancels animation)
      if (identical(_currentPlaybackStopSignal, stopSignal)) {
        _currentPlaybackStopSignal = null;
      }
    } catch (e) {
      AppLogger.error(
        'Failed to play/extract amplitudes for $audioPath',
        tag: 'ChatTtsCubit',
        error: e,
      );
      _currentPlaybackStopSignal = null;
      emit(
        state.copyWith(
          hasError: true,
          errorMessage: 'Failed to play audio: ${e.toString()}',
        ),
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
      emit(
        state.copyWith(
          isInitialized: true,
          hasError: true,
          errorMessage: 'Failed to initialize: ${e.toString()}',
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    _pendingPlaybackQueue.clear();
    if (!(_currentPlaybackStopSignal?.isCompleted ?? true)) {
      _currentPlaybackStopSignal!.complete();
    }
    await _ttsAudioSubscription?.cancel();
    await _interruptionSubscription?.cancel();
    await super.close();
  }
}
