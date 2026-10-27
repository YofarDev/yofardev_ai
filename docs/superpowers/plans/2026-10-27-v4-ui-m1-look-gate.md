# v4 UI redesign, M1 Look gate: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the user a debug-only `/ui-lab` where three candidate looks (palette + type + surface style), three Home layouts and the four scenes can be combined live, so they can pick the 4.0 look before any production screen is restyled.

**Architecture:** Looks are data (`UiLook` presets in `lib/core/design/looks/`) turned into a `ThemeData` by one builder; the lab wraps its preview in `Theme(data: buildLookTheme(...))`, so every kit component and mock is styled exactly as production would be after the pick. `AppTokens` gains the few look-dependent fields the kit needs (scene palette, surface style, outline, radius scale), with defaults equal to today, so production stays pixel-identical. The lab is driven by its own controls and by a debug VM service extension, so the controller can capture a contact sheet for the user.

**Tech Stack:** Flutter, `ThemeExtension`, `google_fonts` 9 (runtime fetch allowed only while the debug lab is open), existing Rive views from the avatar feature barrel, `dart:developer` service extensions.

**Spec:** [`docs/superpowers/specs/2026-10-26-v4-ui-redesign-plan.md`](../specs/2026-10-26-v4-ui-redesign-plan.md) §3.1 (design language), §4.1 (Home Stage), §7 M1 · M0 plan: [`2026-10-26-v4-ui-m0-foundations.md`](2026-10-26-v4-ui-m0-foundations.md)

## Global Constraints

- Everything from `AGENTS.md` applies, including the design-layer rules: colors only via `context.colors` / `context.tokens`; no `AppPalette`/`Colors.*` (except `transparent`) outside `lib/core/design/`; `google_fonts` only in `lib/core/design/` and `lib/main.dart`; Rive only in `lib/features/avatar/presentation/` and `lib/core/design/rive/`. All enforced by `test/architecture_test.dart`.
- **Production must not change.** No golden may change in M1 (never run `--update-goldens`); `AppTheme.dark` keeps today's values; new `AppTokens` fields default to today's behaviour.
- The lab is debug-only: route registered under `kDebugMode`, service extensions registered only in debug. Lab strings are hardcoded with a `// ignore-l10n: debug` file comment.
- Runtime font fetching (`GoogleFonts.config.allowRuntimeFetching = true`) only while the lab screen is mounted in a debug build; restored to `false` on dispose.
- Work in a worktree on branch `ui/m1-look-gate` from `main` (`20da11d` or later). A fresh worktree needs the git-ignored `native` symlink to `~/.pub-cache/hosted/pub.dev/rive_native-0.1.11/native` for Rive tests.
- One commit per task, `type(scope): subject`, ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Before each commit: `dart fix --apply`, `dart format .`, `./scripts/fverify.sh` green.
- Contrast floors for every look × scene: body text on surface ≥ 7:1; scene accent on surface ≥ 3:1 (UI components); text on accent (`onAccent`) ≥ 4.5:1.

### The three candidate looks (values are binding for Task 2)

| | A · Neon (today) | B · Storybook night | C · Cel |
|---|---|---|---|
| Idea | Baseline for comparison | The UI is a theatre around a lamp-lit picture book: deep plum ink, warm paper text, smoked glass; captions read like film subtitles in a soft serif | The UI borrows the character's line art: flat opaque fills, 2 px ink outlines, hard offset shadows, chunky rounded grotesk |
| ink (background) | `#0A0E1A` | `#16121D` | `#1B1830` |
| surface | `#141829` | `#211B2B` | `#2A2545` |
| on-surface text | `#F5F5F7` | `#F3EBDD` | `#FFF8EE` |
| outline | `#2A3148` | `#3A3046` | `#0E0B1A` (ink line) |
| surface style | glass | glass (smoked, warm tint) | cel (solid + outline + hard shadow) |
| outline width | 1.5 | 1 | 2 |
| radius scale | 1.0 | 1.15 | 1.35 |
| display / text fonts | Outfit / Plus Jakarta Sans | Fraunces / Manrope | Bricolage Grotesque / Geist |
| accent: livingRoom | `#00D4FF` | `#F4B860` lamp | `#FFC24B` |
| accent: campfire | `#00D4FF` | `#FF8552` ember | `#FF7A3D` |
| accent: beach | `#00D4FF` | `#FF9478` sunset | `#FF6F91` |
| accent: deepSpace | `#00D4FF` | `#B79CFF` nebula | `#8C7CFF` |

