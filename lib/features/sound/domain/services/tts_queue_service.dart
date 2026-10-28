import 'dart:async';

import 'package:uuid/uuid.dart';

import '../tts_queue_item.dart';
import 'tts_synthesizer.dart';
import '../../../../core/models/avatar_cue.dart';
import '../../../../core/models/voice_effect.dart';
import '../../../../core/services/audio/interruption_service.dart';
import '../../../../core/services/audio/voice_effects_service.dart';
import '../../../../core/utils/logger.dart';

/// Manages queue of TTS generation and playback
class TtsQueueService {
  final TtsSynthesizer _ttsSynthesizer;
  final InterruptionService _interruptionService;
  final VoiceEffectsService _voiceEffectsService;
  final List<TtsQueueItem> _queue = <TtsQueueItem>[];
  final StreamController<String> _audioController =
      StreamController<String>.broadcast();
  final StreamController<List<AvatarCue>> _cueOnlyController =
      StreamController<List<AvatarCue>>.broadcast();
  final StreamController<void> _drainedController =
      StreamController<void>.broadcast();

  /// Cues of completed items, keyed by audio path, until consumed by the
  /// playback side (they must fire exactly when that audio starts).
  final Map<String, List<AvatarCue>> _cuesByPath = <String, List<AvatarCue>>{};

  /// Sentence text of completed items, keyed by audio path, until consumed
  /// by the playback side (shown as a live caption while it plays).
  final Map<String, String> _textByPath = <String, String>{};
  final Uuid _uuid = const Uuid();

  bool _isProcessing = false;
  bool _isPaused = false;

  /// Incremented by [clear]; in-flight [_processNext] runs capture it and
  /// abort after each await if it changed, so a stale sentence synthesized
  /// during an interruption is never emitted.
  int _epoch = 0;
  StreamSubscription<dynamic>? _interruptionSubscription;

  TtsQueueService({
    required TtsSynthesizer ttsSynthesizer,
    required InterruptionService interruptionService,
    required VoiceEffectsService voiceEffectsService,
  }) : _ttsSynthesizer = ttsSynthesizer,
       _interruptionService = interruptionService,
       _voiceEffectsService = voiceEffectsService {
    // Listen to interruptions
    _interruptionSubscription = _interruptionService.interruptionStream.listen(
      (_) => _handleInterruption(),
    );
  }

  /// Stream of generated audio paths ready for playback
  Stream<String> get audioStream => _audioController.stream;

  /// Cues of items that carry no speakable text, emitted the moment the
  /// item is reached in the queue (there is no audio to wait for).
  Stream<List<AvatarCue>> get cueOnlyStream => _cueOnlyController.stream;

  /// Fires each time the queue runs out of speech: the last item failed to
  /// synthesize or carried only cues, or the playback side took the last
  /// parked sentence ([consumeText]). Then [hasPendingSpeech] is false.
  Stream<void> get drained => _drainedController.stream;

  /// Whether speech is still on its way: an item queued or synthesizing,
  /// or synthesized audio whose playback has not started yet (its text is
  /// parked until [consumeText]).
  bool get hasPendingSpeech =>
      _queue.isNotEmpty || _isProcessing || _textByPath.isNotEmpty;

  void _notifyIfDrained() {
    if (!hasPendingSpeech && !_drainedController.isClosed) {
      _drainedController.add(null);
    }
  }

  /// Consumes the cues embedded in the item whose audio path is
  /// [audioPath]; empty when the item carried none. Consumed cues are
  /// removed so they fire exactly once.
  List<AvatarCue> consumeCues(String audioPath) =>
      _cuesByPath.remove(audioPath) ?? const <AvatarCue>[];

  /// Consumes the sentence text of the item whose audio path is
  /// [audioPath]; null when unknown or already consumed. Removed on read so
  /// the map never outlives playback.
  String? consumeText(String audioPath) {
    final String? text = _textByPath.remove(audioPath);
    if (text != null) _notifyIfDrained();
    return text;
  }

  /// The sentence text of the item whose audio path is [audioPath], without
  /// consuming it (the speech analysis reads it ahead of playback); null
  /// when unknown or already consumed.
  String? peekText(String audioPath) => _textByPath[audioPath];

  /// Deletes a played audio file (scratch cleanup; the synthesizer owns the
  /// IO). Safe to call for a path that no longer exists.
  Future<void> deleteAudio(String path) => _ttsSynthesizer.delete(path);

  /// Current queue state (for debugging/monitoring)
  List<TtsQueueItem> get queue => List<TtsQueueItem>.unmodifiable(_queue);

  /// Whether queue is currently processing
  bool get isProcessing => _isProcessing;

