import 'package:equatable/equatable.dart';

class Answer extends Equatable {
  final String chatId;
  final String answerText;
  final String audioPath;
  final List<int> amplitudes;
  final List<String> annotations;
  const Answer({
    this.chatId = '',
    this.answerText = '',
    this.audioPath = '',
    this.amplitudes = const <int>[],
    this.annotations = const <String>[],
  });

  @override
  List<Object> get props => <Object>[
        chatId,
        answerText,
        audioPath,
        amplitudes,
        annotations,
      ];

  Answer copyWith({
    String? chatId,
    String? answerText,
    String? audioPath,
    List<int>? amplitudes,
    List<String>? annotations,
  }) {
    return Answer(
      chatId: chatId ?? this.chatId,
      answerText: answerText ?? this.answerText,
      audioPath: audioPath ?? this.audioPath,
      amplitudes: amplitudes ?? this.amplitudes,
      annotations: annotations ?? this.annotations,
    );
  }
}
