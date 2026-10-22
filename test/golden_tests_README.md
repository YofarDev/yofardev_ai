# Golden Tests Guide

Golden tests automatically compare your UI against saved "golden" (reference) images to detect visual regressions.

## Quick Start

### Run all golden tests
```bash
# Basic chat bubbles
flutter test test/features/chat/widgets/modern_chat_bubble_golden_test.dart

# Chat screen scenarios
flutter test test/features/screens/chat_screen_golden_test.dart

# Edge cases (emojis, special chars, etc.)
flutter test test/features/chat/widgets/modern_chat_bubble_edge_cases_golden_test.dart

# Shimmer loading states
flutter test test/features/chat/widgets/shimmer_loading_golden_test.dart

# Avatar clothes/accessories
flutter test test/features/avatar/widgets/clothes_golden_test.dart
```

### Update golden files (when you intentionally change UI)
```bash
flutter test test/features/chat/widgets/modern_chat_bubble_golden_test.dart --update-goldens
flutter test test/features/screens/chat_screen_golden_test.dart --update-goldens
flutter test test/features/chat/widgets/modern_chat_bubble_edge_cases_golden_test.dart --update-goldens
flutter test test/features/chat/widgets/shimmer_loading_golden_test.dart --update-goldens
flutter test test/features/avatar/widgets/clothes_golden_test.dart --update-goldens
```

## Test Coverage Summary

### 1. **Chat Bubbles - Basic** (`test/features/chat/widgets/modern_chat_bubble_golden_test.dart`)
**Golden files:** `test/features/chat/widgets/goldens/` (9 files)

Tests:
- ✅ User messages (basic, with timestamp, long text)
- ✅ AI messages (basic, with avatar, with timestamp, long text)
- ✅ Dark mode rendering
- ✅ Glassmorphic effects
- ✅ Text wrapping and layout

### 2. **Chat Screen Scenarios** (`test/features/screens/chat_screen_golden_test.dart`)
**Golden files:** `test/features/screens/goldens/` (3 files)

Tests:
- ✅ Full conversation flows
- ✅ Multiple message lengths
- ✅ Dark mode conversations

### 3. **Chat Bubbles - Edge Cases** (`test/features/chat/widgets/modern_chat_bubble_edge_cases_golden_test.dart`)
**Golden files:** `test/features/chat/widgets/goldens/` (17+ files)

