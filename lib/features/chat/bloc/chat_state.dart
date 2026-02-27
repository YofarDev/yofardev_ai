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
  final List<Map<String, dynamic>> audioPathsWaitingSentences;
  final bool initializing;
  final bool functionCallingEnabled;

  const ChatsState({
    this.status = ChatsStatus.loading,
    this.chatsList = const <Chat>[],
    this.currentChat = const Chat(),
    this.openedChat = const Chat(),
    this.errorMessage = '',
    this.soundEffectsEnabled = true,
    this.currentLanguage = 'fr',
    this.audioPathsWaitingSentences = const <Map<String, dynamic>>[],
    this.initializing = true,
    this.functionCallingEnabled = true,
  });

  @override
  List<Object?> get props {
    return <Object?>[
      status,
      chatsList,
      currentChat,
      openedChat,
      errorMessage,
      soundEffectsEnabled,
      currentLanguage,
      audioPathsWaitingSentences,
      initializing,
      functionCallingEnabled,
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
    List<Map<String, dynamic>>? audioPathsWaitingSentences,
    bool? initializing,
    bool? functionCallingEnabled,
  }) {
    return ChatsState(
      status: status ?? this.status,
      chatsList: chatsList ?? this.chatsList,
      currentChat: currentChat ?? this.currentChat,
      openedChat: openedChat ?? this.openedChat,
      errorMessage: errorMessage ?? this.errorMessage,
      soundEffectsEnabled: soundEffectsEnabled ?? this.soundEffectsEnabled,
      currentLanguage: currentLanguage ?? this.currentLanguage,
      audioPathsWaitingSentences:
          audioPathsWaitingSentences ?? this.audioPathsWaitingSentences,
      initializing: initializing ?? this.initializing,
      functionCallingEnabled:
          functionCallingEnabled ?? this.functionCallingEnabled,
    );
  }
}
