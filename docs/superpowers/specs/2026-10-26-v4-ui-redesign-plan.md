# Yofardev AI v4.0: UI/UX redesign plan

> Status: **draft for review** (2026-10-26). Nothing built yet.
> Builds on the Rive v4 work: [design](2026-10-22-rive-v4-design.md) ·
> [`rive/CONTRACT.md`](../../../rive/CONTRACT.md).
> Based on a code read of every screen and shared widget, plus a baseline run on macOS and an
> Android emulator: [`../baseline-2026-10-26/`](../baseline-2026-10-26/README.md).
> **Direction approved 2026-10-26: Stage. Defaults on D2-D7 accepted.**

## 1. Intent

The v4 avatar (Rive character + 4 living scenes) is the first thing in this app that feels
premium. Everything around it still looks like a 2024 "AI app" template: cyan/magenta/violet on
near-black, frosted-glass rectangles over a flat gradient, a column of tiny unlabeled icon
buttons, a settings form with a Save button.

**Goal:** the UI stops competing with the character and starts framing it. The app should feel
like a place you visit, not a chat tool with a mascot.

**Anti-goals**

- Jank or battery drain on low-end Android (already a v4 anti-goal). A pretty UI that drops
  frames fails.
- Cheap-looking motion or art (same rule as v4: Rive CLI iteration, no bought assets).
- A rewrite of cubits, domain services or the streaming/TTS pipeline. This is presentation work
  plus the small state hooks listed in §6.

**Non-goals (4.0):** light theme, iOS polish, web demo parity, user-built avatars, new LLM
features.

## 2. What is wrong today (audit)

Severity: **H** hurts the premium feel or usability now, **M** noticeable, **L** polish.

### 2.1 Visual language

| # | Finding | Sev | Evidence |
|---|---|---|---|
| V1 | Glass over nothing. `BackdropFilter` blurs a flat dark gradient, so panels read as muddy grey, not glass. It only works over rich content, and the rich content (the scene) is only on Home. | H | `chat_details_background.dart`, `settings_screen.dart` |
| V2 | The palette (cyan `#00D4FF` + magenta `#FF006E` + violet) is the default "AI neon" look. It says nothing about this app, and it fights the warm illustrated scenes. | H | `app_colors.dart` |
| V3 | Theme is internally inconsistent: a dark palette fed into `ColorScheme.light(...)`, named `lightTheme`. Derived M3 roles (`surfaceContainer*`, `onSurfaceVariant`, `outline`…) are wrong, so any stock widget looks off and has to be hand-painted. | M | `app_theme.dart` |
| V4 | Colors are hard-wired: **241** `AppColors.*` uses in **36** files, none through `Theme`. The UI can't adapt to the scene, can't add a second theme, can't be tested for contrast in one place. | H | grep |
| V5 | Fonts load at runtime from the network (`google_fonts`, nothing bundled). First launch offline or on a slow link shows fallback type, then a swap. | M | `pubspec.yaml`, `assets/` |
| V6 | 8 `BackdropFilter`s, including one per AI bubble inside a reversed `ListView`. This is the single biggest jank risk in the UI. | H | `modern_chat_bubble.dart`, `chat_card.dart`, `app_icon_button.dart` |
| V7 | Spacing, radii (12/16/20/4…) and durations are ad hoc per widget. No scale. | M | everywhere |

### 2.2 Home (the product's main screen)

