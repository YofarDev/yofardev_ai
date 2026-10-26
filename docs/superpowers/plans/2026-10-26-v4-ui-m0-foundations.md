# v4 UI redesign, M0 Foundations: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put a design-token layer, a correct dark Material theme, bundled fonts and a small component kit under the app, and move every screen onto them **without changing what the app looks like** (two reviewed exceptions, below), so M1-M7 can restyle in one place.

**Architecture:** New `lib/core/design/` (tokens, theme, components). `AppColors` becomes an implementation detail of that folder; features read colors and tokens from `Theme.of(context)` via `context.colors` / `context.tokens`. Palette hex values do not change in M0. Goldens are moved onto the real app theme once (Task 4) and from then on are the no-regression proof for the migration (Task 6). Enforcement lives in `test/architecture_test.dart`, like the other layering rules.

**Tech Stack:** Flutter, Material 3 `ColorScheme.dark`, `ThemeExtension`, `google_fonts` 9 in bundled-asset mode, `golden_toolkit` (already used). No cubit, service or DI changes.

**Spec:** [`docs/superpowers/specs/2026-10-26-v4-ui-redesign-plan.md`](../specs/2026-10-26-v4-ui-redesign-plan.md) (§3.2, §7 M0, §9 D2/D7) · baseline: [`docs/superpowers/baseline-2026-10-26/README.md`](../baseline-2026-10-26/README.md)

## Global Constraints

- Project rules from `AGENTS.md` apply: explicit types everywhere, relative imports, `AppLogger` not `print`, no `withOpacity` (use `.withValues(alpha:)`), all user-facing strings through `AppLocalizations` (add with `./scripts/fstr.sh`), never hand-edit `*.g.dart`/`*.freezed.dart`/`lib/core/l10n/generated/`.
- Packages are added with `flutter pub add`, never by editing `pubspec.yaml` by hand (asset-folder declarations are the exception).
- DI only in `lib/core/di/service_locator.dart`. No cubit-to-cubit dependencies. `core/` never imports `features/`.
- **No visible change**, except the two reviewed golden refreshes in Task 3 (dark `ColorScheme` derived roles) and Task 4 (goldens switch to the app theme and real fonts). Palette hex values, radii, paddings, sizes and font families stay as today.
- `flutter analyze` treats infos as failures: no `@Deprecated` shims on symbols that are still used.
- Work happens in a git worktree on branch `ui/m0-foundations` cut from `HEAD` of `main`. The main checkout's uncommitted files are the user's and are never touched.
- One commit per task (Task 6: one per sub-step). Message style `type(scope): subject`, ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Before each commit: `dart fix --apply`, `dart format .`, `./scripts/fverify.sh` green.
- Tokens, from the spec §3.1: spacing `xs 4, sm 8, md 12, lg 16, xl 24, xxl 32`; radii `sm 8, md 14, lg 22, xl 32`, `pill 999`; motion `fast 120 ms, base 200 ms, slow 320 ms, max 500 ms`; glass levels `thin / regular / thick` (blur sigma `6 / 10 / 20`).

## Review Focus

1. **Offline first launch:** with no network the theme's fonts must load from assets; `GoogleFonts.pendingFonts()` must complete without error. Task 2 test.
2. **Missing theme extension:** a widget calling `context.tokens` under a theme without `AppTokens` (a test harness, a stock `ThemeData`) must fail with a clear message naming `AppTheme.dark`, never a null-check crash. Task 1 test; Task 4 moves every golden harness to `AppTheme.dark`.
3. **Per-frame paths:** migrating colors must not add `Theme.of` lookups inside `AnimatedBuilder` builders (`typing_indicator.dart`, shimmer). Task 6 step 3 states where colors are read.
4. **Text scale 1.5× and RTL** on the new `AppIconButton` and `AppPill`: no overflow, hit area stays 48×48. Task 5 tests.
5. **A golden diff during the migration is a bug in the code, not in the golden.** Task 6 never runs `--update-goldens`.

---

## File Structure

