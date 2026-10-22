# Rive contract (v4)

**This file is the single source of truth shared by both agents.**

- Plan A builds it into the `.riv` files.
- Plan B mirrors it in `lib/features/avatar/presentation/rive/avatar_rive_contract.dart`.
- To change it: edit this file first, in its own commit titled `contract: …`. Then tell the
  other side, and also note the change in `rive/CHANGELOG.md`.

Names are case-sensitive and must match exactly, both in the files and in Dart.

Design: `docs/superpowers/specs/2026-10-22-rive-v4-design.md`.

## `assets/rive/avatar.riv`

- **Artboard:** `Avatar`, portrait. The character stands bottom-centre, with transparent padding
  so it can walk out of frame.
- **State machine:** `Main`.
- **View model:** `AvatarVM`, used through data binding. If the Flutter runtime can't bind, the
  same names become state-machine inputs: enum becomes number (its index), and trigger stays
  trigger.

| Property | Type | Values / range |
|---|---|---|
| `mood` | enum | neutral, happy, sad, angry, surprised, thinking, embarrassed |
| `mouth` | number | 0–4: closed, slightly, semi, open, wide (same order as `MouthState`) |
| `phase` | enum | idle, waiting, generating, speaking, error (same as `TalkingPhase`) |
| `gestureId` | enum | wave, laugh, facepalm, shrug, nod, headshake, clap, think |
| `gesture` | trigger | Plays `gestureId` on the upper-body layer. Mood and mouth keep running. |
| `hat` | enum | noHat, beanie, backwardsCap, frenchBeret, swimCap, santaHat, redMagaCap |
| `top` | enum | pinkHoodie, longCoat, tshirt, underwear, swimsuit, christmasSweater, blackSuitAndTie |
| `glasses` | enum | glasses, sunglasses |
| `costume` | enum | none, batman, robocop, soubrette, singularity. Any value other than none replaces the hat and top. |
| `presence` | enum | onScreen, outOfScreen, leaveAndComeBack. The last one walks off, walks back, and ends on onScreen. |

**Idle life**, built into the file with no Dart involvement: blinking, breathing, and eyes that
follow the pointer or touch.

**Rive events emitted:**

| Event | Properties |
|---|---|
| `avatar_tapped` | `zone`: string, `head` or `body` |
| `gesture_done` | `gestureId`: string |
| `presence_done` | `presence`: string |

## `assets/rive/scenes/<sceneId>.riv`

One file per scene. The app loads them lazily.

- **Artboard:** `Scene`, authored at 1080×1920. Keep the important content in a centred safe
  zone and add wide bleed on the sides, so `Fit.cover` also works in desktop landscape.
- **State machine:** `Main`. Ambient loops run on their own.
- **View model:** `SceneVM`.
  - `eventId`: enum, with the values for that scene from the table below.
  - `event`: trigger.
- **Rive event emitted:** `prop_tapped`, with `propId`: string.

| sceneId | eventId values | propId values |
|---|---|---|
| livingRoom | lightsOff, lightsOn, tvOn, catWalksBy | lamp, tv, cat, plant |
| campfire | flare, rain, shootingStar, owlHoot | fire, tent, owl, sky |
| beach | bigWave, seagulls, sunset, rain | crab, umbrella, seagull |
| deepSpace | meteor, warp, alienShip, nebulaPulse | planet, ufo, rubberDuck |

`livingRoom` is the default scene.

## Budgets (anti-jank)

- Vector only. No embedded raster images.
- Keep blur, feather and mesh deformation to a minimum.
- `avatar.riv` must stay at or under 600 KB, and each scene at or under 400 KB.
- The avatar plus one scene must run with no visible stutter on a CPU-throttled Android
  emulator.
