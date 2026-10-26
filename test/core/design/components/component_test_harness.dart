import 'package:flutter/material.dart';

import '../../../helpers/golden_test_helper.dart';

/// Wraps [child] in the app test harness. The [rtl] and [textScale] overrides
/// are applied INSIDE the MaterialApp: its Localizations would otherwise
/// re-install LTR, and its MediaQuery would shadow one placed above it.
Widget componentHarness(
  Widget child, {
  bool rtl = false,
  double textScale = 1,
}) {
  return GoldenTestHelper.makeTestableWidget(
    child: Builder(
      builder: (BuildContext context) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: Center(child: child),
          ),
        );
      },
    ),
  );
}