| # | Finding | Sev |
|---|---|---|
| H1 | Five 36 px icon buttons stacked top-right: language (an emoji flag, not a button), chats, new chat, settings, tool-calling toggle. No labels, no grouping, below the 48 dp touch target, the toggle's meaning is invisible. | H |
| H2 | The assistant's reply is never shown on Home. Only the *user's* last prompt appears (`CurrentPromptText`). No captions: bad with sound off, in noise, and for accessibility. | H |
| H3 | While generating/speaking the text field is hidden with `Opacity(0)` (still in the tree) and the user's prompt is drawn on top. A hack, not a state machine; there is no designed "thinking" or "listening" moment. | H |
| H4 | Stop is a stock red Material FAB floating bottom-right. It clashes with everything and is far from the thumb that just pressed Send. | M |
| H5 | The mic is a small icon inside the text field. Speech-to-text exposes no input level, so there's no live feedback that it's hearing you. | M |
| H6 | Demo mode hides behind a triple tap on the stage, which also competes with avatar/prop taps. | L |
| H7 | `'Demo mode activated'` snackbar is hard-coded English. | L |

### 2.3 Chat detail and history

| # | Finding | Sev |
|---|---|---|
| C1 | Transcript is a separate full screen with a flat background and a static `icon.png` as the avatar. You leave the character to read what it said. | H |
| C2 | Bubble style is generic, 10 px timestamps, no message grouping, no markdown (plain `ParsedText`), no streaming reveal, no per-message actions (copy, speak again, regenerate, delete). | H |
| C3 | Tool calls render as a debug string (`➡️ name("key": "value")`, 11 px, low contrast: `surface` on `onSurface@30%`). Users never see "Searching the web…" as an event. | H |
| C4 | Bubble width is capped twice (outer 32 px padding + 75 % inner), wasting width on phones. | L |
| C5 | Sound-effect chip creates a new `AudioPlayer` per tap and never disposes it. | L |
| C6 | History cards print `'$messageCount messages'` (hard-coded English, breaks the l10n rule). No search, no date grouping, no scene thumbnail, titles exist (`chat_title_service`) but the card previews body text. | M |

### 2.4 Settings

| # | Finding | Sev |
|---|---|---|
| S1 | One long form with a Save button, while the language toggle on Home applies instantly. Two mental models. Unsaved changes are lost silently on back. | H |
| S2 | Flat list of identical gradient tiles. No hierarchy between "name" and "LLM routing". Sub-pages (LLM, task LLM, tools, memory) each use their own header (`SettingsAppBar`, `TaskLlmAppBar`, …). | M |
| S3 | Persona is a dropdown even though personas are the app's personality: ideal for cards with a preview. | M |
| S4 | `SettingsAppBar` calls `Navigator.pop` inside a go_router app; the screen's `stream.listen` in `initState` is never cancelled. | L |

### 2.5 Cross-cutting

| # | Finding | Sev |
|---|---|---|
| X1 | No onboarding. A new user with no API key lands on a talking avatar that can't answer. | H |
| X2 | No motion system: default `MaterialPage` transitions, no shared-element moves (Home → chat), no stagger, no springs. 0 haptic calls. | H |
| X3 | No adaptive layout. `ConstrainedWidth` only acts on web. Desktop/tablet get a stretched phone UI. | M |
| X4 | Accessibility: one `Semantics` in the whole app, no reduce-motion handling, many <48 dp targets, contrast of translucent bubbles over a changing scene is unchecked. | H |
| X5 | Rive is used for the character and scenes only. All UI states (loading, typing, mic, stop, empty) are Dart/Lottie-era widgets with no relation to the avatar's `phase`. | M |

## 3. Direction

Three directions were considered.

| | Idea | Verdict |
|---|---|---|
| **A. Stage** | The scene is the app. Chrome is minimal and floats. Transcript is a draggable sheet over the scene (glass finally has something to blur). One composer that morphs between idle / listening / thinking / speaking. | **Recommended** |
| B. Messenger+ | Keep the two-screen structure; restyle. | Lowest risk, but keeps C1/V1 problems; won't read as a step change. |
| C. Voice-first | Hands-free "live" mode, text hidden. | Great as a *mode* inside A, wrong as the whole product (people still type, and read tool results). |

**Choice: A, with a "Live" voice mode (C) as a P2 stretch.**

### 3.1 Design language (my proposal; every value is a starting point to react to)

