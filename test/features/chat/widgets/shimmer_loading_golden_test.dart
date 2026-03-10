import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:yofardev_ai/features/chat/widgets/chat_list_shimmer_loading.dart';
import '../../../helpers/golden_test_helper.dart';

void main() {
  group('ChatListShimmerLoading Golden Tests', () {
    setUpAll(() async {
      await GoldenTestHelper.init();
    });

    testGoldens('renders shimmer loading placeholder', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        GoldenTestHelper.makeTestableWidget(
          child: const SizedBox(
            width: 400,
            height: 800,
            child: ChatListShimmerLoading(),
          ),
        ),
      );

      await screenMatchesGolden(tester, 'shimmer_loading');
    });

    testGoldens('renders shimmer loading in dark mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        GoldenTestHelper.makeTestableWidget(
          theme: ThemeData.dark(),
          child: const SizedBox(
            width: 400,
            height: 800,
            child: ChatListShimmerLoading(),
          ),
        ),
      );

      await screenMatchesGolden(tester, 'shimmer_loading_dark');
    });
  });
}
