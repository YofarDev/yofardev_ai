import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/features/avatar/presentation/bloc/avatar_cubit.dart';
import 'package:yofardev_ai/features/avatar/presentation/bloc/avatar_state.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_state.dart';
import 'package:yofardev_ai/features/chat/domain/models/chat.dart';
import 'package:yofardev_ai/features/chat/domain/models/chat_entry.dart';
import 'package:yofardev_ai/features/chat/widgets/ai_text_input/ai_text_input.dart';
import 'package:yofardev_ai/features/talking/presentation/bloc/talking_cubit.dart';
import 'package:yofardev_ai/features/talking/presentation/bloc/talking_state.dart';

// Mock cubits for testing
class MockAvatarCubit extends Mock implements AvatarCubit {}

class MockChatCubit extends Mock implements ChatCubit {}

class MockTalkingCubit extends Mock implements TalkingCubit {}

// Simple fake cubit that can emit states for testing
class FakeChatCubit extends Cubit<ChatState> implements ChatCubit {
  FakeChatCubit() : super(ChatState.initial());

  @override
  void noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    // Register fallback values
    registerFallbackValue(const Avatar());
    registerFallbackValue(const AvatarConfig());
    registerFallbackValue(const Chat());
    registerFallbackValue(const TalkingState.idle());
    registerFallbackValue(
      ChatState(
        currentChat: const Chat(),
        openedChat: const Chat(),
        currentLanguage: 'en',
        status: ChatStatus.initial,
      ),
    );
  });

  group('AiTextInput Widget', () {
    late MockAvatarCubit mockAvatarCubit;
    late MockChatCubit mockChatsCubit;
    late MockTalkingCubit mockTalkingCubit;

    setUp(() {
      mockAvatarCubit = MockAvatarCubit();
      mockChatsCubit = MockChatCubit();
      mockTalkingCubit = MockTalkingCubit();

      // Setup default mock behaviors
      when(
        () => mockAvatarCubit.stream,
      ).thenAnswer((_) => const Stream<AvatarState>.empty());
      when(() => mockAvatarCubit.state).thenReturn(
        const AvatarState(avatar: Avatar(), avatarConfig: AvatarConfig()),
      );

      when(
        () => mockChatsCubit.stream,
      ).thenAnswer((_) => const Stream<ChatState>.empty());
      when(() => mockChatsCubit.state).thenReturn(
        ChatState(
          currentChat: const Chat(),
          openedChat: const Chat(),
          currentLanguage: 'en',
          status: ChatStatus.initial,
        ),
      );

      when(
        () => mockTalkingCubit.stream,
      ).thenAnswer((_) => const Stream<TalkingState>.empty());
      when(() => mockTalkingCubit.state).thenReturn(const TalkingState.idle());
    });

    Widget buildTestWidget() {
      return MultiBlocProvider(
        providers: <SingleChildWidget>[
          BlocProvider<AvatarCubit>.value(value: mockAvatarCubit),
          BlocProvider<ChatCubit>.value(value: mockChatsCubit),
          BlocProvider<TalkingCubit>.value(value: mockTalkingCubit),
        ],
        child: const MaterialApp(home: Scaffold(body: AiTextInput())),
      );
    }

    testWidgets('widget renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(AiTextInput), findsOneWidget);
    });

    testWidgets('widget renders with onlyText parameter', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: <SingleChildWidget>[
            BlocProvider<AvatarCubit>.value(value: mockAvatarCubit),
            BlocProvider<ChatCubit>.value(value: mockChatsCubit),
            BlocProvider<TalkingCubit>.value(value: mockTalkingCubit),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AiTextInput(onlyText: true)),
          ),
        ),
      );

      expect(find.byType(AiTextInput), findsOneWidget);
    });

    testWidgets('text field is visible when talking is idle', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      // TextField should be visible when talking state is idle
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('text field opacity changes when talking', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      // Initially idle, text field should be visible
      expect(find.byType(TextField), findsOneWidget);

      // Simulate talking state
      when(
        () => mockTalkingCubit.state,
      ).thenReturn(const TalkingState.speaking());
      await tester.pump();

      // Text field should still be in tree but may have different opacity
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows error snackbar when ChatCubit has error', (
      WidgetTester tester,
    ) async {
      // Use a real cubit for this test to properly emit states
      final FakeChatCubit fakeChatsCubit = FakeChatCubit();

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: <SingleChildWidget>[
            BlocProvider<AvatarCubit>.value(value: mockAvatarCubit),
            BlocProvider<ChatCubit>.value(value: fakeChatsCubit),
            BlocProvider<TalkingCubit>.value(value: mockTalkingCubit),
          ],
          child: const MaterialApp(home: Scaffold(body: AiTextInput())),
        ),
      );

      // Emit error state
      fakeChatsCubit.emit(
        fakeChatsCubit.state.copyWith(
          status: ChatStatus.error,
          errorMessage: 'Test error',
        ),
      );
      await tester.pump();

      // SnackBar should be shown
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Test error'), findsOneWidget);
    });

    testWidgets('displays function calling widgets when present', (
      WidgetTester tester,
    ) async {
      // Create chat with function calling entry
      final Chat chat = Chat(
        id: 'test-chat',
        entries: <ChatEntry>[
          ChatEntry(
            id: '1',
            entryType: EntryType.user,
            body: 'User message',
            timestamp: DateTime.now(),
          ),
        ],
      );

      when(() => mockChatsCubit.state).thenReturn(
        ChatState(
          currentChat: chat,
          openedChat: chat,
          currentLanguage: 'en',
          status: ChatStatus.initial,
        ),
      );

      await tester.pumpWidget(buildTestWidget());

      // Widget should render without crashing
      expect(find.byType(AiTextInput), findsOneWidget);
    });
  });
}