```
lib/core/design/
  design.dart                      barrel: tokens, theme, components, context extension
  context_ext.dart                 context.colors, context.tokens, context.text
  tokens/
    app_palette.dart               raw hex values (moved from lib/core/res/app_colors.dart)
    app_spacing.dart               AppSpace
    app_radius.dart                AppRadius
    app_motion.dart                AppMotion
    app_glass.dart                 AppGlassLevel, AppGlassStyle
    app_tokens.dart                AppTokens extends ThemeExtension<AppTokens>
  theme/
    app_color_scheme.dart          buildDarkColorScheme()
    app_text_theme.dart            buildTextTheme() (moved out of app_theme)
    app_theme.dart                 AppTheme.dark
  components/
    app_icon_button.dart           kit button, 48 dp hit area (adopted from M3 on)
    glass_panel.dart
    app_pill.dart
    app_scaffold.dart
  rive/                            reserved for M2 UI-kit widgets (Task 8)
assets/fonts/google_fonts/         static TTFs + OFL licences
test/core/design/                  tokens, fonts, scheme, theme, components (+ goldens)
```

Deleted by the end of Task 6: `lib/core/res/app_colors.dart`, `lib/core/res/app_theme.dart`.
Kept (colors migrated, size unchanged until M3): `lib/core/widgets/app_icon_button.dart`.

---

### Task 0: Worktree, docs, green gate

The baseline run of `main` + the user's uncommitted files had **71 failing tests**. M0 starts from a clean `HEAD` instead, so the failures must be re-measured there.

**Files:** copies of `docs/superpowers/{specs/2026-10-26-v4-ui-redesign-plan.md, plans/2026-10-26-v4-ui-m0-foundations.md, baseline-2026-10-26/}` and `scripts/perf/` into the worktree; test fixes as triage dictates; regenerated `test/**/goldens/*.png`.

**Interfaces:**
- Produces: worktree on `ui/m0-foundations` whose `./scripts/fverify.sh` is green. Every later task relies on it.

