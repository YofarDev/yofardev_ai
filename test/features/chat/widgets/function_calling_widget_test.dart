import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yofardev_ai/features/chat/widgets/function_calling_widget.dart';

void main() {
  group('FunctionCallingWidget', () {
    testWidgets(
      'renders function call without result when showEverything is false',
      (WidgetTester tester) async {
        const String functionCallText = '''
[
  {
    "name": "getWeather",
    "parameters": {"location": "Paris"},
    "result": {"temperature": 15, "condition": "cloudy"}
  }
]''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: FunctionCallingWidget(
                functionCallingText: functionCallText,
                showEverything: false,
              ),
            ),
          ),
        );

        expect(find.text('➡️ getWeather("location": "Paris")'), findsOneWidget);
        expect(find.text('Result: GetWeather'), findsNothing);
      },
    );

    testWidgets(
      'renders function call with expandable result when showEverything is true',
      (WidgetTester tester) async {
        const String functionCallText = '''
[
  {
    "name": "getWeather",
    "parameters": {"location": "Paris"},
    "result": {"temperature": 15, "condition": "cloudy"}
  }
]''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: FunctionCallingWidget(
                functionCallingText: functionCallText,
                showEverything: true,
              ),
            ),
          ),
        );

        expect(find.text('➡️ getWeather("location": "Paris")'), findsOneWidget);
        expect(find.text('Result: GetWeather'), findsOneWidget);

        // Tap to expand
        await tester.tap(find.text('Result: GetWeather'));
        await tester.pumpAndSettle();

        // The result is formatted as JSON
        expect(find.byType(ExpansionTile), findsOneWidget);
      },
    );

    testWidgets('handles null result gracefully', (WidgetTester tester) async {
      const String functionCallText = '''
[
  {
    "name": "getWeather",
    "parameters": {"location": "Paris"}
  }
]''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FunctionCallingWidget(
              functionCallingText: functionCallText,
              showEverything: true,
            ),
          ),
        ),
      );

      expect(find.text('➡️ getWeather("location": "Paris")'), findsOneWidget);
      expect(find.text('Result: GetWeather'), findsNothing);
    });

    testWidgets('handles multiple function calls', (WidgetTester tester) async {
      const String functionCallText = '''
[
  {
    "name": "getWeather",
    "parameters": {"location": "Paris"},
    "result": {"temperature": 15}
  },
  {
    "name": "googleSearch",
    "parameters": {"query": "Flutter"},
    "result": ["result1", "result2"]
  }
]''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FunctionCallingWidget(
              functionCallingText: functionCallText,
              showEverything: true,
            ),
          ),
        ),
      );

      // Both function calls are displayed on separate lines
      expect(find.textContaining('➡️ getWeather'), findsOneWidget);
      expect(find.textContaining('googleSearch'), findsOneWidget);
      // Both have expandable results
      expect(find.text('Result: GetWeather'), findsOneWidget);
      expect(find.text('Result: GoogleSearch'), findsOneWidget);
    });
  });
}
