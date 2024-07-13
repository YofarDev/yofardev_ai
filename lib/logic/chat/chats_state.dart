

part of 'chats_cubit.dart';

enum ChatsStatus { loading, success, updating, typing, error }

class ChatsState extends Equatable {
  final ChatsStatus status;
  final List<Chat> chatsList;
  final Chat currentChat;
  final Chat openedChat;
  final String errorMessage;
  const ChatsState({
    this.status = ChatsStatus.loading,
    this.chatsList = const <Chat>[],
    this.currentChat = const Chat(),
     this.openedChat = const Chat(),
    this.errorMessage = '',
  });

  @override
  List<Object> get props {
    return <Object>[
      status,
      chatsList,
      currentChat,
      openedChat,
      errorMessage,
    ];
  }

  ChatsState copyWith({
    ChatsStatus? status,
    List<Chat>? chatsList,
    Chat? currentChat,
    Chat? openedChat,
    String? errorMessage,
  }) {
    return ChatsState(
      status: status ?? this.status,
      chatsList: chatsList ?? this.chatsList,
      currentChat: currentChat ?? this.currentChat,
      openedChat: openedChat ?? this.openedChat,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