- [ ] **Step 1: Create the worktree** from `HEAD` (`superpowers:using-git-worktrees`), run `flutter pub get`, `flutter gen-l10n`, `dart run build_runner build --delete-conflicting-outputs`.
- [ ] **Step 2: Copy the docs and `scripts/perf/` from the main checkout**, commit `docs: v4 UI redesign spec, baseline, M0 plan`.
- [ ] **Step 3: Run `flutter test --reporter json` and triage** every failure into (a) stale goldens, (b) test-side breakage (mocks returning `null` for a `Stream`, expectations that no longer match the current code), (c) real product bugs. Baseline categories to expect: goldens in `modern_chat_bubble*`, `chat_screen`, `shimmer_loading`; mock streams in `talking_cubit_test`, `new_chat_animation_test`; `avatar_animation_service_test`, `function_calling_config_screen_test`, `chats_list_screen_test`.
- [ ] **Step 4: Fix (b) test-side only** (stub missing stream getters with the file's existing mocktail style; update expectations to what the code does when the code matches `rive/CONTRACT.md` and the v4 design). For each (c), stop and report to the controller with the failing test and the reason instead of changing the test.
- [ ] **Step 5: Regenerate (a) once**: `flutter test --update-goldens <the failing golden files>`. Open three PNGs and confirm text and bubbles render (no blank frames).
- [ ] **Step 6: Run `./scripts/fverify.sh`.** Expected: `format ✓ analyze ✓ test ✓`.
- [ ] **Step 7: Commit** `test: restore green gate (stub mock streams, refresh stale goldens)` with the triage table in the body.

---

### Task 1: Tokens and context accessors

**Files:**
- Create: `lib/core/design/tokens/{app_spacing,app_radius,app_motion,app_glass,app_tokens}.dart`, `lib/core/design/context_ext.dart`, `lib/core/design/design.dart`
- Test: `test/core/design/tokens_test.dart`

**Interfaces:**
- Produces:
  - `abstract final class AppSpace { static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32; }`
  - `abstract final class AppRadius { static const double sm = 8, md = 14, lg = 22, xl = 32, pill = 999; }`
  - `abstract final class AppMotion { static const Duration fast, base, slow, max; static const Curve standard = Curves.easeOutCubic; static const Curve emphasized = Curves.easeInOutCubicEmphasized; }`
  - `enum AppGlassLevel { thin, regular, thick }`; `@immutable class AppGlassStyle { const AppGlassStyle({required double blurSigma, required double fillAlpha, required double borderAlpha}); static AppGlassStyle lerp(AppGlassStyle a, AppGlassStyle b, double t); }`
  - `@immutable class AppTokens extends ThemeExtension<AppTokens>` with fields `Color background, glassSurface, glassBorder, success, warning, shadow, highlight` and `AppGlassStyle glassThin, glassRegular, glassThick`; method `AppGlassStyle glass(AppGlassLevel level)`; `copyWith`, `lerp`; `static const AppTokens dark`.
  - `extension AppThemeContext on BuildContext { ColorScheme get colors; AppTokens get tokens; TextTheme get text; }`

- [ ] **Step 1: Write failing tests** in `test/core/design/tokens_test.dart`:
  - each `AppSpace`/`AppRadius` constant equals the Global Constraints value;
  - `AppMotion.base == const Duration(milliseconds: 200)`, `AppMotion.max == const Duration(milliseconds: 500)`;
  - `AppTokens.dark.glass(AppGlassLevel.thin).blurSigma == 6`, `regular == 10`, `thick == 20`;
  - `AppTokens.dark.lerp(other, 0.5).background` equals `Color.lerp(dark.background, other.background, 0.5)`; `lerp(null, 0.5)` returns the same instance;
  - pumping a widget that reads `context.tokens` under `MaterialApp(theme: ThemeData())` throws a `FlutterError` whose message contains `AppTheme.dark`.
- [ ] **Step 2: Run** `flutter test test/core/design/tokens_test.dart`. Expected: FAIL (files missing).
- [ ] **Step 3: Implement.** `AppTokens.dark` values, copied from `lib/core/res/app_colors.dart`: `background 0xFF0A0E1A`, `glassSurface 0xFF1A1F35`, `glassBorder 0xFF2A3148`, `success 0xFF00D68F`, `warning 0xFFFFB020`, `shadow 0xFF000000`, `highlight 0xFFFFFFFF`. Glass fill/border alphas: thin `0.06 / 0.3`, regular `0.12 / 0.3`, thick `0.22 / 0.55` (the values `chat_card.dart` and `modern_chat_bubble.dart` use today). `context.tokens` throws `FlutterError('AppTokens missing from the theme: build the app and tests with AppTheme.dark')`.
- [ ] **Step 4: Run the test.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(design): spacing, radius, motion, glass tokens and AppTokens extension`.

---

### Task 2: Bundled fonts

**Files:**
- Create: `assets/fonts/google_fonts/{Outfit-Regular,Outfit-Medium,Outfit-SemiBold,PlusJakartaSans-Regular,PlusJakartaSans-Medium}.ttf`, `assets/fonts/google_fonts/OFL-Outfit.txt`, `OFL-PlusJakartaSans.txt`, `README.md` (source URLs + licence)
- Modify: `pubspec.yaml` (add `- assets/fonts/google_fonts/` under `flutter: assets:`), `lib/main.dart` (`GoogleFonts.config.allowRuntimeFetching = false;` before `runApp`)
- Test: `test/core/design/fonts_offline_test.dart`

**Interfaces:**
- Produces: every `GoogleFonts.outfit(...)` / `GoogleFonts.plusJakartaSans(...)` call resolves from assets. Weights in use today: Outfit 400/500/600, Plus Jakarta Sans 400/500. `google_fonts` 9 matches assets by file name `<Family>-<Variant>.ttf` in any declared asset folder.

- [ ] **Step 1: Write the failing test**: `GoogleFonts.config.allowRuntimeFetching = false;` then build one `TextStyle` per family/weight listed above with `GoogleFonts.outfit(fontWeight: …)` / `GoogleFonts.plusJakartaSans(fontWeight: …)`, then `await expectLater(GoogleFonts.pendingFonts(), completes);`.
- [ ] **Step 2: Run.** Expected: FAIL with `allowRuntimeFetching is false but font Outfit-Regular was not found in the application assets`.
- [ ] **Step 3: Download the static TTFs** (checked reachable 2026-10-26): `https://github.com/Outfitio/Outfit-Fonts/raw/main/fonts/ttf/Outfit-{Regular,Medium,SemiBold}.ttf` and `https://github.com/tokotype/PlusJakartaSans/raw/master/fonts/ttf/PlusJakartaSans-{Regular,Medium}.ttf`, plus each repo's `OFL.txt`. Declare the folder in `pubspec.yaml`; set the flag in `main.dart`.
- [ ] **Step 4: Run the test.** Expected: PASS. Then run the app on macOS with Wi-Fi off and confirm by eye that Home and Settings text is Outfit/Jakarta, and the log has no `google_fonts` error.
- [ ] **Step 5: Commit** `feat(design): bundle Outfit and Plus Jakarta Sans, forbid runtime font fetch`.

---

### Task 3: Palette move and `ColorScheme.dark`

**Files:**
- Create: `lib/core/design/tokens/app_palette.dart` (the hex constants from `app_colors.dart`, class `AppPalette`, used only inside `lib/core/design/`), `lib/core/design/theme/app_color_scheme.dart`
- Modify: `lib/core/res/app_colors.dart` → plain forwarder (`static const Color primary = AppPalette.primary;` …, **no** `@Deprecated`), removed in Task 6. Drop `gradientMesh` and `pink` (unused).
- Modify: `lib/core/res/app_theme.dart` → `colorScheme: buildDarkColorScheme()`
- Test: `test/core/design/color_scheme_test.dart`; refreshed goldens (reviewed)

**Interfaces:**
- Produces: `ColorScheme buildDarkColorScheme()` returning `ColorScheme.dark(...)` with: `primary, onPrimary, primaryContainer, secondary, onSecondary, secondaryContainer, error, onError` ← same-named palette values; `tertiary ← accent 0xFF7B61FF`; `surface ← 0xFF141829`; `onSurface ← 0xFFF5F5F7`; `onSurfaceVariant ← onSurface @ 70 % alpha`; `surfaceContainerLowest ← background`; `surfaceContainerLow, surfaceContainer, surfaceContainerHigh, surfaceContainerHighest ← glassSurface`; `outline, outlineVariant ← glassBorder`.

- [ ] **Step 1: Write failing tests**: `brightness == Brightness.dark`; `primary == const Color(0xFF00D4FF)`; `tertiary == const Color(0xFF7B61FF)`; `outline == const Color(0xFF2A3148)`; contrast `onSurface` on `surface` ≥ 7.0 and `onPrimary` on `primary` ≥ 4.5 (helper `double contrastRatio(Color a, Color b)` in the test file from `computeLuminance()`).
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement**, switch `lib/core/res/app_theme.dart` to the new scheme.
- [ ] **Step 4: Run `flutter test`.** Golden diffs are expected only where stock Material widgets read derived roles (switches, dropdown menus, expansion tiles). For each diff, open the `failures/` image, confirm the change is a derived-role color on a stock widget, then `--update-goldens` those files. Any diff in a widget that paints with explicit `AppColors` is a bug: fix it.
- [ ] **Step 5: Commit** `refactor(design): palette under core/design, proper dark ColorScheme` listing the refreshed goldens in the body.

---

### Task 4: `AppTheme.dark`, goldens on the app theme

**Files:**
- Create: `lib/core/design/theme/app_theme.dart`, `lib/core/design/theme/app_text_theme.dart`
- Modify: `lib/app.dart` (`theme: AppTheme.dark`, `themeMode: ThemeMode.dark`); `lib/core/res/app_theme.dart` → forwarder `static ThemeData get lightTheme => AppTheme.dark;` (no `@Deprecated`; removed in Task 6); `test/helpers/golden_test_helper.dart` (default `theme: AppTheme.dark`); every golden test passing `ThemeData.dark()` / `ThemeData.light()` / `ThemeData(...)` → `AppTheme.dark` (`chat_screen_golden_test.dart:166`, `modern_chat_bubble_golden_test.dart:210,229`, `modern_chat_bubble_edge_cases_golden_test.dart:303`, `shimmer_loading_golden_test.dart:35`); delete "Dark Mode" golden cases that become identical to their default twin.
- Test: `test/core/design/app_theme_test.dart`; all goldens refreshed once (reviewed)

**Interfaces:**
- Consumes: `buildDarkColorScheme()`, `AppTokens.dark`, bundled fonts.
- Produces: `abstract final class AppTheme { static ThemeData get dark; }`: `useMaterial3: true`, `brightness: Brightness.dark`, `colorScheme: buildDarkColorScheme()`, `scaffoldBackgroundColor: AppTokens.dark.background`, `extensions: <ThemeExtension<dynamic>>[AppTokens.dark]`, `textTheme: buildTextTheme(colorScheme)`, and every component theme from `lib/core/res/app_theme.dart` (appBar, card, radio, input, iconButton, fab, listTile, snackBar, divider) with identical values, reading the scheme/tokens instead of `AppColors`.

- [ ] **Step 1: Write failing tests**: `AppTheme.dark.brightness == Brightness.dark`; `AppTheme.dark.extension<AppTokens>() != null`; `scaffoldBackgroundColor == AppTokens.dark.background`; `inputDecorationTheme.focusedBorder!.borderSide == BorderSide(color: Color(0xFF00D4FF), width: 2)`; `textTheme.titleLarge!.fontFamily` contains `Outfit`; `textTheme.bodyMedium!.fontFamily` contains `PlusJakartaSans`. Set `GoogleFonts.config.allowRuntimeFetching = false` in `setUpAll`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement**; text theme moved verbatim (sizes, weights, letter spacing unchanged).
- [ ] **Step 4: Switch the golden harnesses** as listed, run `flutter test --update-goldens` on the golden files, and review every changed PNG: backgrounds/text styles now come from the app theme and the real fonts; layout and bubble colors must match the app as seen in `docs/superpowers/baseline-2026-10-26/03-chat-detail.jpg`.
- [ ] **Step 5: Run `./scripts/fverify.sh`.** Expected: green.
- [ ] **Step 6: Commit** `refactor(design): AppTheme.dark with tokens extension; goldens render with the app theme`.

---

### Task 5: Component kit

**Files:**
- Create: `lib/core/design/components/{app_icon_button,glass_panel,app_pill,app_scaffold}.dart`
- Test: `test/core/design/components/{app_icon_button,glass_panel,app_pill,app_scaffold}_test.dart`, goldens in `test/core/design/components/goldens/`

These are new widgets for M3+; no existing screen switches to them in M0 (the 48 dp button would change Home and chat layouts).

**Interfaces:**
- Consumes: `context.tokens`, `context.colors`, `AppGlassLevel`, `AppSpace`, `AppRadius`, `AppMotion`.
- Produces:
  - `AppIconButton({required VoidCallback? onPressed, required IconData icon, required String semanticLabel, String? tooltip, double iconSize = 20, bool active = false})`: 36 dp visual inside a **48×48** hit area; `Semantics(button: true, label: semanticLabel, enabled: onPressed != null)`; hover/pressed/focus visuals using the alpha steps of today's `lib/core/widgets/app_icon_button.dart` (fill `0.15/0.05 → 0.2/0.1 → 0.3/0.15`, border `0.3 → 0.5 → 0.6`).
  - `GlassPanel({required Widget child, AppGlassLevel level = AppGlassLevel.regular, BorderRadius? borderRadius, bool blur = false, EdgeInsetsGeometry? padding})`: gradient fill from `tokens.glass(level).fillAlpha` and a 1.5 px border; a `BackdropFilter` **only** when `blur: true`.
  - `AppPill({required String label, IconData? icon, VoidCallback? onTap, bool selected = false})`
  - `AppScaffold({required String title, List<Widget> actions = const <Widget>[], required Widget body})`: header with a back button that calls `context.pop()` (go_router) and the localized `commonBack` tooltip, title in `headlineSmall`, the current `background → surface` diagonal gradient behind the body, `SafeArea` top and bottom.

- [ ] **Step 1: Write failing tests**:
  - `AppIconButton`: `tester.getSize(find.byType(AppIconButton)) == const Size(48, 48)`; one tap → callback count 1; `onPressed: null` → semantics `isEnabled` false and no callback; under `MediaQuery(textScaler: TextScaler.linear(1.5))` and `Directionality(textDirection: TextDirection.rtl)` no exception.
  - `GlassPanel(blur: false)`: `find.byType(BackdropFilter)` finds nothing; `blur: true`: exactly one.
  - `AppPill`: renders label; tap → `onTap` once; RTL + 1.5× text: no overflow.
  - `AppScaffold` inside a `GoRouter` with two routes: tapping back returns to the first route; title text present.
  - Goldens (via `GoldenTestHelper`, `AppTheme.dark`): `app_icon_button_states.png` (idle, active, disabled), `glass_panel_levels.png` (thin/regular/thick, `blur: false`), `app_pill_states.png` (idle, selected, with icon).
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run tests; create the new goldens** with `flutter test --update-goldens test/core/design/components` and review the PNGs.
- [ ] **Step 5: Commit** `feat(design): AppIconButton (48 dp), GlassPanel, AppPill, AppScaffold`.

---

### Task 6: Migrate every `AppColors` use, then forbid it

**Files:**
- Modify: the 35 files outside `lib/core/res/` that use `AppColors.` (largest: `settings/screens/memory_page.dart` 40, `settings/screens/llm/widgets/styled_dropdown.dart` 16, `core/widgets/glassmorphic/glassmorphic_text_field.dart` 13, `chat/widgets/chat_card.dart` 12, `chat/widgets/modern_chat_bubble.dart` 11, `settings/widgets/sound_effects_toggle.dart` 11) and the 5 `Colors.white`/`Colors.black` uses (`glassmorphic_text_field.dart:142,178`, `chat_list_shimmer_loading.dart:85,128,145`)
- Delete: `lib/core/res/app_colors.dart`, `lib/core/res/app_theme.dart`
- Modify: `test/architecture_test.dart`

**Interfaces:**
- Consumes: `context.colors`, `context.tokens` (Task 1).
- Mapping, applied mechanically:

  | Old | New |
  |---|---|
  | `AppColors.primary / onPrimary / primaryContainer / secondary / onSecondary / secondaryContainer / error / onError / surface / onSurface` | `context.colors.<same name>` |
  | `AppColors.accent` | `context.colors.tertiary` |
  | `AppColors.background / glassSurface / glassBorder / success / warning` | `context.tokens.<same name>` |
  | `Colors.black` | `context.tokens.shadow` |
  | `Colors.white` | `context.tokens.highlight` |
  | `AppTheme.lightTheme` | `AppTheme.dark` |

- [ ] **Step 1: Add failing tests** to `test/architecture_test.dart`: (a) no file under `lib/` outside `lib/core/design/` contains `AppColors` or `AppPalette`; (b) no file under `lib/` outside `lib/core/design/` matches `(^|[^A-Za-z])Colors\.(?!transparent\b)`; (c) `package:google_fonts` is imported only under `lib/core/design/` and in `lib/main.dart`.
- [ ] **Step 2: Run.** Expected: FAIL, listing the offending files (the work list).
- [ ] **Step 3: Migrate in four commits**, `flutter test` green after each, **never** `--update-goldens`: (i) `lib/core/widgets/**`; (ii) `lib/features/chat/**`; (iii) `lib/features/settings/**`; (iv) `lib/features/home/**`, `lib/app.dart`, delete the two legacy files. Where a `const` decoration referenced `AppColors`, drop `const` and build it in `build`. Read colors once at the top of `build`, outside any `AnimatedBuilder`/`builder:` callback that runs per frame (`typing_indicator.dart`, `chat_list_shimmer_loading.dart`). `lib/core/widgets/app_icon_button.dart` keeps its 36 dp size; add a one-line comment that M3 replaces it with `core/design/components/app_icon_button.dart`.
- [ ] **Step 4: Run the full suite.** Expected: all tests and **every golden unchanged since Task 5**. A golden diff means a mapping changed a value: fix the code.
- [ ] **Step 5: Run `./scripts/fverify.sh`**, then launch on macOS and compare Home, history, chat detail and settings with `docs/superpowers/baseline-2026-10-26/0{1,2,3,4}-*.jpg` by eye. Expected: identical.
- [ ] **Step 6: The fourth commit** is `refactor(design): features read colors from Theme; forbid AppColors outside core/design`.

---

### Task 7: Hard-coded strings found in the audit

**Files:**
- Modify: `lib/features/chat/widgets/chat_card.dart` (`'$messageCount messages'`), `lib/features/home/screens/home_screen.dart` (`'Demo mode activated'`), `lib/features/chat/widgets/function_calling_widget.dart` (`'Result: …'`), `lib/features/settings/screens/function_calling_config_screen.dart` (lines 144-210: service titles and hints)
- Modify: `lib/core/l10n/app_localizations_{en,fr}.arb` (via `./scripts/fstr.sh`; ICU plurals by hand in both files, then `flutter gen-l10n`)
- Test: `test/features/chat/widgets/chat_card_l10n_test.dart`, `test/features/home/demo_snackbar_l10n_test.dart`

**Interfaces:**
- Produces ARB keys: `chatMessageCount` (ICU plural on `int count`; en `{count, plural, =1{1 message} other{{count} messages}}`, fr `{count, plural, =0{0 message} =1{1 message} other{{count} messages}}`), `demoModeActivated` (fr `Mode démo activé`, en `Demo mode activated`), `functionResultTitle` (placeholder `String name`; fr `Résultat : {name}`, en `Result: {name}`), and `googleSearchApiTitle`, `googleSearchApiKeyHint`, `searchEngineIdHint`, `openWeatherApiTitle`, `openWeatherApiKeyHint`, `nytApiTitle`, `nytApiKeyHint` (translations: product names stay untranslated, hints get French wording).

- [ ] **Step 1: Write failing widget tests**: `ChatCard` under `Locale('fr')` with `messageCount: 1` finds `1 message`, with `3` finds `3 messages`; under `Locale('en')`, `1` → `1 message`. `HomeScreen`'s demo listener under `fr` shows `Mode démo activé` (pump the `BlocListener` with a `DemoCubit` mock emitting `isActive: true`).
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Add the keys and replace the literals.**
- [ ] **Step 4: Run `./scripts/fl10n.sh`**; the literals above must no longer be reported. Run tests. Expected: PASS.
- [ ] **Step 5: Commit** `fix(l10n): localize message counts, demo snackbar, tool result titles, API config labels`.

---

### Task 8: Rive allowed under `core/design/rive/` (decision D2)

**Files:**
- Modify: `AGENTS.md` (Gotchas, Rive line: "Rive types must stay in `lib/features/avatar/presentation/` and `lib/core/design/rive/`"), `test/architecture_test.dart`
- Create: `lib/core/design/rive/README.md` (one paragraph: M2 UI-kit widgets live here; contract in `rive/CONTRACT.md`)

**Interfaces:**
- Produces: architecture rule "`package:rive` is imported only under `lib/features/avatar/presentation/` and `lib/core/design/rive/`".

- [ ] **Step 1: Write the tests**: a pure function `bool riveImportAllowed(String path)` in the test file, unit-tested with `lib/features/avatar/presentation/x.dart` → true, `lib/core/design/rive/x.dart` → true, `lib/features/chat/x.dart` → false, `lib/core/design/x.dart` → false; then a scan over `lib/` asserting every `package:rive/` import passes it.
- [ ] **Step 2: Run.** Expected: FAIL (function missing).
- [ ] **Step 3: Implement the function, update `AGENTS.md`, add the README.**
- [ ] **Step 4: Run `./scripts/fverify.sh`.** Expected: green.
- [ ] **Step 5: Commit** `docs(arch): allow Rive widgets under core/design/rive (D2)`.

---

## Out of scope for M0

- Android 16 KB page-size alignment (baseline finding 4): its own release-blocker ticket.
- Android scene not rendering, composer behind the nav bar, mic permission at launch (baseline findings 1-3): M3.
- Any palette, type, size or layout change: M1 onward. Adopting the kit components on real screens: M3-M5.
- `ScenePalette` tokens: M3, when the scene-driven accent is built.

## Self-review

- **Spec coverage (§7 M0):** tokens + proper dark scheme → Tasks 1, 3, 4; bundled fonts → 2; component kit with goldens → 5; `AppColors.` codemod + color gate → 6; hard-coded strings C6/H7/"Result:" → 7; D2 rule → 8; baseline perf → already in `scripts/perf` + baseline README (committed in Task 0). "Boots offline with correct fonts" → Task 2 steps 1 and 4.
- **Ordering:** fonts (2) precede any theme test that instantiates `GoogleFonts` styles (3, 4); goldens move to `AppTheme.dark` (4) before widgets start requiring `AppTokens` (6).
- **Types:** `AppTokens.glass(AppGlassLevel)` returns `AppGlassStyle`; `GlassPanel.level` is `AppGlassLevel`; Task 6 uses only `context.colors` and `context.tokens`.
