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
            // ChatListShimmerLoading is an Expanded: it needs a Flex parent.
            child: Column(children: <Widget>[ChatListShimmerLoading()]),
          ),
        ),
      );

      // The shimmer animates forever, so pumpAndSettle would time out.
      await GoldenTestHelper.matchGolden(
        tester,
        'shimmer_loading',
        customPump: (WidgetTester t) => t.pump(),
      );
    });
  });
}
