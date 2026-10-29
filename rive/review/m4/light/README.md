# M4 Task 4: the avatar binds the scene light rig (contract v7)

Rendered by `uv run rive/tools/review_face.py light` (real CLI renders of `rive/avatar`, the
AvatarVM light numbers written exactly as `SceneLights.of(scene)` / `art_bible.SCENES`).

| File | What |
|---|---|
| `light_sheet.png` | 4 scene rigs (rows: livingRoom, campfire, beach, deepSpace) × neutral / happy × yaw −1 / 0 / 1, flicker 0 |
| `flicker_strip.png` | campfire rig, full flicker: 10 frames, every 12 frames across one 2 s loop |
| `flicker.gif` | the same, 60 frames at 30 fps (2 s, one loop) |
| `lean_wardrobe_check.png` | campfire rig: lean 0, lean 1, sunglasses + beanie at yaw 0.7, batman |
| `gates.txt` | history, flicker seam and silhouette gates (all ok) |

What the file does (`rive/tools/avatar_light.py`, minted in the M4 id range):

- **Rim**: copies of the face outline (skinned to the same turn bones, so it follows yaw/pitch/jaw)
  and of the back-hair silhouette, stroked and clipped by their silhouettes: an interior band
  (3 bible px past the ink's inner half). Linear gradient: clear on the key side, `lightRim` at
  the far side (endpoints ±150 px × `lightKeyX/Y`), gradient opacity = `lightRimIntensity`.
- **KeyCheek**: radial `lightKey` pool, screen blend, face-clipped, centred 0.35 face widths toward
  the key from the cheek line, opacity 0.45 × `lightKeyIntensity`, inside the `Firelight` node.
- **AmbientWash**: face-clipped multiply wash, `lightAmbient` on the far side, opacity
  0.5 × `lightAmbientAmount`.
- **Glints**: the four lens glints (glasses, sunglasses) take `lightKey`, slide 6 px toward the key,
  each inside a `FirelightGlare<n>` node.
- **Flicker**: `Firelight` SM layer, 1D VM blend on `lightFlicker`: `light_steady` (opacity 1) ↔
  `light_flicker` (harmonics 3/5/7 of the 120-frame loop, 0.62–1.0; the loop ends meet exactly).
- **lean**: the body tips about the shoulder line (scale 1 + 0.02 lean ≈ a 3.2° tip, sink 3 px) and
  the head drops; net face-centre drop 7.8 px at lean 1.

Gates (`gates.txt`):
- history: each rig reached from livingRoom and from another rig + lean 1 + yaw 1 — max 1/255, or
  no more noisy pixels than a control pair with the same lean/yaw history (deepSpace: one pixel at
  2/255 on the cheek wash, a gradient ramp re-quantised; accepted as renderer noise);
- flicker seam: frame 61 vs 781 (six loops; every idle loop back in phase) — the same 2 noisy
  pixels as the flicker-0 control pair, so the loop adds no seam or drift;
- silhouette: rig on vs every light number 0, 4 rigs × yaw −1/0/1 — 0 lit pixels outside the
  painted avatar.

Self-check (ruling 17, objective defects only):
- fixed: the planned torso-outline rim drew blue lines across the hood (the TORSO outline is not
  the body's silhouette: sleeves cover its sides, the hood/collar its shoulder line) — dropped;
- fixed (tool): history captures must write the same number of mid-run `--data` keys (each costs
  the CLI one frame), else the idle breath shifts the whole body;
- no clipping, no light outside the silhouette, no pop at the loop seam, no broken shapes with
  hats, sunglasses, costumes, lean or the 3/4 turn.

Known limits: the KeyCheek pool is subtle on the already bright skin (screen blend at the plan's
0.45); hands get no ambient wash (each hand pose would need its own clipped wash); the campfire
scene itself does not bind its light rig yet (Task 6).