- **Ink + scene, not neon.** Neutral warm-ink base (`#0E0F14`-ish), text near-white at three
  fixed opacities. **One** signature accent used only for the primary action and active state.
- **Scene-adaptive accent.** Each scene ships a 2-colour palette (livingRoom warm lamp-amber,
  campfire ember, beach sunset coral, deepSpace violet). The accent and glow tint cross-fade when
  the scene changes (the LLM can change it mid-chat), so the UI feels *lit by* the world.
- **Real glass, rationed.** At most **two** live blurs on screen (dock + sheet header). Message
  bubbles and list rows use opaque tinted fills + a 1 px top highlight, which look like glass
  and cost nothing.
- **Type.** One display face for titles/captions, one text face for body; **bundled** as assets,
  never fetched. Captions get the biggest, most deliberate type in the app.
- **Shape.** Radii scale 8 / 14 / 22 / 32 and a pill; the composer is a pill, sheets have 32 top
  radius, tool chips are pills.
- **Motion.** Springs for things you drag, 200-320 ms emphasized ease for things the app moves,
  nothing over 500 ms. Everything respects reduce-motion.
- **Haptics.** Light impact on send, selection tick on toggles/snap points, nothing on desktop.

### 3.2 Tokens and architecture

New `lib/core/design/` (tokens, theme, components), consumed through `Theme.of(context)`
extensions; `AppColors` becomes private to the theme.

- `ColorScheme.dark(...)` built properly (fixes V3), plus `AppTokens extends ThemeExtension`:
  `space` (4-pt scale), `radius`, `motion` (durations/curves/springs), `glass` (3 levels),
  `scenePalette` (animated).
- A grep-based gate in `fverify.sh`: no `AppColors.` and no `Colors.` literals outside
  `core/design/` after M3 (fixes V4 permanently).
- Component kit (`core/design/components/`): `AppButton`, `AppIconButton` (48 dp hit area),
  `GlassPanel`, `Pill`, `SettingsGroup`/`SettingsRow`, `SectionHeader`, `AppToast`, `ToolChip`,
  `PersonaCard`. Each gets a golden test.
- Candidate packages (via `flutter pub add`): `animations` (shared-axis / fade-through),
  `flutter_markdown_plus` (or equivalent). Prefer built-ins first; no `flutter_animate`
  unless the motion code gets noisy.

## 4. Screen-by-screen

### 4.1 Home: "Stage"

```
┌────────────────────────────┐
│ ◐ History        Scene · ⋯ │  top bar: two glass chips, safe-area aware
│                            │
│        (Rive scene)        │
│          avatar            │
│                            │
│  "…and that's why the sky  │  live caption: current TTS sentence,
│   turns orange at dusk."   │  big type, 2 lines max, fades per sentence
│  [🔎 Searching the web…]   │  tool chip (animated while running)
│ ╭────────────────────────╮ │
│ │ ＋  Ask anything…   🎙 │ │  composer pill → morphs (see below)
│ ╰──── ▔▔▔ drag handle ───╯ │  swipe up = transcript sheet
└────────────────────────────┘
```

- **Top bar:** left = History (opens chat list sheet); right = Scene/Customize and an overflow
  (new chat, language, tools toggle, settings). Removes the 5-button column and the emoji flag.
  Tool-calling becomes a labeled chip *inside* the composer's "＋" menu, with state shown on the
  chip.
- **Composer state machine** (one widget, `AnimatedSwitcher`/Rive-driven, replaces the
  `Opacity(0)` hack):
  | State | Looks like | Source |
  |---|---|---|
  | idle | pill + mic | default |
  | typing | pill + send (mic morphs to send) | text non-empty |
  | listening | pill shrinks to an orb that pulses with input level, live words above | STT |
  | thinking | orb "breathing", matches avatar `phase=generating` | `TalkingState` |
  | speaking | **Stop** replaces the send/mic slot in place (no floating FAB) | `TalkingState` |
  | error | orb shakes once, toast, returns to idle | `ChatState` |
