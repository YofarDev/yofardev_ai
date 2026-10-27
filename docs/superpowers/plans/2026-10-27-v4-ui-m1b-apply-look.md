# v4 UI redesign, M1b Apply the chosen look: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make look **B · Storybook night** the app's real theme (palette, Fraunces + Manrope, scene-lit accent that follows the current scene), remove the losing looks and the cel code path, and leave M3 the public building blocks it needs.

**User decision (2026-10-27):** look **B · Storybook night**, Home layout **L1 Stage chips** (layout is input for M3, not built here). Comparison page: https://claude.ai/artifact/ECQhzY7qbhxisDxZkjYU4U

**Architecture:** One theme source: `AppTheme.forScene(AvatarScene)` = `buildLookTheme(UiLooks.storybook, scene, textThemeBuilder: googleFontsTextThemeBuilder)` with the missing scheme roles reconciled, cached per scene. `lib/app.dart` (composition root) feeds the current scene from `AvatarCubit` into `MaterialApp.theme`; `MaterialApp`'s built-in theme animation cross-fades the accent (`AppTokens.lerp` already interpolates `scene`). The duplicated component-theme body and `buildTextTheme` are deleted.

**Tech Stack:** Flutter, `ThemeExtension`, `google_fonts` 9 (bundled assets only), golden_toolkit.

