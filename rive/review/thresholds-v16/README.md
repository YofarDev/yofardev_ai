# Thresholds polish review index (contract v15 names, v16 notes)

The four scene-journey thresholds brought up to the scenes' finish (2026-11-07). One render, one
cheap self-check for objective defects (the M4+ ruling); the owner reviews the motion.

| Evidence | What it shows | Files | Self-check | Known limits |
|---|---|---|---|---|
| **Before / after** | The v15 tour's beats over the v16 tour's: same scenes, same harness | [before_after.png](before_after.png) | - | Beats only; the motion is in the MP4 |
| **Strips** | `journey.riv` (137,648 B ≤ 160 KB) per family over every scene's poster in the phone framing: book (now a page face with a drop cap and the story's lines, a gilt corner and title plate on the cover), path (scalloped thicket, lantern, ferns, the tunnel lit in the far scene's light), portal (narrower 330 × 900 ring so its core reaches the phone frame edge, vortex, comets, tear), rocket (riveted hull, brass porthole, lit cabin, ignition smoke) | [book](book_strip.png), [path](path_strip.png), [portal](portal_strip.png), [rocket](rocket_strip.png), [sheet](sheet.png), [gates](gates.txt) | Every gate line `ok`: nothing drawn at zero, family isolation, every threshold covers the band open, the book's v15 staging gates unchanged, rocket gone at lift 1, loop seam 0.00 % | Portrait shows only x 640-800 of the threshold: the path's tunnel centre and the rocket's right half stay off a phone screen (landscape / tablet show them) |
| **The four-family tour in the app** | living room → campfire (book), campfire → beach (path), beach → deep space (rocket: lands from the sky, hatch onto the lit cabin, ignition rumble and smoke, climb; lands in deep space, then takes off empty), deep space → living room (portal: tear, iris, tunnel to the room's warm light) | [tour.mp4](wow/tour.mp4), [tour.gif](wow/tour.gif), [beats](wow/tour_beats.png), [gates](wow/tour_gates.txt) | All 27 gates ok + 1 info (632 frames, none blank, 0 network): four journeys, each its family, beats in order, camera wide 100 %, avatar off screen only while clipped, the switch behind the closed threshold; GIF 4.09 MB under its 4.19 MB budget | The GIF is close to its budget; `say`-free (the tour has no speech) |

## What changed

- **Portal**: tears open as a white blade (`portal` bump) and widens (scaleY leads scaleX); a two-speed
  vortex of tapered arms turns behind the ring and irises with `open` into a tunnel of rings flying
  towards the far scene's light (`vignetteKey`); comets run round the rim (`TrimPath` offset laps),
  sparks are drawn in along the spiral, the rim twinkles, the ring lights the floor and washes the
  avatar's side (screen).
- **Path**: a scalloped thicket with key-lit clumps, flowers, vines and a lantern on the left bough
  (inside the portrait band); real fern fronds that spring up staggered on `path` and part with a
  follow-through on `open`, knocking loose leaves; the tunnel's far end lights in the scene beyond,
  its light running along the ground in rays, fireflies drifting in it.
- **Rocket**: riveted, glossed steel tinted by the scene's key (multiply), brass porthole lit by the
  far scene, a hatch onto a warm cabin with its light spilling out, nozzle, struts and feet; `lift`
  0-0.02 is the ignition (a sine-of-`lift` rumble, soft smoke rolling out over the pad, a ground
  flare), then the climb on a three-layer flame with shock diamonds; the shadow shrinks as it rises.
  App side: it lands before boarding, lifts off with an ignition hold (`_LiftOffCurve`,
  `JourneyTiming.liftOff`), and takes off empty after the arrival (`vanishOf`).
- **Book**: the block's face is a page (paper, gutter shade, drop cap, story lines, fore-edge),
  key-tinted; the cover gains a gilt corner and a foil title plate. Its v15 ids and staging are
  unchanged.
- **App**: `vignetteKey` / `vignetteAmbient` are written for every family (the scene not on screen).

## How to regenerate

```
uv run rive/tools/gen_journeys.py && ./scripts/frive.sh   # or build rive/journeys alone
uv run --with pillow --with numpy rive/tools/review_journey.py --out=rive/review/thresholds-v16
flutter test integration_test/wow_capture_test.dart -d macos --dart-define=WOW=tour
uv run --with pillow --with numpy rive/tools/wow_capture.py ~/Library/Caches/fr.yofardev.yofardevAi/wow/tour rive/review/thresholds-v16/wow
```

## Not verified

- No emulator / phone frame-cost run for the heavier overlay (more shapes, two screen-blend glows, a
  clipped vortex). The journey draws only during a journey, but a low-end phone may drop frames
  there; `integration_test/frame_cost_test.dart` does not cover the journey layer.
- The wow3 capture (book with speech) was not re-run; the book's staging is unchanged and its
  gates pass.
