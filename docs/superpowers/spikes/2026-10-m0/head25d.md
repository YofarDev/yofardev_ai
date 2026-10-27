# M0 Task 4: skinned 2.5D head prototype

Question: can the illustrated 2D avatar head turn into a 3/4 view (yaw ±30°, pitch ±15°) by
skinned vector deformation, authored entirely as Python → RML → Rive CLI (no editor, no
raster), at an acceptable quality, file size and frame cost?

Short answer: **technically yes; size-feasible for the head only; no runtime failure
observed, but the cost of animating yaw/pitch is unmeasured.** The rig is continuous,
history-free and renders correctly on the pinned runtime on both tiers. The device numbers
cover one static pose only. They are timeline-tail P95s (see the caveat under Device cost).
Rive's CPU work is inside `build` (Task 7 atrace on the emulator), but its GPU execution is not
observed, and the emulator raster P95 is dominated by noise. Per-frame cost while yaw/pitch change (88
binds re-evaluated, 371 vertices re-skinned) was not measured. Visual quality: the
independent critic scored it below the 8.5 bar (next line).

Critic score: **6.7/10** (visual 7.1, animation 6.3): **no-go against the 8.5 bar as
prototyped**. Blockers: static crown and silhouette, no 3/4 outline structure, and a linear
sweep with no secondary motion. See [head25d-critic.md](head25d-critic.md).

Implementer's own read (not the critic): at ±30° the yaw reads as a believable 3/4 turn in
stills and moves smoothly; the weakest points are the static cranium/hair crown (the turn lives
in the face, fringe, ears and jaw), pitch that reads as features sliding inside a mostly fixed
outline, and no new planes on the near side. I would not expect it to clear an 8.5 bar for
"exceptional professional work" as is; it is a credible base, not finished art.

Sources: `rive/spikes/head25d/gen_head25d.py` (generator, writes `head.rml`),
`rive/spikes/head25d/measure_head25d.py` (CLI checks, sheet, sweep, GIF, sizes),
asset `assets/rive/spikes/head25d.riv`, harness case `head25d` in
`integration_test/spikes/spike_cases.dart`. Evidence: `head25d/grid.png` (3×3 contact sheet),
`head25d/sweep.gif` (yaw −1→1→−1, then pitch −1→1→−1). Rive CLI 1.8.0; runtime `rive`
0.14.11 / `rive_native` 0.1.11.

```bash
uv run rive/spikes/head25d/gen_head25d.py && rive rive/spikes/head25d --verify --format=json
uv run rive/spikes/head25d/measure_head25d.py   # ~40 s; results in rive/spikes/head25d/build/measure/results.json
```

## Interface

