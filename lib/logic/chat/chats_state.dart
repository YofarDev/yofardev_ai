


part of 'chats_cubit.dart';

enum ChatsStatus { loading, success, updating, typing, error }

class ChatsState extends Equatable {
  final ChatsStatus status;
  final List<Chat> chatsList;
  final Chat currentChat;
  final Chat openedChat;
  final String errorMessage;
  final bool soundEffectsEnabled;
  final String currentLanguage;
  const ChatsState({
    this.status = ChatsStatus.loading,
    this.chatsList = const <Chat>[],
    this.currentChat = const Chat(),
     this.openedChat = const Chat(),
    this.errorMessage = '',
    this.soundEffectsEnabled = true,
    this.currentLanguage = 'fr',
  });

  @override
  List<Object> get props {
    return <Object>[
      status,
      chatsList,
      currentChat,
      openedChat,
      errorMessage,
      soundEffectsEnabled,
      currentLanguage,
    ];
  }

  ChatsState copyWith({
    ChatsStatus? status,
    List<Chat>? chatsList,
    Chat? currentChat,
    Chat? openedChat,
    String? errorMessage,
    bool? soundEffectsEnabled,
    String? currentLanguage,
  }) {
    return ChatsState(
      status: status ?? this.status,
      chatsList: chatsList ?? this.chatsList,
      currentChat: currentChat ?? this.currentChat,
      openedChat: openedChat ?? this.openedChat,
      errorMessage: errorMessage ?? this.errorMessage,
      soundEffectsEnabled: soundEffectsEnabled ?? this.soundEffectsEnabled,
      currentLanguage: currentLanguage ?? this.currentLanguage,
    );
  }
}
