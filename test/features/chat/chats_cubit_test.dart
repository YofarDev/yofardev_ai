import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/core/services/avatar_animation_service.dart';
import 'package:yofardev_ai/core/services/llm/llm_service.dart';
import 'package:yofardev_ai/core/services/llm/llm_stream_chunk.dart';
import 'package:yofardev_ai/core/services/prompt_datasource.dart';
import 'package:yofardev_ai/core/services/stream_processor/stream_processor_service.dart';
import 'package:yofardev_ai/features/avatar/domain/repositories/avatar_repository.dart';
import 'package:yofardev_ai/features/chat/domain/models/chat.dart';
import 'package:yofardev_ai/features/chat/domain/models/chat_entry.dart';
import 'package:yofardev_ai/features/chat/domain/repositories/chat_repository.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_entry_service.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_title_service.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_state.dart';
import 'package:yofardev_ai/features/settings/domain/repositories/settings_repository.dart';
import 'package:yofardev_ai/features/sound/data/datasources/tts_datasource.dart';

// Mocktail mock classes
class MockChatRepository extends Mock implements ChatRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockAvatarAnimationService extends Mock
    implements AvatarAnimationService {}

class MockAvatarRepository extends Mock implements AvatarRepository {}

class MockInterruptionService extends Mock implements InterruptionService {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  @override
  Stream<void> get interruptionStream => _controller.stream;

  @override
  Future<void> interrupt() async => _controller.add(null);

  @override
  void reset() {}

  @override
  bool get isInterrupted => false;

  @override
  void dispose() => _controller.close();
}

class MockPromptDatasource extends Mock implements PromptDatasource {}

class MockStreamProcessorService extends Mock
    implements StreamProcessorService {}

class MockChatEntryService extends Mock implements ChatEntryService {}

class MockTtsDatasource extends Mock implements TtsDatasource {}

