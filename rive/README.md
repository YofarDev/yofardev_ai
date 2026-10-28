# Rive sources (Plan A)

Everything in `assets/rive/` is generated from here with the Rive CLI only. Don't edit the `.riv` files by hand.

Art direction, independent playback critiques and current acceptance status are
recorded in [CRITIC_ITERATIONS.md](CRITIC_ITERATIONS.md).

```bash
./scripts/frive.sh              # regenerate RML, build every .riv, check budgets + contract
./scripts/frive.sh beach        # avatar + UI kit + only the named scenes (and their posters)
uv run --with pillow rive/tools/review_ui_kit.py   # UI kit contact sheets + behavioural proofs
```

| Path | What it is |
|---|---|
| `CONTRACT.md` | Names shared with the app. Changes go in their own `contract: …` commit. |
| `CHANGELOG.md` | One line per milestone (A0–A7). |
| `tools/gen_avatar.py` + `tools/avatar_kit.py` | Avatar generator → `avatar/avatar.rml` |
| `tools/gen_scenes.py` | Scene generator → `scenes/<sceneId>/<sceneId>.rml` |
| `tools/scene_art.py` + `tools/wardrobe_art.py` | Vector material details and secondary motion |
| `tools/review.py`, `motion_review.py`, `wardrobe_review.py` | Rendered visual evidence and loop checks |
| `tools/gen_ui_kit.py` | UI kit generator → `ui_kit/ui_kit.rml` (ComposerOrb, StatusGlow, ToolIcon, Toggle, Mark) |
| `tools/review_ui_kit.py` | UI kit contact sheets and proofs → `ui_kit/review/` (sheets + `proof.txt`) |
| `tools/gen_posters.py` | Scene posters → `assets/rive/posters/<sceneId>.webp` |
| `tools/rml.py` | Tiny RML builder (deterministic ids) |
| `tools/check_contract.py` | Self-check: `rive inspect` + built bytes vs `CONTRACT.md` |
| `tools/sheet.py` | Dev helper: labelled contact sheet of headless captures |
| `tools/rig_dsl.py` | Rig DSL: formula bone drives, skin weights, skinned paths, baked springs (`perform_turn`) |
| `tools/gen_head.py` | 2.5D head v2 generator → `head/head.rml` (artboards `Head`, `PerformedTurn`) |
| `tools/review_head.py` | Head evidence → `head/review/` (yaw × pitch grid, zooms, turn GIF, `metrics.txt`) |

The generated `.rml` files are committed so diffs show what changed; `build/` is ignored.

How the avatar is wired: every state-machine layer keys its own nodes (`HeadMood`, `HeadPhase`, `HeadLook`,
`HeadGesture`, `GazeM/P/G`, …), so mood, phase, gestures, blinking and eye-follow add up instead of fighting.
Wardrobe items are `Solo` switches. The Costume layer comes after Hat/Top/Glasses and overrides them while
a costume is on. Its `none` state keys nothing, which hands control back.

How the UI kit is wired: no listeners or events (the app owns taps). Each element has its own pose layer
(`Mic`, `Arrow`, `Stop`, `Dots`, `Listen`, `Disc`, …) with one static pose per enum value; transitions
between poses carry cubic interpolators (overshoot on the way in, quick ease-in on the way out), so any
state can follow any other without a pop. Every transition has a `reduceMotion` twin of ≤ 110 ms, and
ambient loops sit in gate layers whose conditions include `reduceMotion == false`. Colours are
`SolidColor` binds to the artboard's view-model colours; StatusGlow and the Mark halo use feathered
fills because a gradient stop bound to a colour loses its alpha for a frame on every colour change.
