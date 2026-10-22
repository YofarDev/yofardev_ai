import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/chat_entry.dart';
import 'package:yofardev_ai/core/models/global_memory.dart';
import 'package:yofardev_ai/core/models/llm_message.dart';
import 'package:yofardev_ai/core/models/result.dart';
import 'package:yofardev_ai/core/repositories/global_memory_repository.dart';
import 'package:yofardev_ai/core/repositories/settings_repository.dart';
import 'package:yofardev_ai/core/services/llm/llm_service_interface.dart';
import 'package:yofardev_ai/features/chat/domain/services/global_memory_service.dart';

class MockGlobalMemoryRepository extends Mock
    implements GlobalMemoryRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockLlmServiceInterface extends Mock implements LlmServiceInterface {}

void main() {
  setUpAll(() {
    registerFallbackValue(GlobalMemory.empty());
    registerFallbackValue(<String>[]);
  });

  late MockGlobalMemoryRepository memoryRepository;
  late MockSettingsRepository settingsRepository;
  late MockLlmServiceInterface llmService;
  late GlobalMemoryService service;

  setUp(() {
    memoryRepository = MockGlobalMemoryRepository();
    settingsRepository = MockSettingsRepository();
    llmService = MockLlmServiceInterface();

    when(() => llmService.init()).thenAnswer((_) async {});

    service = GlobalMemoryService(
      memoryRepository: memoryRepository,
      settingsRepository: settingsRepository,
      llmService: llmService,
    );
  });

  GlobalMemory storedMemory(GlobalMemory memory) {
    when(() => memoryRepository.getMemory())
        .thenAnswer((_) async => Result<GlobalMemory>.ok(memory));
    when(
      () => memoryRepository.saveMemory(any()),
    ).thenAnswer((_) async => Result<void>.ok(null));
    return memory;
  }

  Chat chatWithExchange({String? userBody, String? assistantBody}) {
    final List<ChatEntry> entries = <ChatEntry>[];
    if (userBody != null) {
      entries.add(
        ChatEntry(
          id: 'user-1',
          entryType: EntryType.user,
          body: "User : \n'''$userBody'''",
          timestamp: DateTime.now(),
        ),
      );
    }
    if (assistantBody != null) {
      entries.add(
        ChatEntry(
          id: 'assistant-1',
          entryType: EntryType.yofardev,
          body:
              '{"message": "$assistantBody", "background": "none", "soundEffect": "none"}',
          timestamp: DateTime.now(),
        ),
      );
    }
    return Chat(id: 'chat-1', entries: entries);
  }

  group('GlobalMemoryService.buildMemoryMessage', () {
    test('returns null when memory is disabled', () async {
      when(
        () => settingsRepository.getMemoryEnabled(),
      ).thenAnswer((_) async => Result<bool>.ok(false));

      expect(await service.buildMemoryMessage(), isNull);
      verifyNever(() => memoryRepository.getMemory());
    });

    test('returns null when memory is empty', () async {
      when(
        () => settingsRepository.getMemoryEnabled(),
      ).thenAnswer((_) async => Result<bool>.ok(true));
      storedMemory(GlobalMemory.empty());

      expect(await service.buildMemoryMessage(), isNull);
    });

    test('builds a system message listing all items', () async {
      when(
        () => settingsRepository.getMemoryEnabled(),
      ).thenAnswer((_) async => Result<bool>.ok(true));
      storedMemory(
        GlobalMemory(
          items: <GlobalMemoryItem>[
            GlobalMemoryItem(
              id: 'a',
              text: 'Works as a developer',
              updatedAt: DateTime(2026, 1, 1),
            ),
            GlobalMemoryItem(
              id: 'b',
              text: 'Lives in Paris',
              updatedAt: DateTime(2026, 1, 2),
            ),
          ],
        ),
      );

      final LlmMessage? message = await service.buildMemoryMessage();

      expect(message, isNotNull);
      expect(message!.role, LlmMessageRole.system);
      expect(message.body, contains('Works as a developer'));
      expect(message.body, contains('Lives in Paris'));
    });
  });

  group('GlobalMemoryService.updateMemory', () {
    void stubExtraction(String? response) {
      when(
        () => llmService.extractMemory(
          conversationExcerpt: any(named: 'conversationExcerpt'),
          currentMemory: any(named: 'currentMemory'),
          config: any(named: 'config'),
        ),
      ).thenAnswer((_) async => response);
    }

    test('skips when memory is disabled', () async {
      when(
        () => settingsRepository.getMemoryEnabled(),
      ).thenAnswer((_) async => Result<bool>.ok(false));

      await service.updateMemory(chatWithExchange(userBody: 'hello'));

      verifyNever(
        () => llmService.extractMemory(
          conversationExcerpt: any(named: 'conversationExcerpt'),
          currentMemory: any(named: 'currentMemory'),
          config: any(named: 'config'),
        ),
      );
    });

    test('skips when the chat has no user message', () async {
      when(
        () => settingsRepository.getMemoryEnabled(),
      ).thenAnswer((_) async => Result<bool>.ok(true));

      await service.updateMemory(
        chatWithExchange(assistantBody: 'hi there'),
      );

      verifyNever(() => llmService.extractMemory(
        conversationExcerpt: any(named: 'conversationExcerpt'),
        currentMemory: any(named: 'currentMemory'),
        config: any(named: 'config'),
      ));
    });

    test('saves merged list when the LLM returns new facts', () async {
      when(
        () => settingsRepository.getMemoryEnabled(),
      ).thenAnswer((_) async => Result<bool>.ok(true));
      storedMemory(GlobalMemory.empty());
      stubExtraction('{"memory": ["Likes hiking", "Has a dog"]}');

      await service.updateMemory(
        chatWithExchange(userBody: 'I love hiking with my dog'),
      );

      final dynamic saved = verify(
        () => memoryRepository.saveMemory(captureAny()),
      ).captured.single as GlobalMemory;

      expect(saved.texts, <String>['Likes hiking', 'Has a dog']);
    });

    test('keeps existing item ids for unchanged texts', () async {
      when(
        () => settingsRepository.getMemoryEnabled(),
      ).thenAnswer((_) async => Result<bool>.ok(true));
      storedMemory(
        GlobalMemory(
          items: <GlobalMemoryItem>[
            GlobalMemoryItem(
              id: 'stable-id',
              text: 'Lives in Paris',
              updatedAt: DateTime(2026, 1, 1),
            ),
          ],
        ),
      );
      stubExtraction(
        '{"memory": ["Lives in Paris", "works as a DEVELOPER"]}',
      );

      await service.updateMemory(chatWithExchange(userBody: 'hi'));

      final dynamic saved = verify(
        () => memoryRepository.saveMemory(captureAny()),
      ).captured.single as GlobalMemory;

      expect(saved.items.first.id, 'stable-id');
      expect(saved.items.first.text, 'Lives in Paris');
      expect(saved.items.last.text, 'works as a DEVELOPER');
    });

    test('does not save when nothing changed', () async {
      when(
        () => settingsRepository.getMemoryEnabled(),
      ).thenAnswer((_) async => Result<bool>.ok(true));
      storedMemory(
        GlobalMemory(
          items: <GlobalMemoryItem>[
            GlobalMemoryItem(
              id: 'a',
              text: 'Lives in Paris',
              updatedAt: DateTime(2026, 1, 1),
            ),
          ],
        ),
      );
      stubExtraction('{"memory": ["lives in  paris"]}');

      await service.updateMemory(chatWithExchange(userBody: 'hello'));

      verifyNever(() => memoryRepository.saveMemory(any()));
    });

    test('keeps current memory on unparseable response', () async {
      when(
        () => settingsRepository.getMemoryEnabled(),
      ).thenAnswer((_) async => Result<bool>.ok(true));
      storedMemory(GlobalMemory.empty());
      stubExtraction('Sorry, I cannot answer that.');

      await service.updateMemory(chatWithExchange(userBody: 'hello'));

      verifyNever(() => memoryRepository.saveMemory(any()));
    });

    test('keeps current memory on null response', () async {
      when(
        () => settingsRepository.getMemoryEnabled(),
      ).thenAnswer((_) async => Result<bool>.ok(true));
      storedMemory(GlobalMemory.empty());
      stubExtraction(null);

      await service.updateMemory(chatWithExchange(userBody: 'hello'));

      verifyNever(() => memoryRepository.saveMemory(any()));
    });

    test('parses markdown-fenced JSON responses', () async {
      when(
        () => settingsRepository.getMemoryEnabled(),
      ).thenAnswer((_) async => Result<bool>.ok(true));
      storedMemory(GlobalMemory.empty());
      stubExtraction('```json\n{"memory": ["Likes pizza"]}\n```');

      await service.updateMemory(chatWithExchange(userBody: 'pizza'));

      final dynamic saved = verify(
        () => memoryRepository.saveMemory(captureAny()),
      ).captured.single as GlobalMemory;

      expect(saved.texts, <String>['Likes pizza']);
    });

    test('deduplicates and caps item length', () async {
      when(
        () => settingsRepository.getMemoryEnabled(),
      ).thenAnswer((_) async => Result<bool>.ok(true));
      storedMemory(GlobalMemory.empty());
      stubExtraction(
        '{"memory": ["Same fact", "same  FACT", "${'x' * 300}"]}',
      );

      await service.updateMemory(chatWithExchange(userBody: 'hello'));

      final dynamic saved = verify(
        () => memoryRepository.saveMemory(captureAny()),
      ).captured.single as GlobalMemory;

      expect(saved.items.length, 2);
      expect(
        saved.items.last.text.length,
        lessThanOrEqualTo(GlobalMemory.maxItemLength),
      );
    });
  });
}