- **Captions** show the sentence currently being spoken, in sync with TTS (§6). A tap toggles
  captions off (remembered).
- **Triple-tap demo** moves to the overflow ("Demo") + stays as a hidden gesture only in debug.
- **Reduced-motion / low-power:** idle Rive loops pause; only reactive animation stays.

### 4.2 Transcript sheet (replaces the separate chat screen)

- Draggable sheet over the stage, snap points **peek (last reply) / half / full**. When ≥85 %
  open, the stage Rive controllers are paused (battery, and no pointless rendering).
- **Messages:** assistant text is un-bubbled full-width markdown (code blocks with copy, lists,
  links); user messages are a solid accent-tinted bubble. 16 px body, 12 px timestamps shown on
  tap/group end, existing date separators kept, 90 % width.
- **Streaming reveal:** tokens fade in per word; a soft cursor shows while streaming.
- **Tool calls** become collapsible chips: `🔎 Searched the web · 3 results ▸` with an animated
  icon while running and the raw JSON under "Details" (replaces C3).
- **Message actions** on long-press: copy, speak again, regenerate (last reply only), delete.
- **Avatar in transcript:** header shows a small live thumbnail of the avatar (same Rive file, one
  more artboard) instead of `icon.png`.
- The sound-effect chip uses one shared player.
- The dev "show everything" view moves behind a debug toggle in the sheet menu.

### 4.3 History

Bottom sheet from Home (full screen on tablet). Search field, groups **Today / Yesterday /
Earlier**, rows = scene poster thumbnail + LLM title (existing `chat_title_service`) + one-line
preview + relative time. Swipe-to-delete with undo toast (kills confirm dialogs). Localized
counts via ICU plurals (fixes C6). Empty state = the avatar waving (reuses `avatar.riv`).

### 4.4 Settings

- **Autosave.** No Save button; each change applies immediately with a subtle "Saved" tick.
  Reads like iOS Settings: inset grouped lists.
- **Groups:** *You* (name, language) · *Personality* (persona cards: horizontal carousel, each
  card = name, one-line voice sample, tiny avatar mood) · *Voice & sound* · *Brain* (LLM, per-task
  LLM, tools) · *Memory* · *Appearance* (default scene, captions, reduced motion, haptics) ·
  *About* (version, debug tools in debug builds).
- **Sub-pages** share one `AppScaffold` header (fixes S2/S4); LLM config gets provider rows and
  a **Test connection** button with an animated result.
- **Memory page:** cards with pin/forget, search.

### 4.5 Onboarding (new, first run only)

1. **Meet**: avatar walks in (`presence`), waves; asks language + name.
2. **Brain**: pick provider, paste key, *Test connection* (green tick animation). "Skip, I'll do
   it later" is allowed but the Home composer then shows a persistent "Connect a brain" pill.
3. **Voice**: mic permission asked in context, with a try-it moment.
4. First message sent for them ("Say hello!") so the first reply is the hook.

Also covers the no-key empty state (X1).

### 4.6 Customize sheet (P2, high delight, low cost)

The contract already supports scene, hat, top, glasses and costume. A bottom sheet with live
preview lets users choose them directly, not only via the LLM. No new Rive work.

### 4.7 Adaptive layout (desktop / tablet / web)

≥ 840 dp: stage on the left ~60 %, transcript docked permanently on the right, history as a
collapsible sidebar. Replaces `ConstrainedWidth`. Landscape phones use the compact layout with
the sheet as a side panel.

### 4.8 System states

Skeleton shimmer only where content is real-but-loading (history); everything else uses the
avatar (thinking, empty, error "oops" gesture). Errors use `AppToast` (top pill) instead of
Material SnackBars; text stays through `localizeFailure`.

## 5. Where Rive earns its place

The rule: **Rive for the few hero moments that benefit from continuous, state-driven motion;
Flutter for lists and layout.** Each Rive widget is a render surface, so cap at three visible at
once (scene, avatar, one UI orb) and never put one inside a list item.

