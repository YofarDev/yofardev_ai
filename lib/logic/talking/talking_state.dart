
part of 'talking_cubit.dart';

enum TalkingStatus { initial, loading, success, failure }

enum MouthState { open, closed, semi, slightly, wide }

class TalkingState extends Equatable {
  final TalkingStatus status;
  final String prompt;
  final Answer answer;
  final MouthState mouthState;
  final bool isTalking;

  const TalkingState({
    this.status = TalkingStatus.initial,
     this.prompt = '',
    this.answer = const Answer(),
    this.mouthState = MouthState.closed,
    this.isTalking = false,
  });

  @override
  List<Object> get props {
    return <Object>[
      status,
      prompt,
      answer,
      mouthState,
      isTalking,
    ];
  }

  TalkingState copyWith({
    TalkingStatus? status,
    String? prompt,
    Answer? answer,
    MouthState? mouthState,
    bool? isTalking,
  }) {
    return TalkingState(
      status: status ?? this.status,
      prompt: prompt ?? this.prompt,
      answer: answer ?? this.answer,
      mouthState: mouthState ?? this.mouthState,
      isTalking: isTalking ?? this.isTalking,
    );
  }
}
