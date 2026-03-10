import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:yofardev_ai/features/avatar/widgets/clothes.dart';
import '../../../helpers/golden_test_helper.dart';

void main() {
  group('Clothes Golden Tests', () {
    setUpAll(() async {
      await GoldenTestHelper.init();
    });

    testGoldens('renders sunglasses accessory', (WidgetTester tester) async {
      await tester.pumpWidget(
        GoldenTestHelper.makeTestableWidget(
          child: const SizedBox(
            width: 400,
            height: 400,
            child: Center(child: Clothes(name: 'sunglasses')),
          ),
        ),
      );

      await screenMatchesGolden(tester, 'clothes_sunglasses');
    });

    testGoldens('renders clothes in dark mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        GoldenTestHelper.makeTestableWidget(
          theme: ThemeData.dark(),
          child: const SizedBox(
            width: 400,
            height: 400,
            child: Center(child: Clothes(name: 'sunglasses')),
          ),
        ),
      );

      await screenMatchesGolden(tester, 'clothes_sunglasses_dark');
    });
  });
}
