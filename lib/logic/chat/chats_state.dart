
part of 'chats_cubit.dart';

enum ChatsStatus { loading, success, updating, typing, failure }

class ChatsState extends Equatable {
  final ChatsStatus status;
  final List<Chat> chatsList;
  final Chat currentChat;
  final Chat openedChat;
  const ChatsState({
    this.status = ChatsStatus.loading,
    this.chatsList = const <Chat>[],
    this.currentChat = const Chat(),
     this.openedChat = const Chat(),
  });

  @override
  List<Object> get props => <Object>[status, chatsList, currentChat, openedChat];

  ChatsState copyWith({
    ChatsStatus? status,
    List<Chat>? chatsList,
    Chat? currentChat,
    Chat? openedChat,
  }) {
    return ChatsState(
      status: status ?? this.status,
      chatsList: chatsList ?? this.chatsList,
      currentChat: currentChat ?? this.currentChat,
      openedChat: openedChat ?? this.openedChat,
    );
  }
}
