import 'package:freezed_annotation/freezed_annotation.dart';

part 'caption_state.freezed.dart';

/// Live caption of the TTS sentence being spoken.
///
/// [text] is the sentence currently on screen (null when nothing is shown),
/// [seq] increments with each new caption so the UI can key its transition,
/// [enabled] is the persisted user preference (the UI hides captions when
/// false; [text] keeps tracking playback so toggling on mid-sentence shows
/// the current sentence).
@freezed
sealed class CaptionState with _$CaptionState {
  const factory CaptionState({
    String? text,
    @Default(0) int seq,
    @Default(true) bool enabled,
  }) = _CaptionState;
}
