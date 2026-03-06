import 'package:freezed_annotation/freezed_annotation.dart';

part 'talking_state.freezed.dart';

/// Status enum for backward compatibility
enum TalkingStatus { initial, idle, loading, success, error }

/// Mouth animation states for lip-sync
enum MouthState { closed, slightly, semi, open, wide }

@freezed
sealed class TalkingState with _$TalkingState {
  const factory TalkingState.idle([
    @Default(MouthState.closed) MouthState mouthState,
  ]) = IdleState;

  /// Playing waiting sentences - NO thinking animation
  const factory TalkingState.waiting([
    @Default(MouthState.closed) MouthState mouthState,
  ]) = WaitingState;

  /// Generating TTS - SHOWS thinking animation
  const factory TalkingState.generating([
    @Default(MouthState.closed) MouthState mouthState,
  ]) = GeneratingState;

  /// Playing TTS response
  const factory TalkingState.speaking([
    @Default(MouthState.closed) MouthState mouthState,
  ]) = SpeakingState;

  /// Error occurred
  const factory TalkingState.error(
    String message, [
    @Default(MouthState.closed) MouthState mouthState,
  ]) = ErrorState;
}

extension TalkingStateX on TalkingState {
  /// Should we show the thinking animation?
  bool get shouldShowTalking {
    return this is GeneratingState || this is SpeakingState;
  }

  /// Are we currently playing audio?
  bool get isPlaying {
    return this is WaitingState || this is SpeakingState;
  }

  /// Backward compatibility: alias for isPlaying
  bool get isTalking => isPlaying;

  /// Backward compatibility: map to old TalkingStatus enum
  TalkingStatus get status {
    return when(
      idle: (MouthState mouthState) => TalkingStatus.idle,
      waiting: (MouthState mouthState) => TalkingStatus.success,
      generating: (MouthState mouthState) => TalkingStatus.loading,
      speaking: (MouthState mouthState) => TalkingStatus.success,
      error: (String message, MouthState mouthState) => TalkingStatus.error,
    );
  }

  /// Backward compatibility: answer with amplitudes
  /// Returns a dummy answer since the new API doesn't store this in state
  AnswerData get answer => const AnswerData(amplitudes: <int>[]);
}

/// Backward compatibility: answer data class
class AnswerData {
  const AnswerData({required this.amplitudes});

  final List<int> amplitudes;
}
