import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/task_llm_config.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/core/services/llm/llm_service.dart';
import 'package:yofardev_ai/core/services/prompt_datasource.dart';
import 'package:yofardev_ai/core/services/stream_processor/stream_processor_service.dart';
import 'package:yofardev_ai/features/chat/bloc/chat_message_cubit.dart';
import 'package:yofardev_ai/features/chat/bloc/chat_message_state.dart';
import 'package:yofardev_ai/features/chat/domain/models/chat.dart';
import 'package:yofardev_ai/features/chat/domain/models/chat_entry.dart';
import 'package:yofardev_ai/features/chat/domain/repositories/chat_repository.dart';
import 'package:yofardev_ai/features/settings/domain/repositories/settings_repository.dart';
import 'package:yofardev_ai/features/chat/widgets/floating_stop_button.dart';

class MockChatRepository implements ChatRepository {
  @override
  Future<Either<Exception, List<ChatEntry>>> askYofardevAi(
    Chat chat,
    String userMessage, {
    bool functionCallingEnabled = true,
  }) async {
    return const Right<Exception, List<ChatEntry>>(<ChatEntry>[]);
  }

  @override
  Future<Either<Exception, void>> updateChat({
    required String id,
    required Chat updatedChat,
  }) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, Chat>> createNewChat() async {
    return const Right<Exception, Chat>(Chat(id: 'test-id'));
  }

  @override
  Future<Either<Exception, Chat>> getCurrentChat() async {
    return const Right<Exception, Chat>(Chat(id: 'test-id'));
  }

  @override
  Future<Either<Exception, Chat?>> getChat(String id) async {
    return const Right<Exception, Chat?>(Chat(id: 'test-id'));
  }

  @override
  Future<Either<Exception, void>> deleteChat(String id) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, List<Chat>>> getChatsList() async {
    return const Right<Exception, List<Chat>>(<Chat>[]);
  }

  @override
  Future<Either<Exception, void>> setCurrentChatId(String chatId) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, void>> updateAvatar(
    String chatId,
    Avatar avatar,
  ) async {
    return const Right<Exception, void>(null);
  }
}

class MockSettingsRepository implements SettingsRepository {
  @override
  Future<Either<Exception, String?>> getLanguage() async {
    return const Right<Exception, String?>('en');
  }

  @override
  Future<Either<Exception, void>> setLanguage(String language) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, bool>> getSoundEffects() async {
    return const Right<Exception, bool>(true);
  }

  @override
  Future<Either<Exception, void>> setSoundEffects(bool soundEffects) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, String?>> getUsername() async {
    return const Right<Exception, String?>(null);
  }

  @override
  Future<Either<Exception, void>> setUsername(String username) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, String>> getSystemPrompt() async {
    return const Right<Exception, String>('System prompt');
  }

  @override
  Future<Either<Exception, void>> setSystemPrompt(String prompt) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, ChatPersona>> getPersona() async {
    return const Right<Exception, ChatPersona>(ChatPersona.normal);
  }

  @override
  Future<Either<Exception, void>> setPersona(ChatPersona persona) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, TaskLlmConfig>> getTaskLlmConfig() async {
    return Right<Exception, TaskLlmConfig>(TaskLlmConfig());
  }

  @override
  Future<Either<Exception, void>> setTaskLlmConfig(TaskLlmConfig config) async {
    return const Right<Exception, void>(null);
  }
}

class MockPromptDatasource implements PromptDatasource {
  @override
  Future<String> getSystemPrompt() async => 'Test system prompt';
}

class MockLlmService extends Mock implements LlmService {}

class MockStreamProcessorService extends Mock
    implements StreamProcessorService {}

void main() {
  group('FloatingStopButton', () {
    late InterruptionService interruptionService;
    late ChatMessageCubit chatCubit;

    setUp(() {
      interruptionService = InterruptionService();
      chatCubit = ChatMessageCubit(
        chatRepository: MockChatRepository(),
        settingsRepository: MockSettingsRepository(),
        llmService: MockLlmService(),
        streamProcessor: MockStreamProcessorService(),
        promptDatasource: MockPromptDatasource(),
        interruptionService: interruptionService,
      );
    });

    tearDown(() {
      chatCubit.close();
      interruptionService.dispose();
    });

    testWidgets('should not show when not streaming', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: chatCubit,
            child: const Scaffold(body: FloatingStopButton()),
          ),
        ),
      );

      // Assert
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('should show when streaming', (WidgetTester tester) async {
      // Arrange
      chatCubit.emit(
        chatCubit.state.copyWith(status: ChatMessageStatus.streaming),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: chatCubit,
            child: const Scaffold(body: FloatingStopButton()),
          ),
        ),
      );

      // Assert
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsOneWidget);
    });

    testWidgets('should call interrupt when tapped', (
      WidgetTester tester,
    ) async {
      // Arrange
      chatCubit.emit(
        chatCubit.state.copyWith(status: ChatMessageStatus.streaming),
      );
      final List<bool> interrupted = <bool>[false];

      interruptionService.interruptionStream.listen((_) {
        interrupted[0] = true;
      });

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: chatCubit,
            child: Scaffold(
              body: RepositoryProvider.value(
                value: interruptionService,
                child: const FloatingStopButton(),
              ),
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      // Assert
      expect(interrupted[0], true);
    });
  });
}
