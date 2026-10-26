# Golden Tests Guide

Golden tests compare rendered widgets against saved reference PNGs to catch
visual regressions. The app has a single (dark) theme, so every golden renders
with `AppTheme.dark`; there are no light-theme or dark-mode variants.

## Run

```bash
flutter test test/features/chat/widgets/modern_chat_bubble_golden_test.dart
flutter test test/features/chat/widgets/modern_chat_bubble_edge_cases_golden_test.dart
flutter test test/features/chat/widgets/shimmer_loading_golden_test.dart
flutter test test/features/screens/chat_screen_golden_test.dart
flutter test test/core/design/components   # design component kit
```

`./scripts/fverify.sh` runs all of them as part of `flutter test`.

## Update (only for an intentional visual change)

```bash
flutter test --update-goldens test/core/design/components
```

Open the regenerated PNGs, check they look right, re-run **without** the flag
to confirm the result is deterministic, then commit the PNGs with the change.
A golden diff during a refactor is a bug in the code, not in the golden.

## Writing a golden test

Use the helpers in `test/helpers/golden_test_helper.dart`, never
`screenMatchesGolden` directly:

- `GoldenTestHelper.init()` in `setUpAll`: loads the app fonts and forbids
  runtime Google Fonts fetching (a missing bundled weight fails loudly).
- `GoldenTestHelper.makeTestableWidget(child: ...)`: wraps the child in a
  `MaterialApp` with `AppTheme.dark` and the localization delegates, so
  `context.tokens` and `AppLocalizations` work.
- `GoldenTestHelper.matchGolden(tester, 'name')`: settles the bundled fonts
  first, then compares. Without it, text can be captured in a fallback font.

```dart
setUpAll(() async {
  await GoldenTestHelper.init();
});

testGoldens('my widget', (WidgetTester tester) async {
  await tester.pumpWidgetBuilder(
    GoldenTestHelper.makeTestableWidget(child: const MyWidget()),
    surfaceSize: const Size(300, 200),
  );
  await GoldenTestHelper.matchGolden(tester, 'my_widget');
});
```

Goldens live next to their test, in a `goldens/` folder.

## Tips

- Widgets that animate forever (shimmer, progress indicators) never settle:
  pass `customPump: (WidgetTester t) => t.pump()` to `matchGolden` instead of
  relying on `pumpAndSettle`.
- Worth covering: loading/error/success states, long and empty text, RTL and
  CJK scripts, and 1.5x text scale.
- Goldens are rendered on the host platform; regenerate them on the same
  platform you verify on.