/// Factory to create ChatTitleService with real LlmService for testing
ChatTitleService createMockChatTitleService() {
  final LlmService llmService = LlmService();
  final MockChatRepository mockChatRepository = MockChatRepository();

  // Stub default methods
  when(
    () => mockChatRepository.getCurrentChat(),
  ).thenAnswer((_) async => const Right<Exception, Chat>(Chat(id: 'test-id')));
  when(
    () => mockChatRepository.getChat(any()),
  ).thenAnswer((_) async => const Right<Exception, Chat?>(Chat(id: 'test-id')));
  when(
    () => mockChatRepository.updateChat(
      id: any(named: 'id'),
      updatedChat: any(named: 'updatedChat'),
    ),
  ).thenAnswer((_) async => const Right<Exception, void>(null));
  when(
    () => mockChatRepository.getChatsList(),
  ).thenAnswer((_) async => const Right<Exception, List<Chat>>(<Chat>[]));
  when(
    () => mockChatRepository.setCurrentChatId(any()),
  ).thenAnswer((_) async => const Right<Exception, void>(null));
  when(
    () => mockChatRepository.updateAvatar(any(), any()),
  ).thenAnswer((_) async => const Right<Exception, void>(null));
  when(
    () => mockChatRepository.deleteChat(any()),
  ).thenAnswer((_) async => const Right<Exception, void>(null));

  return ChatTitleService(
    chatRepository: mockChatRepository,
    llmService: llmService,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const Chat());
    registerFallbackValue(<Chat>[]);
    registerFallbackValue(<ChatEntry>[]);
    registerFallbackValue(const AvatarConfig());
    registerFallbackValue(const Avatar());
    registerFallbackValue(true);
    registerFallbackValue(0);
    registerFallbackValue(const Stream<LlmStreamChunk>.empty());
  });

  group('ChatCubit', () {
    late ChatCubit chatsCubit;
    late MockChatRepository mockChatRepository;

    setUp(() {
      // Create mock services
      mockChatRepository = MockChatRepository();
      final MockSettingsRepository mockSettingsRepository =
          MockSettingsRepository();
      final MockInterruptionService mockInterruptionService =
          MockInterruptionService();
      final MockPromptDatasource mockPromptDatasource = MockPromptDatasource();
      final MockStreamProcessorService mockStreamProcessorService =
          MockStreamProcessorService();
      final MockChatEntryService mockChatEntryService = MockChatEntryService();

      // Create a minimal AvatarAnimationService
      final AvatarAnimationService mockAnimationService =
          MockAvatarAnimationService();

      // Stub mockChatRepository default methods
      when(
        () =>
            mockChatRepository.createNewChat(language: any(named: 'language')),
      ).thenAnswer(
        (_) async => const Right<Exception, Chat>(Chat(id: 'test-id')),
      );
      when(() => mockChatRepository.getCurrentChat()).thenAnswer(
        (_) async => const Right<Exception, Chat>(Chat(id: 'test-id')),
      );
      when(() => mockChatRepository.getChat(any())).thenAnswer(
        (_) async => const Right<Exception, Chat?>(Chat(id: 'test-id')),
      );
      when(
        () => mockChatRepository.updateChat(
          id: any(named: 'id'),
          updatedChat: any(named: 'updatedChat'),
        ),
      ).thenAnswer((_) async => const Right<Exception, void>(null));
      when(
        () => mockChatRepository.getChatsList(),
      ).thenAnswer((_) async => const Right<Exception, List<Chat>>(<Chat>[]));
      when(
        () => mockChatRepository.setCurrentChatId(any()),
      ).thenAnswer((_) async => const Right<Exception, void>(null));
      when(
        () => mockChatRepository.updateAvatar(any(), any()),
      ).thenAnswer((_) async => const Right<Exception, void>(null));
      when(
        () => mockChatRepository.deleteChat(any()),
      ).thenAnswer((_) async => const Right<Exception, void>(null));
      when(
        () => mockChatRepository.askYofardevAi(
          any(),
          any(),
          functionCallingEnabled: any(named: 'functionCallingEnabled'),
        ),
      ).thenAnswer(
        (_) async => Right<Exception, List<ChatEntry>>(<ChatEntry>[
          ChatEntry(
            id: 'test',
            entryType: EntryType.yofardev,
            body: 'response',
            timestamp: DateTime.now(),
          ),
        ]),
      );

      // Stub mockSettingsRepository default methods
      when(
        () => mockSettingsRepository.getLanguage(),
      ).thenAnswer((_) async => const Right<Exception, String?>('fr'));
      when(
        () => mockSettingsRepository.getSoundEffects(),
      ).thenAnswer((_) async => const Right<Exception, bool>(true));
      when(
        () => mockSettingsRepository.setLanguage(any()),
      ).thenAnswer((_) async => const Right<Exception, void>(null));
      when(
        () => mockSettingsRepository.setSoundEffects(any()),
      ).thenAnswer((_) async => const Right<Exception, void>(null));

      // Stub PromptDatasource
      when(
        () => mockPromptDatasource.getSystemPrompt(),
      ).thenAnswer((_) async => 'Test system prompt');

      // Stub StreamProcessorService
      when(
        () => mockStreamProcessorService.processStream(
          any(),
          expectJson: any(named: 'expectJson'),
        ),
      ).thenAnswer((_) async* {});

      // Stub ChatEntryService
      when(
        () => mockChatEntryService.createUserEntry(
          prompt: any(named: 'prompt'),
          avatar: any(named: 'avatar'),
          attachedImage: any(named: 'attachedImage'),
        ),
      ).thenAnswer(
        (_) async => ChatEntry(
          id: 'test-id',
          entryType: EntryType.user,
          body: 'prompt',
          timestamp: DateTime.now(),
        ),
      );

      chatsCubit = ChatCubit(
        chatRepository: mockChatRepository,
        settingsRepository: mockSettingsRepository,
        avatarAnimationService: mockAnimationService,
        chatTitleService: createMockChatTitleService(),
        llmService: LlmService(),
        streamProcessor: mockStreamProcessorService,
        promptDatasource: mockPromptDatasource,
        interruptionService: mockInterruptionService,
        chatEntryService: mockChatEntryService,
      );
    });

    tearDown(() {
      chatsCubit.close();
    });

    test('initial state should have default values', () {
      expect(chatsCubit.state.status, ChatStatus.loading);
      expect(chatsCubit.state.chatsList, isEmpty);
      expect(chatsCubit.state.currentChat, const Chat());
      expect(chatsCubit.state.openedChat, const Chat());
      expect(chatsCubit.state.errorMessage, '');
      expect(chatsCubit.state.soundEffectsEnabled, isTrue);
      expect(chatsCubit.state.currentLanguage, 'fr');
      expect(chatsCubit.state.audioPathsWaitingSentences, isEmpty);
      expect(chatsCubit.state.initializing, isTrue);
      expect(chatsCubit.state.functionCallingEnabled, isFalse);
    });

    test('init should set initializing to false', () async {
      // Initially true
      expect(chatsCubit.state.initializing, isTrue);

      // Call init
      await chatsCubit.init();

      // Should be false after init completes
      expect(chatsCubit.state.initializing, isFalse);
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
      test('should update current language', () async {
        const String newLanguage = 'de';

        await chatsCubit.setCurrentLanguage(newLanguage);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(chatsCubit.state.currentLanguage, newLanguage);
      });
    });

    group('setSoundEffects', () {
      test('should update sound effects enabled', () async {
        const bool newSoundEffectsEnabled = false;

        await chatsCubit.setSoundEffects(newSoundEffectsEnabled);
        await Future<void>.delayed(const Duration(milliseconds: 10));

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

    group('ChatState', () {
      test('should create state with default values', () {
        const ChatState state = ChatState(
          currentChat: Chat(),
          openedChat: Chat(),
        );

        expect(state.status, ChatStatus.initial);
        expect(state.chatsList, isEmpty);
        expect(state.currentChat, const Chat());
        expect(state.openedChat, const Chat());
        expect(state.errorMessage, '');
        expect(state.soundEffectsEnabled, isTrue);
        expect(state.currentLanguage, 'fr');
        expect(state.audioPathsWaitingSentences, isEmpty);
        expect(state.initializing, isTrue);
        expect(state.functionCallingEnabled, isFalse);
      });

      test('should copy with new values correctly', () {
        const ChatState state = ChatState(
          currentChat: Chat(),
          openedChat: Chat(),
        );

        final ChatState newState = state.copyWith(
          status: ChatStatus.success,
          errorMessage: 'Test error',
          soundEffectsEnabled: false,
          currentLanguage: 'en',
          functionCallingEnabled: false,
        );

        expect(newState.status, ChatStatus.success);
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
        const ChatState state = ChatState(
          currentChat: Chat(),
          openedChat: Chat(),
        );

        final List<Chat> newChatsList = <Chat>[
          const Chat(id: 'chat1'),
          const Chat(id: 'chat2'),
        ];

        final List<Map<String, dynamic>> newAudioPaths = <Map<String, dynamic>>[
          <String, dynamic>{'sentence': 'test', 'audioPath': 'path'},
        ];

        final ChatState newState = state.copyWith(
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
        const ChatState state = ChatState(
          currentChat: Chat(),
          openedChat: Chat(),
        );

        const Chat newCurrentChat = Chat(id: 'current-chat');
        const Chat newOpenedChat = Chat(id: 'opened-chat', language: 'fr');

        final ChatState newState = state.copyWith(
          currentChat: newCurrentChat,
          openedChat: newOpenedChat,
        );

        expect(newState.currentChat, newCurrentChat);
        expect(newState.openedChat, newOpenedChat);

        // Unchanged fields
        expect(newState.status, state.status);
        expect(newState.chatsList, state.chatsList);
      });

      test('should include all fields', () {
        const ChatState state = ChatState(
          currentChat: Chat(),
          openedChat: Chat(),
        );

        // Verify all fields are present via toString
        final String str = state.toString();
        expect(str, contains('ChatState'));
        expect(str, contains('status'));
        expect(str, contains('chatsList'));
        expect(str, contains('currentChat'));
        expect(str, contains('openedChat'));
      });

      test('props should be unique for different states', () {
        const ChatState state1 = ChatState(
          currentChat: Chat(),
          openedChat: Chat(),
        );
        const ChatState state2 = ChatState(
          status: ChatStatus.success,
          currentChat: Chat(),
          openedChat: Chat(),
        );

        expect(state1, isNot(state2));
      });

      test('props should be same for equal states', () {
        const ChatState state1 = ChatState(
          status: ChatStatus.success,
          currentLanguage: 'en',
          currentChat: Chat(),
          openedChat: Chat(),
        );
        const ChatState state2 = ChatState(
          status: ChatStatus.success,
          currentLanguage: 'en',
          currentChat: Chat(),
          openedChat: Chat(),
        );

        expect(state1, state2);
      });
    });

    group('ChatStatus enum', () {
      test('should have all required values', () {
        expect(ChatStatus.values.length, 10);
        expect(ChatStatus.values, contains(ChatStatus.initial));
        expect(ChatStatus.values, contains(ChatStatus.loading));
        expect(ChatStatus.values, contains(ChatStatus.updating));
        expect(ChatStatus.values, contains(ChatStatus.loaded));
        expect(ChatStatus.values, contains(ChatStatus.typing));
        expect(ChatStatus.values, contains(ChatStatus.success));
        expect(ChatStatus.values, contains(ChatStatus.streaming));
        expect(ChatStatus.values, contains(ChatStatus.error));
        expect(ChatStatus.values, contains(ChatStatus.interrupted));
        expect(ChatStatus.values, contains(ChatStatus.creatingChat));
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
      expect(chat.language, 'fr');
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

  group('createNewChat with animation', () {
    late MockChatRepository mockChatRepository;
    late MockAvatarAnimationService mockAvatarAnimationService;
    late ChatCubit cubit;

    setUp(() {
      mockAvatarAnimationService = MockAvatarAnimationService();
      mockChatRepository = MockChatRepository();

      // Create mock services
      final MockInterruptionService mockInterruptionService =
          MockInterruptionService();
      final MockPromptDatasource mockPromptDatasource = MockPromptDatasource();
      final MockStreamProcessorService mockStreamProcessorService =
          MockStreamProcessorService();
      final MockChatEntryService mockChatEntryService = MockChatEntryService();

      // Stub mockChatRepository methods
      when(
        () =>
            mockChatRepository.createNewChat(language: any(named: 'language')),
      ).thenAnswer(
        (_) async => const Right<Exception, Chat>(Chat(id: 'test-id')),
      );
      when(() => mockChatRepository.getCurrentChat()).thenAnswer(
        (_) async => const Right<Exception, Chat>(Chat(id: 'test-id')),
      );
      when(() => mockChatRepository.getChat(any())).thenAnswer(
        (_) async => const Right<Exception, Chat?>(Chat(id: 'test-id')),
      );
      when(
        () => mockChatRepository.updateChat(
          id: any(named: 'id'),
          updatedChat: any(named: 'updatedChat'),
        ),
      ).thenAnswer((_) async => const Right<Exception, void>(null));
      when(
        () => mockChatRepository.deleteChat(any()),
      ).thenAnswer((_) async => const Right<Exception, void>(null));
      when(
        () => mockChatRepository.getChatsList(),
      ).thenAnswer((_) async => const Right<Exception, List<Chat>>(<Chat>[]));
      when(
        () => mockChatRepository.setCurrentChatId(any()),
      ).thenAnswer((_) async => const Right<Exception, void>(null));
      when(
        () => mockChatRepository.updateAvatar(any(), any()),
      ).thenAnswer((_) async => const Right<Exception, void>(null));
      when(
        () => mockChatRepository.askYofardevAi(
          any(),
          any(),
          functionCallingEnabled: any(named: 'functionCallingEnabled'),
        ),
      ).thenAnswer(
        (_) async => Right<Exception, List<ChatEntry>>(<ChatEntry>[
          ChatEntry(
            id: 'test',
            entryType: EntryType.yofardev,
            body: 'response',
            timestamp: DateTime.now(),
          ),
        ]),
      );

      // Stub mockAvatarAnimationService
      when(
        () => mockAvatarAnimationService.playNewChatSequence(any(), any()),
      ).thenAnswer((_) async {});

      cubit = ChatCubit(
        chatRepository: mockChatRepository,
        settingsRepository: MockSettingsRepository(),
        avatarAnimationService: mockAvatarAnimationService,
        chatTitleService: createMockChatTitleService(),
        llmService: LlmService(),
        streamProcessor: mockStreamProcessorService,
        promptDatasource: mockPromptDatasource,
        interruptionService: mockInterruptionService,
        chatEntryService: mockChatEntryService,
      );
    });

    tearDown(() {
      cubit.close();
    });

    test('should trigger animation sequence after chat creation', () async {
      // Arrange
      const Chat testChat = Chat(id: 'test-chat-123');
      when(
        () =>
            mockChatRepository.createNewChat(language: any(named: 'language')),
      ).thenAnswer((_) async => const Right<Exception, Chat>(testChat));

      // Act
      await cubit.createNewChat();

      // Assert
      verify(
        () =>
            mockAvatarAnimationService.playNewChatSequence(testChat.id, any()),
      ).called(1);
    });

    test(
      'should pass correct background config to animation service',
      () async {
        // Arrange
        const Chat testChat = Chat(
          id: 'test-chat-456',
          avatar: Avatar(background: AvatarBackgrounds.beach),
        );
        when(
          () => mockChatRepository.createNewChat(
            language: any(named: 'language'),
          ),
        ).thenAnswer((_) async => const Right<Exception, Chat>(testChat));

        // Act
        await cubit.createNewChat();

        // Assert
        verify(
          () => mockAvatarAnimationService.playNewChatSequence(
            testChat.id,
            any(
              that: isA<AvatarConfig>().having(
                (AvatarConfig c) => c.background,
                'background',
                AvatarBackgrounds.beach,
              ),
            ),
          ),
        ).called(1);
      },
    );
  });
}
