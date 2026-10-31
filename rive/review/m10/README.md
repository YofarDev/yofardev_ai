# Moonshot M10 review index

One row per evidence set (M10 plan ruling 17, as M4–M9: no critic rounds, one render, one cheap
Sonnet defect-only pass over every sheet: 0 blocker, 0 should-fix, 2 notes kept for the owner). The
plan, the quarter split (ruling 1) and every ruling:
[2026-10-31-moonshot-m10.md](../../../docs/superpowers/plans/2026-10-31-moonshot-m10.md).

**M10's own exit (ruling 20):** the avatar ends at 488,418 B (M10 line 564,776) with every outfit
untinted identical to M9 (277 render cases); one in-app capture each for the wardrobe, the personas
and the captions, every gate ok, 0 network; `WOW=wow1` re-run as a regression check of the changed
avatar: 10/10. The quarter's exit gate (every tier passes its perf gate) is M12's.

## Budgets

| File | M9 (`58aeff2`) | M10 | Budget |
|---|---:|---:|---:|
| `avatar.riv` | 564,776 | **488,418** (dedupe −87,602, tints + anchor +2,088, signatures +9,156) | 614,400 (M10 line 564,776) |
| `journeys/journey.riv` | 22,364 | 22,364 (untouched) | 163,840 |
| `scenes/livingRoom.riv` | 143,411 | 143,428 | 409,600 |
| `scenes/campfire.riv` | 252,491 | 252,508 | 409,600 |
| `scenes/beach.riv` | 304,870 | 306,555 (night) | 409,600 |
| `scenes/deepSpace.riv` | 79,151 | 79,711 (seam) | 409,600 |
| `scenes/cafe.riv` | 125,039 | 138,681 (wipe holes) | 409,600 |
| `scenes/rooftop.riv` | 154,732 | 154,863 (day lift) | 409,600 |
| `scenes/mountainHut.riv` | 116,612 | 116,629 | 409,600 |
| posters (7) | ≤ 31,228 each | unchanged (no rest pose changed) | 40,960 each |
| `assets/foley/` (12 WAVs) | 830,932 | 830,932 (untouched) | 921,600 |

No wardrobe file: ruling 4 rejected a lazily loaded one (bones, skins and gesture keys live in
`avatar.riv`). The new committed evidence is 5.9 MB (ruling 18: ≤ 15 MB).

## Evidence

