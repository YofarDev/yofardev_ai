import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yofardev_ai/core/design/theme/app_theme.dart';
import 'package:yofardev_ai/core/widgets/glassmorphic/glassmorphic_text_field.dart';

/// Pins the drawn hint/label geometry of [GlassmorphicTextField] to what the
/// pre-migration widget (direct `GoogleFonts.plusJakartaSans` styles, commit
/// 9344dff) drew under `AppTheme.dark`. The expected values were measured by
/// pumping that old widget next to the migrated one.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('hint and label keep their pre-migration geometry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: GlassmorphicTextField(hintText: 'Hint', labelText: 'Label'),
        ),
      ),
    );
    await tester.pump();

    final TextStyle hint = tester.widget<Text>(find.text('Hint')).style!;
    expect(hint.fontFamily, contains('PlusJakartaSans'));
    expect(hint.fontSize, 14);
    expect(hint.fontWeight, FontWeight.w400);
    expect(hint.letterSpacing, 0.5);
    expect(hint.height, 1.5);

    // The floating label is painted with the ambient default text style.
    final TextStyle label = DefaultTextStyle.of(
      tester.element(find.text('Label').first),
    ).style;
    expect(label.fontFamily, contains('PlusJakartaSans'));
    expect(label.fontFamily, contains('500'));
    expect(label.fontSize, 14);
    expect(label.fontWeight, FontWeight.w500);
    expect(label.letterSpacing, 0.5);
    expect(label.height, 1.0);
  });
}