`onAccent` per accent is the darkest of (ink, `#000000`) that clears 4.5:1, else `#FFFFFF`. Glow = accent at 35 % alpha. If a listed value misses a contrast floor, adjust lightness only (keep hue), and record the change in the task report.

### The three Home layouts (Task 5)

```
L1 Stage chips              L2 Dock                      L3 Curtain
┌──────────────────┐        ┌──────────────────┐         ┌──────────────────┐
│[◐ History] [⋯]   │        │                  │         │                  │
│                  │        │      scene       │         │      scene       │
│      scene       │        │      avatar      │         │  ╭───────────╮   │
│      avatar      │        │                  │         │  │ caption   │◄─ speech bubble
│                  │        │  “caption line   │         │  ╰──╮────────╯   │   near the head
│  “caption line   │        │   as subtitle”   │         │     avatar       │
│   two lines”     │        │ ╭──────────────╮ │         │                  │
│ ╭──────────────╮ │        │ │◐ │ Ask… 🎙│ ⋯│ │         │ ╭──────────────╮ │
│ │＋ Ask…     🎙│ │        │ ╰──────────────╯ │         │ │  Ask…      🎙│ │
│ ╰──────────────╯ │        └──────────────────┘         │ ╰──────────────╯ │
└──────────────────┘        one floating dock            └──────────────────┘
                                                          chrome appears on tap
```

## Review Focus

1. **Production drift:** a new `AppTokens` field or a kit change altering today's rendering. Every existing golden must pass untouched (Tasks 1, 3).
2. **Font fetch flag leaks:** leaving the lab (pop, hot restart, exception) must restore `allowRuntimeFetching = false`; release builds never flip it (Task 4).
3. **Contrast per scene:** each look × scene palette clears the floors above (Task 2 tests).
4. **Lab robustness:** switching look/scene/layout rapidly must not leak Rive files or controllers (scene view already disposes per scene; the lab must not create extra copies per rebuild) (Task 5).
5. **Service extension input:** unknown keys or bad values return an error response, never crash the app (Task 4).

---

## File Structure

```
lib/core/design/
  tokens/scene_palette.dart        ScenePalette {accent, onAccent, glow}
  tokens/app_tokens.dart           + scene, surfaceStyle, outlineWidth, radiusScale (defaults = today)
  looks/ui_look.dart               UiLook data class + LookFonts
  looks/ui_look_presets.dart       UiLooks.neon / storybook / cel
  looks/look_theme.dart            buildLookTheme(look, scene, textThemeBuilder)
  looks/look_fonts.dart            googleFontsTextThemeBuilder, LabFontFetching (only google_fonts user)
  components/*                     honour surfaceStyle / outlineWidth / radiusScale
lib/features/home/
  screens/ui_lab_screen.dart       debug lab (route /ui-lab)
  widgets/lab/                     lab_controls.dart, lab_surfaces_preview.dart, lab_stage_preview.dart,
                                   lab_stage_layouts.dart, lab_composer_mock.dart, lab_service_extension.dart
lib/core/router/{app_router.dart, route_constants.dart}   + /ui-lab under kDebugMode
test/core/design/                  scene_palette_test, looks_test, components (style variants)
test/features/home/lab/            ui_lab_screen_test, lab_service_extension_test
```

---