  /// Add a sentence to the TTS queue
  Future<void> enqueue({
    required String text,
    required String language,
    required VoiceEffect voiceEffect,
    TtsPriority priority = TtsPriority.normal,
    List<AvatarCue> cues = const <AvatarCue>[],
  }) async {
    // Skip empty text
    if (text.trim().isEmpty && cues.isEmpty) return;

    final TtsQueueItem item = TtsQueueItem(
      id: _uuid.v4(),
      text: text.trim(),
      language: language,
      voiceEffect: voiceEffect,
      priority: priority,
      timestamp: DateTime.now(),
      isProcessing: false,
      isCompleted: false,
      cues: cues,
    );

    // Insert in priority order
    _insertInPriorityOrder(item);

    AppLogger.debug(
      'Enqueued TTS item: ${text.substring(0, text.length > 30 ? 30 : text.length)}... (queue size: ${_queue.length})',
      tag: 'TtsQueueService',
    );

    // Start processing if not already running
    if (!_isProcessing && !_isPaused) {
      _processNext();
    }
  }

  /// Clear all pending items
  void clear() {
    _epoch++;
    _queue.clear();
    _cuesByPath.clear();
    _textByPath.clear();
    _isProcessing = false;
    AppLogger.debug('TTS queue cleared', tag: 'TtsQueueService');
  }

  /// Handle interruption by clearing queue and stopping processing
  void _handleInterruption() {
    AppLogger.debug(
      'TTS queue interrupted, clearing queue',
      tag: 'TtsQueueService',
    );
    clear();
    _isProcessing = false;
  }

  /// Pause processing (doesn't clear queue)
  void setPaused(bool paused) {
    _isPaused = paused;
    if (paused) {
      _isProcessing = false;
    } else if (_queue.isNotEmpty) {
      _processNext();
    }
  }

  void _insertInPriorityOrder(TtsQueueItem item) {
    // Find insert position based on priority and timestamp
    int insertIndex = _queue.length;

    for (int i = 0; i < _queue.length; i++) {
      if (item.priority.index > _queue[i].priority.index) {
        insertIndex = i;
        break;
      } else if (item.priority == _queue[i].priority) {
        if (item.timestamp.isBefore(_queue[i].timestamp)) {
          insertIndex = i;
          break;
        }
      }
    }

    _queue.insert(insertIndex, item);
  }

  Future<void> _processNext() async {
    if (_isProcessing || _isPaused || _queue.isEmpty) return;

    _isProcessing = true;
    final int epoch = _epoch;
    void abortIfCleared() {
      if (epoch != _epoch) {
        throw _ClearedException();
      }
    }

    final TtsQueueItem item = _queue.first;

    // Cue-only item (no speakable text): nothing to synthesize or play;
    // hand its cues to the playback side immediately and carry on.
    if (item.text.isEmpty) {
      _queue.removeAt(0);
      _isProcessing = false;
      if (item.cues.isNotEmpty) {
        _cueOnlyController.add(item.cues);
      }
      if (_queue.isNotEmpty && !_isPaused) {
        await _processNext();
      } else {
        _notifyIfDrained();
      }
      return;
    }

    // Mark as processing
    _queue[0] = item.copyWith(isProcessing: true);

    try {
      AppLogger.debug(
        'Generating TTS for: ${item.text.substring(0, item.text.length > 30 ? 30 : item.text.length)}...',
        tag: 'TtsQueueService',
      );

      // Generate audio (with neutral voice effects for post-processing)
      final String rawAudioPath = await _ttsSynthesizer.synthesize(
        text: item.text,
        language: item.language,
        voiceEffect: item.voiceEffect,
      );
      abortIfCleared();

      // Apply post-processing voice effects using FFmpeg
      final String processedAudioPath = await _voiceEffectsService
          .applyVoiceEffects(rawAudioPath, item.voiceEffect);
      abortIfCleared();

      // The cues fire when this audio starts playing; park them for the
      // playback side to consume.
      if (item.cues.isNotEmpty) {
        _cuesByPath[processedAudioPath] = item.cues;
      }
      _textByPath[processedAudioPath] = item.text;

      // Update item as completed
      _queue[0] = item.copyWith(
        audioPath: processedAudioPath,
        isCompleted: true,
        isProcessing: false,
      );

      // Emit to stream for playback
      _audioController.add(processedAudioPath);

      AppLogger.debug(
        'TTS generated successfully: $processedAudioPath',
        tag: 'TtsQueueService',
      );

      // Remove from queue
      _queue.removeAt(0);

      // Mark processing complete before starting next item.
      _isProcessing = false;

      // Process next item
      if (_queue.isNotEmpty && !_isPaused) {
        await _processNext();
      }
    } on _ClearedException {
      // Queue was cleared mid-synthesis (interruption/new message): drop the
      // stale item without emitting.
      _queue.remove(item);
      _isProcessing = false;
    } catch (e) {
      AppLogger.error(
        'Failed to generate TTS for: ${item.text}',
        tag: 'TtsQueueService',
        error: e,
      );

      // Remove failed item
      _queue.removeAt(0);

      // Mark processing complete before starting next item.
      _isProcessing = false;

      // Continue with next
      if (_queue.isNotEmpty && !_isPaused) {
        await _processNext();
      } else {
        // The failed item produced no audio: nothing may be left to say.
        _notifyIfDrained();
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _interruptionSubscription?.cancel();
    _audioController.close();
    _drainedController.close();
  }
}

/// Internal signal that the queue was cleared while synthesis was in flight.
class _ClearedException implements Exception {}
