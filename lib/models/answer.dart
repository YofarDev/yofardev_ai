import 'package:equatable/equatable.dart';

import 'avatar.dart';

class Answer extends Equatable {
  final String chatId;
  final String answerText;
  final String audioPath;
  final List<int> amplitudes;
  final AvatarConfig avatarConfig;
  const Answer({
    this.chatId = '',
    this.answerText = '',
    this.audioPath = '',
    this.amplitudes = const <int>[],
    this.avatarConfig = const AvatarConfig(),
  });

  @override
  List<Object> get props => <Object>[
        chatId,
        answerText,
        audioPath,
        amplitudes,
        avatarConfig,
      ];

  Answer copyWith({
    String? chatId,
    String? answerText,
    String? audioPath,
    List<int>? amplitudes,
    AvatarConfig? avatarConfig,
  }) {
    return Answer(
      chatId: chatId ?? this.chatId,
      answerText: answerText ?? this.answerText,
      audioPath: audioPath ?? this.audioPath,
      amplitudes: amplitudes ?? this.amplitudes,
      avatarConfig: avatarConfig ?? this.avatarConfig,
    );
  }
}
