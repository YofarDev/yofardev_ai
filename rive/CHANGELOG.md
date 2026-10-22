# Rive assets changelog

Plan A writes one line per finished milestone, saying which parts of `CONTRACT.md` now exist in the `.riv` files.
Plan B reads this file to find out when it can start the steps that need real assets (B8, B9).

Format: `YYYY-MM-DD · A<n> · <contract parts now real> · <notes>`

<!-- entries below, newest first -->
2026-10-22 · A0 · avatar.riv: artboard `Avatar`, SM `Main`, full `AvatarVM` (every property + enum value declared); live: mood neutral/happy, mouth 0–4, gesture=wave (+`gesture_done`), hat noHat/beanie, idle breath/blink, pointer eye-follow · campfire.riv: artboard `Scene`, SM `Main`, `SceneVM` (eventId all 4 values, event trigger), live: flare, prop `fire` → `prop_tapped` · SPIKE for the user gate. Other enum values are declared but no-op until A1+. Built by `scripts/frive.sh` (avatar 34 KB, campfire 35 KB).
