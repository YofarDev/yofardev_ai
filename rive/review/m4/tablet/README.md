# M4 Task 5: the tablet prop (`prop` = tablet)

Rendered by `uv run --with pillow python rive/tools/motion_review.py --tablet` (real CLI renders of
`rive/avatar`, head at the director's reading target `yaw` 0.6 / `pitch` −0.5, `autoBlink` off).

| File | What |
|---|---|
| `out_sheet.png` | `prop_tablet_out`, 10 frames (0–28) |
| `hold_sheet.png` | `prop_tablet_hold`, 10 frames across the 2 s loop |
| `away_sheet.png` | `prop_tablet_away`, 10 frames (0–25), started from the hold |
| `out_hold_away.gif` | out → hold → away, every 2nd frame at 30 fps (real time) |
| `interrupt_*.png` | Review Focus 1: `short_tool` (prop back to none at out frame 10), `back_early` / `back_late` (tablet again at away frame 6 / 17), `gesture_under_away` (a wave started with the put-away) |
| `gates.txt` | hold seam, pop gate, IK check |

What the file does (`rive/tools/avatar_tablet.py`, M4 id range after the light rig):

- **Art**: a 280 × 190 slab (corner 38 = 0.2 of the short side; screen corner 0.185), dark bezel
  with a 1.4 px rim, a 9 px back edge, and an `emitScreen` gradient with generated glyphs (search
  bar, sun + temperature card, a periodic result list under its own clip, a diagonal sheen). It is
  authored flat and projected exactly by two nodes (`TabletPlane` rotation + scale over
  `TabletFace` rotation = the SVD of the slab tipped back 48°, turned 16° toward the face, rolled
  −7°), so the screen faces the eyes and still shows to the viewer. It hangs in
  `BreathShoulderLPivot`, behind both arms and in front of the head and torso: it rides the torso,
  `breath` and `lean` with the hand targets. Colours lint clean (`art_bible.fit_colour`; the screen
  subtree is `emit*`): 605 hits before and after.
- **Hands**: the `edge` pose closes on the two side edges; every frame the wrist sits 52 px behind
  its grip along the fingers, the targets, chain lengths, art scales and `invertDirection` keyed
  through `arm_rig.gesture_tracks` (as the gestures). Elbows hang at the sides, forearms point at
  the camera (fs2 0.36 / 0.25).
- **`prop_tablet_out`** (28 f, 467 ms): the left hand reaches to the hip and lifts
  (`motion_synth.action`: 18 % anticipation, 12 % overshoot, 220 ms settle); the slab hangs from it
  by its edge and swings up into the reading angle one part offset later; the right hand follows
  40 ms behind (`motion_synth.stagger`) and closes on the left edge.
- **`prop_tablet_hold`** (120 f loop): a slow tilt and tip, a thumb flick at 0.73–0.97 s that
  scrolls the result list by exactly one item (seamless) and rocks the left hand 4 px.
- **`prop_tablet_away`** (25 f, 417 ms): the right hand lets go, 40 ms later the left lifts a little
  and drops the slab past the hip; the arms are in the exact rest pose from frame 12, the slab
  hidden below the frame.
- **`ScreenGlow`**: a cool radial pool (screen blend) under the chin, clipped by the face (follows
  the turn), opacity 0 → 0.55 in out, 0.52–0.55 in hold (dips with the scroll), 0 by away frame 12;
  `ScreenReflectL/R` in both lenses of both glasses sets (0 → 0.6).
- **Layer `Prop`** (right after `Gesture`): none (`prop_none`, no keys: gestures win) → out
  (prop = tablet, 100 ms blend) → hold (exit time); out / hold → away (prop = none, 120 ms); away →
  out (tablet again after 55 % of the put-away, 160 ms) or → hold (tablet again earlier, 160 ms);
  away → none at its end (120 ms, so a gesture started under the put-away blends in).

Gates (`gates.txt`):
- hold seam: the hold clip alone, its first frame vs its last key: max 1/255 (the scrolled list
  draws like the unscrolled one, the tilt closes);
- pop gate: in every interruption no frame-to-frame change exceeds the largest one of the plain
  out / away clips (+5 %);
- IK (`ik_check` markers, outside the blend windows): rendered hand within 1.23 px of the Python
  solver (elbow 1.08 px), one bend direction per arm per clip (no elbow flip; also unit-tested).

Self-check (ruling 17, objective defects only):
- fixed: the first pose's forearm sleeves covered most of the screen (elbows rode up) — elbows now
  at the sides, forearms foreshortened toward the camera;
- fixed: the left arm bent both ways during the pull-out (the slab's path dragged the wrist across
  the body) — the wrist path is primary, the slab is seated on the hand;
- fixed: the put-away's settle bent the left arm up again and showed the hand at the frame edge —
  both arms are in the rest pose once the main move ends;
- fixed: the caught right hand slid 3 px off the edge in its settle — it stays seated once caught;
- checked: batman, robocop, soubrette, long coat + sunglasses, tank top + beanie, lean 1 + breath 1:
  hands on the slab, no clipping through the body or face, no broken shapes.

Known limits: the tablet draws behind both forearms (one draw slot), so the hands overlap the
screen's side edges from the front; the walk swing (`presence`) would pull the hands off the slab
(the director does not walk while reading); the face glow is subtle on the light skin by design.
