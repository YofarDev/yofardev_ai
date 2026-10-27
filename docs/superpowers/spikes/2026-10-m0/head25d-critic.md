# Critic review: skinned 2.5D head (M0 Task 4)

Independent, read-only review of `rive/spikes/head25d` under the method in
`rive/CRITIC_ITERATIONS.md`: I judged actual renders and playback. Visual design and
animation have equal weight, 10 means exceptional professional work, and I did not round
any score up. I formed this read from the renders before opening `head25d.md`.

## Scores

| | score |
|---|---:|
| Visual design | **7.1** |
| Animation | **6.3** |
| **Overall** | **6.7** |

**No-go** against the 8.5 bar. The existing avatar art scored 8.51–8.82 under this rubric.
This head's neutral pose is close to that level, but the turned poses and the motion are not.
They read as a well-engineered face layer sliding over a rigid head, not as a head turning in
space.

## What works

- **The yaw extremes read as clean 3/4 views in stills** (grid, yaw ±1 at every pitch). The
  far eye compresses in a believable way (about 0.58 of the near eye), the iris and lid
  compress with it, and the far blush runs off the cheek. The far ear tucks away without a pop
  and the near ear comes out from under its side lock. The far eye stays inside the outline
  at ±30°, though only just.
- **The jaw and chin really turn.** The chin travels along the turn and the jaw outline goes
  asymmetric. The chin's cast shadow on the neck follows it. This is the strongest single cue in
  the rig.
- **The motion is mechanically perfect.** I rendered 41 frames of yaw −1→1 at pitch 0.6.
  Frame-to-frame mean differences were 2.52–2.61 (8-bit luma), rising monotonically without a
  spike. The GIF shows the same spread (2.7–3.0) apart from the documented assembly cut. There
  are no layer-order flips, tears, lock overlaps that snap, or plateaus. The rig is
  history-free and exact, which makes it a sound base for driving.
- **Pitch is better than its own doc says.** Source pitch frames 000/007/015/022/029 show the
  chin dropping and the face lengthening when looking down. When looking up, the chin rises,
  the face rounds and the neck lengthens. The fringe covers more of the eyes when looking down.
  It reads in motion.
- **The art stays clean in every pose.** Line weight holds, the cubic paths do not kink, and
  the eye rendering (lash mass, iris gradient, two highlights) is on par with the shipped avatar.

## What blocks a higher score (ranked by impact)

1. **The hair crown and outer silhouette are static: in motion the face slides on a balloon.**
   Across the whole yaw sweep (`r/yaw_sheet.png`, all nine yaw values) the outer hair contour
   and side masses do not change. So does the dark back-hair shape. Only the fringe and the
   hairline edge move. Stills hide this, but playback exposes it immediately. It is the single
   biggest "2.5D tell". It also leaves a seam: at yaw +1 the hairline edge (skinned) and the
   crown edge (static) stack into doubled, parallel strand outlines near the right temple
   (`r/ext.png`, right).
   *Fix:* skin the crown and back hair to the head model too. Give the crown locks material
   points on the cranium ellipsoid and let the parting line and lock contours travel with yaw,
   at about 60–70 % of the face displacement, since they sit behind the face plane. Shift the
   side masses: the near side mass narrows and the far side widens, because more of the back
   of the head shows on the side the face turns away from. Keep the outline rotation-invariant
   only where it truly is: the top of the crown.

2. **The face outline has no 3/4 structure.** At ±1 the contour is still a symmetric egg,
   only shifted (`r/ext.png`). The far side lacks the anime 3/4 landmarks: the cheekbone bump
   under the far eye, the slight inward step at the eye socket and temple, and the nose tip
   approaching or breaking the far contour. The near side lacks a jaw-angle plane. The nose
   stays a frontal line plus hook that just translates.
   *Fix:* add silhouette bones at the far cheekbone and temple with their own depth (a convex
   cheek ellipse, not one elliptic cross-section). Blend them in with |yaw| so the far contour
   gains a cheek bulge and socket notch at ±1. Give the nose a separate tip shape whose
   silhouette crosses toward the far cheek line at |yaw| = 1. Add a near-side jaw-angle vertex
   that sharpens with |yaw|.

