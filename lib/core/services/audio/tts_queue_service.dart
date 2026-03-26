import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../../features/sound/data/datasources/tts_datasource.dart';
import '../../../features/sound/domain/tts_queue_item.dart';
import '../../models/voice_effect.dart';
import 'interruption_service.dart';
import 'voice_effects_service.dart';
import '../../utils/logger.dart';

/// Manages queue of TTS generation and playback
class TtsQueueService {
  final TtsDatasource _ttsDatasource;
  final InterruptionService _interruptionService;
  final VoiceEffectsService _voiceEffectsService;
  final List<TtsQueueItem> _queue = <TtsQueueItem>[];
  final StreamController<String> _audioController =
      StreamController<String>.broadcast();
  final Uuid _uuid = const Uuid();

  bool _isProcessing = false;
  bool _isPaused = false;
  Timer? _processingTimer;
  StreamSubscription<dynamic>? _interruptionSubscription;

  TtsQueueService({
    required TtsDatasource ttsDatasource,
    required InterruptionService interruptionService,
    required VoiceEffectsService voiceEffectsService,
  }) : _ttsDatasource = ttsDatasource,
       _interruptionService = interruptionService,
       _voiceEffectsService = voiceEffectsService {
    // Listen to interruptions
    _interruptionSubscription = _interruptionService.interruptionStream.listen(
      (_) => _handleInterruption(),
    );
  }

  /// Stream of generated audio paths ready for playback
  Stream<String> get audioStream => _audioController.stream;

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
  }) async {
    // Skip empty text
    if (text.trim().isEmpty) return;

    final TtsQueueItem item = TtsQueueItem(
      id: _uuid.v4(),
      text: text.trim(),
      language: language,
      voiceEffect: voiceEffect,
      priority: priority,
      timestamp: DateTime.now(),
      isProcessing: false,
      isCompleted: false,
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
    _queue.clear();
    _isProcessing = false;
    _processingTimer?.cancel();
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
      _processingTimer?.cancel();
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
    final TtsQueueItem item = _queue.first;

    // Mark as processing
    _queue[0] = item.copyWith(isProcessing: true);

    try {
      AppLogger.debug(
        'Generating TTS for: ${item.text.substring(0, item.text.length > 30 ? 30 : item.text.length)}...',
        tag: 'TtsQueueService',
      );

      // Generate audio (with neutral voice effects for post-processing)
      final String rawAudioPath = await _ttsDatasource.textToFrenchMaleVoice(
        text: item.text,
        language: item.language,
        voiceEffect: item.voiceEffect,
      );

      // Apply post-processing voice effects using FFmpeg
      final String processedAudioPath = await _voiceEffectsService
          .applyVoiceEffects(rawAudioPath, item.voiceEffect);

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

      // Mark processing complete before scheduling next item.
      _isProcessing = false;

      // Process next item
      if (_queue.isNotEmpty && !_isPaused) {
        _processingTimer = Timer(
          const Duration(milliseconds: 100),
          _processNext,
        );
      }
    } catch (e) {
      AppLogger.error(
        'Failed to generate TTS for: ${item.text}',
        tag: 'TtsQueueService',
        error: e,
      );

      // Remove failed item
      _queue.removeAt(0);

      // Mark processing complete before scheduling next item.
      _isProcessing = false;

      // Continue with next
      if (_queue.isNotEmpty && !_isPaused) {
        _processingTimer = Timer(
          const Duration(milliseconds: 100),
          _processNext,
        );
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _processingTimer?.cancel();
    _interruptionSubscription?.cancel();
    _audioController.close();
  }
}