New asset `assets/rive/ui/ui_kit.riv` (one file, several artboards, ≤150 KB), generated with the
existing CLI pipeline (`rive/tools/…`, `frive.sh`), contract extended in `rive/CONTRACT.md`
in its own `contract:` commit:

| Artboard | View model | Replaces |
|---|---|---|
| `ComposerOrb` | `state` enum (idle, typing, listening, thinking, speaking, error), `level` number 0-1, `tap` event | mic button, send button, `FloatingStopButton`, Lottie-era typing dots in the composer |
| `StatusGlow` | `phase` enum (= `TalkingPhase`), `accent` color | ambient glow behind the composer; thinking/speaking atmosphere |
| `ToolIcon` | `kind` enum (search, weather, news, memory, generic), `running` bool | tool-call chips' icons |
| `Toggle` | `value` bool | settings switches |
| `Mark` | `play` trigger | splash / onboarding logo sting |

Reused with no new work: `avatar.riv` for onboarding, empty states, the transcript header
thumbnail and error moments. Scene posters (4 static WebP, ~20 KB each) are exported with the
existing headless screenshot tool for History rows and the Customize sheet.

Rive types currently must stay in `lib/features/avatar/presentation/`. The orb is used by
chat/home, so this needs a small rule change, see decision D2.

## 6. State and logic the redesign needs (all small)

| Need | Where | Notes |
|---|---|---|
| Live captions | `TtsPlaybackService` already knows which queue item is playing → emit `CaptionEvent(sentence, index)`; surface via `TalkingState` (no new cubit-to-cubit dependency) | text per sentence chunk already exists |
| Mic level | `SpeechToText.listen(onSoundLevelChange:)` → `ComposerController` value → Rive `level` | currently not wired |
| Composer state | small `ComposerCubit` (or derived selector) combining `TalkingState`, `ChatState`, text-empty | removes the logic now inside `AiTextInput` build |
| Sheet state | local to Home (`DraggableScrollableController`) + pause hook to Rive views | presentation-only |
| Message actions | `ChatCubit`: `regenerateLast()`, `deleteEntry()` | check streaming pipeline; regenerate is the only non-trivial one |
| Settings autosave | `SettingsCubit` already has the setters; remove local controllers + Save | debounce text fields |
| Scene palette | `AvatarState.scene` → `AppTokens.scenePalette` (animated `ThemeExtension.lerp`) | |
| Onboarding flag | `SettingsRepository` bool | |

DI changes only in `service_locator.dart`; architecture rules stay enforced.

## 7. Milestones

Internal milestones; **4.0 ships once**, no flag (same call as the Rive v4 design).

```
M0 foundations ─┐
M1 look gate ───┼─► M3 Home Stage ─► M4 Transcript ─┐
M2 Rive UI kit ─┘                     M5 History+Settings ─► M6 Onboarding+Customize ─► M7 Adaptive+polish
                                      (M4 ∥ M5)
```

