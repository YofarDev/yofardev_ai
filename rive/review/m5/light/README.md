# M5 Task 7: firelight reads on the cheek (ruling 7)

Rendered by `uv run --with pillow rive/tools/review_face.py light_m5 <older avatar.rml>` (real CLI
renders of `rive/avatar`; the older file here is the Task 2 commit, M4 light + the M5 head).

| File | What |
|---|---|
| `light_sheet.png` | 4 scene rigs × neutral / happy × yaw −1 / 0 / 1 (flicker 0 stills, as in M4) |
| `flicker_strip.png` | campfire rig, full flicker: 10 frames, every 12 frames across one 2 s loop |
| `flicker.gif` | the same, 60 frames at 30 fps |
| `cheek.txt` | the cheek flicker gate (M5 vs M4) and the tint-on silhouette gate |
| `gates.txt` | the M4 light gates re-run: history, flicker seam, silhouette (all ok) |

What changed (`rive/tools/avatar_light.py`, new elements in the M5 id range 1,000,000+):

- **KeyCheekTint**: the key pool again, `lightKey` multiply-blended, face-clipped, under
  `KeyCheek` inside the `Firelight` node (so the flicker loop drives it), opacity
  `KEY_TINT × lightKeyIntensity × lightFlicker` in one formula converter (history-free).
  `KEY_TINT` = 1.0, not the plan's 0.4 (execution ruling 34).
- **Flicker range** 0.62–1.0 → 0.45–1.0 at `lightFlicker` 1 (the glints follow it too).
- **Pool shape**: both pools are a 150 × 150 circle squashed by `scaleY` 0.8, so the circular
  radial gradient fades to clear at the whole rim (the M4 150 × 120 ellipse cut it at 20 % alpha
  top and bottom: a hard edge inside the face, seen on the flicker-vs-steady difference image).

Gate (`cheek.txt`): box (338, 462, 362, 494) artboard px on the key-side lower cheek; 30 frames
across one loop, each minus the same frame at `lightFlicker` 0 (the idle sway cancels): the mean
cheek colour spans **11.4/255** over the loop (M4: 5.4/255; gate ≥ 10), mostly blue and green
(the cheek turns orange at the flicker's peaks). Light outside the silhouette: 0 px in all 12
flicker-0 cells and in the 3 campfire tint-on cells (yaw −1/0/1, brightest frame).
avatar.riv 563,594 → 563,993 B.

Self-check (ruling 11, one Sonnet pass over the sheet, the strip vs M4's and both gate files): no
objective defect; no pop across the strip; the tint edge is soft; the cheek visibly pulses orange
in M5 and barely in M4. It again flagged a thin stroke just outside the back hair at yaw ±1 on
some rigs: pre-existing (M4 back-hair outline / `RimHair`), not light from this task (0 px outside
the silhouette in every gate).

Known limits: at livingRoom (`lightFlicker` 0.15) the tint is 0.13 at most, barely there by
design; the light sheet's stills are at flicker 0, so they do not show the tint (the strip and
GIF do); with the key low (campfire) the pool sits on the lower cheek and jaw, not under the eye.
