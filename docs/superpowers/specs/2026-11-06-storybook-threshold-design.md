# The Storybook Threshold — design (contract v15)

Date: 2026-11-06
Status: approved concept (door replaced), design finalized
Replaces: the `door` journey family in `assets/rive/journeys/journey.riv` (contract v10/v11)

## Why

The door transition (66 of 90 journeys) is the weakest animation on the stage:

- its leaf "opens" by a mirrored scaleX flip around the far hinge edge (`gen_journeys.py:218`) — it
  reads as the slab flattening, not swinging away;
- the lit opening sits past the portrait frame edge (the M7 review itself: "the door's 'open'
  column reads as a slab of light at the frame edge");
- nothing lives beyond it: the portal has a swirling core and sparks, the rocket flame and smoke —
  the door opens onto a static radial gradient;
- no anticipation, no follow-through: appear → flip → flip back → vanish.

The owner chose to **replace** the metaphor, not repair it.

## What replaces it

A **standing pop-up storybook** on the threshold line, spine (gutter) at artboard x 640 — the
existing clip line, so `ThresholdClipper`, the walk-through semantics and every beat of
`JourneyPhase` survive unchanged.

- **Right page block** (gutter → past the frame edge, like the old door frame): the *static*
  occluder. It covers x ≥ 640 from y 200 to the ground **at every instant**, closed or mid-swing
  (a stronger guarantee than the door's, whose open-state coverage relied on the light slab).
- **Front cover**: hinged at the spine. Closed, it lies on the block (we see its outer face,
  leather, with an embossed **destination medallion**); open, it has swung left, foreshortened,
  into the visible portrait band (x ≈ 260–640). The swing is a true foreshortened rotation —
  projected width compresses around the in-frame hinge, outer/inner faces crossfade at the
  edge-on moment — never a mirrored flip.
- **Pop-up vignette**: paper-cut silhouette layers unfolding from the gutter **on top of the
  opened cover**, tinted by the destination's `lightKey` / `lightAmbient` (already bound), plus
  a small per-destination emblem group (10 groups, 2–5 shapes each). A light shaft, drifting
  motes and a widening floor spill complete it.
  - **Exit side shows the destination; arrival side shows the origin** — the book carries you,
    and on arrival its pages still hold a paper-cut memory of where you were, folding away as it
    closes.
- **Ribbon bookmark** replaces the peg: draped over the right block's top edge, tail hanging at
  the contract hook point (628, 560) — exactly where the avatar's `grab`/`hang` contacts fire.
  The jacket hangs from the ribbon tail (`JourneyVM.jacket`, unchanged semantics). The tail
  sways with the cover's motion (converter-driven rotation from `open`).

## Motion design (what makes it premium)

Principles: anticipation, overlapping action, mass contrast, secondary motion, a close that is
choreographed — not a reverse — and continuity across the cut.

### Open (exit side)

| t | Move | Ease / feel |
|---|---|---|
| 0–300 ms | **Appear**: the closed book fades and grows in (`show`, as today) | easeOut; the medallion is legible at rest |
| 300–390 ms | **Crack**: a sliver of warm light at the gutter; the covers jitter once, as if pushed from inside | slow start of the `open` ramp (piecewise curve) |
| 390–1010 ms | **Swing**: the front cover rotates around the spine into the left band; projected width compresses then grows leftward; the ribbon tail lifts with it | heavy `easeInOutCubic` — the cover has mass |
| ~850 ms | **Riffle**: three page flaps flip spine-ward, staggered (clamp windows of `unfold`), paper foley | light and fast — mass contrast with the cover |
| 950–1350 ms | **Unfold**: vignette panels rise from the gutter with overshoot, staggered tallest-first; motes and shaft fade in; the floor spill widens | springy `easeOutBack` per panel, staggered |
| 1400 ms (settle) | Glow breathes, motes rise (ambient loop `amb_journey`, seamless at 240 frames) | continuous life, like the portal's swirl |

### Close (not a reverse)

| t | Move |
|---|---|
| 0–200 ms | **Fold**: the vignette snaps flat (fast `easeOut`), riffle flaps flutter shut — pages before cover, reverse-staggered |
| 200–580 ms | **Fall**: the cover swings shut under gravity (`easeIn`), the ribbon tail whips out of the way; **paper** foley at the flutter, **click** at the land |
| 580–640 ms | **Land**: a 60 ms rebound (the tail of the app's ramp curve), a scatter of motes from the closing edge, the glow snuffs to a sliver |

Arrival mirrors the open (`arriveHold` then the same staged curve), with the **origin** vignette.
`vanish` fades the book out (300 ms, as today).

### Curves and where they live

- The app owns the eases: `JourneyChoreography` ramps `open` and `unfold` with **piecewise custom
  curves** (crack slow → swing heavy; riffle fast → panels springy), exactly as it ramps `show` /
  `lift` today. The file stays history-free.
- Stagger *inside* one number comes from clamp-windowed formula converters (`F.fn min/max`, the
  rocket-flame precedent in `gen_journeys.py:409-419`): flap *i* and panel *j* each move only
  within their window of `unfold`.
- The ambient loop (glow breath, mote drift, sparkle) extends today's `amb_journey` tracks. M12
  lessons apply and are satisfied: one artboard (eases resolve in it), no copy-opacity posing.

### Sound

App-timed, beat-relative, epoch-cancelled, behind the sound-effects setting — no new WAV kinds
(`paper`, `click`, `cloth` all exist):

- **paper** at the riffle (~840 ms into the open beat) and at the arrival riffle;
- **click** at the cover's land (~640 ms into the close beat);
- **cloth** at the grab/hang contacts (unchanged, contact-driven).

## View model (contract v15)

`JourneyVM` changes:

| Property | Type | Change |
|---|---|---|
| `book` | number | **new** (replaces `door`): 0–1, how much of the book shows |
| `unfold` | number | **new**: 0–1, the riffle + vignette + shaft + spill staging |
| `destLivingRoom` … `destDeepSpace` | number ×10 | **new**: which destination vignette (and medallion) is erected; exactly one nonzero, the family-number pattern |
| `open` | number | re-pointed: the cover swing (crack lives in its early window) |
| `lift` | number | rocket only, unchanged |
| `jacket` | number | unchanged; hangs on the ribbon tail at the same hook point |
| `lightKey` / `lightAmbient` | color | unchanged; tint the vignette's lit/shadow sides |

Budget: 22 KB today; estimated 50–60 KB built; the 160 KB cap holds.

## Dart changes

- `JourneyFamily.door` → `JourneyFamily.book` (rename ripple: planner, choreography, layer,
  contract mirror, tests, wow-harness expectations).
- `JourneyFrame` gains `unfold` and `destination` (the `AvatarScene` whose vignette is erected:
  `to` before the cut, `from` from the cut on — `journey.sceneNow`'s complement).
- `JourneyTiming` (locked): `open` 450 → **1400** ms (appear 0–300, crack 300–390, swing
  390–1010, riffle from 850, panels 950–1350, settle 1400), `close` 350 → **640** ms (fold
  0–200, fall 200–580, rebound 580–640; click at 580), `arriveOpen` → **1000** ms (hold 120,
  swing 120–570, riffle 470, panels 560–980); `closeOf`/`arriveOpenOf` updated for `book`.
  Net journey length grows ≈ 1.7 s; the walks still dominate.
- `JourneyLayer._write`: writes `book`, `unfold`, the ten `dest*` numbers (one nonzero),
  unchanged `open`/`lift`/`jacket`/lights. No new binding code — `setNumber` covers it.
- `AvatarCubit`: beat delays follow the new timings; three epoch-guarded foley hooks
  (open-riffle, close-land, arrive-riffle) through `FoleyService`.
- Reduce motion: untouched (cross-fade cut, no threshold). Tier behaviour: untouched (one
  artboard at every tier, like today). Camera: untouched (journey holds wide — the M7 gate
  stands).

## Gates and evidence

- `review_journey.py` re-aimed at the book: nothing at zero; family isolation (book included);
  **band coverage ≥ 85% at open 0 *and* open 1** (the static block — stronger than the door's
  gate); `open`/`unfold` change pixels in the left band; riffle-before-panels window check; dest
  isolation (each of the ten erects alone); rocket gates unchanged; loop seam 0%.
- `check_contract.py`: the v15 journey table (new props) parsed and mirrored in
  `avatar_rive_contract.dart`; the 160 KB cap re-checked.
- `rive_gates.py` journey gates run by `frive.sh` (unchanged wiring).
- Wow re-captures: `WOW=wow3` (door journey → book) and `WOW=tour` (its first leg); harness
  gate text expects family `book`.
- Evidence index: `rive/review/book-threshold/README.md` (strips, sheet, gates, wows) — post-M12
  work gets its own directory, not a moonshot milestone.

## Out of scope (YAGNI)

- Mini-dioramas inside the vignette (emblems + tinted layers give the glimpse).
- 3D nodes or skinned page bend (multi-flap stagger reads as a bow at this size).
- New foley samples; camera moves during journeys; tier branching; a second render target.
- Touching the path / portal / rocket families.
