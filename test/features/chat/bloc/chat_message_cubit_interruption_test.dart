import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/core/services/llm/llm_service.dart';
import 'package:yofardev_ai/core/services/prompt_datasource.dart';
import 'package:yofardev_ai/core/services/stream_processor/stream_processor_service.dart';
import 'package:yofardev_ai/features/chat/bloc/chat_message_cubit.dart';
import 'package:yofardev_ai/features/chat/bloc/chat_message_state.dart';
import 'package:yofardev_ai/features/chat/domain/repositories/chat_repository.dart';
import 'package:yofardev_ai/features/settings/domain/repositories/settings_repository.dart';

class MockChatRepository extends Mock implements ChatRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockLlmService extends Mock implements LlmService {}

class MockStreamProcessorService extends Mock
    implements StreamProcessorService {}

class MockPromptDatasource extends Mock implements PromptDatasource {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatMessageCubit Interruption', () {
    late MockChatRepository mockChatRepository;
    late MockSettingsRepository mockSettingsRepository;
    late MockLlmService mockLlmService;
    late MockStreamProcessorService mockStreamProcessor;
    late MockPromptDatasource mockPromptDatasource;
    late InterruptionService interruptionService;
    late ChatMessageCubit cubit;

    setUp(() {
      mockChatRepository = MockChatRepository();
      mockSettingsRepository = MockSettingsRepository();
      mockLlmService = MockLlmService();
      mockStreamProcessor = MockStreamProcessorService();
      mockPromptDatasource = MockPromptDatasource();
      interruptionService = InterruptionService();

      cubit = ChatMessageCubit(
        chatRepository: mockChatRepository,
        settingsRepository: mockSettingsRepository,
        llmService: mockLlmService,
        streamProcessor: mockStreamProcessor,
        promptDatasource: mockPromptDatasource,
        interruptionService: interruptionService,
      );
    });

    tearDown(() async {
      await cubit.close();
      interruptionService.dispose();
    });

    test(
      'should transition to interrupted state when interruption occurs',
      () async {
        // Arrange - start with streaming state
        cubit.emit(cubit.state.copyWith(status: ChatMessageStatus.streaming));

        // Act
        await interruptionService.interrupt();
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(cubit.state.status, ChatMessageStatus.interrupted);
        expect(cubit.state.streamingContent, '');
      },
    );

    test('should not interrupt when not streaming', () async {
      // Arrange - start with initial state
      expect(cubit.state.status, ChatMessageStatus.initial);

      // Act
      await interruptionService.interrupt();
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert - should still be in initial state
      expect(cubit.state.status, ChatMessageStatus.initial);
    });
  });
}