3. **There is no performance in the turn: the playback is a linear mechanical sweep.** The
   per-frame change is constant from end to end, with no ease-in/out, no settle, no arc and no
   secondary motion. The hair has no lag or overshoot, the eyes do not lead the head, there is
   no blink on a large turn, and no roll is coupled with yaw. A premium VTuber-grade head turn
   comes from these cues far more than from projection accuracy.
   *Fix:* the rig is history-free, which suits a driver layer. Add a `yawTarget` input and
   spring the actual `yaw` toward it (critically damped, about 0.25–0.35 s). Drive gaze ahead of
   the head (eyes reach the target about 80 ms earlier), trigger a blink when |Δyaw| > 0.5,
   and add a small roll (about 2–3° toward the turn) and a slight dip in the arc mid-turn.
   Give the fringe, side locks and crown a velocity-driven lag (a second-order follower on
   d(yaw)/dt) so the hair trails and settles.

4. **The forehead shading reads as stripes.** The pink hair-shadow band, the brow-crease
   lines and the double-lid lines stack into horizontal bands across the forehead. They are
   most visible at pitch +1 and mid-yaw (`r/zoom.png`). It reads more like a headband or a
   sunburn line than a soft cast shadow, and it widens with yaw, which flattens the forehead.
   *Fix:* cut the band's alpha and feather it (a radial or vertically faded gradient that
   follows the fringe's lower edge, not a flat strip). Drop the crease line that runs above
   the brow, and clip the band to the fringe's shadow footprint so it moves with the locks.

5. **Pitch moves features inside a mostly fixed head.** The chin and jaw respond, but the
   ears do not move vertically. The crown does not reveal or hide the forehead plane, and no
   under-chin plane appears when looking up. The mouth curve and the eye lid shapes do not
   change with pitch (looking down should flatten the upper lid arc and curve the mouth
   downward on the sphere).
   *Fix:* give the ears a pitch term opposite to the features (up when looking down, down when
   looking up). Bend the lid and mouth curves with pitch: they are surface curves on the
   sphere, so add a vertex-level y-term that follows cos(longitude). When looking up, reveal
   an under-jaw shade shape whose height grows with positive pitch.

6. **The ears and mouth are rigid.** The near ear does not widen as it rotates toward the
   viewer, and the mouth does not foreshorten: at yaw 0.5 it is still the frontal symmetric
   smile (`r/zoom.png`, left).
   *Fix:* skin the ear to two bones (front and back edge at different depths) so its width
   follows yaw. Put the mouth on the surface-grid weights with its corners on separate bones,
   so the far corner compresses and the curve wraps around the muzzle.

Minor: the yaw-0 pose already reads slightly turned. The nose is drawn 3/4-style, the fringe
part is asymmetric and the mole is on one side, so in small thumbnails the pitch-only GIF frames
looked yawed until I checked them against the source frames. It is a character-design choice,
but it reduces the readable contrast between "front" and "turned".

## Verdict

Engineering-wise this is a strong spike: an exact, smooth, pop-free rig at about 49 KB. As art
and animation it is a competent base at about 6.7. Blockers 1–3 are the gap to 8.5. A turn
reads as premium only when the whole head (hair mass and outline) participates and the motion
is performed (ease, lead, lag, blink), not swept linearly. On the evidence, fixing only
blockers 4–6 would land around 7.3–7.5.

## Evidence I looked at

- `docs/superpowers/spikes/2026-10-m0/head25d/grid.png`: the full 3×3 sheet.
- `head25d/sweep.gif`: all 178 frames measured (frame diffs), and frames 0, 7, 15, …, 177
  (24 evenly spaced) viewed as a sheet. I also viewed frames 116–119 (around the cut, not
  penalised) and 125, 133, 140, 147, 148, 155, 162, 170, 177 (pitch segment).
- Source pitch frames `rive/spikes/head25d/build/measure/sweep_pitch/{000,007,015,022,029}`
  at full resolution, to rule out a GIF artefact after the thumbnails looked yawed.
- My own CLI renders (scratch, not committed; the `r/…` names above refer to them, and
  `rive rive/spikes/head25d --screenshot=… --advance=1 --data=yaw=… --data=pitch=…`
  reproduces each one): yaw ∈ {−1, −0.75, …, 1} at pitch 0 (sheet and
  a 2× enlargement of ±1); pitch ∈ {−1, −0.5, 0, 0.5, 1} at yaw 0; zooms of yaw 0.5 and
  pitch +1. I also rendered a 41-frame yaw sweep at pitch 0.6 for the smoothness numbers.
- `rive rive/avatar --advance=1` (the shipped avatar) for the style and quality bar.
- `head25d.md`, read only after forming the scores above. Its limits section agrees with
  blockers 1, 2 and 5, and I scored independently of its self-assessment.