| M | Deliverable | Done when |
|---|---|---|
| **M0** Foundations | `core/design/` tokens + proper dark `ColorScheme` + `AppTokens`; bundled fonts; component kit with goldens; codemod `AppColors.` → tokens; fix hard-coded strings (C6, H7, "Result:"); `fverify.sh` color gate | `flutter test` + goldens green, zero `AppColors.` outside `core/design/`, app boots offline with correct fonts |
| **M1** Look gate | Debug `/ui-lab` route (like `/rive-lab`) with 2-3 Home variants, token tweaker, scene palettes. **User picks the look.** | User approves direction + palette + type. Everything after builds on this. |
| **M2** Rive UI kit (parallel to M0/M1) | `ui_kit.riv` per §5, contract entries, Rive Lab controls, scene posters | `check_contract.py` green; budgets met; critic loop like `CRITIC_ITERATIONS.md` |
| **M3** Home Stage | Top bar, composer state machine + orb, captions, stop-in-place, tool chip, reduce-motion | Full voice + text loop works; no `Opacity(0)` hack; 60 fps on throttled emulator with scene + avatar + orb |
| **M4** Transcript | Sheet, markdown, streaming reveal, tool chips, message actions, avatar thumbnail, pause-when-covered | One shared player; ≤2 blurs on screen; long chat scrolls smoothly |
| **M5** History + Settings | History sheet (search, groups, swipe-undo), autosave settings, persona cards, shared `AppScaffold`, Test connection | No Save button; l10n gate clean |
| **M6** Onboarding + Customize | First-run flow, no-key state, Customize sheet | Fresh install → first spoken reply in < 60 s without docs |
| **M7** Adaptive + polish | ≥840 dp layout, a11y pass, haptics, page transitions/Hero, perf + battery pass, store screenshots | a11y checklist below; fverify green |

**A11y checklist (M7 gate):** all targets ≥48 dp; text scales to 1.5× without overflow; contrast
≥4.5:1 for captions and bubbles *over each of the 4 scenes*; screen-reader labels and live-region
announcements for avatar state; captions on by default; reduce-motion honored.

**Parallelism:** M2 (Rive agent, like Plan A) runs beside M0/M1 (app agent); M4 and M5 touch
different features and can run in separate worktrees.

## 8. Risks

| Risk | Mitigation |
|---|---|
| Glass blur costs frames on low-end Android | Blur budget (≤2); opaque faux-glass elsewhere; throttled-emulator check each milestone |
| Sheet drag vs. Rive taps/prop taps vs. triple-tap | Sheet owns vertical drags only from handle/composer; prop taps stay on the stage; demo gesture leaves the stage |
| Keyboard + composer + sheet layout interplay | Single `Scaffold` with `resizeToAvoidBottomInset: false` and explicit inset handling; widget tests with `viewInsets` |
| Many Rive surfaces → memory | Max 3 visible; pause when covered; lazy-load `ui_kit.riv` |
| Golden churn | Regenerate once per milestone, intentionally; README already documents the rule |
| Scope creep (Live mode, wardrobe, light theme) | Marked P2 / non-goal; M7 cuts first |
| Streaming "regenerate" touches the fragile chat pipeline | Isolate behind `ChatStreamingService`; own tests; can be cut without affecting other work |

## 9. Decisions needed (my default in bold)

| # | Decision | Options |
|---|---|---|
| D1 | Direction | **A Stage (+ Live mode later)** · B Messenger+ |
| D2 | Where UI Rive widgets may live | **Amend AGENTS.md + `architecture_test.dart`: Rive types allowed in `avatar/presentation/` and `core/design/rive/`** · export the orb through the avatar barrel |
| D3 | Brand colour | **Scene-adaptive accent over neutral ink** · one fixed accent (e.g. warm amber) · keep cyan/magenta |
| D4 | Light theme | **No, dark only in 4.0** · yes (doubles golden/contrast work) |
| D5 | Customize sheet + Live voice mode | **Customize in 4.0 (cheap), Live mode after 4.0** · both in · neither |
| D6 | Markdown package | **`flutter_markdown_plus`** (check maintenance when adding) · custom minimal renderer |
| D7 | Fonts | **Bundle two families (I'll shortlist in M1)** · keep Outfit + Plus Jakarta Sans, bundled |

## 10. What I did not verify

- I read the code but did not run or screenshot the app. Findings about *how it looks* (V1, V2,
  contrast) come from reading the styling code; M1 should start with real screenshots of today's
  screens on Android and macOS as the baseline.
- Frame times and the cost of the 8 blur sites are unmeasured. M0 should add a baseline
  measurement on the throttled emulator before any change.
- `speech_to_text` input-level callback support differs per platform (STT is disabled on
  macOS/Linux in this app today); the orb needs a fallback pulse where no level arrives.
