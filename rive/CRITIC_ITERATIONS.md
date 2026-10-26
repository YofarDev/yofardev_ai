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
