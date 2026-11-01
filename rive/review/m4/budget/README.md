# M4 Task 1: budget headroom by key decimation (ruling 1)

`rive/tools/rml.py` `write()` now runs `decimate_tree` before serialising: every `KeyedProperty`
whose property has a tolerance in `TOLERANCES` (rotation 0.002 rad, x/y and vertex x/y 0.25 px,
scaleX/scaleY/opacity 0.002) has its runs of `linear` keys thinned by Ramer–Douglas–Peucker
(value error at each dropped frame against the line between the kept neighbours). Hold and cubic
keys, the ends of each run and every key of an untoleranced property survive; kept keys keep their
ids. `presence_leaveAndComeBack` is no longer baked: the Presence layer plays walkOut, then walkIn
after an exit time of 1,992 ms (frame 120, as v6's baked copy), then fires `presence_done`
(`leaveAndComeBack`) and settles in the "returned" state.

## Sizes (bytes)

| file | before | after |
|---|---:|---:|
| avatar.riv (budget 614,400; target ≤ 574,000) | 607,684 | **545,036** (−62,648; headroom 69,364) |
| scenes/beach.riv | 201,494 | 199,497 |
| scenes/campfire.riv | 188,961 | 163,201 |
| scenes/deepSpace.riv | 62,649 | 62,117 |
| scenes/livingRoom.riv | 105,518 | 93,562 |
| ui/ui_kit.riv, posters | unchanged | unchanged |

`KeyFrameDouble`s in avatar.rml: 14,098 → 8,133 (1,853 of them were the baked leave-and-come-back).

## Before/after captures

Pre-change RML built in a scratch copy; same `--data`/`--advance` captures at 800×1000, compared per
pixel (max channel difference) at full size and downscaled to the art bible's 360 px phone check.
Gestures: 8 frames each, spread over the clip; presence: every 12 frames of leaveAndComeBack;
scenes: frames 0/90/240/480. Raw numbers per frame: `compare.json`.

| clip | max Δ full | % px > 1/255 full | max Δ 360 | % px > 1/255 360 | % px > 16/255 360 |
|---|---:|---:|---:|---:|---:|
| wave | 67 | 0.77 | 36 | 1.29 | 0.091 |
| laugh | 56 | 0.75 | 21 | 1.23 | 0.003 |
| facepalm | 90 | 1.29 | 38 | 2.24 | 0.268 |
| shrug | 62 | 1.51 | 31 | 2.35 | 0.080 |
| nod | 55 | 0.53 | 30 | 0.91 | 0.050 |
| headshake | 53 | 0.51 | 25 | 1.08 | 0.034 |
| clap | 51 | 0.89 | 28 | 1.45 | 0.040 |
| think | 59 | 1.10 | 28 | 2.03 | 0.080 |
| presence (walk out/in) | 231 | 4.18 | 111 | 8.76 | 1.623 |
| beach / livingRoom | 0 | 0 | 0 | 0 | 0 |
| campfire | 24 | 0.07 | 9 | 0.10 | 0 |
| deepSpace | 29 | 0.06 | 5 | 0.08 | 0 |

(Worst-frame values. `rive --compare` on sample frames: clap f18 2.15 %, wave f51 1.84 %,
facepalm f19 2.69 % of pixels differ, i.e. any non-zero difference.)

**The plan's "≤ 1/255 noise" gate is not met, and cannot be with any non-zero positional
tolerance:** a 0.25 px (or 0.002 rad × lever arm) shift moves anti-aliased edges, which changes edge
pixels by up to ~¼ of the edge contrast. The differences are edge outlines only (see the diff rows
of the strips): no shape, colour, timing or pop changes; rest frames and clip ends are identical
(0). The walk shows the largest numbers because the whole figure moves ~12 px/frame and the body
lean (rotation error ≤ 0.002 rad on a ~600 px lever) shifts the head by up to ~0.6 px. The walk-in
starts on the same frame as before (centroid within 0.5 px at frames 168–216).

Measured alternative (not applied, plan tolerances kept): rotation 0.0005 rad gives avatar.riv
558,049 B (still ≤ 574,000) and removes the walk-in difference (frame 180: 0 % > 16/255), but x/y
0.25 px edge shifts remain (facepalm f19 still 0.18 %). Rotation 0.001 gives 552,067 B.

Strips (rows: before, after, |diff| × 4; header = % px > 16/255 at 360 px):
`gesture_wave_before_after.png`, `gesture_clap_before_after.png`,
`presence_leave_before_after.png`.

## Motion metrics

`rive/tools/motion_metrics.py` (pops, centroid jerk, largest frame step) on every 2nd frame
(30 fps) of clap and of leaveAndComeBack, before → after:

| clip | pops | jerk (px/s³) | max step |
|---|---|---:|---:|
| clap | none → none | 2,313,602 → 2,315,748 (+0.1 %) | 0.0331 → 0.0331 |
| presence | same 46 frames → same 46 frames | 538,214 → 543,320 (+0.9 %) | 0.0573 → 0.0567 |

(The presence "pops" are the metric's artefact on a clip whose median step is 0 while the figure
is off screen; the list is identical before and after, so the chained walkOut → walkIn adds no
pop.) The `motion_review.py --ik-check` was not rerun: it compares the runtime against channels
read from the same (decimated) RML, so it cannot see the decimation error.
