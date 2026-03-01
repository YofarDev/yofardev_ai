import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/models/answer.dart';

part 'talking_state.freezed.dart';

enum TalkingStatus { initial, loading, success, failure }

enum MouthState { open, closed, semi, slightly, wide }

@freezed
sealed class TalkingState with _$TalkingState {
  const TalkingState._();

  const factory TalkingState({
    @Default(TalkingStatus.initial) TalkingStatus status,
    @Default(Answer()) Answer answer,
    @Default(MouthState.closed) MouthState mouthState,
    @Default(false) bool isTalking,
  }) = _TalkingState;
}
