import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_audio_state.freezed.dart';

@freezed
sealed class ChatAudioState with _$ChatAudioState {
  const factory ChatAudioState({
    @Default(<Map<String, dynamic>>[])
    List<Map<String, dynamic>> audioPathsWaitingSentences,
    @Default(true) bool initializing,
  }) = _ChatAudioState;

  factory ChatAudioState.initial() => const ChatAudioState();
}
