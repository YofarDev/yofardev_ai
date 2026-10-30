# Rive contract (v12)

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
| `gestureId` | enum | wave, laugh, facepalm, shrug, nod, headshake, clap, think, **v11 (appended):** thumbsUp, count, grab. `thumbsUp`: the viewer's-left hand rises, thumb up. `count`: the viewer's-right hand counts one, two, three (index, + middle, + ring), about 420 ms per number. `grab` (about 900 ms): the viewer's-right hand reaches to the hook point (628, 560) in this artboard, closes to a grip at 380 ms (the contact) and comes back to the side; with `jacket` true the same clip opens the hand at the contact (the app swaps `jacket` there). |
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
| `jacket` | boolean | v11, default false: the viewer's-right hand holds the storybook jacket (closed grip, the jacket hanging from the fist; it follows the reach, the walk and the IK). False: no jacket. It shows or goes in one frame: the app flips it at a `grab` contact, while the journey door's peg shows the other copy. |
| `tabletWeather` | enum | v11: none, clear, clouds, rain, snow, storm, fog. The tablet's weather card: `none` (default) keeps the generic card; any other value shows that glyph and the `tabletTemp` readout. |
| `tabletTemp` | number | v11, −40–50, default 0: the temperature on the tablet's weather card in °C (the app rounds it), a signed two-digit seven-segment readout; shown only when `tabletWeather` is not none. |