| Evidence | What it shows | Files | Self-check | Known limits |
|---|---|---|---|---|
| **Wardrobe dedupe** (Task 2a, ruling 3) | One sleeve set per sleeve kind, one shared hand; each outfit's paint keyed in its switch clip | [rest sheet](wardrobe/rest_sheet.png), [budget](wardrobe/budget.md), [gates](wardrobe/gates.txt) | 277 cases vs M9 (11 outfits × rest and every gesture's mid and peak, 5 hand skins × 4 poses, 6 switch-order sequences, costume loops): 0 px or ≤ 1/255; history-free (each sequence's end = the direct render) | +84–200 keyed values applied per frame by the top / costume clips (M11 perf) |
| **Tints** (Task 2b, ruling 5) | `topTint` / `hatTint` over 3 tops and 2 hats, 9 colours | [tints](wardrobe/tints.png) | Alpha 0 identical to 2a; the color blend renders on rive_native macOS (contract test: blue torso samples 0 → 1,965; 0 under batman); Sonnet: no spill on skin, hair, ink or prints | The sheet uses lane A's full-alpha swatches; the app writes `WardrobeTints` (alpha 0.9). Yellow reads olive on dark garments. Android unproven |
| **Mouth anchor** (Task 2b, ruling 12) | `MouthAnchor` on the upper-lip bone, pulled halfway to the lower lip | [anchor](wardrobe/anchor.png), [numbers](wardrobe/anchor.txt) | ≤ 2.9 px from the lips' centre over 14 poses (yaw, pitch, roll, jaw, lean, breath, walk); read in the app at (400, 490) at rest, moving with yaw and the jaw | — |
| **Costume signatures** (Task 2c, ruling 6) | batman cape sweep, robocop stepped scan-and-salute, soubrette curtsy, singularity levitation | [batman](wardrobe/signature_batman.png), [robocop](wardrobe/signature_robocop.png), [soubrette](wardrobe/signature_soubrette.png), [singularity](wardrobe/signature_singularity.png), [notes](wardrobe/signatures.txt) | ≤ 1.2 s each, end on the costume's rest (0 px), `gesture_done` from all five clips (macOS contract test too) | Sonnet note: a tone seam across singularity's arms at the sleeve join (identical to M9) |
| **Wardrobe in the app** (Task 7, ruling 20) | `WOW=wardrobe`: blue hoodie, red beanie, the four costumes (each plays its signature after the walk back), back to normal | [reel](wow/wardrobe.mp4) (10 s), [sheet](wow/wardrobe_sheet.webp), [gates](wow/wardrobe_gates.txt) | All ok: tints read back from the file per turn (transparent under every costume), 4 signatures once each with `gesture_done` 1.14–1.25 s after the trigger, 0 network | The batman line's bubble sits over the cowl |
| **Persona body language** (Task 4, rulings 9–11) | The same scripted reply through the real director, face performer, solver and ladder for all 8 personas; in the app as doomer, philosopher, coach | [trace](personas/trace.md), [reel](wow/persona.mp4), [sheet](wow/persona_sheet.webp), [gates](wow/persona_gates.txt) | All ok: doomer shrug ×2 (pitch −0.23), philosopher think ×3 (−0.13), coach thumbsUp / count / thumbsUp / think (+0.03); ladder onsets normal 30/120/600 s, coach 21/84/420, philosopher 42/168/840 | Keyed arm gesture amplitude is not scaled (ruling 9); the doomer's lean-back clamps at 0 |
| **Speech-bubble captions** (Tasks 5, 7, rulings 12–14) | A 4-sentence reply three times: default, reduce motion, text scale 1.6 | [reel](wow/caption.mp4), [sheet](wow/caption_sheet.webp), [gates](wow/caption_gates.txt) | All ok: bubble in 99 % of 314 speaking samples (anchor read 100 %), never both captions; reduce motion: each sentence placed once, 0 moves; text scale 1.6: classic only | On a portrait stage the bubble sits over the head (no room beside the face), so it covers hair, never eyes or mouth |
| **M9 notes** (Task 3, ruling 15) | Café wipe as holes in the mist, deepSpace spin seam, the beach's night, the rooftop floor at noon | [cafe](notes/cafe_wipe.png), [spin](notes/deepSpace_spin.png), [zoom](notes/deepSpace_spin_zoom.png), [beach](notes/beach_night.png), [clock](notes/beach_night_clock.png), [rooftop](notes/rooftop_day.png), [gates](notes/gates.txt) | 27/27 gates; every scene at the v13 defaults identical to M9 (rest, f90, noon, dusk, rain, fog, parallax); widest band gap 2 px (M9 8–13); beach night 1 sky ×0.20; roof floor 42.5 → 95.1 at noon | Sonnet note: the wipe's outline is scalloped and reads violet-grey over the sky; the ghost dog is kept (a state-blend crossfade) |
| **Regression of Wow #1** (ruling 20) | `WOW=wow1` with the M10 avatar | [gates](wow/wow1_gates.txt) (no media kept) | 10/10: lean 0.60, breath 1.00, 11 lip closures for 9 p/b/m words, brows 1.84 | — |
| **Contract on the real runtime** | `integration_test/rive_contract_test.dart -d macos`, 47 tests | — | v13 names and defaults; tints render, not under a costume; each costume's signature fires `gesture_done`; the anchor follows yaw and the jaw; every scene declares `night`; the café wipe's holes show | — |

## How to regenerate

```
./scripts/frive.sh                       # FRIVE_GATES=all adds the prop gates
uv run --with pillow --with numpy rive/tools/review_wardrobe_identity.py
uv run --with pillow --with numpy rive/tools/review_wardrobe_v13.py tints|anchor|signatures
uv run --with pillow --with numpy rive/tools/review_m10_notes.py
flutter test tool/body_language_trace_test.dart
flutter test integration_test/rive_contract_test.dart -d macos
flutter test integration_test/wow_capture_test.dart -d macos --dart-define=WOW=wardrobe   # or persona, caption, wow1
uv run --with pillow --with numpy rive/tools/wow_capture.py ~/Library/Caches/fr.yofardev.yofardevAi/wow/<run> rive/review/m10/wow
```

## Not verified

- **The owner's mid-tier phone run** (M6's, `../m6/device/README.md`) is still open: nothing in M10
  ran on a device or an emulator. The color-blend tint fills, the `MouthAnchor` read-back per frame and
  the extra keyed values of the deduped wardrobe are unmeasured on Android; no frame-cost JSON in M10.
- The speech bubble on a real phone (touch, notch insets, a screen reader).
- The persona body language by eye beyond the three captured personas; the generated sounds, drags and
  haptics (M8–M9) are still unheard / unfelt.
