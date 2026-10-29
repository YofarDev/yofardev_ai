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

## avatar head turn (2.5D, M1)

28 October 2026 (`moonshot/m1`). Independent critics: a fresh agent per round, given renders and
the rubric only. Gate 8.5 (art bible). From round 5 the head is the shipped avatar's own art with
a yaw/pitch rig (`rive/tools/head_turn.py`); from round 6 it is judged as the app drives it
(`app_turn.gif`, rendered from `tool/head_motion_trace.dart`). Evidence:
`rive/avatar/review/head_rig/`; regenerate with `uv run rive/tools/review_avatar_turn.py`.

| Round | Score | Subject | Main remaining issues |
|---|---:|---|---|
| M0 | 6.7 | spike head | static sweep, no 3/4 structure |
| 1–3 | 7.6 / 7.8 / 7.9 | standalone head v2 | rim bands outside the silhouette, nose/mouth parallax, identity drift |
| 4 | 7.6 | head v2 with avatar identity | face and eyes still not the same person |
| 5 | 7.5 | rig on the shipped head | mouth escaping the chin, far-lens grey, temple spike, rigid hair |
| 6 | 7.8 | app-driven (solver v1) | eye lead invisible, no vertical gaze, dead holds |
| 7 | 8.1 | + eyeLeadPitch, tip-weighted hair | reading too small, gaze unleads, idle invisible |
| 8 | 8.4 | solver round 3 | sleepy caret look, far side lock over the face |
| 9 | **8.5 PASS** | final tuning | see below |

Open after round 9 (for the M4–M6 presence work):
1. The look-down lid line slopes toward the nose and reads slightly stern; keep it parallel to the
   lower lid, thin it to the 3 px interior weight, cap the drop at about 18 %.
2. The chin turns into a hard V at negative pitch and high yaw; move the handles with the vertex
   and keep a minimum jaw corner radius.
3. A hard-edged forehead highlight band shows under the fringe when looking down; feather it or
   clip it under the fringe shadow.
4. The eyes freeze for about 0.8 s on the caret hold and idle drift is faint at phone size; add
   micro-saccades during holds over 400 ms and a blink on large gaze changes.
5. The back hair domes out past the near side at the deep glance (1.3× lag); drop it to about
   1.0× or clamp it to the head silhouette, and soften the nose-highlight streak at high yaw.

## avatar face and speech (M2)

28 October 2026 (`claude/moonshot-m2-579044`). Independent critics: a fresh opus agent per round,
given only the evidence, the art-bible rubric and the brief. Gate (M2 plan ruling 12): face ≥ 9.0
and speech ≥ 9.0, at most 6 rounds. Evidence: `rive/avatar/review/face/` (AU solo, moods, visemes,
yaw sheet, and for three macOS `say` sentences a 15 fps strip and a timing chart of every number
the app writes); regenerate with `tool/face_speech_trace_test.dart` + `uv run rive/tools/review_face.py`.

| Round | Face | Speech | Main issues |
|---|---:|---:|---|
| 1 | 7.3 | 6.5 | no f/v detected; missed and weak p/b/m closures; the jaw snaps shut into seals; under-articulated mouth; one breath, a short question tilt, faint nods, brow beats that read as surprise; droop/squint strokes spill past the eye over the glasses; brows buried under the fringe; thinking mouth a dark blob; far blush spills past the cheek at yaw ±1; cool frame black |
| 2 | 7.3 | 7.5 | p/b/m count now right, holds clean, blinks in pauses; still: sad and angry alike (brow ends under the centre spike, sad eyes startled), scratchy lid strokes (scaled nodes thin their strokes), doubled/peaked lower lid on cheek raise, open vowels read as grins (lip line keeps its smile with the jaw), mauve interiors (half-transparent lower teeth), f/v and s too subtle, first "M" of a phrase open, breaths peak on onsets, beats too small, far lens past the silhouette at yaw ±1 |
| 3 | 7.3 | 7.5 | brows read over the fringe, lids clean, f/v and seals detected; still: the centre spike tip pops under raised brows, happy eyes read pained (dark lower-lid arc, open upper lid), angry brows too level, surprised mouth a smile, f/v a white teeth pill without the lower lip, sad visemes wince, the first breath starts with the audio, brow beats a repeating plateau, small question tilt and nods, the closed-blink lash zig-zags |
| 4 | 7.7 | 7.5 | sad and angry now read from the brows, seals and blinks reliable, breath leads the line; still: surprised eyes jam the frames, the happy lower lid a grey wavy band, angry eyes and mouth under-built, the sad lid a straight bar, mouth AUs alike at phone size, oh/ou pops for 2–3 frames, dead holds on long vowels, prosody faint outside happy, the question release snaps, the breath holds into the first words |
| 5 | 7.6 | 7.7 | angry reads, surprised fits the frames, the jaw follows loudness, no oh/ou pops; still: happy eyes not a true crescent, sad and embarrassed weaker than v4 (flat mouths), a peaked frown apex, raised brows meet the fringe tips, a flat 3/4 turn (far lens past the head, mouth lags the nose), blink shapes break over the smile and sad lids, f/v vs s/n/th still alike, boxy rounded vowels that grin in a happy mood, sawtooth brow beats, nods too small |
| 6 | **7.9** | **7.6** | rounded vowels round, blinks close cleanly, sad and sheepish frown; still: see the open items below |

