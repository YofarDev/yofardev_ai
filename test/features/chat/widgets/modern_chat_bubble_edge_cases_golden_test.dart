import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:yofardev_ai/features/chat/widgets/modern_chat_bubble.dart';
import '../../../helpers/golden_test_helper.dart';

/// Golden tests for edge cases in chat bubbles
void main() {
  group('ModernChatBubble Edge Cases Golden Tests', () {
    setUpAll(() async {
      await GoldenTestHelper.init();
    });

    group('Special Characters', () {
      testGoldens('renders message with emojis', (WidgetTester tester) async {
        await tester.pumpWidget(
          GoldenTestHelper.makeTestableWidget(
            child: const SizedBox(
              width: 400,
              child: ModernChatBubble(
                isUser: true,
                child: Text('Hello! 👋 How are you? 🎉😊'),
              ),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'chat_bubble_emojis');
      });

      testGoldens('renders message with special characters', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          GoldenTestHelper.makeTestableWidget(
            child: const SizedBox(
              width: 400,
              child: ModernChatBubble(
                isUser: false,
                child: Text('Special chars: < > & @ # \$ % ^ *'),
              ),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'chat_bubble_special_chars');
      });

      testGoldens('renders message with code/monospace', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          GoldenTestHelper.makeTestableWidget(
            child: const SizedBox(
              width: 400,
              child: ModernChatBubble(
                isUser: false,
                child: Text(
                  'Use `const` for compile-time constants\n'
                  '```dart\nfinal x = 42;\n```',
                ),
              ),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'chat_bubble_code');
      });

      testGoldens('renders message with links', (WidgetTester tester) async {
        await tester.pumpWidget(
          GoldenTestHelper.makeTestableWidget(
            child: const SizedBox(
              width: 400,
              child: ModernChatBubble(
                isUser: false,
                child: Text('Check out https://flutter.dev or https://pub.dev'),
              ),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'chat_bubble_links');
      });
    });

    group('Edge Cases', () {
      testGoldens('renders very short message', (WidgetTester tester) async {
        await tester.pumpWidget(
          GoldenTestHelper.makeTestableWidget(
            child: const SizedBox(
              width: 400,
              child: ModernChatBubble(isUser: true, child: Text('OK')),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'chat_bubble_very_short');
      });

      testGoldens('renders empty message', (WidgetTester tester) async {
        await tester.pumpWidget(
          GoldenTestHelper.makeTestableWidget(
            child: const SizedBox(
              width: 400,
              child: ModernChatBubble(isUser: true, child: Text('')),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'chat_bubble_empty');
      });

      testGoldens('renders message with only spaces', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          GoldenTestHelper.makeTestableWidget(
            child: const SizedBox(
              width: 400,
              child: ModernChatBubble(isUser: false, child: Text('   ')),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'chat_bubble_spaces');
      });

      testGoldens('renders extremely long single word', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          GoldenTestHelper.makeTestableWidget(
            child: const SizedBox(
              width: 400,
              child: ModernChatBubble(
                isUser: false,
                child: Text(
                  'Pneumonoultramicroscopicsilicovolcanoconiosis'
                  'supercalifragilisticexpialidocious',
                ),
              ),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'chat_bubble_long_word');
      });

      testGoldens('renders message with newlines', (WidgetTester tester) async {
        await tester.pumpWidget(
          GoldenTestHelper.makeTestableWidget(
            child: const SizedBox(
              width: 400,
              child: ModernChatBubble(
                isUser: false,
                child: Text(
                  'Line 1\nLine 2\nLine 3\n\n\nLine 6 (after empty lines)',
                ),
              ),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'chat_bubble_newlines');
      });

      testGoldens('renders message with many consecutive spaces', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          GoldenTestHelper.makeTestableWidget(
            child: const SizedBox(
              width: 400,
              child: ModernChatBubble(
                isUser: true,
                child: Text('Word1     Word2     Word3'),
              ),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'chat_bubble_many_spaces');
      });
    });

    group('Overflow Tests', () {
      testGoldens('renders message with 50+ emojis', (
        WidgetTester tester,
      ) async {
        final String manyEmojis = List<String>.generate(
          50,
          (int i) => '😀',
        ).join();

        await tester.pumpWidget(
          GoldenTestHelper.makeTestableWidget(
            child: SizedBox(
              width: 400,
              child: ModernChatBubble(isUser: true, child: Text(manyEmojis)),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'chat_bubble_many_emojis');
      });

      testGoldens('renders extremely long paragraph', (
        WidgetTester tester,
      ) async {
        final String longText = List<String>.generate(
          20,
          (int i) =>
              'This is sentence number ${i + 1} in a very long paragraph.',
        ).join(' ');

        await tester.pumpWidget(
          GoldenTestHelper.makeTestableWidget(
            child: SizedBox(
              width: 400,
              child: ModernChatBubble(isUser: false, child: Text(longText)),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'chat_bubble_extremely_long');
      });
    });

    group('Internationalization', () {
      testGoldens('renders RTL text (Arabic)', (WidgetTester tester) async {
        await tester.pumpWidget(
          GoldenTestHelper.makeTestableWidget(
            child: const SizedBox(
              width: 400,
              child: ModernChatBubble(
                isUser: false,
                child: Text('مرحبا! كيف حالك؟ أنا مساعد ذكي اصطناعي'),
              ),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'chat_bubble_arabic');
      });

      testGoldens('renders Chinese text', (WidgetTester tester) async {
        await tester.pumpWidget(
          GoldenTestHelper.makeTestableWidget(
            child: const SizedBox(
              width: 400,
              child: ModernChatBubble(
                isUser: true,
                child: Text('你好！我很好，谢谢！人工智能助手'),
              ),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'chat_bubble_chinese');
      });

      testGoldens('renders Japanese text', (WidgetTester tester) async {
        await tester.pumpWidget(
          GoldenTestHelper.makeTestableWidget(
            child: const SizedBox(
              width: 400,
              child: ModernChatBubble(
                isUser: false,
                child: Text('こんにちは！AIアシスタントです'),
              ),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'chat_bubble_japanese');
      });

      testGoldens('renders mixed scripts', (WidgetTester tester) async {
        await tester.pumpWidget(
          GoldenTestHelper.makeTestableWidget(
            child: const SizedBox(
              width: 400,
              child: ModernChatBubble(
                isUser: true,
                child: Text('Hello 你心 こんにちは مرحبا 🌍'),
              ),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'chat_bubble_mixed_scripts');
      });
    });

    group('Accessibility', () {
      testGoldens('renders with high contrast mode', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          GoldenTestHelper.makeTestableWidget(
            theme: ThemeData(
              brightness: Brightness.light,
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),
            child: const SizedBox(
              width: 400,
              child: ModernChatBubble(
                isUser: false,
                child: Text('High contrast test'),
              ),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'chat_bubble_high_contrast');
      });
    });
  });
}