### Task 1: Scene palette and look-dependent tokens

**Files:**
- Create: `lib/core/design/tokens/scene_palette.dart`
- Modify: `lib/core/design/tokens/app_tokens.dart`, `lib/core/design/design.dart`
- Test: `test/core/design/scene_palette_test.dart`, extend `test/core/design/tokens_test.dart`

**Interfaces:**
- Produces:
  - `@immutable class ScenePalette { const ScenePalette({required Color accent, required Color onAccent, required Color glow}); static ScenePalette lerp(ScenePalette a, ScenePalette b, double t); }` with `==`/`hashCode`.
  - `enum AppSurfaceStyle { glass, cel }`
  - `AppTokens` new fields: `ScenePalette scene` (default in `AppTokens.dark`: accent `0xFF00D4FF`, onAccent `0xFF001F29`, glow `0x5900D4FF`), `AppSurfaceStyle surfaceStyle` (default `glass`), `double outlineWidth` (default `1.5`), `double radiusScale` (default `1.0`); all in `copyWith`, `lerp` (`surfaceStyle` switches at t ≥ 0.5), `==`, `hashCode`.
  - `double AppTokens.radius(double base)` → `base * radiusScale`.

- [ ] **Step 1: Failing tests**: ScenePalette lerp halfway equals `Color.lerp` per field; equality; `AppTokens.dark.scene.accent == Color(0xFF00D4FF)`; `AppTokens.dark.surfaceStyle == AppSurfaceStyle.glass`; `outlineWidth == 1.5`; `radius(14) == 14`; lerp between tokens with different `surfaceStyle` returns the first below 0.5 and the second at/above 0.5; `copyWith` round-trip.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** Export `scene_palette.dart` from `design.dart`.
- [ ] **Step 4: Run the full suite.** Expected: green, **no golden diffs**.
- [ ] **Step 5: Commit** `feat(design): scene palette and look tokens on AppTokens`.

---

### Task 2: Look presets and theme builder

**Files:**
- Create: `lib/core/design/looks/{ui_look,ui_look_presets,look_theme,look_fonts}.dart`, `lib/core/design/looks/looks.dart` (barrel; not exported from `design.dart`)
- Test: `test/core/design/looks_test.dart`

**Interfaces:**
- Consumes: `ScenePalette`, `AppSurfaceStyle`, `AppTokens`, `AvatarScene` (`lib/core/models/avatar_scene.dart`).
- Produces:
  - `@immutable class LookFonts { const LookFonts({required String display, required String text}); }` (Google Fonts family names as accepted by `GoogleFonts.getFont`).
  - `@immutable class UiLook { const UiLook({required String id, required String name, required Color ink, required Color surface, required Color onSurface, required Color outline, required AppSurfaceStyle surfaceStyle, required double outlineWidth, required double radiusScale, required LookFonts fonts, required Map<AvatarScene, Color> accents}); ScenePalette palette(AvatarScene scene); }` — `palette` derives `onAccent` and `glow` by the rule in Global Constraints.
  - `abstract final class UiLooks { static const UiLook neon, storybook, cel; static const List<UiLook> all; }` with the table's values.
  - `typedef LookTextThemeBuilder = TextTheme Function(LookFonts fonts, ColorScheme scheme);`
  - `ThemeData buildLookTheme(UiLook look, AvatarScene scene, {required LookTextThemeBuilder textThemeBuilder})`: dark `ColorScheme` (primary = scene accent, onPrimary = onAccent, surface/onSurface/outline from the look, tertiary = accent, `surfaceContainer*` = surface), `AppTokens.dark.copyWith(background: ink, glassSurface: surface, glassBorder: outline, scene: look.palette(scene), surfaceStyle, outlineWidth, radiusScale)`, component themes structurally like `AppTheme.dark` (radii multiplied by `radiusScale`).
  - `LookTextThemeBuilder googleFontsTextThemeBuilder` in `look_fonts.dart`: display font for display/headline/title, text font for body/label; same sizes and weights as `buildTextTheme` today.
  - `abstract final class LabFontFetching { static void enable(); static void restore(); }` (stores and restores the previous flag; `enable` is a no-op outside `kDebugMode`).