**Gate not met** (≥ 9.0 on both; M2 plan ruling 12 caps the loop at 6 rounds). Trajectory: face
7.3 → 7.9, speech 6.5 → 7.6. The remaining critiques are structural rather than tuning, so they
are logged here for the next slice instead of being chased further in M2:

Face:
1. Lids do not occlude: the happy squint and the lid-tighten line sit over an iris that still
   shows below them (doubled lower lid). A real crescent needs the iris and white clipped by a
   moving lid shape (eye rebuilt on lid bones), not a skin crescent laid on top.
2. The 3/4 turn slides the features over a symmetric outline: the far lens overhangs the cheek,
   the jaw and cheek contour do not change (head-turn work, M4–M6 presence; see the M1 list
   above).
3. There are no asymmetric AUs (left and right brows, a one-sided lip corner), so thinking and
   embarrassed lean on gaze and accents. A per-side AU split is a contract change.
4. Off-model details: the nose-wrinkle scribble, pucker drawn as an open "o" rather than pushed
   lips, the lower-lash gap and faceted eye-white corners, and angry needing its mark.

Speech:
5. f/v is not distinct from s/n at phone size: it needs the lower lip as a pink band over the
   teeth edge, not a shifted line.
6. The audio classifier mislabels rounded vowels ("blue", "so", "view" read as ih/aa). It needs
   text-informed phoneme alignment, or Kokoro's phoneme durations (the `SpeechTimeline` seam is
   ready).
7. The beats are correctly timed but uniform: varied nod depth, left/right brow offsets and
   eased rebounds would need asymmetric AUs and a little noise.
8. The blink is a cross-fade of lash strokes, not a lid sweep. Plosives have no compression or
   release pop; the upper-teeth edge has a V notch; the interior colour is banded.

## avatar face and speech (M3)

