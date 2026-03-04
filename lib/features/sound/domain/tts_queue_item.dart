import 'package:freezed_annotation/freezed_annotation.dart';
import '../../sound/data/datasources/tts_datasource.dart';

part 'tts_queue_item.freezed.dart';

/// Priority levels for TTS queue items
enum TtsPriority { low, normal, high }

/// Item in the TTS generation queue
@freezed
sealed class TtsQueueItem with _$TtsQueueItem {
  const factory TtsQueueItem({
    required String id,
    required String text,
    required String language,
    required VoiceEffect voiceEffect,
    required TtsPriority priority,
    required DateTime timestamp,
    String? audioPath,
    @Default(false) bool isProcessing,
    @Default(false) bool isCompleted,
  }) = _TtsQueueItem;
}
