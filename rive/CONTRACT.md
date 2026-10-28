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
| `yaw` | number | −1–1, default 0: head turn (±30°). +1 = the character turns toward the **viewer's right**. Only the head turns; neck and body stay. History-free: the pose depends only on the value. |
| `pitch` | number | −1–1, default 0: head tilt (±15°). +1 = looks **up**. Only the head moves. Composes with yaw, moods, gestures and hair follow-through. |
| `hairLagYaw` | number | −1–1, default 0 (locked): yaw offset of the fringe locks, cowlicks and side locks relative to the head, same sign as `yaw` (the hair sits as if the head were at `yaw + hairLagYaw`); the back hair takes 1.3× it. Written by the app's follow-through spring. |
| `hairLagPitch` | number | −1–1, default 0 (locked): the same for pitch (+ = the hair sits as if looking further up). |
| `eyeLeadYaw` | number | −1–1, default 0: extra iris/pupil shift toward the viewer's right for +, on top of the pointer follow and the yaw slide, so the eyes can lead a turn. The irises stay clipped inside the eye whites. |
| `eyeLeadPitch` | number | −1–1, default 0: extra iris/pupil shift up for + (about 25 % of the eye-white height at ±1), on top of the pointer follow; at − the upper lids also drop (about 25 % lid coverage at −1) so looking down reads. Composes with blinks and mood lids; history-free. |

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
- `ui_kit.riv` must stay at or under 150 KB. At most one UI-kit artboard animates continuously
  on screen at once (the orb or the glow), and none animates while `reduceMotion` is true.

## `assets/rive/ui/ui_kit.riv`

The v4 UI kit (design: `docs/superpowers/specs/2026-10-26-v4-ui-redesign-plan.md` §5). One file,
several artboards. The app loads it lazily, once, and creates one controller per widget.

- Every artboard has a state machine named `Main` and its own view model named `<Artboard>VM`
  (for example `ComposerOrbVM`). The app binds each artboard to its own view-model instance.
- **No Rive events and no Rive listeners.** The app owns taps and the 48 dp hit areas (the
  Flutter runtime does not apply listener → view-model trigger writes).
- Colors are view-model `color` properties: the app writes the current scene's theme colors, so
  nothing in the file hard-codes the accent. The file's default values use Storybook night
  (accent `F4B860`, ink `16121D`, paper `F3EBDD`).
- `reduceMotion` = true stops every ambient loop (pulse, breathing, orbiting). State changes still
  animate, in 120 ms or less.

| Artboard | Size | Property | Type | Values / range |
|---|---|---|---|---|
| `ComposerOrb` | 96×96 | `state` | enum | idle, typing, listening, thinking, speaking, error |
| `ComposerOrb` | 96×96 | `level` | number | 0–1, microphone input level (used while listening) |
| `ComposerOrb` | 96×96 | `accent` | color | disc fill |
| `ComposerOrb` | 96×96 | `onAccent` | color | glyph |
| `ComposerOrb` | 96×96 | `reduceMotion` | boolean | |
| `StatusGlow` | 480×200 | `phase` | enum | idle, waiting, generating, speaking, error |
| `StatusGlow` | 480×200 | `accent` | color | glow tint |
| `StatusGlow` | 480×200 | `reduceMotion` | boolean | |
| `ToolIcon` | 48×48 | `kind` | enum | search, weather, news, memory, generic |
| `ToolIcon` | 48×48 | `running` | boolean | animates while true |
| `ToolIcon` | 48×48 | `tint` | color | glyph |
| `Toggle` | 104×64 | `value` | boolean | the knob slides when it changes |
| `Toggle` | 104×64 | `accent` | color | track when on |
| `Toggle` | 104×64 | `track` | color | track when off |
| `Toggle` | 104×64 | `knob` | color | knob |
| `Mark` | 256×256 | `play` | trigger | plays the logo sting once |
| `Mark` | 256×256 | `accent` | color | sting accent |

**ComposerOrb states:**
- idle: a mic glyph on the accent disc.
- typing: the mic morphs into a send arrow.
- listening: the disc becomes a ring that pulses with `level`.
- thinking: slow breathing with three orbiting dots (matches the avatar's `phase=generating`).
- speaking: a stop square.
- error: one horizontal shake (400 ms or less), then it holds still.

**StatusGlow phases** (a soft horizontal glow behind the composer):
- idle: faint and still.
- waiting: a gentle drift.
- generating: slow breathing.
- speaking: a brighter shimmer.
- error: one dim pulse.

**Scene posters:** `assets/rive/posters/<sceneId>.webp`, one per scene in the table above,
540×960, at most 40 KB each. Rendered from the scene file's rest pose, with no avatar. Used by
History rows and the Customize sheet.
