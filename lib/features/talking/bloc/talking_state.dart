import 'package:freezed_annotation/freezed_annotation.dart';

part 'talking_state.freezed.dart';

@freezed
class TalkingState with _$TalkingState {
  const factory TalkingState.idle() = IdleState;

  /// Playing waiting sentences - NO thinking animation
  const factory TalkingState.waiting() = WaitingState;

  /// Generating TTS - SHOWS thinking animation
  const factory TalkingState.generating() = GeneratingState;

  /// Playing TTS response
  const factory TalkingState.speaking() = SpeakingState;

  /// Error occurred
  const factory TalkingState.error(String message) = ErrorState;
}

extension TalkingStateX on TalkingState {
  /// Should we show the thinking animation?
  bool get shouldShowTalking {
    return this is GeneratingState;
  }

  /// Are we currently playing audio?
  bool get isPlaying {
    return this is WaitingState || this is SpeakingState;
  }
}