- [ ] **Step 1: Failing tests** (use a fake `LookTextThemeBuilder` that returns `ThemeData.dark().textTheme` with the family names applied, so no font loads in tests):
  - for every look × scene: contrast(onSurface, surface) ≥ 7; contrast(accent, surface) ≥ 3; contrast(onAccent, accent) ≥ 4.5;
  - `buildLookTheme(UiLooks.neon, AvatarScene.livingRoom, …)` yields the same `colorScheme.primary/surface/onSurface/outline` and the same `AppTokens` `background/glassSurface/glassBorder/success/warning` as `AppTheme.dark` (the scene palette's `onAccent` may differ: it follows the derivation rule);
  - `buildLookTheme(UiLooks.cel, …).extension<AppTokens>()!.surfaceStyle == AppSurfaceStyle.cel` and `outlineWidth == 2`;
  - `palette(scene).glow.a` ≈ 0.35;
  - `LabFontFetching.enable()` then `restore()` returns the flag to its previous value.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** Adjust any table value that fails a contrast floor (lightness only) and list it in the report.
- [ ] **Step 4: Run the suite.** Expected: green, no golden diffs.
- [ ] **Step 5: Commit** `feat(design): candidate looks and look theme builder`.

---

### Task 3: Kit components honour the look tokens

**Files:**
- Modify: `lib/core/design/components/{glass_panel,app_pill,app_icon_button,app_scaffold}.dart`
- Test: extend `test/core/design/components/*_test.dart`; new goldens `test/core/design/components/goldens/*_cel.png`

**Interfaces:**
- Consumes: `tokens.surfaceStyle`, `tokens.outlineWidth`, `tokens.radius(...)`, `tokens.scene`.
- Produces: with `surfaceStyle == cel`: opaque `glassSurface` fill, `outlineWidth` border in `glassBorder`, hard shadow `Offset(0, 3)` blur 0 in `tokens.shadow` at 0.6 alpha, no gradient, no blur. With `glass`: exactly today's rendering. Radii go through `tokens.radius(...)`. Active/selected states use `tokens.scene.accent` / `onAccent` (today's default palette equals today's primary, so glass goldens stay identical).

- [ ] **Step 1: Failing tests**: under a theme with `surfaceStyle: cel`, `GlassPanel` decoration has no gradient and a border of width 2 (when tokens say 2); `AppPill(selected: true)` fill equals `tokens.scene.accent`; radius scales with `radiusScale`. Add three `_cel` goldens (panel levels, pill states, icon button states) rendered with `buildLookTheme(UiLooks.cel, AvatarScene.livingRoom, textThemeBuilder: <bundled-font builder that maps every family to the bundled Plus Jakarta Sans/Outfit>)` so goldens never fetch fonts.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the suite.** Every pre-existing golden passes untouched; create only the new `_cel` goldens with `--update-goldens` on those three files' new cases and review them by eye.
- [ ] **Step 5: Commit** `feat(design): kit components render glass or cel from tokens`.

---

### Task 4: UI lab screen, controls, surfaces preview, service extension

**Files:**
- Create: `lib/features/home/screens/ui_lab_screen.dart`, `lib/features/home/widgets/lab/{lab_config.dart,lab_controls.dart,lab_surfaces_preview.dart,lab_service_extension.dart}`
- Modify: `lib/core/router/route_constants.dart` (`uiLab = '/ui-lab'`), `lib/core/router/app_router.dart` (route + `open` extension under `kDebugMode`), `lib/features/settings/screens/settings_screen.dart` (debug-only lab tiles)
- Test: `test/features/home/lab/ui_lab_screen_test.dart`, `test/features/home/lab/lab_service_extension_test.dart`

**Interfaces:**
- Consumes: `UiLooks`, `buildLookTheme`, `googleFontsTextThemeBuilder`, `LabFontFetching` (Task 2); kit components.
- Produces:
  - `@immutable class LabConfig { final String lookId; final AvatarScene scene; final LabLayout layout; final LabComposerState composer; final LabTab tab; final double? accentHueOverride; final double glassAlphaScale; final double? radiusScaleOverride; LabConfig copyWith(...); Map<String, Object?> toJson(); static LabConfig fromJson(Map<String, Object?> json); }` with `enum LabLayout { stageChips, dock, curtain }`, `enum LabComposerState { idle, typing, listening, thinking, speaking }`, `enum LabTab { stage, surfaces }`. `fromJson` throws `FormatException` on unknown keys/values.
  - `UiLabScreen` (StatefulWidget) owning a `ValueNotifier<LabConfig>`; preview wrapped in `Theme(data: buildLookTheme(...overrides applied...))`; a collapsible controls panel (segmented look / scene / layout / composer / tab, sliders for accent hue override, glass alpha scale, radius scale, a "Copy config" button that puts `jsonEncode(config.toJson())` on the clipboard and logs it via `AppLogger`).
  - `LabSurfacesPreview`: transcript snippet (assistant text un-bubbled full width, user bubble in accent, a tool chip "Searched the web · 3 results"), a settings group (3 rows with a switch, a value, a chevron), toast, `AppPill`s (idle/selected/icon), `AppIconButton`s (idle/active/disabled), `GlassPanel` levels, type specimen (display 32, title 22, body 16, caption 20 in display font).
  - `registerUiLabExtensions(ValueNotifier<LabConfig> config)` (debug only): `ext.yofardev.uiLab.configure` (params: any `LabConfig` JSON keys as strings; merges; returns the new config JSON; error response on bad input) and `ext.yofardev.uiLab.state` (returns current config JSON). Registration is idempotent across remounts (registerExtension throws on duplicates: register once per isolate, route calls to the currently mounted notifier, return an error when no lab is mounted).
  - `initState`: `LabFontFetching.enable()`; `dispose`: `LabFontFetching.restore()`.
  - Entry points (debug only): in `lib/core/router/app_router.dart` (composition root, the only place that may touch `AppRouter.router`) register `ext.yofardev.uiLab.open` once, which pushes `RouteConstants.uiLab`; in `lib/features/settings/screens/settings_screen.dart` add, under `kDebugMode`, two plain list tiles at the end of the list: "UI lab" → `context.push(RouteConstants.uiLab)` and "Rive lab" → `context.push(RouteConstants.riveLab)`.

- [ ] **Step 1: Failing tests**: `LabConfig` JSON round-trip and `FormatException` on `{"lookId":"nope"}`; the configure handler applied to a notifier changes it and returns JSON, bad input returns an error result (test the pure handler function, not `registerExtension`); pumping `UiLabScreen` (with `GoogleFonts.config.allowRuntimeFetching=false` and the fake text builder injected through a constructor parameter `textThemeBuilder` defaulting to `googleFontsTextThemeBuilder`) shows the controls and the surfaces tab; switching look to `cel` changes the preview's `AppTokens.surfaceStyle`; disposing the screen restores the font flag.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** The Stage tab shows a placeholder until Task 5.
- [ ] **Step 4: Run the suite**, then run the app in debug on macOS, open `/ui-lab` from the new debug tile in Settings and check fonts load for B and C.
- [ ] **Step 5: Commit** `feat(home): debug UI lab with look, scene and surface previews`.

---

### Task 5: Stage preview — three Home layouts and composer states

**Files:**
- Create: `lib/features/home/widgets/lab/{lab_stage_preview.dart,lab_stage_layouts.dart,lab_composer_mock.dart,lab_caption.dart}`
- Modify: `lib/features/home/screens/ui_lab_screen.dart` (Stage tab)
- Test: `test/features/home/lab/lab_stage_test.dart`

**Interfaces:**
- Consumes: `LabConfig`; `RiveSceneView` and `RiveAvatarView` from `lib/features/avatar/avatar.dart` (barrel); kit components.
- Produces:
  - `LabStagePreview(config)`: one `RiveSceneView(scene: config.scene)` and one `RiveAvatarView` (constructed from default `AvatarState`/`TalkingState` values; `phase` follows the composer mock state: thinking → generating, speaking → speaking) kept alive across layout/look changes (keyed by scene only), overlaid by the layout chrome.
  - `LabStageLayout` per `LabLayout` as drawn in Global Constraints: L1 top chips (History, overflow) + caption above composer; L2 single bottom dock (history | composer | overflow) + subtitle-style caption; L3 curtain (composer only; tap on stage toggles chips; caption as a speech bubble near the avatar's head).
  - `LabComposerMock(state)`: idle (pill, placeholder "Ask anything", mic), typing (text + send), listening (pill collapses to a pulsing circle, live words above), thinking (breathing glow in `scene.glow`), speaking (stop replaces send in place). Simple Flutter animations only (Rive orb is M2); respects `MediaQuery.disableAnimations`.
  - `LabCaption`: two lines max, display font, sample sentences per scene (e.g. livingRoom "The cat thinks the lamp is a second moon.").

- [ ] **Step 1: Failing tests** (Rive views replaced by a placeholder through a constructor-injected `stageBuilder` in tests, since Rive files are not decoded in widget tests): each layout renders its chrome (finders on semantic labels); composer shows send for typing and stop for speaking; curtain toggles chips on tap; with `disableAnimations: true` no `AnimationController` repeats (`tester.hasRunningAnimations` false after pump).
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the suite**, then run on macOS: switch look/scene/layout 20 times quickly and confirm the log shows no Rive load errors and memory settles (DevTools not required: watch for duplicate scene loads in the log).
- [ ] **Step 5: Commit** `feat(home): UI lab stage preview with three layouts and composer states`.

---

### Task 6 (controller): Contact sheet and the user's pick

Not dispatched to a subagent.

- [ ] Run the app in profile on macOS, open the lab via `ext.yofardev.uiLab.open`, then for each look × layout (scene = livingRoom) and each look × scene (layout = the user's likely favourite, else L1) call `ext.yofardev.uiLab.configure` and capture `_flutter.screenshot` (`scripts/perf/bin/shot.dart` pattern). Also capture the Surfaces tab per look.
- [ ] Publish one comparison page (Artifact) with the captures grouped by look, plus the token table above.
- [ ] Ask the user to pick look, font pair, layout and any slider overrides ("Copy config" JSON welcome). Their answer is the input of the M1b plan (apply the chosen look to `AppTheme.dark`, bundle the chosen fonts, remove the losing presets and the lab's runtime-fetch path, intentional golden refresh).

## Out of scope for M1

- Applying the chosen look to production screens (M1b, after the pick), Home rebuild (M3), Rive UI kit (M2), any production layout change.

## Self-review

- **Spec coverage (§7 M1):** debug `/ui-lab` with 2-3 Home variants (Task 5), token tweaker (Task 4 sliders), scene palettes (Tasks 1-2), user picks the look (Task 6). §3.1 scene-adaptive accent and rationed glass are expressed as data (Task 2) and in the kit (Task 3).
- **Ordering:** tokens (1) → looks (2) → kit honours tokens (3) → lab (4) → stage (5) → pick (6). Goldens stay frozen through 1-5 except the new `_cel` goldens in Task 3.
- **Types:** `UiLook.palette(AvatarScene) → ScenePalette`; `buildLookTheme(UiLook, AvatarScene, {textThemeBuilder})`; `LabConfig.fromJson` throws `FormatException`.
