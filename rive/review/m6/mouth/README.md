# M6 Task 8: the M3 mouth list, objective gates only (ruling 13, execution ruling 27)

Both gates were measured on the M5 avatar before any change; a gate M5 already passes means there
is nothing objective to fix, so nothing was changed and `avatar.riv` stays 574,335 B.

| Gate | Measure | M5 value | Verdict |
|---|---|---|---|
| (a) "sticker" mouth line | closed-mouth line width vs the face's silhouette line, from `face_rig.py` (`MOUTH_INK` vs `SILHOUETTE_ART`) | 1.56 / 2.6 art px = 0.6× (≤ 0.6×) | passes: dropped (M3 round 3e already thinned it from 2.7) |
| (b) tuck ≠ press | `rive rive/avatar --data=autoBlink=false --advance=30`, `lipTuck 1` vs `auLipPress 1` at `auJawDrop` 0.1 (the f/v speech jaw): mean abs difference over the mouth box, and bright (upper-teeth) pixels | 38.5/255 (≥ 12); bright px tuck 97, press 54, rest 62 | passes: dropped |

Recorded, not fixed: at a fully shut jaw (`auJawDrop` 0) tuck and press differ by only 8.1/255
(a rolled-in thin line vs a pressed firm line: `TUCK = min(1, 3 lipTuck, 30 jaw)` is 0 there by
design, M3 round 2c). Whether the speech pipeline ever writes a tuck on a shut jaw was not
measured. Crops (rest | tuck | press, 4× nearest): [jaw 0](rest_tuck_press_jaw0.png),
[jaw 0.1](rest_tuck_press_jaw0.1.png).
