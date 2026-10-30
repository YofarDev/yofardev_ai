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
- 2026-10-29 · Task 3 shared diorama + campfire rain and steam · campfire.riv 166,802 → 227,517 B, poster 19,042 B · objective check (Sonnet, every sheet + gates): no defect (no revealed edge at the 9 corners, zones cover their props, steam soft, streaks full height, no pops); fixed while gating: faint steam (peak 0.8, larger plumes), a lantern reorder that changed 39 dry-tent px, a held saw-tooth reset that lagged the streaks a tile · evidence `rive/review/m5/campfire/`
- 2026-10-29 · Task 7 firelight on the cheek · avatar.riv 563,594 → 563,993 B · objective check (Sonnet, light sheet + flicker strip vs M4 + gates): no light outside the silhouette (15 cells), no pop, soft tint edge, the cheek pulses orange (11.4/255 vs M4 5.4); fixed before the check: the key pools' hard top/bottom edge (ellipse → squashed circle) · evidence `rive/review/m5/light/`
- 2026-10-29 · Task 4 livingRoom diorama · livingRoom.riv 93,886 → 112,599 B, poster 27,144 → 26,524 B · objective check (Sonnet, every sheet + gates + RML): no defect (9 corners opaque, no gap at the window opening or the floor/wall junction, cornice and panel stop at the opening, streaks inside the panes, zones cover their props, cat on its ledge, pool without a hard step); fixed while gating: a missing top streak copy at the loop's end (0.10 % seam), a wet tint as dark as the view (ratio 1.03), `TvFloorSpill`'s hard-edged band · evidence `rive/review/m5/livingRoom/`
- 2026-10-29 · Task 5 beach diorama · beach.riv 199,815 → 256,807 B, poster 32,168 → 31,228 B · objective check (Sonnet, every sheet + gates + own corner renders): no defect (9 corners opaque, sand / wet band / foam continuous, clean horizon seam, no hard veil or glow edge, palm and post bases on the sand, no rain pops, zones cover their props); fixed while gating: a haze band that greyed the whole sea, a key-coloured halo that tinted the sun disc, a dry dune under rain · evidence `rive/review/m5/beach/`
- 2026-10-29 · Task 8 newspaper prop · avatar.riv 563,993 → 574,335 B · objective check (Sonnet, 3 clip sheets + 7 interrupt / hand-over strips + gates): no clipping or pop, hands on the paper in every held frame, newspaper and tablet never visible together; fixed (tool): hand-overs and the gesture case are gated against every clip involved (the gesture-under-put-away arm snap is the shared layer's, equal with the tablet) · evidence `rive/review/m5/newspaper/`
- 2026-10-29 · Task 6 deepSpace diorama · deepSpace.riv 62,435 → 67,089 B, poster 15,632 → 15,032 B · objective check (Sonnet, every sheet + gates + own renders: 9 corners, alienShip at 4 corners over frames 40–530, loop ends 240/600/720/1020): no revealed edge, alpha 255 everywhere, beam on the duck at every corner, no loop pop, zones cover their props; fixed: the mothership beam's hard bottom edge (11.7 → 2.4/255, pre-existing in M4); left: the back ring's butt-capped stub at the planet's limb (M4, unchanged) · evidence `rive/review/m5/deepSpace/`
- 2026-10-29 · Task 11 wow re-shoots (`storyboard_m5.py`) · no asset change · objective check (Sonnet, both sheets + rain_steam and 3 parallax GIFs + gates): no defect (live campfire at rain 1 and livingRoom behind every beat, streaks and steam visible, avatar centred and uncut, no background halo, tablet only in beats 3–4, no frozen/black frame, no revealed parallax edge); fixed while gating: rain_steam.gif at 540 px was 3.17 MB (now 480 px, 2.73 MB); the firelight close-up frame is measured (cheek blue −45.1/255 vs steady, frame 165) · evidence `rive/review/m5/wow/`, index `rive/review/m5/README.md`
- 2026-10-29 · Task 10 emulator check · `Medium_Phone` (API 37, host GPU), profile mode, 10 s per scene with the avatar: build P95 12.6–13.1 ms, raster P95 9.3–9.7 ms, 0–0.5 % of frames over 16.6 ms on all four scenes and campfire at rain 1 (an emulator is not a tier) · tilt: `ParallaxSource` matches its doc but right edge down moves the near planes RIGHT (ruling 10 expects left), left unchanged (the pointer and 3 tests share the sign), decision open · evidence `rive/review/m5/device/`

## M6 self-checks (ruling 14: one line per asset or acting change, no critic rounds)

- 2026-10-30 · Task 2 `SceneFront` (rain in front of the avatar) · campfire.riv 227,517 → 243,975 B, beach.riv 256,807 → 273,016 B, posters unchanged · objective check (Sonnet, both front strips + gates): no seam or hard edge, splashes on the ground line, aligned at both sides; dry front alpha 0, travel ±50 px, loop seam 0 %, `Scene` rest frames pixel-identical to M5.
- 2026-10-30 · Task 6 Wow #1 and #2 played by the macOS app · no asset change (capture of the real app) · objective check (Sonnet, both beat sheets + 12-frame contact sheets of both GIFs + gates): no blank or frozen frame, avatar never cut, tablet out exactly while the tool runs; noted only: the caption cross-fade overprints two sentences for one frame, two evidence crops cut the thinking bubble / leave the tablet below the frame. All 20 behaviour gates ok.

## M7 self-checks (ruling 17: one line per asset or acting change, no critic rounds)

- 2026-10-30 · Task 7 journey thresholds (door, path, portal, rocket) · new `journey.riv` 20,743 B (budget 160 KB), avatar and scenes untouched · objective check (Sonnet, four strips over every scene's poster + gates): no face covered, no draw-order error, path foliage covers only the shoulder; flagged the rocket's lift-off frame cut flat at the top (an evidence artifact: the composite pasted only the artboard box; pose moved to lift 0.08) and called the open door's doorway light "flat" at the frame edge (taste, kept). 14/14 gates ok.
- 2026-10-30 · Task 5 time of day (`daylight` / `dusk` veils in the sky plane) · livingRoom 112,635 → 112,956 B, campfire 244,011 → 244,332 B, beach 273,052 → 273,373 B, deepSpace unchanged, posters unchanged · no Sonnet pass needed beyond the gates (night frames pixel-identical to M6, noon / sunset deltas, ground untouched); my own look: the beach first hid its sun at noon (veils moved behind the sun and clouds), the campfire twilight band sat behind the ridges (horizon raised to y 720).
- 2026-10-30 · Task 9 Wow #3, the four-family tour and Wow #1 re-shot with the camera, played by the macOS app · no asset change · objective check (Sonnet, three beat sheets + 24-frame sheets of the wow3 and tour GIFs + gates): no pop, blank or frozen stretch, avatar never past a threshold, old scene never on arrival, no head cut by a framing; flagged the tour GIF showing only the idle room (a GIF start bug, fixed), the app's one-frame caption cross-fade and a caption sliding under the composer (both transient, kept). All 13 + 26 + 11 behaviour gates ok.

## M8 self-checks (ruling 15: one line per asset or acting change, no critic rounds)

- 2026-10-30 · Task 4 cat NPC (livingRoom) · livingRoom.riv 112,956 → 139,180 B (NPC + fog +26.2 KB) · objective check (Sonnet, state sheet, 2× crops, path strip + 14 gates): flagged the hop at npcX 0.25 (mid-air beside the cabinet: the intended leap down), the react hop above its shadow (intended) and the sleeping / sitting cross-fade at react f6 (the 200 ms state blend, kept); fixed before the pass: the tails' fill strokes painted behind their ink, a frowning mouth · evidence `rive/review/m8/npc/livingRoom/`
- 2026-10-30 · Task 4 owl NPC (campfire) · campfire.riv 244,332 → 249,842 B (NPC + fog) · objective check (Sonnet): no defect; fixed before the pass: its talons stayed on the bough in `away` (now inside `OwlNpc`), head turns softened (eyes left the body outline) · evidence `rive/review/m8/npc/campfire/`
- 2026-10-30 · Task 4 crab NPC (beach) · beach.riv 273,373 → 285,130 B (NPC + fog) · objective check (Sonnet): the far-end crop ran past the artboard (evidence crop now clamped), the crab overlapping the gull post's base at npcX 0.75 (same depth, kept); fixed before the pass: notice lowered the claws (signs flipped), the far end pulled in to x 1016, its rest loop ran one frame behind v10 (AnyState → rest re-entered it; rest is now reached from each state) · evidence `rive/review/m8/npc/beach/`
- 2026-10-30 · Task 4 alien NPC (deepSpace) · deepSpace.riv 67,125 → 74,588 B · objective check (Sonnet): only the 200 ms fade-in at react f6 (the state blend, kept) · evidence `rive/review/m8/npc/deepSpace/`
- 2026-10-30 · Task 4 fog (livingRoom window, campfire, beach; deepSpace ignores it) · in the sizes above · objective check (Sonnet): no defect, the living room's haze only through the window; fixed before the pass: +0.45 on the M5 veils alone barely read (campfire's back veil is already 0.93, tinted navy), so each scene got one fog bank (execution ruling proposal) · evidence `rive/review/m8/fog/`
- 2026-10-30 · Task 2 articulated hands + thumbsUp / count / grab · avatar.riv 574,335 → 556,626 B (back dropped −26.3 KB; digits, drivers, HandRest +2.6 KB; gestures +6.0 KB) · objective check (Sonnet, 5 pose sheets + 3 gesture strips + gates): the glove knuckle chevrons drew over the curled thumb (thumb pivot moved in front), the `up` pose's glove seams ran past its shorter fingers (an M7 defect, fixed), thumb tips cut by the evidence crop (crop widened), labels overprinted (moved); noted and kept: seams sit off-centre on the fingers (the M7 rest drawing), white glove `edge` cuff wedges (M7). Gates: rest frames 0 px, grip 0.42 px · evidence `rive/review/m8/hands/`
- 2026-10-30 · Task 3 jacket (avatar hand + journey door peg) · avatar.riv +1.75 KB, journey.riv 20,743 → 22,364 B · objective check (Sonnet, grab / hang strips with the open door composited, contact overlay): one jacket in every frame, the swap at f23 seamless, copies coincide (≤ 1 px); fixed before the pass: the coat's right edge passed under the door jamb (the journey draws over the avatar), so it moved 18 px left of the hook; noted and kept: the fist passes behind the jamb after the tug (the door stands in front) · evidence `rive/review/m8/jacket/`
- 2026-10-30 · Task 3 tablet weather card · avatar.riv +5.9 KB · objective check (Sonnet, 6 glyphs × 3 temperatures + a digits run): every readout matches, minus and degree ring visible, glyphs intact; noted: `none` keeps the generic sun card (by contract); fixed before the pass: the glyph sat under the left thumb (card moved right), first build over its line (+7.5 KB: shared segment masks, one tinted cloud) · evidence `rive/review/m8/tablet/`
- 2026-10-30 · Task 3 foley events · avatar.riv +277 B · no visual change; `rive inspect` firedBy lists every key (walk steps 6 per walk, cloth at the grab contact, tablet clicks, paper) and the previewer prints `event foley` as they fire; no key in a looping clip
- 2026-10-31 · Task 8 Wow #3 with the jacket, the cat's behaviour tree (`WOW=npc`) and Wow #2 with the Tokyo card, played by the macOS app · no asset change (one director fix: the weather card is held 1.5 s, execution ruling 32) · objective check (Sonnet, three beat sheets + 24-frame sheets of the GIFs): no two jackets, no floating or clipping cat, no old scene after the cut, no blank stretch; flagged the caption cross-fade overprinting two sentences for 1–2 frames in all three (the app's caption transition, as in M6–M7: not changed), the jacket "vanishing" at the start of the walk out (the hand passes the threshold first and is clipped there: the intended walk into the door), a faint arch ghost as the door vanishes (M7's 300 ms vanish fade sampled at 8 fps), a one-frame double cat (the 200 ms state blend), the tablet's quick put-away (M4's 417 ms clip) · evidence `rive/review/m8/wow/`

## M9 self-checks (ruling 17: one line per asset, no critic rounds; one Sonnet defect-only pass over every sheet: 0 blocker, 1 should-fix, 12 notes)

- 2026-10-31 · Task 2 world kit (moon-phase rig, festive lights, trail dots) · no scene byte beyond the declared v12 members (+121 to +770 B per M8 scene) · self-check on the kit sheets; the moon's dark side is drawn 0.6 px wider than the lit disc (a bright hairline at the limb, found by the rooftop lane) · evidence `rive/review/m9/world_kit/`
- 2026-10-31 · Task 3a cafe · cafe.riv 125,039 B, poster 30,156 B · lane self pass fixed wipe beading (darken blend), wreath / rod overlap, faint espresso steam, the fish's tail outside the bowl, door-gap glare, mist and floor contrast; Sonnet notes kept for the owner: wipe banding at trailFade 0.5, a festive bulb over the moon's edge · evidence `rive/review/m9/scenes/cafe/`
- 2026-10-31 · Task 3b rooftop · rooftop.riv 154,732 B, poster 22,386 B · lane self pass fixed pigeon scale, clipped water tower, hidden bridge tower, window density, glow, moon-reflection blob, roof sheen, airliner size, peck feet; key light flipped to the moon's side (upper left); Sonnet notes kept: telescope tip and pigeon at the avatar band's edge, the pigeon at npcX 1 in the phone crop, dark roof and faint stars at noon · evidence `rive/review/m9/scenes/rooftop/`
- 2026-10-31 · Task 3c mountainHut · mountainHut.riv 116,612 B, poster 30,940 B · lane self pass fixed frost rime, stocking vs kettle, trot scale, wall glow; Sonnet should-fix fixed: the sleeping dog moved clear of the avatar (x 771–975); the rope now sways with the ringing bell; kept: a ghost double dog during the 200 ms rest → react blend · evidence `rive/review/m9/scenes/mountainHut/`
- 2026-10-31 · Task 4 livingRoom cord + moon + festive · 139,301 → 143,411 B · 1 fix (the moon's dark side sampled under the veil); the cord hangs visible at rest (ruling: discoverability over identity, its box masked in the M8 identity gates); kept: `lightsOff` dims the festive lights with the moon · evidence `rive/review/m9/{drags,moon,festive}/`
- 2026-10-31 · Task 4 campfire poke stick + moon · 249,997 → 252,491 B · 1 fix (the stick's far end showed); the stick lies left of the fire at rest and lifts in from the lower left, never behind the avatar · evidence `rive/review/m9/drags/campfire_poke.png`, `moon/campfire.png`
- 2026-10-31 · Task 4 beach sand trail + gulls · 285,900 → 304,390 B (gulls 14,695, trail 3,795) · 1 fix (the pair overlapped and flew over the crab: spread apart, the path climbs right first); loop seams ≤ 0.03 % · evidence `rive/review/m9/{drags,gulls}/`
- 2026-10-31 · Task 4 deepSpace planet spin · 74,709 → 79,151 B · kept (Sonnet note): a 4–7 px seam line travels across the disc while it spins, the size of the bands' own gaps · evidence `rive/review/m9/drags/deepSpace_spin.png`
