import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/features/chat/bloc/chats_cubit.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/models/chat.dart';
import 'package:yofardev_ai/models/chat_entry.dart';
import 'package:yofardev_ai/repositories/yofardev_repository.dart';
import 'package:yofardev_ai/services/chat_history_service.dart';
import 'package:yofardev_ai/services/settings_service.dart';

class MockChatHistoryService implements ChatHistoryService {
  @override
  Future<Chat> createNewChat() async => const Chat(id: 'test-id');

  @override
  Future<Chat?> getChat(String chatId) async => const Chat(id: 'test-id');

  @override
  Future<void> updateChat({
    required String chatId,
    required Chat updatedChat,
  }) async {}

  @override
  Future<void> deleteChat(String chatId) async {}

  @override
  Future<void> updateChatsList(String chatId) async {}

  @override
  Future<List<Chat>> getChatsList() async => <Chat>[];

  @override
  Future<Chat> getCurrentChat() async => const Chat();

  @override
  Future<void> setCurrentChatId(String chatId) async {}

  @override
  Future<void> updateAvatar(String chatId, Avatar avatar) async {}
}

class MockSettingsService implements SettingsService {
  @override
  Future<ChatPersona> getPersona() async => ChatPersona.normal;

  @override
  Future<void> setPersona(ChatPersona persona) async {}

  @override
  Future<String?> getUsername() async => null;

  @override
  Future<void> setUsername(String username) async {}

  @override
  Future<String?> getLanguage() async => 'fr';

  @override
  Future<void> setLanguage(String language) async {}

  @override
  Future<String> getBaseSystemPrompt() async => '';

  @override
  Future<void> setBaseSystemPrompt(String baseSystemPrompt) async {}

  @override
  Future<bool> getSoundEffects() async => true;

  @override
  Future<void> setSoundEffects(bool soundEffects) async {}

  @override
  Future<String> getTtsVoice(String language) async => 'voice';

  @override
  Future<void> setTtsVoice(String name, String language) async {}
}

class MockYofardevRepository implements YofardevRepository {
  @override
  Future<ChatEntry> askYofardevAi(
    Chat chat,
    String userMessage, {
    bool functionCallingEnabled = true,
  }) async {
    return ChatEntry(
      id: 'test',
      entryType: EntryType.yofardev,
      body: 'response',
      timestamp: DateTime.now(),
    );
  }
}

