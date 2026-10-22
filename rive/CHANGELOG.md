# Rive assets changelog

Plan A writes one line per finished milestone, saying which parts of `CONTRACT.md` now exist in the `.riv` files.
Plan B reads this file to find out when it can start the steps that need real assets (B8, B9).

Format: `YYYY-MM-DD · A<n> · <contract parts now real> · <notes>`

<!-- entries below, newest first -->
2026-10-22 · A7 · whole contract enforced: `scripts/frive.sh` rebuilds all 5 .riv deterministically and runs `rive/tools/check_contract.py` (artboards, SMs, VMs, property types, enum values in order, event names + payload values, built bytes) · budgets: avatar 132 KB/600, scenes 19–52 KB/400, vector only, no feather/mesh; CLI bench render ≤ 0.36 ms mean. On-device check of avatar + scene on the throttled emulator (Rive Lab) still needs the user.
2026-10-22 · A6 · all 4 scenes (livingRoom, campfire, beach, deepSpace): artboard `Scene`, SM `Main`, `SceneVM` with every eventId value wired, every propId → `prop_tapped` · lightsOff/lightsOn are sticky (Lights layer); every other event is a one-shot on its own layer, so events can overlap. Sizes 19–52 KB; CLI bench render < 0.4 ms mean per scene.
2026-10-22 · A5 · presence onScreen/outOfScreen/leaveAndComeBack (walk off right, back, ends on screen) + `presence_done` (prop `presence`) · Presence layer has no AnyState so leaveAndComeBack can't retrigger; after it the avatar waits on screen until `presence` changes.
2026-10-22 · A4 · costume batman (cape sway), robocop (scanning visor), soubrette (feather duster swing), singularity (starfield body, aura pulse, eye lasers); any costume overrides hat/top (and glasses for batman/robocop/singularity) · costume `none` hands control back to hat/top/glasses.
2026-10-22 · A3 · every `hat`, `top`, `glasses` value (Solo switches incl. arm sleeves), layered correctly through all gestures · hats hide hair where needed (swimCap).
2026-10-22 · A2 · all 8 `gestureId` values on the `gesture` trigger (IK-posed arms + head), mood/mouth keep running · `gesture_done` fires at the end with prop `gestureId`.
2026-10-22 · A1 · every `mood` (7) and `phase` (5) pose, mouth 0–4, idle blink/breath/eye-follow, `avatar_tapped` (prop `zone` head|body) · generating = thought bubble with bouncing dots; waiting = glance aside; speaking = talk bob; error = "?" + sweat. A1–A5 landed in one commit (shared generator).
2026-10-22 · A0 · avatar.riv: artboard `Avatar`, SM `Main`, full `AvatarVM` (every property + enum value declared); live: mood neutral/happy, mouth 0–4, gesture=wave (+`gesture_done`), hat noHat/beanie, idle breath/blink, pointer eye-follow · campfire.riv: artboard `Scene`, SM `Main`, `SceneVM` (eventId all 4 values, event trigger), live: flare, prop `fire` → `prop_tapped` · SPIKE for the user gate. Other enum values are declared but no-op until A1+. Built by `scripts/frive.sh` (avatar 34 KB, campfire 35 KB).
