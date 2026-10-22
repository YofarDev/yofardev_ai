# Rive sources (Plan A)

Everything in `assets/rive/` is generated from here with the Rive CLI only. Don't edit the `.riv` files by hand.

```bash
./scripts/frive.sh              # regenerate RML, build every .riv, check budgets + contract
./scripts/frive.sh beach        # avatar + only the named scenes
```

| Path | What it is |
|---|---|
| `CONTRACT.md` | Names shared with the app. Changes go in their own `contract: …` commit. |
| `CHANGELOG.md` | One line per milestone (A0–A7). |
| `tools/gen_avatar.py` + `tools/avatar_kit.py` | Avatar generator → `avatar/avatar.rml` |
| `tools/gen_scenes.py` | Scene generator → `scenes/<sceneId>/<sceneId>.rml` |
| `tools/rml.py` | Tiny RML builder (deterministic ids) |
| `tools/check_contract.py` | Self-check: `rive inspect` + built bytes vs `CONTRACT.md` |
| `tools/sheet.py` | Dev helper: labelled contact sheet of headless captures |

The generated `.rml` files are committed so diffs show what changed; `build/` is ignored.

How the avatar is wired: every state-machine layer keys its own nodes (`HeadMood`, `HeadPhase`, `HeadLook`,
`HeadGesture`, `GazeM/P/G`, …), so mood, phase, gestures, blinking and eye-follow add up instead of fighting.
Wardrobe items are `Solo` switches. The Costume layer comes after Hat/Top/Glasses and overrides them while
a costume is on. Its `none` state keys nothing, which hands control back.
