import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/design/theme/app_theme.dart';
import 'package:yofardev_ai/core/l10n/generated/app_localizations.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/features/chat/widgets/chat_card.dart';

Future<void> _pumpCard(
  WidgetTester tester, {
  required Locale locale,
  required int messageCount,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      locale: locale,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ChatCard(
          chat: const Chat(id: 'c1'),
          isSelected: false,
          previewText: 'Hello',
          timeLabel: '',
          messageCount: messageCount,
          onTap: () {},
        ),
      ),
    ),
  );
}

void main() {
  group('ChatCard message count', () {
    testWidgets('fr singular', (WidgetTester tester) async {
      await _pumpCard(tester, locale: const Locale('fr'), messageCount: 1);
      expect(find.text('1 message'), findsOneWidget);
    });

    testWidgets('fr plural', (WidgetTester tester) async {
      await _pumpCard(tester, locale: const Locale('fr'), messageCount: 3);
      expect(find.text('3 messages'), findsOneWidget);
    });

    testWidgets('fr zero is singular', (WidgetTester tester) async {
      await _pumpCard(tester, locale: const Locale('fr'), messageCount: 0);
      expect(find.text('0 message'), findsOneWidget);
    });

    testWidgets('en singular', (WidgetTester tester) async {
      await _pumpCard(tester, locale: const Locale('en'), messageCount: 1);
      expect(find.text('1 message'), findsOneWidget);
    });

    testWidgets('en plural', (WidgetTester tester) async {
      await _pumpCard(tester, locale: const Locale('en'), messageCount: 2);
      expect(find.text('2 messages'), findsOneWidget);
    });
  });
}
