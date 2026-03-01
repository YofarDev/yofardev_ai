import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/features/chat/widgets/ai_text_input/ai_text_input.dart';

void main() {
  group('AiTextInput Widget', () {
    // Note: Full widget tests require BLoC providers which will be updated
    // after the architecture restructure. This is a basic smoke test.

    testWidgets('widget can be created', (WidgetTester tester) async {
      // Basic smoke test - widget class exists and is constructible
      expect(() => const AiTextInput(), returnsNormally);
    });
  });
}
