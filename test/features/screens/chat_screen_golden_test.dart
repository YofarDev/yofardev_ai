import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:yofardev_ai/features/chat/widgets/modern_chat_bubble.dart';
import '../../helpers/golden_test_helper.dart';

/// Golden tests for complete chat screen scenarios
void main() {
  group('Chat Screen Scenarios Golden Tests', () {
    setUpAll(() async {
      await GoldenTestHelper.init();
    });

    testGoldens('chat conversation flow - user and AI messages', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        GoldenTestHelper.makeTestableWidget(
          child: const SizedBox(
            width: 400,
            height: 800,
            child: Column(
              children: <Widget>[
                // User message 1
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: ModernChatBubble(
                      isUser: true,
                      timestamp: '10:30 AM',
                      child: Text('Hello! How are you?'),
                    ),
                  ),
                ),
                // AI response 1
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: ModernChatBubble(
                      isUser: false,
                      showAvatar: true,
                      avatar: ColoredBox(color: Colors.blue),
                      timestamp: '10:30 AM',
                      child: Text("I'm doing well, thank you!"),
                    ),
                  ),
                ),
                // User message 2
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: ModernChatBubble(
                      isUser: true,
                      timestamp: '10:31 AM',
                      child: Text('Can you help me with something?'),
                    ),
                  ),
                ),
                // AI response with streaming
                // Align(
                //   alignment: Alignment.centerLeft,
                //   child: Padding(
                //     padding: EdgeInsets.all(8.0),
                //     child: ModernChatBubble(
                //       isUser: false,
                //       showAvatar: true,
                //       isStreaming: true,
                //       avatar: ColoredBox(color: Colors.blue),
                //       child: Text('Of course! I\'d be happy to help...'),
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
        ),
      );

      await screenMatchesGolden(tester, 'chat_conversation_flow');
    });

    testGoldens('chat with various message lengths', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        GoldenTestHelper.makeTestableWidget(
          child: SizedBox(
            width: 400,
            height: 800,
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: const <Widget>[
                // Short message
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: ModernChatBubble(isUser: true, child: Text('Hi!')),
                  ),
                ),
                // Medium message
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: ModernChatBubble(
                      isUser: false,
                      showAvatar: true,
                      avatar: ColoredBox(color: Colors.blue),
                      child: Text('Hello! How can I assist you today?'),
                    ),
                  ),
                ),
                // Long message
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: ModernChatBubble(
                      isUser: true,
                      child: Text(
                        'I have a question about Flutter development. '
                        'I\'m trying to implement a new feature in my app '
                        'that involves complex state management.',
                      ),
                    ),
                  ),
                ),
                // Very long AI response
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: ModernChatBubble(
                      isUser: false,
                      showAvatar: true,
                      avatar: ColoredBox(color: Colors.blue),
                      child: Text(
                        'That\'s a great question! Flutter provides several '
                        'options for state management. For complex scenarios, '
                        'you might want to consider using BLoC or Riverpod. '
                        'BLoC is particularly good for separating business '
                        'logic from UI, making your code more testable and '
                        'maintainable. Would you like me to explain more '
                        'about these approaches?',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await screenMatchesGolden(tester, 'chat_various_lengths');
    });

    testGoldens('chat in dark mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        GoldenTestHelper.makeTestableWidget(
          theme: ThemeData.dark(),
          child: SizedBox(
            width: 400,
            height: 800,
            child: const Column(
              children: <Widget>[
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: ModernChatBubble(
                      isUser: true,
                      child: Text('Dark mode message'),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: ModernChatBubble(
                      isUser: false,
                      showAvatar: true,
                      avatar: ColoredBox(color: Colors.blue),
                      child: Text('Dark mode response'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await screenMatchesGolden(tester, 'chat_dark_mode');
    });
  });
}