- Artboard `Head` (400×480), state machine `Main` (one empty layer: it only exists so binds
  run), view model `HeadVM` with numbers `yaw` and `pitch`, each clamped to −1..1 inside the
  formulas. ±1 = ±30° yaw (positive turns the face to the viewer's right) and ±15° pitch
  (positive looks up).
- Default instance: **yaw = 0.6, pitch = 0.3** (deliberately non-neutral: the device harness
  binds the default instance and cannot change it per frame, so the on-device cost is that of a
  turned, deformed pose). The authored bone positions are the neutral pose.

## Rig design

**Skeleton.** `Neck` (RootBone, base of the neck, pointing up, length 200) → `Head` (Bone,
length 175) → 44 face-plane `RootBone`s nested in `Head` (legal: `rive docs rigging`).
`Neck` and `Head` are never animated in this prototype; they carry the static parts
(cranium silhouette, back hair, neck, collar) and would carry a whole-head tilt/bob later.

**Driving the bones: data binds, not blend states.** Each face bone is a point of a simple 3D
head model (cranium ellipsoid 108×150×100 px above the pivot, a widened elliptic cylinder
below it so the jaw and chin have depth in front of the yaw axis). Its local `x`/`y`
(propertyKey 90/91) are bound to `pitch`/`yaw` through a `DataConverterGroup`:

1. a shared `YawAngle` / `PitchAngle` formula: `a = k · min(1, max(−1, input))`;
2. the bone's own `DataConverterFormula`: `c0 + c1·cos(a) + c2·sin(a)`, i.e. the exact
   projection of the rotated 3D point (material point (X, Z): `dx = X(cos a − 1) + Z sin a`;
   pitch: `dy = Y(cos a − 1) − Z sin a`). Silhouette bones use
   `side·(√(w²cos²a + d²sin²a) − w) + z0·sin a` (the edge of an elliptic cross-section
   rather than a material point, so the outline does not shrink like a material point would).

The formula parser honours `*` over `+` precedence and evaluates exactly as computed in
Python (CLI check: a test bone landed at the predicted pixel for 5 inputs, clamp included).
`DataConverterFormula`, `DataConverterGroup` and sin/cos/sqrt exist in the runtime source
(`rive_native-0.1.11/runtime/src/data_bind/converters/`). No scripting is involved (scripts
do not run on the device runtime, Task 3).

Yaw and pitch are **separable** (yaw only moves bone x, pitch only bone y). The true combined
rotation couples them (pitch shift should scale by cos of the yawed longitude): error ≤ 1 −
cos 30° ≈ 13 % of the pitch shift at the corners of the grid. Not visible at ±15° pitch.

**Bone families and weights** (all weights are 8-bit, summing to exactly 255, at most 4 bones
per vertex; cubic vertices carry `CubicWeight` with the in/out handles weighted at the handle
positions):

| family | bones | weighted parts | falloff |
|---|---|---|---|
| surface grid | 35 `G<c>_<r>`: X ∈ {−105, −70, −35, 0, 35, 70, 105}, Y ∈ {−120, −60, 0, 60, 120} px around the pivot (400, 370) | eyes (lash, crease, lids, white, iris, pupil, shines), brows, mouth, mole, blush, hair-shadow band, fringe locks, side locks, hairline edge of the hair cap | tent (bilinear) in screen distance to the 4 surrounding bones: ≤ 4 bones/vertex |
| silhouette | `JawL/R`, `ChinL/R`, `Chin` + `Head` | face outline, chin's cast shadow on the neck | angular tent about (400, 400) between neighbouring outline bones; above the cheeks `Head` only: ≤ 2 bones/vertex |
| nose | `NoseBridge` (Z = surface + 12), `NoseTip` (Z = surface + 30) | nose line, light, shade | linear in y between the two: ≤ 2 |
| ears | `EarL/R` (Z = −15, behind the yaw axis) | ear + inner ear | rigid (1) |
| static | `Head` / `Neck` | crown edge of the hair cap, back hair / neck, collar | rigid (1) |

Why the falloff works: displacement is linear in the weights, so tent weights reproduce the
smooth 3D displacement field between bones. Max |interpolated − exact model| screen-x shift at
yaw = 1 (Python, 2 px raster over each region): mouth 2.5 px, brows 6.4, eyes 6.5, blush 8.9,
10 px worst on the lower cheek near the outline where the model's depth falls off steeply. The
error is smooth (it bends the model, it does not tear the art); a denser grid lowers it. The **far eye compresses by itself**: its inner corner sits on a bone that moves
more than the one at its outer corner. The **far ear hides by itself**: it moves inward
(Z < 0) by 22 px while the side lock in front of it stays near the silhouette, and the near ear
moves out from under its side lock (Z(lock) > Z(ear)). Gradients are left in place (lighting
stays fixed in the world), so iris/hair gradients are vertical only.

Counts (`rive inspect --summary`): 46 bones (44 face RootBones + `Neck` + `Head`), 88 data binds,
178 converters (2 shared angles, 88 formulas, 88 groups), 371 path vertices (346 cubic, 25
straight) in 59 skinned shapes, 382 tendons. Step 1 check: `--verify` exit 0, 0 problems;
`rive inspect` reports no `weight-without-bone` (its only finding is the editor-only
`artboard-without-style` warning).

## Blend intermediates (open question from Task 3)

Finding: **a `BlendState1DViewModel` does not interpolate; it converges, over a few frames, to
a biased fixed point.** Measured on `rive/spikes/cap/blend2d` (square at x = 50 for input 0,
x = 200 for input 1, expected linear centre 50 + 150·t):

| x input | advance 1 | advance 2 | advance 3 | ≥ 5 (settled) | linear |
|---|---|---|---|---|---|
| 0.25 | 87.5 | 94.5 | 96.0 | 96.0 | 87.5 |
| 0.5 | 125.0 | 143.5 | 148.5 | 150.0 | 125.0 |
| 0.75 | 162.5 | 183.5 | 187.5 | 188.5 | 162.5 |
| 0 / 1 | 50 / 200 | same | same | same | 50 / 200 |

The settled values match exactly a model in which each blend animation is mixed onto the
**current** property value (`v ← lerp(v, A, 1−t)`, then `v ← lerp(v, B, t)`), with nothing
resetting the property between frames: fixed point `v = 0.25 v + 112.5 → 150` at t = 0.5,
96.15 at 0.25, 188.46 at 0.75. Frame 0 looks right only because the authored value equals the
first animation's key. So intermediate blend poses are **biased toward the last animation and
lag a moving input** (exponential smoothing per frame); endpoints are exact, which is why
Task 3's ✅ at (1, 1) held.

Workaround (verified, CLI): a layer **below** the blend that plays an animation keying the rest
value every frame. With it, 0.25/0.5/0.75 give exactly 87.5/125/162.5 at every advance
(1, 2, 10, 61). This also likely affects the shipped avatar's `Mouth` blend (5 animations, no
reset layer): worth checking separately (not in this task's scope; nothing changed there).

Choice for the head: the continuous formula binds above. They are exact (sin/cos, not a
linear blend between key poses), history-free (pose at `--advance=1` and `--advance=40` for
yaw 0.37 / pitch −0.42: **0 differing pixels**), need no animations at all, and a single CLI
frame shows the settled pose, which makes per-frame `--data` sweeps valid.

## 3×3 grid: visual pass criteria

`head25d/grid.png`: rows pitch +1 / 0 / −1, columns yaw −1 / 0 / +1. Each criterion is scored
from pixels of the actual CLI renders by `measure_head25d.py`, using check variants of the same
file (`gen_head25d.py --variant …` hides parts or tints the ears magenta) at every pose:

- (a) feature pixels (eyes, brows, nose, mouth, mole drawn alone) outside the face mask (face
  drawn alone, fill + stroke);
- (b) eye-white bounding-box width, each eye drawn alone;
- (c) magenta ear pixels left in the full composite / ear pixels drawn alone, per side.

| pose (yaw, pitch) | (a) feature px outside face | (b) far / near eye width | (c) far ear visible | near ear visible | result |
|---|---|---|---|---|---|
| (−1, +1) | 0 | 38 / 65 = 0.585 | 0.0 % | 62.1 % | pass |
| (0, +1) | 0 | 58 / 58 | n/a (L 42.8 % / R 42.8 %) | n/a | pass (a) |
| (+1, +1) | 0 | 38 / 65 = 0.585 | 0.0 % | 62.1 % | pass |
| (−1, 0) | 0 | 38 / 65 = 0.585 | 0.0 % | 56.4 % | pass |
| (0, 0) | 0 | 58 / 58 | n/a (L 40.3 % / R 40.3 %) | n/a | pass (a) |
| (+1, 0) | 0 | 38 / 65 = 0.585 | 0.0 % | 56.4 % | pass |
| (−1, −1) | 0 | 38 / 65 = 0.585 | 0.0 % | 50.5 % | pass |
| (0, −1) | 0 | 58 / 58 | n/a (L 39.4 % / R 38.5 %) | n/a | pass (a) |
| (+1, −1) | 0 | 38 / 65 = 0.585 | 0.0 % | 50.6 % | pass |

- (a) **pass, 9/9**: no feature pixel leaves the face. The tightest spot is the far eye's outer
  lash at |yaw| = 1 (visibly close to the outline in the sheet, but inside).
- (b) **pass, 6/6** at |yaw| = 1: far eye 0.585 × the near eye (the same eye on the 3D model, corners at
  longitudes 10°/40°, would give 0.297 / 0.516 = 0.58).
- (c) **pass, 6/6**: the far ear is fully hidden (0 %) behind the side lock and the face; the
  near ear is revealed (51–62 % visible vs 39–43 % at yaw 0). Pass threshold used: far ≤ 5 %.
  Strictly, "the hair occludes" is shared: the ear slides behind the face outline and the far
  side lock covers what still sticks out.

## Sweep

Yaw −1 → 1 in 60 frames, pitch 0. Each frame is one `render_sequence(project, dir, 1,
{"yaw": v, "pitch": "0"})` call (frame 0 of its own CLI run; valid because the pose is
history-free, see above). Scored with `motion_metrics.score(frames, rest)`, rest = yaw 0 /
pitch 0. Also a 30-frame pitch sweep −1 → 1.

| sweep | pops (criterion: 0) | per-frame diff min / median / max | jerk vs rest | jerk vs frame 0 |
|---|---|---|---|---|
| yaw, 60 frames | **0** | 0.00696 / 0.00710 / 0.00728 | 746,035 | 2,204,638 |
| pitch, 30 frames | **0** | | 713,775 | 2,104,409 |

**Pass**: 0 pops, but that criterion is nearly vacuous here. `pops` only counts a diff above
both 4 × median and the 0.01 floor, and every diff in this sweep is ≈ 0.007, under the floor.
The real smoothness evidence is the spread: the frame-to-frame change stays within ±2.3 % over
the whole sweep (0.00696–0.00728), so a linear input gives near-linear motion with no snaps and
no plateaus. `seam` (9.2) is meaningless
for a one-way sweep. The centroid jerk is noisy for this kind of motion (the "changed pixels"
region grows from nothing, so its centroid jumps; vs rest it also flips side at yaw 0) and is
reported for completeness only. For scale only (not like-for-like): the shipped wave gesture
scored jerk 3,444,343 and 2 pops in Task 2.

## Size

| file | bytes | KiB |
|---|---|---|
| `head25d.riv` (rigged, shipped asset) | 49,928 | 48.8 |
| same art, bones + binds, no weights | 29,859 | 29.2 |
| same art, no rig at all | 17,939 | 17.5 |
| `assets/rive/avatar.riv` (today) | 493,462 | 481.9 |

So the rig costs **11,920 B fixed** (46 bones, 88 binds, 178 converters, VM; 29,859 − 17,939)
plus **54.1 B per weighted vertex** ((49,928 − 29,859) / 371). (A first version with one
self-contained formula per bind, the clamp repeated inside each, was 60,905 B; the shared
angle converter saved 11 KB.)

Extrapolation to the avatar (5,707 path vertices in `rive/avatar/avatar.rml`: head 1,095;
torso / tops 1,167 + 75 loose; hands 2 × 1,145 incl. 5 skin variants × poses; sleeves 1,080),
assuming every vertex of a region needs weights (every wardrobe/skin variant drawn there does)
and one fixed rig the size of this head's per region:

- **Head only**: 1,095 × 54.1 = 59,233 + 11,920 = 71,153 B → 493,462 + 71,153 = 564,615 B =
  **551.4 KiB** of the 600 KiB budget (48.6 KiB headroom). Fits.
- **Head + torso + hands**: (1,095 + 1,242 + 2,290) = 4,627 × 54.1 = 250,295 + 4 × 11,920
  = 297,975 B → 791,437 B = **772.9 KiB**, **173 KiB over** budget.
- Everything (5,707 vertices): 308,716 + 47,680 → 849,858 B = 829.9 KiB.

Not counted: extra art a turned body may need (back-of-head hair, side planes of hands), and
any second view of features. Cheaper weights (straight vertices, or weights shared across
skin variants) would be needed before skinning hands; the head alone fits as is.

## Device cost (harness, profile mode, static default pose yaw 0.6 / pitch 0.3)

> † **Timeline caveat** (added in Task 8; source: [tiers.md](tiers.md) § Timeline vs FrameTiming).
> The timeline P95s in this section come from 10 s runs. The VM timeline is a ring buffer, so
> each P95 covers only about the last 4–5 s of frames. Same-run ratios share this bias. These
> numbers were not re-measured: the M1 follow-up is a re-run with `--endless-trace-buffer` or
> with `FrameTiming`. Task 7's atrace (emulator sequence c) also refines the claim that "the
> timeline under-reports Rive": Rive encodes and submits on the UI thread inside build, so
> `build` includes Rive's CPU work. Only its GPU execution is unobserved.

Both runs: all 21 cases passed (`All tests passed`), one run per tier, stale `head25d.*`
and `baseline_avatar.*` cleared first. P95 = nearest rank over the Flutter timeline's frame
lists (`rive/spikes/tools/matrix.py` `p95_ms`), 10 s per case, 400×400 stage.

| tier (renderer) | case | frames | P95 build ms | P95 raster ms |
|---|---|---|---|---|
| macos (skia) | baseline_avatar | 312 | 1.71 | 0.61 |
| macos (skia) | **head25d** | 225 | 0.23 | 0.83 |
| emu (impeller, OpenGLES per logcat) | baseline_avatar | 287 | 7.84 | 18.05 |
| emu (impeller) | **head25d** | 293 | 0.95 | 20.15 |

Same-run deltas, head25d vs baseline_avatar:

- macos: build −1.48 ms (0.13×), raster **+0.22 ms (1.36×)**.
- emu: build −6.89 ms (0.12×), raster **+2.10 ms (1.12×)**.

Read with care:

- **Not like-for-like.** The avatar animates every frame (breath, blink, cape) and has its full
  state machine; the head holds one static pose (no animation; the view model never changes
  after it is bound). The lower build time is that, not a rig win. The raster figure is
  the comparable one: the deformed head (59 skinned paths, 371 weighted vertices) costs about
  what the whole avatar costs to draw, within the noise.
- Emulator noise dominates: in the same run `skin` (one bent bar) reads 19.96 ms raster P95 and
  `skin_stress` (20 of them) 5.12 ms. Never extrapolate these to a device tier.
- `rive_native` draws Rive into its own surfaces (Task 3: `ImageReader` on Android), so the
  Flutter timeline under-reports Rive's own GPU work on both tiers (Task 3 "Frame cost
  cross-check"); gfxinfo framestats is unusable here (Task 3).
- Per-frame cost of **animating** yaw/pitch (88 formula re-evaluations + re-skinning 371
  vertices per frame) is not measured by this harness.
- Device images (`build/spikes/<tier>/head25d.png`) were viewed on both tiers: the head is drawn
  turned right and looking up (the default yaw 0.6 / pitch 0.3), identical between tiers, so
  formula converters, converter groups, nested root bones and skinning all run on the pinned
  runtime with both renderers.
- The emulator was not running at the start of this task; the same AVD the emu tier used
  (`Medium_Phone`, android-37.2) was booted with default options, nothing reconfigured.

## Limits

- **Static cranium.** The cranium silhouette, hair crown and back hair do not move (a sphere's
  outline is rotation invariant), so the turn is read from the face, fringe, ears and jaw. At
  ±30° this reads as a 3/4 turn; beyond ~35° the far features would need occlusion (the far
  eye would have to slide *behind* the cheek, which skinning cannot do without a clip or a
  swap) and the back of the head would need real art.
- **No new silhouette art.** The near side of the face does not gain a cheekbone/temple plane;
  ears are rigid (a real near ear would widen as it turns toward the viewer).
- **Lighting is fixed** (gradients do not deform), which is right for world lighting but means
  shading never wraps around the turning face.
- **Yaw/pitch are separable** (see rig design): fine at ±15° pitch.
- **Pitch reads weaker than yaw**: features slide inside a mostly static outline; only the chin
  and jaw move with it.
- The device harness measures one static pose; it does not measure 88 binds re-evaluating every
  frame while yaw/pitch animate (Task 5's harness hook that writes VM numbers per frame would).
- Emulator numbers are not a device tier (constraints); physical tiers not run.
- Not merged with the shipped avatar: this is a standalone head with the avatar's palette and
  shapes; mood/blink/viseme animations were not combined with the rig.
