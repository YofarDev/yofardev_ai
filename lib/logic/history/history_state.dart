part of 'history_cubit.dart';

enum HistoryStatus { loading, success, updating, failure }

class HistoryState extends Equatable {
  final HistoryStatus status;
  final List<Chat> history;
  final List<ChatEntry> currentChat;
  const HistoryState({
    this.status = HistoryStatus.loading,
    this.history = const <Chat>[],
    this.currentChat = const <ChatEntry>[],
  });

  @override
  List<Object> get props => <Object>[status, history, currentChat];

  HistoryState copyWith({
    HistoryStatus? status,
    List<Chat>? history,
    List<ChatEntry>? currentChat,
  }) {
    return HistoryState(
      status: status ?? this.status,
      history: history ?? this.history,
      currentChat: currentChat ?? this.currentChat,
    );
  }
}