void main() {
  group('ChatsCubit', () {
    late ChatsCubit chatsCubit;

    setUp(() {
      chatsCubit = ChatsCubit(
        chatHistoryService: MockChatHistoryService(),
        settingsService: MockSettingsService(),
        yofardevRepository: MockYofardevRepository(),
      );
    });

    tearDown(() {
      chatsCubit.close();
    });

    test('initial state should have default values', () {
      expect(chatsCubit.state.status, ChatsStatus.loading);
      expect(chatsCubit.state.chatsList, isEmpty);
      expect(chatsCubit.state.currentChat, const Chat());
      expect(chatsCubit.state.openedChat, const Chat());
      expect(chatsCubit.state.errorMessage, '');
      expect(chatsCubit.state.soundEffectsEnabled, isTrue);
      expect(chatsCubit.state.currentLanguage, 'fr');
      expect(chatsCubit.state.audioPathsWaitingSentences, isEmpty);
      expect(chatsCubit.state.initializing, isTrue);
      expect(chatsCubit.state.functionCallingEnabled, isTrue);
    });

    group('toggleFunctionCalling', () {
      test('should toggle function calling enabled state', () {
        final bool initialValue = chatsCubit.state.functionCallingEnabled;

        chatsCubit.toggleFunctionCalling();

        expect(chatsCubit.state.functionCallingEnabled, !initialValue);

        chatsCubit.toggleFunctionCalling();

        expect(chatsCubit.state.functionCallingEnabled, initialValue);
      });
    });

    group('setCurrentLanguage', () {
      test('should update current language', () {
        const String newLanguage = 'en';

        chatsCubit.setCurrentLanguage(newLanguage);

        expect(chatsCubit.state.currentLanguage, newLanguage);
      });
    });

    group('setSoundEffects', () {
      test('should update sound effects enabled', () {
        const bool newSoundEffectsEnabled = false;

        chatsCubit.setSoundEffects(newSoundEffectsEnabled);

        expect(chatsCubit.state.soundEffectsEnabled, newSoundEffectsEnabled);
      });
    });

    group('setCurrentChat', () {
      test('should update current chat', () {
        const Chat testChat = Chat(id: 'test-chat-id');

        chatsCubit.setCurrentChat(testChat);

        expect(chatsCubit.state.currentChat.id, testChat.id);
        expect(chatsCubit.state.currentChat.language, testChat.language);
      });
    });

    group('setOpenedChat', () {
      test('should update opened chat', () {
        const Chat testChat = Chat(id: 'opened-chat-id', language: 'fr');

        chatsCubit.setOpenedChat(testChat);

        expect(chatsCubit.state.openedChat.id, testChat.id);
        expect(chatsCubit.state.openedChat.language, testChat.language);
      });
    });

    group('shuffleWaitingSentences', () {
      test('should shuffle audio paths waiting sentences', () {
        final List<Map<String, dynamic>> originalList = <Map<String, dynamic>>[
          <String, dynamic>{'sentence': 'Hello', 'audioPath': 'path1'},
          <String, dynamic>{'sentence': 'World', 'audioPath': 'path2'},
          <String, dynamic>{'sentence': 'Test', 'audioPath': 'path3'},
        ];

        // Emit state with test data
        chatsCubit.emit(
          chatsCubit.state.copyWith(audioPathsWaitingSentences: originalList),
        );

        final List<Map<String, dynamic>> beforeShuffle =
            chatsCubit.state.audioPathsWaitingSentences;

        chatsCubit.shuffleWaitingSentences();

        final List<Map<String, dynamic>> afterShuffle =
            chatsCubit.state.audioPathsWaitingSentences;

        // Same length
        expect(afterShuffle.length, beforeShuffle.length);

        // Same elements (just shuffled)
        for (final Map<String, dynamic> item in beforeShuffle) {
          expect(afterShuffle.contains(item), isTrue);
        }
      });
    });

    group('updateBackgroundOpenedChat', () {
      test('should update background of opened chat', () {
        const Chat testChat = Chat(id: 'test-chat');

        chatsCubit.setOpenedChat(testChat);
        // Note: This method is async but we don't await in test
        // as it makes external service calls
        chatsCubit.updateBackgroundOpenedChat(AvatarBackgrounds.beach);

        // Verify state was updated
        expect(
          chatsCubit.state.openedChat.avatar.background,
          AvatarBackgrounds.beach,
        );
      });
    });

    group('updateAvatarOpenedChat', () {
      test('should update avatar config of opened chat', () {
        const Chat testChat = Chat(id: 'test-chat');

        const AvatarConfig newConfig = AvatarConfig(
          background: AvatarBackgrounds.beach,
          hat: AvatarHat.frenchBeret,
          top: AvatarTop.longCoat,
        );

        chatsCubit.setOpenedChat(testChat);
        // Note: This method is async but we don't await in test
        // as it makes external service calls
        chatsCubit.updateAvatarOpenedChat(newConfig);

        expect(
          chatsCubit.state.openedChat.avatar.background,
          AvatarBackgrounds.beach,
        );
        expect(chatsCubit.state.openedChat.avatar.hat, AvatarHat.frenchBeret);
        expect(chatsCubit.state.openedChat.avatar.top, AvatarTop.longCoat);
      });

      test('should update only specified avatar fields', () {
        const Chat testChat = Chat(id: 'test-chat');

        const AvatarConfig partialConfig = AvatarConfig(
          hat: AvatarHat.beanie,
          // Other fields null - should remain unchanged
        );

        chatsCubit.setOpenedChat(testChat);
        chatsCubit.updateAvatarOpenedChat(partialConfig);

        expect(chatsCubit.state.openedChat.avatar.hat, AvatarHat.beanie);
        // Unchanged fields
        expect(
          chatsCubit.state.openedChat.avatar.background,
          AvatarBackgrounds.lake,
        );
        expect(chatsCubit.state.openedChat.avatar.top, AvatarTop.pinkHoodie);
        expect(
          chatsCubit.state.openedChat.avatar.glasses,
          AvatarGlasses.glasses,
        );
      });
    });

    group('ChatsState', () {
      test('should create state with default values', () {
        const ChatsState state = ChatsState();

        expect(state.status, ChatsStatus.loading);
        expect(state.chatsList, isEmpty);
        expect(state.currentChat, const Chat());
        expect(state.openedChat, const Chat());
        expect(state.errorMessage, '');
        expect(state.soundEffectsEnabled, isTrue);
        expect(state.currentLanguage, 'fr');
        expect(state.audioPathsWaitingSentences, isEmpty);
        expect(state.initializing, isTrue);
        expect(state.functionCallingEnabled, isTrue);
      });

      test('should copy with new values correctly', () {
        const ChatsState state = ChatsState();

        final ChatsState newState = state.copyWith(
          status: ChatsStatus.success,
          errorMessage: 'Test error',
          soundEffectsEnabled: false,
          currentLanguage: 'en',
          functionCallingEnabled: false,
        );

        expect(newState.status, ChatsStatus.success);
        expect(newState.errorMessage, 'Test error');
        expect(newState.soundEffectsEnabled, isFalse);
        expect(newState.currentLanguage, 'en');
        expect(newState.functionCallingEnabled, isFalse);

        // Unchanged fields
        expect(newState.chatsList, state.chatsList);
        expect(newState.currentChat, state.currentChat);
        expect(newState.openedChat, state.openedChat);
        expect(
          newState.audioPathsWaitingSentences,
          state.audioPathsWaitingSentences,
        );
        expect(newState.initializing, state.initializing);
      });

      test('should copy with list values', () {
        const ChatsState state = ChatsState();

        final List<Chat> newChatsList = <Chat>[
          const Chat(id: 'chat1'),
          const Chat(id: 'chat2'),
        ];

        final List<Map<String, dynamic>> newAudioPaths = <Map<String, dynamic>>[
          <String, dynamic>{'sentence': 'test', 'audioPath': 'path'},
        ];

        final ChatsState newState = state.copyWith(
          chatsList: newChatsList,
          audioPathsWaitingSentences: newAudioPaths,
        );

        expect(newState.chatsList, newChatsList);
        expect(newState.audioPathsWaitingSentences, newAudioPaths);

        // Unchanged fields
        expect(newState.status, state.status);
        expect(newState.currentChat, state.currentChat);
        expect(newState.openedChat, state.openedChat);
      });

      test('should copy with chat values', () {
        const ChatsState state = ChatsState();

        const Chat newCurrentChat = Chat(id: 'current-chat');
        const Chat newOpenedChat = Chat(id: 'opened-chat', language: 'fr');

        final ChatsState newState = state.copyWith(
          currentChat: newCurrentChat,
          openedChat: newOpenedChat,
        );

        expect(newState.currentChat, newCurrentChat);
        expect(newState.openedChat, newOpenedChat);

        // Unchanged fields
        expect(newState.status, state.status);
        expect(newState.chatsList, state.chatsList);
      });

      test('props should include all fields', () {
        const ChatsState state = ChatsState();

        expect(
          state.props.length,
          11, // status, chatsList, currentChat, openedChat, errorMessage,
          // soundEffectsEnabled, currentLanguage, audioPathsWaitingSentences,
          // initializing, functionCallingEnabled
        );
      });

      test('props should be unique for different states', () {
        const ChatsState state1 = ChatsState();
        const ChatsState state2 = ChatsState(status: ChatsStatus.success);

        expect(state1.props, isNot(state2.props));
      });

      test('props should be same for equal states', () {
        const ChatsState state1 = ChatsState(
          status: ChatsStatus.success,
          currentLanguage: 'en',
        );
        const ChatsState state2 = ChatsState(
          status: ChatsStatus.success,
          currentLanguage: 'en',
        );

        expect(state1.props, state2.props);
      });
    });

    group('ChatsStatus enum', () {
      test('should have all required values', () {
        expect(ChatsStatus.values.length, 5);
        expect(ChatsStatus.values, contains(ChatsStatus.loading));
        expect(ChatsStatus.values, contains(ChatsStatus.success));
        expect(ChatsStatus.values, contains(ChatsStatus.updating));
        expect(ChatsStatus.values, contains(ChatsStatus.typing));
        expect(ChatsStatus.values, contains(ChatsStatus.error));
      });
    });
  });

  group('ChatEntry model', () {
    test('should create entry with all fields', () {
      final ChatEntry entry = ChatEntry(
        id: 'test-id',
        entryType: EntryType.user,
        body: 'Test message',
        timestamp: DateTime(2024),
        attachedImage: '/path/to/image.jpg',
      );

      expect(entry.id, 'test-id');
      expect(entry.entryType, EntryType.user);
      expect(entry.body, 'Test message');
      expect(entry.attachedImage, '/path/to/image.jpg');
    });

    test('should copy with new values', () {
      final ChatEntry entry = ChatEntry(
        id: 'test-id',
        entryType: EntryType.user,
        body: 'Original message',
        timestamp: DateTime(2024),
      );

      final ChatEntry newEntry = entry.copyWith(
        body: 'Updated message',
        entryType: EntryType.yofardev,
      );

      expect(newEntry.id, entry.id);
      expect(newEntry.body, 'Updated message');
      expect(newEntry.entryType, EntryType.yofardev);
      expect(newEntry.timestamp, entry.timestamp);
      expect(newEntry.attachedImage, entry.attachedImage);
    });

    test('should serialize and deserialize correctly', () {
      final ChatEntry entry = ChatEntry(
        id: 'test-id',
        entryType: EntryType.functionCalling,
        body: 'Test body',
        timestamp: DateTime(2024),
        attachedImage: '/path/to/image.jpg',
      );

      final Map<String, dynamic> json = entry.toJson();
      final ChatEntry deserialized = ChatEntry.fromJson(json);

      expect(deserialized.id, entry.id);
      expect(deserialized.entryType, entry.entryType);
      expect(deserialized.body, entry.body);
      expect(deserialized.attachedImage, entry.attachedImage);
    });

    test('should handle deserialization with missing fields', () {
      final Map<String, dynamic> incompleteJson = <String, dynamic>{
        'id': 'generated-id',
        'entryType': 'user',
        'body': 'Test',
        'timestamp': DateTime(2024).toIso8601String(),
        // Missing attachedImage
      };

      final ChatEntry entry = ChatEntry.fromJson(incompleteJson);

      expect(entry.id, 'generated-id');
      expect(entry.entryType, EntryType.user);
      expect(entry.body, 'Test');
    });

    test('should convert to and from JSON', () {
      final ChatEntry entry = ChatEntry(
        id: 'test-id',
        entryType: EntryType.user,
        body: 'Test message',
        timestamp: DateTime(2024),
      );

      final Map<String, dynamic> json = entry.toJson();
      final ChatEntry fromJson = ChatEntry.fromJson(json);

      expect(fromJson.id, entry.id);
      expect(fromJson.entryType, entry.entryType);
      expect(fromJson.body, entry.body);
    });

    test('should implement value equality', () {
      final ChatEntry entry1 = ChatEntry(
        id: 'test-id',
        entryType: EntryType.user,
        body: 'Test',
        timestamp: DateTime(2024),
        attachedImage: 'image.jpg',
      );

      final ChatEntry entry2 = ChatEntry(
        id: 'test-id',
        entryType: EntryType.user,
        body: 'Test',
        timestamp: DateTime(2024),
        attachedImage: 'image.jpg',
      );

      expect(entry1, equals(entry2));
      expect(entry1.hashCode, equals(entry2.hashCode));
    });
  });

  group('Chat model', () {
    test('should create chat with default values', () {
      const Chat chat = Chat();

      expect(chat.id, '');
      expect(chat.entries, isEmpty);
      expect(chat.avatar, const Avatar());
      expect(chat.language, 'en');
      expect(chat.systemPrompt, '');
      expect(chat.persona, ChatPersona.normal);
    });

    test('should create chat with custom values', () {
      const Chat chat = Chat(
        id: 'test-id',
        language: 'fr',
        systemPrompt: 'You are helpful',
        persona: ChatPersona.assistant,
      );

      expect(chat.id, 'test-id');
      expect(chat.language, 'fr');
      expect(chat.systemPrompt, 'You are helpful');
      expect(chat.persona, ChatPersona.assistant);
    });

    test('should copy with new values', () {
      const Chat chat = Chat(id: 'original-id');

      final List<ChatEntry> newEntries = <ChatEntry>[
        ChatEntry(
          id: 'entry1',
          entryType: EntryType.user,
          body: 'Hello',
          timestamp: DateTime(2024),
        ),
      ];

      final Chat newChat = chat.copyWith(
        id: 'new-id',
        entries: newEntries,
        language: 'fr',
      );

      expect(newChat.id, 'new-id');
      expect(newChat.entries, newEntries);
      expect(newChat.language, 'fr');
      expect(newChat.avatar, chat.avatar); // unchanged
      expect(newChat.persona, chat.persona); // unchanged
    });

    test('should serialize and deserialize correctly', () {
      final Chat chat = Chat(
        id: 'test-id',
        entries: <ChatEntry>[
          ChatEntry(
            id: 'entry1',
            entryType: EntryType.user,
            body: 'Hello',
            timestamp: DateTime(2024),
          ),
        ],
        language: 'fr',
        systemPrompt: 'Test prompt',
        persona: ChatPersona.coach,
      );

      final Map<String, dynamic> map = chat.toMap();
      final Chat deserialized = Chat.fromMap(map);

      expect(deserialized.id, chat.id);
      expect(deserialized.entries.length, chat.entries.length);
      expect(deserialized.entries.first.body, chat.entries.first.body);
      expect(deserialized.language, chat.language);
      expect(deserialized.systemPrompt, chat.systemPrompt);
      expect(deserialized.persona, chat.persona);
    });

    test('should convert to and from map', () {
      const Chat chat = Chat(id: 'test-id');

      final Map<String, dynamic> map = chat.toMap();
      final Chat fromMap = Chat.fromMap(map);

      expect(fromMap.id, chat.id);
      expect(fromMap.language, chat.language);
    });

    test('should support value equality', () {
      const Chat chat1 = Chat(id: 'test-id');
      const Chat chat2 = Chat(id: 'test-id');
      const Chat chat3 = Chat(id: 'different-id');

      expect(chat1, equals(chat2));
      expect(chat1, isNot(equals(chat3)));
    });
  });

  group('ChatPersona enum', () {
    test('should have all required personas', () {
      expect(ChatPersona.values.length, 8);
      expect(ChatPersona.values, contains(ChatPersona.assistant));
      expect(ChatPersona.values, contains(ChatPersona.normal));
      expect(ChatPersona.values, contains(ChatPersona.doomer));
      expect(ChatPersona.values, contains(ChatPersona.conservative));
      expect(ChatPersona.values, contains(ChatPersona.philosopher));
      expect(ChatPersona.values, contains(ChatPersona.geek));
      expect(ChatPersona.values, contains(ChatPersona.coach));
      expect(ChatPersona.values, contains(ChatPersona.psychologist));
    });
  });

  group('EntryType enum', () {
    test('should have all required types', () {
      expect(EntryType.values.length, 3);
      expect(EntryType.values, contains(EntryType.user));
      expect(EntryType.values, contains(EntryType.yofardev));
      expect(EntryType.values, contains(EntryType.functionCalling));
    });
  });
}
