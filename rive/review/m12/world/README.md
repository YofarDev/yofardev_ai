# M12 ruling 9: whole-world contact sheets (for the defect pass)

Made by `uv run --with pillow --with numpy rive/tools/review_world.py`. It uses review_diorama's `Renderer` /
`FrontRenderer` and review_tiers' `over`. The renders are CLI renders of the built RML at
`--viewport=1080x1920 --fit=contain`, frame 91 (`--advance=91`), after lane Q's changes (working tree on top of
`3220b26`).

**Layout.** Each scene has two sheets: `<sceneId>_ultra.webp` and `<sceneId>_low.webp`. Each sheet has three
cells per row, every cell 540 x 960 (half size), with a yellow label in its top-left corner.

## The cells

| cell | the data written | notes |
|---|---|---|
| `rest` | the v14 defaults | No world clock, so this is the storybook night every scene is drawn in. |
| `rain 1` | `rain` 1 | Ultra: `SceneFront`, alpha-composited over the scene, where the scene has one (campfire, beach, rooftop, forestCabin). Low: the back alone, labelled `(no SceneFront at low)`, because the app never creates the front at low. |
| `night 1` | `night` 1 | What the world clock writes at night, (1 − daylight) × (1 − dusk). Only beach binds it. |
| `noon (daylight 1)` | `daylight` 1 | |
| `dusk 1, daylight 0.4` | `daylight` 0.4, `dusk` 1 | |
| `festive` | `festive` 1 | |
| `spring 1` / `autumn 1` | `spring` 1 / `autumn` 1 | |

A cell appears only when the scene binds that member. The tool reads the bindings from the built RML: a SceneVM
member that some bind references.

**What is not shown:**
- No NPC states. Those are in `rive/review/m12/polish/npc_states_q.webp` and `rive/review/m8–m11` `npc/`.
- No drags, events or moon phases.
- No `fog`.
- The beach gulls are `away` at the defaults, so they do not appear in the beach sheets.

## The sheets

| scene | cells (ultra and low alike) | ultra / low bytes |
|---|---|---|
| livingRoom | rest, rain 1, noon, dusk, festive, spring 1, autumn 1 | 127,866 / 129,174 |
| campfire | rest, rain 1 + SceneFront, noon, dusk, spring 1, autumn 1 | 99,084 / 92,808 |
| beach | rest, rain 1 + SceneFront, night 1, noon, dusk | 105,032 / 102,098 (lane P2: the pole at night) |
| deepSpace | rest, rain 1 (deepSpace ignores rain, and binds neither time of day nor festive) | 21,296 / 21,750 |
| cafe | rest, rain 1, noon, dusk, festive | 102,296 / 101,978 |
| rooftop | rest, rain 1 + SceneFront, noon, dusk | 73,126 / 66,596 |
| mountainHut | rest, rain 1, noon, dusk, festive | 106,690 / 105,418 |
| forestCabin | rest, rain 1 + SceneFront, noon, dusk, festive, spring 1, autumn 1 | 175,592 / 165,582 (lane P2: the birches) |
| trainCompartment | rest, rain 1, noon, dusk, spring 1, autumn 1 | 110,890 / 109,678 |
| library | rest, rain 1, noon, dusk, festive | 140,270 / 124,626 |

All 20 sheets are WebP at quality 80, each ≤ 300 KB (2.1 MB in all).

## Known notes, not defects to re-report

These are kept by earlier rulings:
- deepSpace's 3 px band step;
- the beach palm as a silhouette at night 1;
- the rooftop vent and pot plant staying dark at noon;
- the M9–M11 notes in `rive/CRITIC_ITERATIONS.md`.

What the low tier hides per scene is listed in `rive/review/m11/tiers/gates.txt` and `rive/review/m12/bench/`.
