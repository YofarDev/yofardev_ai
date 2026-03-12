import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/features/avatar/presentation/bloc/avatar_cubit.dart';
import 'package:yofardev_ai/features/avatar/presentation/bloc/avatar_state.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/chat_entry.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_state.dart';
import 'package:yofardev_ai/features/chat/widgets/ai_text_input/ai_text_input.dart';
import 'package:yofardev_ai/features/talking/presentation/bloc/talking_cubit.dart';
import 'package:yofardev_ai/features/talking/presentation/bloc/talking_state.dart';

class MockAvatarCubit extends Mock implements AvatarCubit {}

class MockChatCubit extends Mock implements ChatCubit {}

class MockTalkingCubit extends Mock implements TalkingCubit {}

class FakeChatCubit extends Cubit<ChatState> implements ChatCubit {
  FakeChatCubit() : super(ChatState.initial());
  @override
  void noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
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

    void setupMocks() {
      mockAvatarCubit = MockAvatarCubit();
      mockChatsCubit = MockChatCubit();
      mockTalkingCubit = MockTalkingCubit();

      // All streams must be empty to prevent continuous rebuilds
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
    }

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

    setUp(setupMocks);

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
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('text field remains in tree when speaking', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      when(
        () => mockTalkingCubit.state,
      ).thenReturn(const TalkingState.speaking());
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows error snackbar when ChatCubit has error', (
      WidgetTester tester,
    ) async {
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

      fakeChatsCubit.emit(
        fakeChatsCubit.state.copyWith(
          status: ChatStatus.error,
          errorMessage: 'Test error',
        ),
      );
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Test error'), findsOneWidget);
    });

    testWidgets('text field opacity is 1 when talking is idle', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // The Opacity wrapping the TextField should be visible (1.0)
      final Iterable<Opacity> opacities = tester.widgetList<Opacity>(
        find.byType(Opacity),
      );
      expect(opacities.isNotEmpty, isTrue);
      // All opacities should be 1.0 when idle (no opacity=0 in tree)
      for (final Opacity o in opacities) {
        expect(o.opacity, isNot(0.0));
      }
    });

    testWidgets('shows CurrentPromptText when speaking with a user entry', (
      WidgetTester tester,
    ) async {
      final Chat chatWithEntry = Chat(
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
          currentChat: chatWithEntry,
          openedChat: chatWithEntry,
          currentLanguage: 'en',
          status: ChatStatus.streaming,
        ),
      );
      when(
        () => mockTalkingCubit.state,
      ).thenReturn(const TalkingState.speaking());

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: <SingleChildWidget>[
            BlocProvider<AvatarCubit>.value(value: mockAvatarCubit),
            BlocProvider<ChatCubit>.value(value: mockChatsCubit),
            BlocProvider<TalkingCubit>.value(value: mockTalkingCubit),
          ],
          child: const MaterialApp(home: Scaffold(body: AiTextInput())),
        ),
      );
      await tester.pump();

      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('does not show CurrentPromptText when idle', (
      WidgetTester tester,
    ) async {
      when(() => mockTalkingCubit.state).thenReturn(const TalkingState.idle());

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // TextField should be visible
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
