# M5 Task 2: the faired 3/4 face (ruling 1)

Rendered by `uv run --with pillow rive/tools/review_face.py yaw_sweep <M4 avatar.rml>` (real CLI
renders of `rive/avatar`; the M4 file is `git show c56d83c:rive/avatar/avatar.rml`).

| File | What |
|---|---|
| `yaw_sweep_campfire.png` | campfire rig: neutral / happy / jaw open × yaw −1, −0.5, 0, 0.5, 1 |
| `yaw_sweep_livingRoom.png` | the same on the livingRoom rig |
| `before_after.png` | M4 vs M5 at yaw −1 / +1, neutral and jaw open (campfire rig) |
| `yaw_sweep.gif` | 18 frames yaw −1 → 1 and back (campfire, neutral) |
| `gates.txt` | posed-bone gates (pytest's numbers) and the rendered dent depths, M4 vs M5 |

Method (`rive/tools/head_turn.py`):

- **Caps:** `SECTION_BACK_N` ≤ 2.6 (M4: 2.8 / 4.0 / 3.4 at y 428 / 458 / 476), `FAR_FLAT` ≤ 0.2
  (M4: 0.237 / 0.326 at y 428 / 458).
- **Fairing** (`fair_contour`): the yaw +1 poses of the 17 contour bones in chain order
  (FTL … Chin … FTR) are pushed out to their convex hull (x only: yaw moves the bones' x, pitch
  and the jaw their y), then Laplacian steps on the bones' yaw *displacement* (so the rest
  outline's own curvature is kept) at every bone that breaks a gate, until every turn lies in
  [−bound, −4°] at the main pose and the whole grid (yaw +1 / +0.5 × pitch −1/0/1 × jaw 0/1) is
  convex within its bound (1.25 × the unturned outline's largest turn at that pitch / jaw).
  Yaw −1 is the mirror. Rest poses are untouched (rest render vs M4: 0 of 800,000 px differ).
- **Nose:** the far tip lands 2 px past the faired far contour (`nose_tip_travel`: 35.4 / 38.3 px
  extra at yaw −1 / +1, M4 13 / 19; the faired far cheek no longer dips in to meet it).
- **Mouth:** width = mean `foreshorten` of the lip line (0.866 at ±1, M4 a flat 0.88), rebound in
  the M5 id range (1,000,000+; the old chain is deleted, no surviving id moves).

Numbers (`gates.txt`):

- posed bones, yaw +1: M4 not convex (a +54.4° dent under the far lens), largest turn 55.0°;
  M5 convex, 26.8° (bound 32.5° = 1.25 × 26.0°). All 24 grid cells convex within their bounds
  (worst: pitch −1 jaw 1, 37.0° vs 45.7°; least bend −0.5°).
- rendered face silhouette, deepest dent below the hairline: M4 19.1–20.7 px at yaw ±1, 3–4 px at
  ±0.5; M5 ≤ 1.1 px everywhere (the rest pose's own antialiasing is 0.9–1.1 px).
- avatar.riv 563,612 → 563,594 B.

Self-check (ruling 11, one Sonnet pass over the sheets, the GIF frames and `gates.txt`): no
objective defect in any M5 cell; no pop across the 18 sweep frames; the nose tip sits on the far
contour. It flagged a pale line just outside the back hair on the livingRoom rig, present at yaw 0
too: the M4 `RimHair` band (not touched here; the light silhouette gate is re-run in Task 7).

Known limits: the temple vertices (y 330, under the side locks) keep a skinning kink between the
crown and contour bones (as in M4, hidden by the hair); the near jaw angle now moves 14 px with the
turn (M3 held it within 6) because the chin's swing is spread up the jaw line; the nose line at
yaw ±1 rides the far contour, so its shade swings further (45 % follow, unchanged).
