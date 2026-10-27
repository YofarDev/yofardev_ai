# Avatar and environment art review

24 October 2026. Work continues on `pipeline-optimizations`, starting from
`8579f09`. The requested acceptance target is an independent overall 9/10.
**The target is not yet certified.** Scores describe visual evidence, not builds.

## Review method

A separate, read-only critic reviews actual Rive renders and animation playback,
with dense frame sequences for contact poses, transitions and secondary motion.
Visual design and animation receive equal weight for each of the five assets.
Ten means exceptional professional work. No score is rounded up to meet the goal.

The prior reviewed art was recovered from this chat's saved generator patches
after unrelated repository resets removed uncommitted work. Only Rive sources,
generators, review tools and generated assets were reapplied to the newest branch;
its newer Dart application changes were preserved. The recovered avatar, room,
campfire and space RML matched the frozen `build/critic-next` sources exactly
before further revisions. Beach also includes the later canopy gust and foam.

## Improvements

- Avatar: articulated contact gestures and projected arms; separate gesture
  eyelids; gaze anticipation; asymmetrical laugh and clap beats; delayed hair and
  cloth motion; walking anticipation, shoulder alternation and head settling;
  detailed outfits and restrained singularity eye light.
- Living room: coherent wood, brass and cotton materials; soft lamplight and
  moonlight; anchored curtain deformation; two-link cat legs with stance/recovery
  phases, visible pupils and a gradual head turn.
- Campfire: irregular deforming flame tongues, detached flare embers, rain steam,
  feathered owl with beak, eyelid, wing and tuft acting, and folded tent canvas.
- Beach: a changing wave contour with a curling lip, ballistic spray, staggered
  draining foam, a perched gull's reaction and a delayed canopy gust.
- Space: layered atmospheres and hull materials, secondary particles and softened
  tractor beams. Layer alpha/ranges are staggered to prevent their quantization
  boundaries aligning into horizontal stripes.

The public artboard, state-machine, view-model and event contract is unchanged.
Assets remain vector-only.

## Review history

| Checkpoint | Overall | Evidence |
|---|---:|---|
| Initial detailed art | 8.51 | `build/critic-initial` |
| First revisions | 8.74 | `build/critic-current` |
| Wave, rays and beach accepted | 8.82 | `build/critic-final/REVIEW-CHECKPOINT.md` |
| Newest branch, further laugh/beam/foam revisions | Pending | `build/critic-resumed` |

The prior scores apply to the saved art snapshots; they do not score the older
Rive files that were present in the newest branch before this art was reapplied.

## Verification and limits

- Deterministic generator/build and contract/budget checks pass.
- Five rig regression checks pass; all five assets have unique ordered timeline
  channels.
- `dart fix --apply`: no fixes. `dart format .`: no changes. Analysis is clean.
- The full Flutter test gate remains red: its 71 failing test names exactly match
  the saved pre-existing art-review failure set. Comparison is recorded in
  `build/art-nine/failure-comparison-resumed.json`; full log is
  `build/art-nine/fverify-resumed.log`. This is not a passing full quality gate.
- Fresh native contract/binding checks and loop endpoint results are pending.

Playback is headless-rendered video, not an Android 60 fps performance
certification. Not every wardrobe × gesture × mood combination is covered.
End-to-end TTS lip sync and the current Flutter scene lighting/composition are
outside the certified visual scope. Earlier app-colour-grading observations do
not establish current-branch behavior.

Review media and capture logs are ignored build artifacts. Recreate general
renders and loop checks with `uv run --with pillow python rive/tools/review.py`;
dense avatar motion and wardrobe helpers live alongside that script.

## ui_kit

27 October 2026, M2 (`ui/m2-rive-art`). Self-critique against the brief (premium, storybook-warm,
reads at 48 dp, no clip-art, no neon). Scores are my own reads of the contact sheets in
`rive/ui_kit/review/`, not an independent critic; regenerate with
`uv run --with pillow rive/tools/review_ui_kit.py`.

| Iteration | Score | What I saw | What changed |
|---|---:|---|---|
| 1 | 6.5 | Every state built and bound. Orb: glossy "candy" highlight; listening interior a muddy brown (accent 16 % over plum); at `level` 1 the echo ring clipped on the 96 px edge; idle→typing showed the mic and arrow blurred together for ~3 frames; error dim (62 %) read as a dirty brown disabled button; raw mic levels would jitter the ring. Glow: soft everywhere, but mostly hidden behind a composer pill; waiting drift hard to see. Mark: lenses touching with a blob for a bridge; halo cut by the artboard edge; brown lens tint. Tools and toggle already clean. | — |
| 2 | 7.8 | Echo/pulse inside the frame; level ramps over ~8 frames; listening reads as a hollow lit ring; gloss now a soft sheen; glyph swap is clean (mic gone by 100 ms, arrow pops with overshoot at ~200 ms); error is a shake then a subdued (78 %) disc; glow lobes peek past the pill ends over all four scenes. | Echo 1.15×, pulse 1.05×; `level` through RangeMapper → DataConverterInterpolator (0.14 s); tint 7–22 %; gloss alpha 0x38→0x24; hides 100 ms; error dim 0.78; glow haze 350 px, lobes at ±104 with a ±34 px drift. |
| 3 | 8.4 | Mark: real arched bridge, lenses spaced, halo fully inside the frame (border = backdrop), sparkle sits clear of the frame; glass tint barely there so the halo glows through. Behavioural proofs all green (`review/proof.txt`): loop seams identical (two spins differ only by antialiasing, worst Δ 19/255), every change ends exactly on its rest pose, reduceMotion captures are pixel-still, every colour property reaches its paint. | Mark geometry and halo (150×76, feather 30); seam holds on every looping value; memory twinkle swings back instead of wrapping; review captures run on per-thread project copies (parallel `rive` builds of one dir raced). |
| 4 (coordinator review, StatusGlow) | 8.7 | Reported: stepped concentric rings over livingRoom/campfire and an olive band inside the violet deepSpace glow. Diagnosis: the raw render over black had 0 off-hue pixels and a per-pixel second difference of at most 3/255, so neither defect was in the paint. Both came from the review sheet: it was palette-quantised to 128 colours shared by all four scenes, with no dither. That drew the rings, and it mapped violet (117,100,170) to the palette's grey-olive (91,89,83). The compositing also recovered colour as k/alpha, which shifts hue at low alpha (1,884 off-hue pixels). The art did have one real flaw: two lobes with a dimmer centre (idle 82 → 69 → 81), which read as two lights. | The glow is now one light: core 200×40 with feather 34, lobes 170×50 with feather 40 at ±70 and 30 % opacity, haze 360×72 with feather 50, shimmer 110×28 with feather 26. Every phase has a single peak. Glow sheets are no longer palette-quantised, and the composite is premultiplied (bg·(w−k)/255 + k, no division). New `glow_zoom.png` (3× nearest-neighbour crops) and `glow_profile.txt`: alpha from the top and left edges to the pill rises monotonically in all 12 scene × phase cases; maximum border alpha is 3/255. |

Open points I would still look at on a device: feathered glow cost on a CPU-throttled emulator
(5 feathered ellipses, CLI only proves they are soft), and whether rive_native renders
`DataConverterInterpolator` (the CLI does; if not, the ring follows the raw level).