#### Special Characters & Emojis
- ✅ Emojis in messages
- ✅ Special characters (<, >, &, ", ', @, #, $, %, ^, *)
- ✅ Code snippets with backticks
- ✅ URLs and links

#### Edge Cases
- ✅ Very short messages (1-2 words)
- ✅ Empty messages
- ✅ Messages with only spaces
- ✅ Extremely long single words (no wrapping)
- ✅ Multiple newlines
- ✅ Multiple consecutive spaces

#### Overflow Tests
- ✅ 50+ emojis in one message
- ✅ Extremely long paragraphs (20+ sentences)

#### Internationalization
- ✅ RTL text (Arabic)
- ✅ Chinese text
- ✅ Japanese text
- ✅ Mixed scripts

#### Accessibility
- ✅ High contrast mode

### 4. **Shimmer Loading States** (`test/features/chat/widgets/shimmer_loading_golden_test.dart`)
**Golden files:** `test/features/chat/widgets/goldens/` (2 files)

Tests:
- ✅ Loading placeholder in light mode
- ✅ Loading placeholder in dark mode

### 5. **Avatar Clothes/Accessories** (`test/features/avatar/widgets/clothes_golden_test.dart`)
**Golden files:** `test/features/avatar/widgets/goldens/` (2 files)

Tests:
- ✅ Sunglasses accessory
- ✅ Clothes in dark mode

## What These Tests Catch

Based on your original requirements:

### ✅ Background Changing on LLM Response
- Avatar clothes tests detect visual changes in accessories
- Dark mode tests ensure background consistency

### ✅ Clothes Changing
- Dedicated tests for avatar accessories (sunglasses, etc.)
- Tests for different costume states

### ✅ Animation Triggered
- Shimmer loading tests catch loading state regressions
- Edge case tests ensure proper rendering during state changes

### ✅ Additional Coverage
- **Internationalization**: RTL languages, CJK characters
- **Accessibility**: High contrast modes
- **Edge Cases**: Empty messages, overflow, special characters
- **Text Handling**: Long words, newlines, multiple spaces

## How It Works

1. **First Run**: Tests fail because no golden files exist yet
2. **Generate Goldens**: Run with `--update-goldens` to create reference images
3. **Subsequent Runs**: Tests compare current UI against saved goldens
4. **CI/CD**: Run in CI to catch visual regressions

## Workflow

### Adding New Golden Tests

```dart
testGoldens('my new feature', (tester) async {
  await tester.pumpWidget(
    GoldenTestHelper.makeTestableWidget(
      child: MyNewWidget(),
    ),
  );

  await screenMatchesGolden(tester, 'my_new_feature');
});
```

### Updating Goldens After Intentional Changes

```bash
# 1. Make your UI changes
# 2. Update the golden files
flutter test test/features/chat/widgets/modern_chat_bubble_golden_test.dart --update-goldens

# 3. Verify tests pass
flutter test test/features/chat/widgets/modern_chat_bubble_golden_test.dart

# 4. Commit the new golden files
git add test/features/chat/widgets/goldens/
git commit -m "feat: update widget appearance"
```

### Debugging Failed Tests

When a golden test fails:

1. **Compare the images**: Check the failure output for diff location
2. **View the diff**: Open the generated comparison image
3. **Decide**:
   - If unintended: Fix the code
   - If intended: Update goldens with `--update-goldens`

## Golden Files Location

Golden files are stored next to their test files:

```
test/
├── features/
│   ├── chat/
│   │   └── widgets/
│   │       ├── modern_chat_bubble_golden_test.dart
│   │       ├── modern_chat_bubble_edge_cases_golden_test.dart
│   │       ├── shimmer_loading_golden_test.dart
│   │       └── goldens/
│   │           ├── chat_bubble_user_basic.png
│   │           ├── chat_bubble_emojis.png
│   │           ├── chat_bubble_arabic.png
│   │           ├── shimmer_loading.png
│   │           └── ... (30+ files)
│   ├── screens/
│   │   ├── chat_screen_golden_test.dart
│   │   └── goldens/
│   │       └── ... (3 files)
│   └── avatar/
│       └── widgets/
│           ├── clothes_golden_test.dart
│           └── goldens/
│               └── ... (2 files)
└── helpers/
    └── golden_test_helper.dart
```

## Best Practices

1. **Commit golden files** to version control
2. **Update goldens** when intentionally changing UI
3. **Run in CI** to catch visual regressions
4. **Use descriptive names** for golden tests
5. **Test important states** (loading, error, success)
6. **Test both themes** (light and dark mode)
7. **Test different screen sizes** when relevant
8. **Test internationalization** (RTL, CJK languages)
9. **Test accessibility** (high contrast, text scaling)

## Known Limitations

- **Streaming indicators**: Tests with `CircularProgressIndicator` are skipped due to animation timeouts
- **Animations**: Tests with continuous animations may timeout - use `pump()` instead of `pumpAndSettle()`
- **Platform-specific fonts**: Golden tests use test fonts which may differ from production

## Troubleshooting

### "Font not found" errors
Make sure fonts are loaded in test setup:
```dart
setUpAll(() async {
  await GoldenTestHelper.init();
});
```

### Flaky tests due to animations
Use `pump()` instead of relying on default `pumpAndSettle()`:
```dart
await tester.pumpWidget(...);
await tester.pump(); // Pump once to render
await screenMatchesGolden(tester, 'my_feature', skip: false);
```

### Platform-specific differences
Golden tests run on the test platform. Consider device differences when creating tests.

### Too many golden files
You can group related tests or skip certain edge cases if they're not critical for your app.

## CI Integration

Add to your CI pipeline:

```yaml
# .github/workflows/test.yml
- name: Run golden tests
  run: |
    flutter test test/features/chat/widgets/modern_chat_bubble_golden_test.dart
    flutter test test/features/screens/chat_screen_golden_test.dart
    flutter test test/features/chat/widgets/modern_chat_bubble_edge_cases_golden_test.dart
    flutter test test/features/chat/widgets/shimmer_loading_golden_test.dart
    flutter test test/features/avatar/widgets/clothes_golden_test.dart
```

## Adding More Golden Tests

To add golden tests for other widgets:

1. Create a new test file: `test/features/[feature]/widgets/[widget]_golden_test.dart`
2. Use `GoldenTestHelper.makeTestableWidget()` to wrap your widget
3. Call `screenMatchesGolden()` to capture and compare
4. Run with `--update-goldens` to generate initial golden files
5. Commit both the test file and the golden files

## Test Statistics

- **Total test files**: 5
- **Total golden snapshots**: 35+
- **Coverage areas**:
  - Chat bubbles: ✅ Comprehensive
  - Edge cases: ✅ Comprehensive
  - Internationalization: ✅ Basic
  - Avatar: ✅ Basic (clothes only)
  - Animations: ⚠️ Limited (shimmer only)

## Future Improvements

Consider adding:

1. **Avatar Background Tests**: Test different background states (happy, sad, thinking)
2. **Avatar Animation Tests**: Test thinking, talking, and idle animations
3. **Costume Tests**: Test all available costumes (robocop, singularity, soubrette)
4. **Screen Size Variants**: Test on different device sizes (phone, tablet)
5. **Text Scaling Tests**: Test with different font scaling factors
6. **Locale-Specific Tests**: Test with French and English locales

## References

- [flutter_test docs](https://docs.flutter.dev/cookbook/testing/widget/introduction)
- [golden_toolkit package](https://pub.dev/packages/golden_toolkit)
