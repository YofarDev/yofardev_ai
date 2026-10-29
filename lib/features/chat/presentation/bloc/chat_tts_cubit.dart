import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/avatar_cue.dart';
import '../../../../core/models/failure.dart';
import '../../../../core/models/performance/speech_timeline.dart';
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
    Duration speechPreroll = defaultSpeechPreroll,
  }) : _ttsQueueManager = ttsQueueManager,
       _speechPreroll = speechPreroll,
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

  /// Speech analysis (visemes + prosody), prefetched on arrival like the
  /// amplitudes. Never fails: an error resolves to null.
  final Map<String, Future<SpeechTimeline?>> _timelineFutures =
      <String, Future<SpeechTimeline?>>{};

  /// Longest a sentence waits for its speech analysis before it plays; past
  /// it the sentence plays with no timeline (the amplitude fallback).
  static const Duration timelineWait = Duration(milliseconds: 150);

  /// Time between announcing a sentence and playing it: the avatar draws a
  /// breath before speaking (M2 plan, critic round 3 ruling).
  static const Duration defaultSpeechPreroll = Duration(milliseconds: 200);

  final Duration _speechPreroll;

  /// Incremented by every interruption: a sentence waiting out its pre-roll
  /// does not start after an interrupt.
  int _generation = 0;

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
      _generation++;
      _pendingPlaybackQueue.clear();
      _amplitudeFutures.clear();
      _timelineFutures.clear();
      clearAudioPaths();
      if (!(_currentPlaybackStopSignal?.isCompleted ?? true)) {
        _currentPlaybackStopSignal!.complete();
      }
      // Stop the mouth animation first: while the player stop is awaited, a
      // resync would read position 0 and restart the mouth.
      _ttsPlaybackService.cancelAnimation();
      await _audioPlayerService.stop();
      await _ttsPlaybackService.interrupt();
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

    // Same for the speech analysis (off the UI isolate). The sentence text
    // and its language are parked in the queue until playback consumes
    // them: peek, not consume.
    _timelineFutures.putIfAbsent(
      audioPath,
      () =>
          Future<SpeechTimeline?>(
            () => _audioAmplitudeService.analyzeSpeech(
              audioPath,
              text: _ttsQueueManager.peekText(audioPath),
              language: _ttsQueueManager.peekLanguage(audioPath) ?? 'en',
            ),
          ).then<SpeechTimeline?>(
            (SpeechTimeline? timeline) => timeline,
            onError: (Object e) {
              AppLogger.error(
                'Speech analysis failed for $audioPath',
                tag: 'ChatTtsCubit',
                error: e,
              );
              return null;
            },
          ),
    );

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
    // An interrupt during any await below drops this sentence instead of
    // playing it after the user stopped the speech.
    final int generation = _generation;
    bool interrupted() => isClosed || generation != _generation;
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

      if (interrupted()) {
        _dropUnplayed(audioPath);
        return;
      }
      // The analysis normally finished during the previous sentence; a slow
      // one never holds the audio back more than [timelineWait]. The wait
      // runs alongside the breath before speaking.
      final Future<SpeechTimeline?> pendingTimeline = _takeTimeline(audioPath);
      if (_speechPreroll > Duration.zero) {
        _ttsPlaybackService.announceSpeech(_speechPreroll);
        await Future<void>.delayed(_speechPreroll);
      }
      final SpeechTimeline? timeline = await pendingTimeline;
      if (interrupted()) {
        _dropUnplayed(audioPath);
        return;
      }

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
        timeline: timeline,
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
      _timelineFutures.remove(audioPath);
      // The sentence never played: drop its parked caption text (no-op if
      // it was already consumed).
      _ttsQueueManager.consumeText(audioPath);
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

  /// The prefetched analysis of [audioPath], waiting at most [timelineWait];
  /// null when missing, failed or too slow.
  /// A sentence dropped before it played: its parked text, history entry
  /// and file go.
  void _dropUnplayed(String audioPath) {
    _amplitudeFutures.remove(audioPath);
    _timelineFutures.remove(audioPath);
    _ttsQueueManager.consumeText(audioPath);
    _ttsQueueManager.consumeCues(audioPath);
    unawaited(_ttsQueueManager.deleteAudio(audioPath));
  }

  Future<SpeechTimeline?> _takeTimeline(String audioPath) async {
    final Future<SpeechTimeline?>? pending = _timelineFutures.remove(audioPath);
    if (pending == null) {
      return null;
    }
    return pending.timeout(
      timelineWait,
      onTimeout: () {
        AppLogger.debug(
          'Speech analysis not ready for $audioPath, using amplitudes',
          tag: 'ChatTtsCubit',
        );
        return null;
      },
    );
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
    _timelineFutures.clear();
    if (!(_currentPlaybackStopSignal?.isCompleted ?? true)) {
      _currentPlaybackStopSignal!.complete();
    }
    await _ttsAudioSubscription?.cancel();
    await _cueOnlySubscription?.cancel();
    await _interruptionSubscription?.cancel();
    await super.close();
  }
}