**Tap zones (v12):** the `avatar_tapped` listeners target two named shapes, `HitHead` (an ellipse,
`zone` head) and `HitBody` (a rectangle, `zone` body). The app reads their bounds each pointer to
decide where the avatar claims a pointer: only there; everywhere else the pointer also reaches the
scene below (its prop taps and drag handles), while the eye follow still hears it.

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
| `foley` | `kind`: string, v11: `step` (every footfall of the walk out and the walk in), `cloth` (the `grab` contact), `click` (the tablet's grip and release), `paper` (the newspaper opening and folding). Fired by timeline keys, several per clip; the app plays a sound and, for `click`, a haptic. |

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
  - `daylight`, `dusk`: numbers, 0–1, default 0 (v10): the time of day, written by the app from
    its world clock. daylight 0 is night and 1 full day; dusk peaks at 1 at sunrise and at sunset
    and is 0 an hour away from them. livingRoom (the window's sky, the skyline's lit windows off by
    day), campfire (the sky and the stars) and beach (the sky and the sun's glow) bind them;
    deepSpace ignores them. At 0 / 0 a scene looks exactly as it did before v10 (night).
  - `fog`: number, 0–1, default 0 (v11): weather fog or mist, written by the app from its world
    state. livingRoom (outside the window), campfire and beach thicken their fog veils (campfire and
    beach also in `SceneFront`'s mist); deepSpace ignores it. At 0 a scene looks as it did in v10.
  - The scene's NPC (v11), one per scene: livingRoom **cat** (the sleeping cat; its path runs from
    the cabinet, 0, to the rug in the lamp's pool, 1), campfire **owl** (on its bough; its path is
    unused), beach **crab** (its path runs along the wet sand from its v10 spot), deepSpace
    **alien** (in the ufo; its path is the ufo's drift). The app runs its behaviour; the file only
    draws it:
    - `npc`: enum, away, rest, idle, move, notice, react; default rest (the v10 look). away: not
      drawn. idle: awake, small life. move: its walk / scuttle / drift cycle while `npcX` changes.
      notice: it looks at the avatar (`npcLook` aims it). react: one short reaction loop (cat hop,
      owl wing flap, crab claw snap, alien wave). State changes blend in 200 ms or less.
    - `npcX`: number, 0–1, default 0: where along its path it is (0 = its v10 spot), history-free.
    - `npcLook`: number, −1–1, default 0: its head and eyes toward the viewer's left (−) or right
      (+).
    - Its existing prop tap (`cat`, `owl`, `crab`, `ufo`) is how the user pokes it.
    At `npc` rest, `npcX` 0, `npcLook` 0 a scene looks as it did in v10.
    v12 NPCs of the new scenes: cafe **fish** (a goldfish in a bowl on the counter; path = its swim
    across the bowl), rooftop **pigeon** (on the parapet; path = its walk along it), mountainHut
    **dog** (by the stove; path = the stove rug, 0, to the avatar's feet, 1). Their pokes: `fish`,
    `pigeon`, `dog`.
  - `npc2`, `npc2X`, `npc2Look` (v12): a second NPC slot with the same values and meaning as `npc`,
    `npcX`, `npcLook`, but default `away`. Only the beach binds it: **two gulls** on the sand right of
    the crab (rest standing, idle pecking, move flying across: `npc2X` 0 = landed, 1 = off the frame's
    right edge, notice heads to the avatar, react a startled flap). Every other scene declares and
    ignores it. Its poke is the beach's `seagull` prop.
  - `moonPhase`: number, default −1 (v12): −1 draws the moon as it was drawn before v12; 0–1 draws
    that phase of the moon (0 new, 0.25 first quarter, 0.5 full, 0.75 last quarter; the northern
    hemisphere's view: waxing lit on the right). History-free. livingRoom (the window), campfire,
    cafe (the window), rooftop and mountainHut (the window) bind it; beach and deepSpace ignore it.
    The app writes it from the local date.
  - `festive`: number, 0–1, default 0 (v12): December dressing, written by the app from the local
    date (1 December to 6 January). livingRoom (string lights along the window), cafe (lights in the
    window, a wreath on the door) and mountainHut (a garland over the stove, a stocking) bind it, with
    a slow twinkle; the other scenes ignore it. At 0 a scene looks as it did in v11.
  - The scene's drag handle numbers (v12, table below): every scene declares only its own. The app
    owns the gesture (Flutter pan recognizer, the handle rect in artboard space) and writes them each
    frame; the file only draws them, history-free. At their defaults a scene looks as it did in v11.
- **Scene `rain` in mountainHut** (v12) falls as snow outside the window (never rain).
- **Rive event emitted:** `prop_tapped`, with `propId`: string.
- **Front artboard (v9, optional):** a scene file may carry a second artboard `SceneFront`,
  1080×1920 like `Scene`, with a state machine `Main` and the same view model `SceneVM`. It holds
  the weather that falls *in front of* the avatar (a near rain sheet, rain mist, splashes at the
  bottom edge) and binds only `rain`, `parallaxX`, `parallaxY` and `lightFog`; at `rain` 0 it draws
  nothing. It has no listeners and emits no events. The app draws it above the avatar with the same
  fit as `Scene`, never hit-tests it, and creates it only while `rain` > 0. campfire, beach and
  rooftop have one; livingRoom, cafe, mountainHut (the weather is outside the window) and deepSpace
  do not (rooftop's is v12).

| sceneId | eventId values | propId values |
|---|---|---|
| livingRoom | lightsOff, lightsOn, tvOn, catWalksBy | lamp, tv, cat, plant |
| campfire | flare, rain, shootingStar, owlHoot | fire, tent, owl, sky |
| beach | bigWave, seagulls, sunset, rain | crab, umbrella, seagull |
| deepSpace | meteor, warp, alienShip, nebulaPulse | planet, ufo, rubberDuck |
| cafe | espresso, doorbell, rain, neonFlicker | cup, espresso, window, fish |
| rooftop | fireworks, plane, shootingStar, windowsLit | telescope, antenna, pigeon, moon |
| mountainHut | snowfall, flare, aurora, bell | stove, window, dog, bell |

v12 scenes: cafe (a rainy café: rain on the window, the wet street, the window's sky and fog),
rooftop (a rooftop at night: rain with a `SceneFront`, the sky, fog), mountainHut (a snowy mountain
hut, inside: snow outside the window from `rain`, the window's sky, fog, the stove's firelight
flicker). Each binds `parallaxX/Y`, its light rig, `daylight`, `dusk`, `fog`, `npc*` like the others.

### Drag handles (v12)

The user drags these props with one finger. `rect` is (x0, y0, x1, y1) in `Scene` artboard px at
parallax 0; the handle moves with its plane's parallax (gain × 40 / 24 px at ±1). `trail*` numbers
are artboard px.

| sceneId | dragId | kind | rect | plane | SceneVM numbers (defaults) | what the app does |
|---|---|---|---|---|---|---|
| livingRoom | cord | pull | (270, 770, 370, 940) | 4 | `cord` 0–1 (0) | pull down; springs back; past 0.6 once per pull: `lightsOff` / `lightsOn` alternately |
| campfire | poke | poke | (0, 1040, 330, 1340) | 4 | `poke` 0–1 (0), `pokeX` −1–1 (0), `pokeY` −1–1 (0) | the stick's tip follows the finger in the box; eased out on release; a stir faster than 900 px/s fires `flare` (once per 3 s) |
| beach | sand | trail | (830, 1230, 980, 1700) | 4 | `trailN` 0–16 (0), `trailX0`…`trailX15`, `trailY0`…`trailY15` (0), `trailFade` 0–1 (1) | dots in the wet sand ≥ 22 px apart, oldest recycled; `bigWave` washes them away |
| deepSpace | spin | spin | (150, 440, 450, 740) | 2 | `spin` 0–1 (0), wraps | a horizontal drag turns the planet's bands; inertia |
| cafe | wipe | trail | (330, 260, 750, 760) | 2 | `trailN`, `trailX*`, `trailY*`, `trailFade` as beach | wipes the misted window; it mists back over 20 s |
| rooftop | aim | aim | (710, 1011, 978, 1317) | 4 | `aim` −1–1 (0) | a horizontal drag swivels the telescope ±35°; it holds |
| mountainHut | rope | pull | (172, 470, 252, 980) | 3 | `rope` 0–1 (0) | pull down; springs back; past 0.6 once per pull: the `bell` event |

The rects are measured from the built art: each covers the prop as it rests and everything its drag moves. The cord and the poke stick draw at rest (v12 affordances); a gull's, the fish's and the pigeon's facing follows the sign of `npc2Look` / `npcLook` (+ = right) while they move.

`livingRoom` is the default scene.

## Budgets (anti-jank)

- Vector only. No embedded raster images.
- Keep blur, feather and mesh deformation to a minimum.
- `avatar.riv` must stay at or under 600 KB, and each scene at or under 400 KB.
- `journey.riv` (v10) must stay at or under 160 KB.
- Scenes are bundled with the app and loaded lazily (v12: seven scenes, no download).
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
the Stage's scene picker (v12).

## `assets/rive/journeys/journey.riv`

v10: the threshold of a scene journey (door, path, portal or rocket), drawn while the avatar
walks from one scene to the next. The app loads the file when a journey starts and disposes it when
the journey ends.

- **Artboard:** `Journey`, 800×1000: the avatar's artboard size. The app draws it with the
  avatar's fit (contain, bottom-centre), above the avatar and below the scene's `SceneFront`.
  The ground line is y 1000, like the avatar's feet.
- **State machine:** `Main`.
- **View model:** `JourneyVM`.
- **Threshold:** x 640 in artboard space. During a journey the app clips the avatar right of it,
  so the avatar disappears into (and comes out of) the threshold. Each threshold's occluding part
  covers x ≥ 640 from y 200 to the ground while it is open.
- No listeners and no events. At every number 0 the artboard draws nothing.

| JourneyVM property | Type | Values / range |
|---|---|---|
| `door` | number | 0–1, default 0: how much of the storybook door shows (it fades and grows in). |
| `path` | number | 0–1, default 0: how much of the path's near ferns and signpost shows. |
| `portal` | number | 0–1, default 0: how much of the portal ring shows (it grows from a point). |
| `rocket` | number | 0–1, default 0: how much of the little rocket shows. |
| `open` | number | 0–1, default 0: the shown threshold opens: the door leaf swings open on its right hinge, the ferns part, the ring's aperture opens, the rocket's hatch opens. |
| `lift` | number | 0–1, default 0: the rocket's height off the ground, with its flame; 1 is out of frame at the top. The other thresholds ignore it. |
| `lightKey` | color | the current scene's key light colour (rim and glow). Default `FFFFD49A`. |
| `lightAmbient` | color | the current scene's ambient colour (the shadow side). Default `FF2C3346`. |
| `jacket` | number | v11, 0–1, default 0: the storybook jacket hanging on the door's peg (door only; the peg shows with the door). The app sets it to 0 at the avatar's grab contact and back to 1 when the avatar hangs it on the next door. |

The app shows one threshold at a time (the other three numbers stay 0).

**Hook point (v11):** the door's peg is at (628, 560) in artboard space (the same point as the
avatar's `grab` contact, since both artboards share the frame). Its jacket is the same drawing as
the avatar's held jacket, so the handoff at the contact shows one jacket.