**Spec:** [`docs/superpowers/specs/2026-10-26-v4-ui-redesign-plan.md`](../specs/2026-10-26-v4-ui-redesign-plan.md) §3.1 · M1 plan: [`2026-10-27-v4-ui-m1-look-gate.md`](2026-10-27-v4-ui-m1-look-gate.md) (its looks table is the source of Storybook's values)

## Global Constraints

- `AGENTS.md` rules apply (design layer, enforced architecture tests, l10n, explicit types, `flutter pub add` only).
- Storybook values (binding): ink `#16121D`, surface `#211B2B`, on-surface `#F3EBDD`, outline `#3A3046`, outline width 1, radius scale 1.15, glass surface style, fonts Fraunces (display/headline/title) + Manrope (body/label), accents livingRoom `#F4B860`, campfire `#FF8552`, beach `#FF9478`, deepSpace `#B79CFF`; onAccent = first of (ink, `#000000`, `#FFFFFF`) clearing 4.5:1; glow = accent at 35 %.
- Roles the look must also define (binding): `error #FF6B6B`, `onError #16121D`; `secondary` = scene accent, `onSecondary` = onAccent; `tertiary #B79CFF`, `onTertiary #16121D`; `primaryContainer` / `secondaryContainer` = accent at 25 % over surface, `onPrimaryContainer` / `onSecondaryContainer` = on-surface; `surfaceContainerLowest` = ink, `surfaceContainerLow…Highest` = glass surface (= surface for Storybook); success `#7BD88F`, warning `#F4B860`. Every pair clears 4.5:1 for text (3:1 for success/warning used as icons).
- Fonts bundled, runtime fetching stays off in `main.dart`. Weights in use after this milestone: Fraunces 400/500/600, Manrope 400/500.
- **Intentional visual change:** this milestone changes how the whole app looks. Goldens are regenerated once, in Task 2 only, and reviewed by eye; every other task keeps goldens frozen.
- Work continues on branch `ui/m1-look-gate` in `/Users/yofardev/development/Projects/Flutter/yofardev_ai-m1`. One commit per task (`type(scope): subject`, ending `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`). `./scripts/fverify.sh` green before each commit.

## Review Focus

1. **Silent role changes:** widgets reading `secondary`, `tertiary`, `error`, `surfaceContainer*`, `outline` get deliberate values (Task 2 test pins every role).
2. **Theme churn:** switching scene must not rebuild the router or re-create cubits; only the theme animates (Task 2).
3. **Font weights:** no style asks for a weight that is not bundled (Task 1 offline test covers every text-theme style, not just a sample).
4. **Dead code after removal:** no cel branch, `AppSurfaceStyle`, `LabFontFetching`, `makeLookTestable`, Outfit/Plus Jakarta Sans assets left behind (Task 3 greps).
5. **Debug lab still works** with one look, and stays debug-only (Task 3).

---

### Task 1: Bundle Fraunces and Manrope

**Files:**
- Create: `assets/fonts/google_fonts/{Fraunces-Regular,Fraunces-Medium,Fraunces-SemiBold,Manrope-Regular,Manrope-Medium}.ttf`, `OFL-Fraunces.txt`, `OFL-Manrope.txt`; update `assets/fonts/google_fonts/README.md`
- Modify: `test/core/design/fonts_offline_test.dart`

**Interfaces:**
- Produces: the five files resolvable by `google_fonts` with fetching off.

- [ ] **Step 1: Failing test**: extend `fonts_offline_test.dart` with a case that builds `googleFontsTextThemeBuilder(UiLooks.storybook.fonts, <any dark scheme>)` and awaits `GoogleFonts.pendingFonts()` with fetching disabled — this covers every style the app theme will use.
- [ ] **Step 2: Run**, expect FAIL (`Fraunces-Regular was not found`).
- [ ] **Step 3: Add the files.** Source: the exact files google_fonts already downloaded on this machine during the lab runs, in `~/Library/Containers/fr.yofardev.yofardevAi/Data/Library/Application Support/fr.yofardev.yofardevAi/` (`Fraunces_regular_*.ttf`, `Fraunces_500_*.ttf`, `Fraunces_600_*.ttf`, `Manrope_regular_*.ttf`, `Manrope_500_*.ttf`); copy and rename to the names above. Verify each is a static TTF (no `fvar` table) and record its SHA-256 in the README. Licences: `https://raw.githubusercontent.com/undercasetype/Fraunces/master/OFL.txt` and `https://raw.githubusercontent.com/sharanda/manrope/master/OFL.txt` (if a URL fails, find the repo's licence file and note the URL).
- [ ] **Step 4: Run the test**, then the suite. Expected: green, goldens unchanged.
- [ ] **Step 5: Commit** `feat(design): bundle Fraunces and Manrope`.

---

### Task 2: Storybook becomes the app theme, scene-lit

**Files:**
- Modify: `lib/core/design/looks/look_theme.dart` (scheme roles), `lib/core/design/looks/ui_look.dart` / `ui_look_presets.dart` (role fields on `UiLook`: `error`, `onError`, `tertiary`, `onTertiary`, `success`, `warning`), `lib/core/design/tokens/app_palette.dart` (Storybook constants), `lib/core/design/tokens/app_tokens.dart` (`AppTokens.dark` = Storybook living room), `lib/core/design/theme/app_theme.dart` (`AppTheme.forScene`, `AppTheme.dark` = living room), `lib/app.dart`
- Delete: `lib/core/design/theme/app_text_theme.dart` (`buildTextTheme`), the component-theme body duplicated in `app_theme.dart`
- Test: `test/core/design/app_theme_test.dart`, `test/core/design/looks_test.dart`, `test/core/design/color_scheme_test.dart` (rewrite for the new roles or fold into app_theme_test), all goldens refreshed once

**Interfaces:**
- Consumes: `UiLooks.storybook`, `buildLookTheme`, `googleFontsTextThemeBuilder`, bundled fonts.
- Produces:
  - `abstract final class AppTheme { static ThemeData forScene(AvatarScene scene); static ThemeData get dark; }` — `forScene` caches one `ThemeData` per scene; `dark` = `forScene(AvatarScene.livingRoom)`.
  - `buildLookTheme` sets every role in Global Constraints.
  - `lib/app.dart`: `MaterialApp.router(theme: AppTheme.forScene(scene), themeAnimationDuration: AppMotion.slow, themeAnimationCurve: AppMotion.standard, …)` where `scene` comes from a `BlocSelector<AvatarCubit, AvatarState, AvatarScene>` wrapping only the `MaterialApp` (the existing language `BlocBuilder` keeps working; the router instance is unchanged).

- [ ] **Step 1: Failing tests**: `AppTheme.dark.colorScheme` has every role value from Global Constraints (primary `#F4B860`, surface `#211B2B`, error `#FF6B6B`, tertiary `#B79CFF`, outline `#3A3046`, surfaceContainerLowest `#16121D`…); `AppTheme.forScene(AvatarScene.beach).extension<AppTokens>()!.scene.accent == Color(0xFFFF9478)`; `identical(AppTheme.forScene(beach), AppTheme.forScene(beach))`; contrast floors for every scene and role pair; `textTheme.titleLarge!.fontFamily` contains `Fraunces`, `bodyMedium` contains `Manrope`; widget test: pumping `App`-like harness with a fake `AvatarCubit` emitting a new scene changes `Theme.of(context).colorScheme.primary` after the animation and does not rebuild a widget keyed under the router (use a counter in a test-only child).
- [ ] **Step 2: Run**, expect FAIL.
- [ ] **Step 3: Implement.** Delete the duplicate component themes and `buildTextTheme`; `googleFontsTextThemeBuilder` is the only text theme. Update any test or helper that imported `buildTextTheme` (e.g. the lab look-test helper) to use `AppTheme`/the builder.
- [ ] **Step 4: Golden refresh (intentional, once).** Run the suite, then `flutter test --update-goldens` on every golden test file. Read at least: one chat screen, one bubble, the shimmer, every component golden. Describe each in the report (fonts Fraunces/Manrope, plum surfaces, amber accent). Re-run without the flag to confirm determinism.
- [ ] **Step 5: Run the app** in debug on macOS (window on an unoccluded display), check Home, history, chat detail, settings render with no overflow or missing font in the log, and switch scenes from the lab or by chat to see the accent cross-fade. Report what you saw.
- [ ] **Step 6: Commit** `feat(design): Storybook night is the app theme, accent follows the scene` (goldens in the same commit).

---

### Task 3: Remove the losing looks and the cel path

**Files:**
- Modify/Delete: `lib/core/design/looks/ui_look_presets.dart` (only `storybook`), `lib/core/design/components/{cel_style.dart (delete), glass_panel.dart, app_pill.dart, app_icon_button.dart, app_scaffold.dart}` (glass only), `lib/core/design/tokens/scene_palette.dart` / `app_tokens.dart` (drop `AppSurfaceStyle` and `surfaceStyle`), `lib/core/design/looks/look_fonts.dart` (drop `LabFontFetching`), lab files under `lib/features/home/` (no look switcher, no `lookId`; scene/layout/composer/sliders stay), `test/helpers/golden_test_helper.dart` (drop `makeLookTestable`), test files for cel and lab, `assets/fonts/google_fonts/` (delete Outfit + Plus Jakarta Sans TTFs and OFLs if nothing uses them), `test/core/design/components/goldens/*_cel.png` (delete)

**Interfaces:**
- Produces: kit components with one (glass) code path; `LabConfig` without `lookId`; `UiLooks.storybook` only (keep `UiLooks.all = [storybook]` only if the lab needs a list).

- [ ] **Step 1: Failing guard tests** in `test/architecture_test.dart`: no `AppSurfaceStyle`, `celFill`, `LabFontFetching`, `makeLookTestable`, `UiLooks.neon`, `UiLooks.cel` anywhere under `lib/` and `test/`; no `Outfit`/`PlusJakartaSans` string under `lib/`.
- [ ] **Step 2: Run**, expect FAIL.
- [ ] **Step 3: Remove.** Lab tests updated to the single look; lab still opens from Settings in debug.
- [ ] **Step 4: Run the suite.** Expected: green; no golden changes other than the deleted `_cel` files.
- [ ] **Step 5: Commit** `refactor(design): drop losing looks and the cel path`.

---

### Task 4: Public building blocks for M3

**Files:**
- Modify: `lib/core/design/tokens/scene_palette.dart` (`ScenePalette.fromAccent`), `lib/core/design/looks/ui_look.dart` (use it), `lib/features/home/widgets/lab/lab_config.dart` (use it; drop the duplicated rule and `Color` literals), `lib/core/design/components/glass_panel.dart` (shape support), lab caption/surfaces/stage files (use `GlassPanel` instead of hand-written decorations and `BackdropFilter`)
- Test: `test/core/design/scene_palette_test.dart`, `test/core/design/components/glass_panel_test.dart`, lab tests

**Interfaces:**
- Produces:
  - `factory ScenePalette.fromAccent(Color accent, {required Color ink})` implementing the onAccent/glow rule (single source).
  - `GlassPanel({…, ShapeBorder? shape})` — when `shape` is given, fill/border/blur follow it (e.g. a speech-bubble shape with a tail); default stays the rounded rectangle (goldens unchanged).
  - Optional `GlassPanel.blur` stays opt-in (spec: at most two live blurs on screen).

- [ ] **Step 1: Failing tests**: `ScenePalette.fromAccent` for the four Storybook accents equals `UiLooks.storybook.palette(scene)`; the ink/black/white order; `GlassPanel(shape: StadiumBorder())` paints with that shape (find the `DecoratedBox`/`ShapeDecoration`); existing glass goldens untouched.
- [ ] **Step 2: Run**, expect FAIL.
- [ ] **Step 3: Implement**; replace the lab's hand-written surface recipes with `GlassPanel`.
- [ ] **Step 4: Run the suite** (goldens frozen).
- [ ] **Step 5: Commit** `feat(design): ScenePalette.fromAccent and shaped GlassPanel`.

---

### Task 5: Docs

**Files:** `AGENTS.md`, `docs/superpowers/specs/2026-10-26-v4-ui-redesign-plan.md`

- [ ] **Step 1:** `AGENTS.md`: theme is `AppTheme.forScene(scene)` (Storybook night; accent follows `AvatarState.scene`); fonts Fraunces + Manrope bundled; debug `/ui-lab` (Settings → UI lab in debug) and `ext.yofardev.uiLab.{open,configure,state}`; fix the two M0 wording nits (only widget tests that need app styling use `AppTheme.dark`; text via `context.text`).
- [ ] **Step 2:** Spec §9: record D1 look = B Storybook night, Home layout = L1 Stage chips (2026-10-27), and update §3.1 with the final palette and fonts.
- [ ] **Step 3:** `./scripts/fverify.sh`, commit `docs: record the 4.0 look and theme rules`.

## Self-review

- Spec §3.1 (ink + scene-adaptive accent, rationed glass, bundled type) → Tasks 1-2; M1 final-review carry-overs: scheme roles (Task 2), single text theme (Task 2), cel path/presets/LabFontFetching removal (Task 3), `ScenePalette.fromAccent` + shaped surface primitive (Task 4), AGENTS.md + plan wording (Task 5).
- Goldens change only in Task 2 (intentional) and lose the `_cel` files in Task 3.
