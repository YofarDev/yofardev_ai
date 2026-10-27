import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yofardev_ai/core/design/design.dart';
import 'package:yofardev_ai/features/chat/widgets/modern_chat_bubble.dart';

import '../../../helpers/golden_test_helper.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<Color?> textColor(WidgetTester tester, {required bool isUser}) async {
    await tester.pumpWidget(
      GoldenTestHelper.makeTestableWidget(
        child: ModernChatBubble(isUser: isUser, child: const Text('Hi')),
      ),
    );
    return DefaultTextStyle.of(tester.element(find.text('Hi'))).style.color;
  }

  testWidgets('user text defaults to onPrimary, legible on the accent', (
    WidgetTester tester,
  ) async {
    final Color? color = await textColor(tester, isUser: true);
    final ColorScheme scheme = AppTheme.dark.colorScheme;
    expect(color, scheme.onPrimary);
  });

  testWidgets('AI text defaults to onSurface', (WidgetTester tester) async {
    final Color? color = await textColor(tester, isUser: false);
    expect(color, AppTheme.dark.colorScheme.onSurface);
  });
}