29 October 2026 (`claude/moonshot-m3-42d35b`). Same method and gate as M2 (M3 plan ruling 9):
a fresh independent opus critic per round, given only the evidence, the art-bible rubric and the
brief (Wow #1 without the firelight); face ≥ 9.0 and speech ≥ 9.0, at most 6 rounds. Evidence adds
the per-side AU sheet, the f/v–s–th–pp sheet at phone size, the blink strip, the outlined yaw sheet
and seven text-aligned speech traces (the three M2 sentences plus the four `test/fixtures/speech`
WAVs, one in French). Regenerate with `tool/face_speech_trace_test.dart` +
`uv run rive/tools/review_face.py`. Round 1's critic was harsher than M2's last (it scored the
same structural areas M2 left open lower), so the M2 and M3 numbers are not on one scale.

| Round | Face | Speech | Main issues |
|---|---:|---:|---|
| 1 | 6.8 | 6.5 | lids occlude, f/v reads at phone size, closures land and hold, blinks fall in pauses, per-side AUs behave; still: the jaw drop leaves the chin in place (open mouths clipped by the face, kissing the jawline), a thick faceted lip ring on the rounded shapes only, hard fringe spikes and brows crossing them, iris stubs mid-blink, cheekRaise closes the eye, noseWrinkle and dimpler invisible, pp ≈ sil and kk ≈ aa; no settle at the full stop (the mouth snaps shut then freezes), a 200 ms gasp of a breath with the lips re-closing before the audio, a question brow no bigger than a stress, metronomic square nods and plateau brows, double lip outlines in cross-fades, no pre-rounding or oh→ou glide, th without tongue in speech, one-frame jaw spikes. Evidence bugs: strips unlabelled, audio lane empty on 16 kHz WAVs |
| 2 | 6.8 | 6.6 | the chin drops with the jaw, one lip rim, settle and idle after the stop, the 350 ms breath, the held question tilt, blinks in pauses; still: heavy square glasses dominate the face, surprised and AU5 barely read, happy upper lid drops (sleepy), the rounded fringe reads as drips, lipTuck ≈ lipPress, chin arcs and a brow band read as marks, a lavender far-cheek patch and a floating ear at yaw −1, a dead blink; f/v passes through a closed bar (the new tuck gate closes it at low jaw), lips still closed before speech, rounded vowels late (s stretch carries into "so", "jour" spread), the hair rides the skull (the trace writes no hair follow-through), stress brows on every word, gaze drifts on the question, sad visemes collapse, one-frame releases |
| 3 | 7.2 | 6.9 | the inhale with parted lips matches the storyboard, the question beat (brows on the pitch, tilt, held wait), f/v reads at phone size, closures land in all seven sentences including French; still: forehead creases always on (read as wrinkles), fang-like mouth interiors and boxy oh/ou, th/dd/kk/nn alike, mouth contour as heavy as the silhouette, untapered lash ends, the 3/4 turn slides features (chin moves 26 px, nose never breaks the far cheek, near ear through the hair), angry reads sulky, pointed fringe tips, weak lipTuck/noseWrinkle/dimpler, kissing lines at the lens rim; she under-articulates (small jaw peaks, sad a slit), lipPress plateaus between bilabials (dark blobs), the mid-sentence catch-breath pops the shoulders in 66 ms, a one-frame press onset on "Bonjour", ou a dot at phone size, th not detected on "The", uniform nods (down-nod on the question), faint hair lag |
| 4 | 7.2 | 7.2 | speech acting and timing 8.0: closures lead every burst (pre-voice "b" included), f/v tucks merge across "of five", the inhale lands 350 ms early, the question tilt is held as a wait, moods survive the visemes, rounded vowels hold; still: the yaw ±1 face breaks (straight near cheek, a near-90° chin corner, a notch under the lens, the nose tip floating off the contour, an unforeshortened mouth), mouths read as heavy-outlined stickers and oh/ou as rubber rings, happy's lower lid a flat edge across the iris, angry brows without the inner pinch, ch/ss teeth without lip mass, lipTuck ≈ lipPress again, a light seam at yaw; speech mumbled (written jaw peaks 0.6–0.7 but a median of 0.09–0.12 while speaking: consonants collapse it), teeth-band visemes alike, small uniform nods, a slow brow rise and linear decay per phrase (sad flat), hair yaw nearly flat, thin idle, a toothy inhale, a late "mm" after the settle, one pair of blinks 1.85 s apart |

**Stopped by the owner after round 4** (gate not met: face 7.2, speech 7.2 against ≥ 9.0). Trajectory
face 6.8 → 6.8 → 7.2 → 7.2, speech 6.5 → 6.6 → 6.9 → 7.2. Round 4's fixes were not started; its
issues above are the open list (top: the yaw ±1 shape, the jaw collapsing between vowels, mouth
construction). Critics disagreed across rounds on the fringe tips and the brow beat density.

## M4 self-checks (ruling 17: one line per asset or acting change, no critic rounds)

- 2026-10-29 · Task 1 key decimation · avatar.riv 607,684 → 545,036 B · objective check: no pops, clipping or broken shapes in the before/after captures; edge shifts are sub-pixel (worst gesture frame 0.27 % px > 16/255 at 360 px, the walk-in 1.6 %), walk-in starts on the same frame as v6 · evidence `rive/review/m4/budget/`.
- 2026-10-29 · Task 4 avatar light rig (v7) · avatar.riv 545,036 → 550,960 B · objective check: no light outside the silhouette (12 renders), history-free (≤ 1/255 bar one 2/255 gradient pixel), no flicker seam; fixed: a torso-outline rim that crossed the hood (dropped) · evidence `rive/review/m4/light/`
- 2026-10-29 · Task 6 campfire diorama · campfire.riv 163,509 → 166,786 B, poster 19,042 B · objective check: no revealed edge at the 9 parallax corners (opaque frame, edge strips; travel measured 40/28/20/6 px), events intact, lint clean, firelight seam 0/255; fixed: veil 0 dimmed the moon (now starts below it), fog at the colour's own alpha did not read (4 stacked fills) · evidence `rive/review/m4/campfire/`.
- 2026-10-29 · Task 5 tablet prop · avatar.riv 550,960 → 563,612 B · objective check: no pops at the four Review Focus 1 interruptions (largest step ≤ the plain clips'), hold seam 1/255, IK ≤ 1.23 px, no elbow flip, hands on the slab in 6 wardrobe / lean variants; fixed: forearm sleeves over the screen, a two-way elbow bend in the pull-out, the put-away settle showing the hand, the caught hand sliding 3 px · evidence `rive/review/m4/tablet/`
- 2026-10-29 · Task 10 Wow #1 and #2 re-shoots · no asset size change (evidence only) · objective check: 13 captures non-empty and centred on the scene, no crop cut at wide/medium, the campfire rig equals `art_bible.SCENES`, flicker and parallax GIFs show change; fixed (tool): the thinking bubble clipped by the 1.3x crop · evidence `rive/review/m4/wow/` (`wow1_campfire_rain.png`, `wow2_tokyo_weather.png`, `flicker.gif`, `parallax_sweep.gif`), index `rive/review/m4/README.md`

## M5 self-checks (ruling 11: one line per asset or acting change, no critic rounds)

- 2026-10-29 · Task 2 faired 3/4 face · avatar.riv 563,612 → 563,594 B · objective check (Sonnet, sheets + 18 GIF frames + gates): no defect in any M5 cell, no pop across the sweep, nose tip on the far contour; flagged (not this task): a pale `RimHair` line beside the back hair on the livingRoom rig at every yaw, re-checked by Task 7's silhouette gate · evidence `rive/review/m5/head/`
