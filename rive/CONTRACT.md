# Rive contract (v8b)

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
| `mood` | enum | neutral, happy, sad, angry, surprised, thinking, embarrassed. **v5: accents only**: blush, sweat drop, anger mark, head tilt/drop, gaze offset, pupil size and the thinking mouth skew. The face's muscles (brows, lids, cheeks, nose, mouth shape) come only from the `au*` numbers; the app writes each mood's AU preset. |
| `mouth` | number | 0–4: closed, slightly, semi, open, wide (same order as `MouthState`). **v5: legacy alias**: the jaw opens by `auJawDrop` + 0.22 × `mouth`. Write `mouth` or the mouth AUs, not both. |
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
| `auBrowInnerUp` | number | 0–1, default 0: FACS AU1, the inner brow ends rise (worry, sadness). |
| `auBrowOuterUp` | number | 0–1: AU2, the outer brow ends rise (surprise, interest). |
| `auBrowLower` | number | 0–1: AU4, the brows lower and pull together (anger, concentration). |
| `auLidTighten` | number | 0–1: AU7, the lower lid rises and the eye narrows. |
| `auUpperLidRaise` | number | 0–1: AU5, the upper lid lifts and the eye opens wider. |
| `auCheekRaise` | number | 0–1: AU6, the cheeks lift and push the lower lids into a smile crescent. |
| `auNoseWrinkle` | number | 0–1: AU9, the nose wrinkles and lifts the upper lip. |
| `auLipCornerPull` | number | 0–1: AU12, the mouth corners pull up and out (smile). |
| `auLipCornerDepress` | number | 0–1: AU15, the mouth corners pull down. |
| `auLipStretch` | number | 0–1: AU20, the lips stretch sideways. |
| `auLipPucker` | number | 0–1: AU18, the lips round and push forward (o, u, w). |
| `auLipPress` | number | 0–1: AU24, the lips press together (thin, sealed: p, b, m). |
| `auJawDrop` | number | 0–1: AU26/27, the jaw opens the mouth (see `mouth`). |
| `auDimpler` | number | 0–1: AU14, the corners tighten into dimples. |
| `auBrowInnerUpL` | number | −1–1, default 0: v6 per-side offset, added to `auBrowInnerUp` on the viewer's left side; the sum is clamped 0–1 by the file. |
| `auBrowInnerUpR` | number | −1–1, default 0: v6 per-side offset, added to `auBrowInnerUp` on the viewer's right side; the sum is clamped 0–1 by the file. |
| `auBrowOuterUpL` | number | −1–1, default 0: v6 per-side offset, added to `auBrowOuterUp` on the viewer's left side; the sum is clamped 0–1 by the file. |
| `auBrowOuterUpR` | number | −1–1, default 0: v6 per-side offset, added to `auBrowOuterUp` on the viewer's right side; the sum is clamped 0–1 by the file. |
| `auBrowLowerL` | number | −1–1, default 0: v6 per-side offset, added to `auBrowLower` on the viewer's left side; the sum is clamped 0–1 by the file. |
| `auBrowLowerR` | number | −1–1, default 0: v6 per-side offset, added to `auBrowLower` on the viewer's right side; the sum is clamped 0–1 by the file. |
| `auLidTightenL` | number | −1–1, default 0: v6 per-side offset, added to `auLidTighten` on the viewer's left side; the sum is clamped 0–1 by the file. |
| `auLidTightenR` | number | −1–1, default 0: v6 per-side offset, added to `auLidTighten` on the viewer's right side; the sum is clamped 0–1 by the file. |
| `auCheekRaiseL` | number | −1–1, default 0: v6 per-side offset, added to `auCheekRaise` on the viewer's left side; the sum is clamped 0–1 by the file. |
| `auCheekRaiseR` | number | −1–1, default 0: v6 per-side offset, added to `auCheekRaise` on the viewer's right side; the sum is clamped 0–1 by the file. |
| `auLipCornerPullL` | number | −1–1, default 0: v6 per-side offset, added to `auLipCornerPull` on the viewer's left side; the sum is clamped 0–1 by the file. |
| `auLipCornerPullR` | number | −1–1, default 0: v6 per-side offset, added to `auLipCornerPull` on the viewer's right side; the sum is clamped 0–1 by the file. |
| `auLipCornerDepressL` | number | −1–1, default 0: v6 per-side offset, added to `auLipCornerDepress` on the viewer's left side; the sum is clamped 0–1 by the file. |
| `auLipCornerDepressR` | number | −1–1, default 0: v6 per-side offset, added to `auLipCornerDepress` on the viewer's right side; the sum is clamped 0–1 by the file. |
| `lipTuck` | number | 0–1, default 0: the lower lip tucks under the upper teeth (f, v). |
| `tongueUp` | number | 0–1, default 0: the tongue tip rises to the upper teeth (th, l, d, n). |
| `roll` | number | −1–1, default 0: head tilt ±6° about the neck, + = toward the viewer's right shoulder. Composes with `yaw`, `pitch`, moods and gestures. |
| `breath` | number | 0–1, default 0: inhale; the chest and shoulders rise and the head lifts slightly. Composes with the idle breathing. |
| `autoBlink` | boolean | default true: the built-in idle blink loop runs. False: the eyes stay open except for `blink`. |
| `blink` | trigger | One blink now, with either `autoBlink` value: the upper lids sweep down to the lower lids and back (v6). |
| `lightKey` | color | v7 light rig: the key light's colour (warm cheek light, glasses glint). Default `FFFFD49A` (livingRoom). |
| `lightKeyIntensity` | number | 0–1, default 0.85: key light strength. |
| `lightKeyX` | number | −1–1, default −0.737: direction toward the key light in viewer space, + = the viewer's right. |
| `lightKeyY` | number | −1–1, default 0.675: the same, + = up. |
| `lightRim` | color | Rim light colour (the silhouette's back edge, opposite the key). Default `FF9FB8E6`. |
| `lightRimIntensity` | number | 0–1, default 0.35. |
| `lightAmbient` | color | Ambient colour the shadow side leans toward. Default `FF2C3346`. |
| `lightAmbientAmount` | number | 0–1, default 0.35: how far the shadow side leans to `lightAmbient`. |
| `lightFlicker` | number | 0–1, default 0.15: firelight flicker of the key light on the cheek and glasses, looped inside the file (0 steady, 1 full campfire flicker). |
| `prop` | enum | none, tablet, newspaper. v7: tablet = pull the tablet out, then hold it (its screen lights the face); back to none puts it away. v8b: newspaper (appended, index 2) = the same out / hold / away with a folded broadsheet (no glow; a soft page shadow on the face). Only one prop shows: a prop changed to another is put away first. Plays on its own layer over the gesture layer. |
| `lean` | number | 0–1, default 0: listening lean; the torso and head tip toward the viewer and the head lowers a little. Composes with `breath`, gestures and the head turn. |

**Idle life**, built into the file with no Dart involvement: blinking, breathing, and eyes that
follow the pointer or touch.

All `au*` (including the v6 `L`/`R` offsets), `lipTuck`, `tongueUp`, `roll`, `breath`, `lean` and `light*` numbers are additive and history-free: the
pose depends only on the current values. Values outside the range are clamped by the app, not
the file. The speaking `phase` keeps only a faint sway; the app's prosody drives brows, nods and
blinks while speaking.

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
  - `parallaxX`, `parallaxY`: number, −1–1, default 0 (v7): device tilt or pointer offset; a
    diorama moves its depth planes by it (campfire in v7; every scene in v8).
  - The scene's light rig as defaults (v7), equal to `rive/tools/art_bible.py` `SCENES`:
    `lightKey` (color), `lightKeyIntensity`, `lightKeyX`, `lightKeyY` (numbers), `lightRim`
    (color), `lightRimIntensity` (number), `lightAmbient` (color), `lightFog` (color),
    `lightFlicker` (number). The app writes the same values to `AvatarVM`; it never reads them
    back from the file.
  - `rain`: number, 0–1, default 0 (v8): steady rain intensity. campfire, beach and livingRoom
    bind it (rain streaks, wet ground, steam off the campfire logs, streaks on the living-room
    window); deepSpace ignores it. The app writes it from its world state. The `rain` events stay
    one-shot showers on top.
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
