import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/chat_entry.dart';
import 'package:yofardev_ai/core/l10n/generated/app_localizations.dart';
import 'package:yofardev_ai/features/avatar/presentation/bloc/avatar_cubit.dart';
import 'package:yofardev_ai/features/avatar/presentation/bloc/avatar_state.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_state.dart';
import 'package:yofardev_ai/features/chat/screens/chats_list_screen.dart';
import 'package:yofardev_ai/features/chat/widgets/chat_list_container.dart';
import 'package:yofardev_ai/features/chat/widgets/chat_list_empty_state.dart';
import 'package:yofardev_ai/features/talking/presentation/bloc/talking_cubit.dart';
import 'package:yofardev_ai/features/talking/presentation/bloc/talking_state.dart';

// Mock cubits for screen testing
class MockChatCubit extends Mock implements ChatCubit {}

class MockAvatarCubit extends Mock implements AvatarCubit {}

class MockTalkingCubit extends Mock implements TalkingCubit {}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    registerFallbackValue(
      ChatState(
        currentChat: const Chat(),
        openedChat: const Chat(),
        currentLanguage: 'en',
        status: ChatStatus.initial,
      ),
    );
    registerFallbackValue(
      const AvatarState(avatar: Avatar(), avatarConfig: AvatarConfig()),
    );
    registerFallbackValue(const TalkingState.idle());
    registerFallbackValue(const Avatar());
    registerFallbackValue(const AvatarConfig());
  });

  group('ChatsListScreen Integration Tests', () {
    late MockChatCubit mockChatsCubit;
    late MockAvatarCubit mockAvatarCubit;
    late MockTalkingCubit mockTalkingCubit;

    setUp(() {
      mockChatsCubit = MockChatCubit();
      mockAvatarCubit = MockAvatarCubit();
      mockTalkingCubit = MockTalkingCubit();

      // Setup default mock behaviors
      when(
        () => mockChatsCubit.stream,
      ).thenAnswer((_) => const Stream<ChatState>.empty());
      when(() => mockChatsCubit.state).thenReturn(
        ChatState(
          currentChat: const Chat(),
          openedChat: const Chat(),
          currentLanguage: 'en',
          status: ChatStatus.initial,
          chatsList: <Chat>[],
        ),
      );

      // Stub methods that will be called by the screen
      when(() => mockChatsCubit.fetchChatsList()).thenAnswer((_) async {});
      when(() => mockAvatarCubit.loadAvatar(any())).thenAnswer((_) async {});
      when(() => mockTalkingCubit.init()).thenAnswer((_) async {});

      when(
        () => mockAvatarCubit.stream,
      ).thenAnswer((_) => const Stream<AvatarState>.empty());
      when(() => mockAvatarCubit.state).thenReturn(
        const AvatarState(avatar: Avatar(), avatarConfig: AvatarConfig()),
      );

      when(
        () => mockTalkingCubit.stream,
      ).thenAnswer((_) => const Stream<TalkingState>.empty());
      when(() => mockTalkingCubit.state).thenReturn(const TalkingState.idle());
    });

    Widget buildTestWidget() {
      return MultiBlocProvider(
        providers: <SingleChildWidget>[
          BlocProvider<ChatCubit>.value(value: mockChatsCubit),
          BlocProvider<AvatarCubit>.value(value: mockAvatarCubit),
          BlocProvider<TalkingCubit>.value(value: mockTalkingCubit),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChatsListPage(),
        ),
      );
    }

    testWidgets('screen renders correctly with empty chat list', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(ChatsListPage), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      verify(() => mockChatsCubit.fetchChatsList()).called(1);
    });

    testWidgets('shows loading indicator when status is loading', (
      WidgetTester tester,
    ) async {
      when(() => mockChatsCubit.state).thenReturn(
        ChatState(
          currentChat: const Chat(),
          openedChat: const Chat(),
          currentLanguage: 'en',
          status: ChatStatus.loading,
          chatsList: <Chat>[],
        ),
      );

      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state when chat list is empty', (
      WidgetTester tester,
    ) async {
      when(() => mockChatsCubit.state).thenReturn(
        ChatState(
          currentChat: const Chat(),
          openedChat: const Chat(),
          currentLanguage: 'en',
          status: ChatStatus.loaded,
          chatsList: <Chat>[],
        ),
      );

      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(ChatListEmptyState), findsOneWidget);
    });

    testWidgets('displays chat list items when available', (
      WidgetTester tester,
    ) async {
      final List<Chat> chatList = <Chat>[
        Chat(id: 'chat1', entries: <ChatEntry>[], language: 'en'),
        Chat(id: 'chat2', entries: <ChatEntry>[], language: 'fr'),
      ];

      when(() => mockChatsCubit.state).thenReturn(
        ChatState(
          currentChat: chatList.first,
          openedChat: chatList.first,
          currentLanguage: 'en',
          status: ChatStatus.loaded,
          chatsList: chatList,
        ),
      );

      await tester.pumpWidget(buildTestWidget());

      // Should display chat list container
      expect(find.byType(ChatListContainer), findsOneWidget);
    });
  });
}
