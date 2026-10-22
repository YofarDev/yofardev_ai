import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:yofardev_ai/features/chat/widgets/modern_chat_bubble.dart';
import '../../../helpers/golden_test_helper.dart';

void main() {
  group('ModernChatBubble Golden Tests', () {
    setUpAll(() async {
      await GoldenTestHelper.init();
    });

    // User message bubbles
    group('User Messages', () {
      testGoldens('renders user message bubble', (WidgetTester tester) async {
        await tester.pumpWidget(
          GoldenTestHelper.makeTestableWidget(
            child: const SizedBox(
              width: 400,
              child: ModernChatBubble(
                isUser: true,
                child: Text('Hello! This is a user message.'),
              ),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'chat_bubble_user_basic');
      });

      testGoldens('renders user message with timestamp', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          GoldenTestHelper.makeTestableWidget(
            child: SizedBox(
              width: 400,
              child: ModernChatBubble(
                isUser: true,
                timestamp: '10:30 AM',
                child: const Text('User message with timestamp'),
              ),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'chat_bubble_user_with_timestamp');
      });

      testGoldens('renders long user message', (WidgetTester tester) async {
        const String longMessage = '''
This is a very long user message that should wrap properly and display correctly in the chat bubble.
It tests the text wrapping and layout behavior of the chat bubble widget.
''';

        await tester.pumpWidget(
          GoldenTestHelper.makeTestableWidget(
            child: const SizedBox(
              width: 400,
              child: ModernChatBubble(isUser: true, child: Text(longMessage)),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'chat_bubble_user_long');
      });
    });

    // AI message bubbles
    group('AI Messages', () {
      testGoldens('renders AI message bubble', (WidgetTester tester) async {
        await tester.pumpWidget(
          GoldenTestHelper.makeTestableWidget(
            child: const SizedBox(
              width: 400,
              child: ModernChatBubble(
                isUser: false,
                child: Text('Hello! This is an AI message.'),
              ),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'chat_bubble_ai_basic');
      });

      testGoldens('renders AI message with avatar', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          GoldenTestHelper.makeTestableWidget(
            child: SizedBox(
              width: 400,
              child: ModernChatBubble(
                isUser: false,
                showAvatar: true,
                avatar: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
                child: const Text('AI message with avatar'),
              ),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'chat_bubble_ai_with_avatar');
      });

      testGoldens('renders AI message with timestamp', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          GoldenTestHelper.makeTestableWidget(
            child: SizedBox(
              width: 400,
              child: ModernChatBubble(
                isUser: false,
                timestamp: '10:31 AM',
                child: const Text('AI message with timestamp'),
              ),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'chat_bubble_ai_with_timestamp');
      });

      // Skip streaming tests due to CircularProgressIndicator animation timeout
      // TODO: Use custom pump logic or skip animation for these tests
      // testGoldens('renders AI message with streaming indicator', (
      //   WidgetTester tester,
      // ) async {
      //   await tester.pumpWidget(
      //     GoldenTestHelper.makeTestableWidget(
      //       child: const SizedBox(
      //         width: 400,
      //         child: ModernChatBubble(
      //           isUser: false,
      //           isStreaming: true,
      //           child: Text('AI is typing...'),
      //         ),
      //       ),
      //     ),
      //   );
      //   await tester.pump();
      //   await screenMatchesGolden(tester, 'chat_bubble_ai_streaming');
      // });

      // testGoldens('renders AI message with avatar and streaming', (
      //   WidgetTester tester,
      // ) async {
      //   await tester.pumpWidget(
      //     GoldenTestHelper.makeTestableWidget(
      //       child: SizedBox(
      //         width: 400,
      //         child: ModernChatBubble(
      //           isUser: false,
      //           showAvatar: true,
      //           isStreaming: true,
      //           avatar: Container(
      //             width: 32,
      //             height: 32,
      //             decoration: const BoxDecoration(
      //               color: Colors.blue,
      //               shape: BoxShape.circle,
      //             ),
      //           ),
      //           child: const Text('Streaming message...'),
      //         ),
      //       ),
      //     ),
      //   );
      //   await tester.pump();
      //   await screenMatchesGolden(tester, 'chat_bubble_ai_avatar_streaming');
      // });

      testGoldens('renders long AI message', (WidgetTester tester) async {
        const String longMessage = '''
This is a very long AI response that should wrap properly and display correctly in the chat bubble.
It tests the glassmorphic effect and backdrop filter on longer text content.
The AI response should be easy to read and visually distinct from user messages.
''';

        await tester.pumpWidget(
          GoldenTestHelper.makeTestableWidget(
            child: const SizedBox(
              width: 400,
              child: ModernChatBubble(isUser: false, child: Text(longMessage)),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'chat_bubble_ai_long');
      });
    });

    // Dark mode tests
    group('Dark Mode', () {
      testGoldens('renders user bubble in dark mode', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          GoldenTestHelper.makeTestableWidget(
            theme: ThemeData.dark(),
            child: const SizedBox(
              width: 400,
              child: ModernChatBubble(
                isUser: true,
                child: Text('Dark mode user message'),
              ),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'chat_bubble_user_dark');
      });

      testGoldens('renders AI bubble in dark mode', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          GoldenTestHelper.makeTestableWidget(
            theme: ThemeData.dark(),
            child: const SizedBox(
              width: 400,
              child: ModernChatBubble(
                isUser: false,
                showAvatar: true,
                avatar: ColoredBox(color: Colors.blue),
                child: Text('Dark mode AI message'),
              ),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'chat_bubble_ai_dark');
      });
    });
  });
}
