import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/avatar_cue.dart';
import '../../../../core/models/failure.dart';
import '../../../../core/services/audio/audio_amplitude_service.dart';
import '../../../../core/services/audio/interruption_service.dart';
import '../../../../core/services/audio/audio_player_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/platform_utils.dart';
import '../../../sound/sound.dart';
import '../../../talking/talking.dart';
import '../../domain/services/waiting_sentences_cache_datasource.dart';
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
    required TtsQueueService ttsQueueManager,
    required AudioAmplitudeService audioAmplitudeService,
    required AudioPlayerService audioPlayerService,
    required InterruptionService interruptionService,
    required TtsPlaybackService ttsPlaybackService,
  }) : _ttsQueueManager = ttsQueueManager,
       _audioAmplitudeService = audioAmplitudeService,
       _audioPlayerService = audioPlayerService,
       _interruptionService = interruptionService,
       _ttsPlaybackService = ttsPlaybackService,
       super(ChatTtsState.initial()) {
    _subscribeToTtsStream();
    _subscribeToCueOnlyItems();
    _subscribeToInterruptions();
  }

  final TtsQueueService _ttsQueueManager;
  final AudioAmplitudeService _audioAmplitudeService;
  final AudioPlayerService _audioPlayerService;
  final InterruptionService _interruptionService;
  final TtsPlaybackService _ttsPlaybackService;
  StreamSubscription<String>? _ttsAudioSubscription;
  StreamSubscription<List<AvatarCue>>? _cueOnlySubscription;
  StreamSubscription<void>? _interruptionSubscription;
  final List<String> _pendingPlaybackQueue = <String>[];
  bool _isPlayingFromQueue = false;
  Completer<void>? _currentPlaybackStopSignal;

  /// Amplitude extraction started as soon as a TTS file arrives, so the
  /// decode overlaps with the previous sentence's playback instead of
  /// blocking the transition. Entries are removed once played / cancelled.
  final Map<String, Future<List<int>>> _amplitudeFutures =
      <String, Future<List<int>>>{};

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

  /// Cue-only items (no speakable text) never emit audio: hand their cues
  /// straight to the playback service the moment they are reached.
  void _subscribeToCueOnlyItems() {
    _cueOnlySubscription?.cancel();
    _cueOnlySubscription = _ttsQueueManager.cueOnlyStream.listen(
      (List<AvatarCue> cues) => _ttsPlaybackService.fireCues(cues),
    );
  }

  void _subscribeToInterruptions() {
    _interruptionSubscription?.cancel();
    _interruptionSubscription = _interruptionService.interruptionStream.listen((
      _,
    ) async {
      AppLogger.debug('Interrupting active TTS playback', tag: 'ChatTtsCubit');
      _pendingPlaybackQueue.clear();
      _amplitudeFutures.clear();
      clearAudioPaths();
      if (!(_currentPlaybackStopSignal?.isCompleted ?? true)) {
        _currentPlaybackStopSignal!.complete();
      }
      await _audioPlayerService.stop();
      await _ttsPlaybackService.stop();
    });
  }

  void _enqueueForPlayback(String audioPath) {
    _pendingPlaybackQueue.add(audioPath);

    if (_isPlayingFromQueue) {
      // Next sentence: start decoding it while the current one plays.
      unawaited(_audioPlayerService.preload(audioPath));
    }

    // Kick off amplitude extraction immediately so it overlaps with the
    // currently playing sentence. Future.sync routes synchronous throws into
    // the future so the playback path's error handling covers them.
    _amplitudeFutures.putIfAbsent(audioPath, () {
      return Future<List<int>>(
        () => _audioAmplitudeService.extractAmplitudes(audioPath),
      );
    });

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

      // 1. Amplitudes were prefetched on arrival; await them here so
      // lip-sync stays aligned (extract-before-play contract preserved).
      final List<int> amplitudes = await _amplitudeFutures.putIfAbsent(
        audioPath,
        () => _audioAmplitudeService.extractAmplitudes(audioPath),
      );
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

      // 4. Trigger the animation via the playback service
      // TalkingCubit handles mouth state updates via the service's event stream
      _ttsPlaybackService.startAmplitudeAnimation(
        audioPath,
        amplitudes,
        audioDuration,
        // Consumed exactly once, here, when this audio starts playing.
        cues: _ttsQueueManager.consumeCues(audioPath),
        caption: _ttsQueueManager.consumeText(audioPath),
      );

      // 5. Wait for playback completion OR interruption before processing next.
      final Completer<void> stopSignal = Completer<void>();
      _currentPlaybackStopSignal = stopSignal;
      await Future.any(<Future<void>>[
        _audioPlayerService.onPlaybackComplete.first,
        stopSignal.future,
      ]);

      AppLogger.debug('Audio playback completed', tag: 'ChatTtsCubit');
      _amplitudeFutures.remove(audioPath);
      await _ttsPlaybackService
          .stop(); // Return to idle state (also cancels animation)
      if (identical(_currentPlaybackStopSignal, stopSignal)) {
        _currentPlaybackStopSignal = null;
      }
      // The sentence is done: drop its entry so state does not grow for the
      // whole app session (audioPathsWaitingSentences is otherwise never
      // freed).
      removeWaitingSentence(audioPath);
      // Played TTS files are scratch: delete now instead of waiting for the
      // 10-minute sweep.
      unawaited(_ttsQueueManager.deleteAudio(audioPath));
    } catch (e) {
      AppLogger.error(
        'Failed to play/extract amplitudes for $audioPath',
        tag: 'ChatTtsCubit',
        error: e,
      );
      _currentPlaybackStopSignal = null;
      removeWaitingSentence(audioPath);
      unawaited(_ttsQueueManager.deleteAudio(audioPath));
      emit(
        state.copyWith(
          hasError: true,
          error: TtsFailure('Failed to play audio: $e', e),
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
          error: TtsFailure('Failed to initialize: $e', e),
        ),
      );
    }
  }

  /// Loads waiting sentences from cache for the given language
  ///
  /// On web platforms, this is a no-op since audio caching is not supported.
  Future<void> prepareWaitingSentences(String language) async {
    if (PlatformUtils.checkPlatform() == 'Web') {
      emit(state.copyWith(initializing: false));
      return;
    }

    try {
      final List<Map<String, dynamic>>? cachedSentences =
          await WaitingSentencesCacheDatasource.getWaitingSentencesMap(
            language,
          );

      if (cachedSentences != null) {
        emit(
          state.copyWith(
            audioPathsWaitingSentences: cachedSentences,
            initializing: false,
          ),
        );
      } else {
        emit(state.copyWith(initializing: false));
      }
    } catch (e) {
      AppLogger.error(
        'Failed to load waiting sentences',
        tag: 'ChatTtsCubit',
        error: e,
      );
      emit(state.copyWith(initializing: false));
    }
  }

  @override
  Future<void> close() async {
    _pendingPlaybackQueue.clear();
    _amplitudeFutures.clear();
    if (!(_currentPlaybackStopSignal?.isCompleted ?? true)) {
      _currentPlaybackStopSignal!.complete();
    }
    await _ttsAudioSubscription?.cancel();
    await _cueOnlySubscription?.cancel();
    await _interruptionSubscription?.cancel();
    await super.close();
  }
}
