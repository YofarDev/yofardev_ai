# v4 Plan A: Rive assets

> **Who runs this:** the expensive Rive agent. Plan B (app integration) is done by a different
> agent, in parallel.
> **Read first:** [`rive/CONTRACT.md`](../../../rive/CONTRACT.md) and the
> [design](../specs/2026-10-22-rive-v4-design.md), sections 1–2 and 4. Load the `rive` skill
> before any Rive work.

## Goal

Generate a rigged Yofardev avatar and 4 interactive scenes as `.riv` files, using **only the Rive
CLI** (RML + Luau scripts). The files must implement every row of `rive/CONTRACT.md`.

The art must **not look cheap**. A simpler vector style is fine, clip-art is not. The files must
also **not cause jank** on low-end Android.

## Scope

You may touch:

- `rive/**`: RML and Luau sources, `CONTRACT.md` (changes only as described below), and
  `CHANGELOG.md`
- `assets/rive/**`: the built `.riv` files, committed
- `scripts/frive.sh`

Never touch `lib/`, `test/`, `integration_test/` or `pubspec.yaml`. Those belong to Plan B, which
runs at the same time.

## Rules

- **Contract changes:** if a contract name or value can't be built as written, edit
  `rive/CONTRACT.md` in its own commit titled `contract: …` and say why in `CHANGELOG.md`.
  Never drift from the contract silently.
- **After every milestone:** commit, then add a line to `rive/CHANGELOG.md` in the format
  `YYYY-MM-DD · A<n> · <contract parts now real> · <notes>`.
- **Reference look, read only:** `assets/avatar/` (PNG layers) and
  `lib/features/avatar/widgets/costumes/*` (costume animations). Matching today's art exactly is
  not required.
- **Budgets:**
  - vector only, no raster images
  - keep blur, feather and mesh to a minimum
  - `avatar.riv` must stay at or under 600 KB, and each scene at or under 400 KB

## Tasks

### A0. Spike: go/no-go gate (throwaway)

1. Build a minimal Yofardev with:
   - a head and body
   - `mood` = neutral and happy
   - `mouth` 0–4
   - the `wave` gesture
   - `hat` = noHat and beanie
2. Build the `campfire` scene with one prop (`fire`) and one event (`flare`).
3. Iterate on the visual style using the CLI's headless screenshots until it no longer reads as
   clip-art.
4. Write the results to `assets/rive/avatar.riv` and `assets/rive/scenes/campfire.riv`, commit,
   and add the A0 line to `CHANGELOG.md`.
5. **Stop.** The user will open the files in Plan B's Rive Lab screen (`/rive-lab`, debug builds
   only) on a CPU-throttled Android emulator and on desktop. They will judge two things: does it
   look cheap, and does it stutter?
   - If either answer is yes, iterate on the CLI style and repeat this step. No editor work, no
     bought assets.
   - **Do not start A1 until the user approves.**

### A1. Avatar v1

- Implement every `mood`, `mouth` (0–4) and `phase` value.
- Give `phase` its own poses: `generating` and `waiting` replace today's Lottie typing and TTS
  indicators.
- Add idle life: blinking, breathing, and eyes that follow the pointer.
- Emit the `avatar_tapped` event with `zone` set to `head` or `body`.

### A2. Gestures

- Build all 8 `gestureId` values on an upper-body layer, fired by the `gesture` trigger.
- Mood and mouth must keep running while a gesture plays.
- Emit `gesture_done` when a gesture finishes.

### A3. Wardrobe

- Build every value of `hat`, `top` and `glasses`.
- Check that each one layers correctly through every gesture.

### A4. Costumes

Build `batman`, `robocop`, `soubrette` and `singularity`. Each costume replaces the hat and top
and keeps its signature animation:

- robocop: scanning eyes
- soubrette: feather duster
- singularity: glow and laser
- batman: cape or cowl motion

### A5. Presence

- Build `onScreen`, `outOfScreen` and `leaveAndComeBack` (walk off, then walk back and end on
  `onScreen`).
- Emit `presence_done` when the movement finishes.

### A6. Scenes

- Build all 4 scenes: livingRoom, campfire, beach and deepSpace.
- Each needs its ambient loops, every `eventId` and every prop from the contract table.
- A tapped prop emits `prop_tapped` with its `propId`.
- Use a 1080×1920 artboard with a centred safe zone and wide side bleed.

### A7. Build script and self-check

- `scripts/frive.sh` rebuilds every `.riv` from `rive/`, and running it is deterministic.
- Add a self-check, run by `frive.sh`, that inspects the built files with the CLI and fails if
  any artboard, state machine, view model, property, enum value or event name differs from
  `CONTRACT.md`.
- Do a final pass against the budgets: file sizes, and smooth playback of avatar plus scene on
  the throttled emulator through Rive Lab.

## Done when

- Every contract row is implemented.
- `scripts/frive.sh` rebuilds everything cleanly and its self-check passes.
- The budgets are met.
- `CHANGELOG.md` has a line for each of A0–A7.
