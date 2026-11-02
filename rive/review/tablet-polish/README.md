# Tablet reading and two-hand grip — 2026-11-02

The main correction is the visible two-hand hold. The old long, flat `edge` hand
pose read as an open palm beside the tablet; the viewer's-right sleeve covered
its contact point. The tablet now draws in front of the sleeves, with compact
`tabletGrip` hand drawings over its edges. Longer projected forearms connect the
wrists to relaxed elbows, and the tablet sits slightly closer to the body center.

The compact hands are tablet-only copies of the existing art. They inherit all
costume paint keys, including the return to bare skin. The newspaper, clapping,
and costume gestures keep their original hand drawings and arm motions. Original
artwork, timeline and state-machine ids are retained. Replacement tablet motion
keys use `READING_ID_START` (1300000); grip art, depth rules and paint keys use
`GRIP_ID_START` (1320000). No Dart behavior or contract names changed.

The earlier timing polish is retained: a 3.6-second reading loop, a prepared
thumb flick, inertial scrolling, restrained screen light and a continuous
lift-to-hold handoff.

## Visual evidence

- [Before / corrected grip](grip-comparison.png): both contact points and the sleeves.
- [All costume variants](grip-costumes.png): bare skin, Batman, Robocop, Soubrette and Singularity.
- [Corrected animation](two-hand-reading.gif) and [ten-frame contact sheet](two-hand-reading-sheet.png):
  lift, two-hand reading, scrolling, release and return to the user.
- [Unchanged pose comparisons](unchanged-poses.txt): idle, clap, cape gesture and
  newspaper all have an exact 0/255 maximum channel difference from the earlier asset.
- [Head pose trace](reading-trace.json): the app's `headTargetFor` and
  `HeadMotionSolver`, stepped at 60 Hz; tablet out at 0.5 s and away at 5 s.
  The preview replays these poses and prop transitions in Rive CLI 1.8.0, with
  centered pointer follow and the file's idle blink. It is a renderer preview,
  not a recording of the running Flutter app.

## Verification

- Rive `--verify` and build: zero warnings or errors.
- Bundled `assets/rive/avatar.riv`: 491277 bytes, under the 600 KiB budget.
- Contract checker: pass across avatar, ten scenes, UI kit, posters and journey.
- Python generator suite: 991 passed, 3 skipped.
- [Tablet renderer gates](tablet-gates.txt): exact loop seam, interruption checks
  pass, maximum hand-position error 0.52 px (limit 2 px).
- `dart fix --apply` and `dart format .`: no Dart changes.
- `./scripts/fverify.sh`: format and analysis clean; 2647 tests passed.

Rebuild with `uv run rive/tools/gen_avatar.py`, then `rive rive/avatar --once`
and copy `rive/avatar/build/avatar.riv` to `assets/rive/avatar.riv`.
Run the prop renderer gates with:

```sh
uv run --with pillow --with numpy rive/tools/motion_review.py --gates-only
```
