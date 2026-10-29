# Moonshot M4 review index

One row per asset or evidence set (M4 plan ruling 17: no critic rounds, one render, one cheap
self-check for objective defects). Every folder has its own `README.md` with the method.

| Evidence | What it shows | Files | Self-check | Known limits |
|---|---|---|---|---|
| Budget (Task 1) | Key decimation: avatar.riv 607,684 to 545,036 B; before/after gesture and walk strips | [README](budget/README.md), [wave](budget/gesture_wave_before_after.png), [clap](budget/gesture_clap_before_after.png), [walk](budget/presence_leave_before_after.png), [numbers](budget/compare.json) | No pops, shape or colour changes; worst gesture frame 0.27 % px > 16/255 at 360 px, walk 1.6 % | The plan's "<= 1/255" gate cannot hold with any position tolerance (edge anti-aliasing shifts); accepted at the plan tolerances (ruling 20). Motion-review IK check not rerun on decimated keys |
| Light rig (Task 4) | Avatar v7 light: 4 scene rigs x neutral/happy x yaw -1/0/1; campfire flicker; lean and wardrobe | [README](light/README.md), [sheet](light/light_sheet.png), [campfire row](light/light_campfire.png), [flicker strip](light/flicker_strip.png), [flicker.gif](light/flicker.gif), [lean/wardrobe](light/lean_wardrobe_check.png), [gates](light/gates.txt) | All gates ok: history <= 1/255 (one 2/255 gradient pixel), flicker seam equals the control, 0 lit pixels outside the silhouette. Fixed: a torso rim that crossed the hood (dropped) | The cheek pool is subtle on the bright skin (screen blend, 0.65); no ambient wash on the hands; no torso rim by design |
| Tablet (Task 5) | `prop=tablet` out, hold, away at the reading gaze (yaw 0.6, pitch -0.5); four interruptions | [README](tablet/README.md), [out](tablet/out_sheet.png), [hold](tablet/hold_sheet.png), [away](tablet/away_sheet.png), [out_hold_away.gif](tablet/out_hold_away.gif), [interrupts](tablet/interrupt_short_tool.png), [gates](tablet/gates.txt) | Hold seam 1/255, no interruption pop above the plain clips, IK <= 1.23 px, no elbow flip. Fixed: sleeves over the screen, two-way elbow bend, hand at the frame edge, 3 px hand slide | Tablet draws behind both forearms (one draw slot); the walk swing would pull the hands off the slab (the director never walks while reading); face glow subtle by design |
| Campfire diorama (Task 6) | Six parallax planes, fog veils, firelight loop, four events; M3 vs M4 poster | [README](campfire/README.md), [poster](campfire/poster_before_after.png), [parallax sheet](campfire/parallax_sheet.png), [edges](campfire/parallax_edges.png), [fire](campfire/fire_strip.png), [events](campfire/events_check.png), [gates](campfire/gates.txt) | No revealed edge at the 9 parallax corners, events intact, lint clean, firelight seam 0/255, budget ok (166,786 B). Fixed: veil 0 dimmed the moon; fog alpha too faint | Flicker not bound to `lightFlicker`; hit zones stay unparallaxed (largest drift 20 px); the other three scenes are still flat |
| Speech jaw (ruling 16 / 16b) | Median jaw while speaking, before/after, on four fixtures; `pp` closures | [README](speech/README.md) (numbers only; traces come from `tool/face_speech_trace_test.dart`) | Medians 0.205 to 0.255 (M3: 0.09 to 0.12); every `pp` span still reaches jaw 0 and press >= 0.85 | `so_true` stays under the 0.22 target (0.205): ou-heavy text and a 225 ms inner silence; accepted |
| Wow #1 (this task) | Campfire diorama poster plus the avatar with the campfire rig written verbatim: listening lean, inhale, `pp` closure, question brows, firelight close-up, settle | [wow1_campfire_rain.png](wow/wow1_campfire_rain.png) | Gates ok (`wow/gates.txt`): 7 of 7 captures non-empty, centred (0.50), nothing cut by the sheet crop at wide/medium; the rig constants equal `art_bible.SCENES` | Rain and steam are a dashed block-out (world sync M7 to M9). The scene is the poster (rest pose), not a live render; face AUs and the lean are hand-written as the app would write them (not driven by a real TTS run); the key light on the avatar is subtle at thumbnail size |
| Wow #2 (this task) | Living room: ask, head turn (yaw 0.6, pitch -0.5), tablet out (frame 14), hold, glance back (prop none, yaw 0, away frame 10), tablet gone and answering | [wow2_tokyo_weather.png](wow/wow2_tokyo_weather.png) | Gates ok: 6 of 6 captures non-empty, centred, no crop cut. Fixed in the tool: the thinking bubble was clipped by the 1.3x crop (now 1.1x), the phase-bubble no longer appears on the inhale beat | "Tokyo result on screen" is a block-out: the tablet screen shows generated placeholder glyphs, not tool data. Gaze values are hand-written; the nod on the stressed syllable is not shown |
| GIF: flicker | Campfire close-up (eyes to chin), 30 consecutive frames, 1 s at 30 fps, full flicker | [wow/flicker.gif](wow/flicker.gif) (the 2 s full-body loop: [light/flicker.gif](light/flicker.gif)) | Up to 13,944 px differ from frame 0 by more than 6/255: the flicker is visible | Only 1 s of the 2 s firelight loop; subtle on the cheek (screen blend) |
| GIF: parallax sweep | Campfire scene alone, `parallaxX` -1 to 1 over 12 frames (plays at 8 fps, a sweep to read, not real time) | [wow/parallax_sweep.gif](wow/parallax_sweep.gif) | 15,591 px differ between -1 and +1; no revealed edge (see campfire gates) | GIF palette (256) bands the glow gradients; Y axis not shown; tilt signs on a real device not verified |
| GIF: tablet out, hold, away | `prop` tablet from reading pose to put-away, real time | [tablet/out_hold_away.gif](tablet/out_hold_away.gif) (not re-rendered or copied) | see Tablet | see Tablet |

## How to regenerate

All Rive runs are sequential. The wow sheets and GIFs, about 2.5 minutes:

```
uv run --with pillow rive/tools/storyboard_m4.py rive/review/m4/wow
```

Exit code 1 and a `FAIL` line in `wow/gates.txt` when a self-check fails. The M1 storyboards in
`docs/superpowers/storyboards/2026-10-m1/` are untouched (`rive/tools/storyboard.py`, which
`storyboard_m4.py` reuses for the frame and caption layout).

Other folders: budget by a pre-change build (see its README); light by
`uv run rive/tools/review_face.py light`; tablet by
`uv run --with pillow python rive/tools/motion_review.py --tablet`; campfire by
`uv run --with pillow --with numpy rive/tools/review_campfire.py <M3 poster.webp>`; speech by
`flutter test tool/face_speech_trace_test.dart` (env-var args, see its header).

## Not verified

- No device run (no phone, no mid-tier device); no macOS UI-lab capture of either wow moment
  (ruling 17: no computer use while the owner works in another app).
- No real LLM or TTS run: the beats use hand-written AU and gaze values, the campfire rig
  from `SceneLights`, and no audio; the nod and the lip sync on a real sentence are covered by the
  speech traces only.
- Parallax tilt signs (which way the planes move for a device tilt) are unverified on a device;
  only the `parallaxX/Y` input is exercised.
- No frame cost: the render budget of the new layers (light, tablet, six parallax planes) is
  measured in bytes only, not in milliseconds per frame.
- World sync (rain, steam), the other three dioramas, hands and Kokoro are not in M4 (ruling 19).
