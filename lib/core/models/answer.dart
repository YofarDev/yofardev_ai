import 'package:freezed_annotation/freezed_annotation.dart';

import 'avatar_config.dart';

part 'answer.freezed.dart';

@freezed
sealed class Answer with _$Answer {
  const factory Answer({
    @Default('') String chatId,
    @Default('') String answerText,
    @Default('') String audioPath,
    @Default(<int>[]) List<int> amplitudes,
    @Default(AvatarConfig()) AvatarConfig avatarConfig,
  }) = _Answer;
}
