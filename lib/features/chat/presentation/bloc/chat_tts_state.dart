import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_tts_state.freezed.dart';

@freezed
sealed class ChatTtsState with _$ChatTtsState {
  const factory ChatTtsState({
    @Default(<Map<String, dynamic>>[])
    List<Map<String, dynamic>> audioPathsWaitingSentences,
    @Default(true) bool initializing,
    @Default(false) bool isInitialized,
    @Default(false) bool hasError,
    @Default('') String errorMessage,
  }) = _ChatTtsState;

  factory ChatTtsState.initial() => const ChatTtsState();
}
