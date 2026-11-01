# M12 lane W: the ghost blends (ruling 7) and the library ladder (ruling 8)

## Ghost blends: mountainHut's dog and library's mouse

**Cause.** Every pose animation on the `Npc` layer keyed the opacity of the NPC's drawing copies: asleep vs
awake, plus the dog's trotting copy. The layer's 200 ms state blend therefore cross-faded two copies.

**Fix.** `scene_npc.draw_layer` moves the drawing switch to its own state-machine layer, `NpcDraw`:

- The copies' opacity keys are removed from the pose animations (keys removed, no id moved).
- `NpcDraw` holds one 1-frame animation per state: `npc_<who>_draw_<state>`, which keys every copy (1 for the
  copy shown, 0 for the others).
- It switches on the same `npc` conditions with 0 ms transitions. The draws are rest/away → asleep;
  idle/notice/react → awake; move → awake (mouse) or the trotting copy (dog).

Poses keep blending in 200 ms on `Npc`, while the drawing cuts on the frame the blend starts. The new elements
mint from each module's own M12 range (`M12_ID_START = 880000`).

**Proof.**

- `ghost_<scene>.webp`: each transition, M11 vs M12, frames +0 to +14 after the change.
- `ghost_<scene>.txt`: per frame, the share of the outgoing copy's own pixels that sit between that copy and the
  bare background (partial opacity).
  - M11: 40 to 100 % over 11 frames.
  - M12: 0.0 % on every measured transition (9 dog, 5 mouse).
  - The mouse's rest → idle/react/move have no outgoing-only pixels (the awake mouse covers the curled one), so
    those rows are judged by eye.
- `npc_states_m12.webp`: the seven states (rest, idle, move, notice ±1, react, away) still render.
- `review_npc.py --gates-only`: every gate passes for both scenes (states move and loop, away clears the crop,
  the poke follows npcX, fog).
- Pytest: `test_*_drawing_switch_cuts_on_its_own_layer`.
- `identity_<scene>.txt`: ultra and high match M11 at 0 px in every world state. In the awake NPC states, 4 to
  55 edge pixels differ by 1/255.

**Not fixed here (the same pattern elsewhere).** In the generators, the same pattern (drawing copies whose
opacity every pose animation keys through `Rig`) also appears in:

- livingRoom's cat (`scene_npc.living_room_cat`: asleep / awake / walker);
- the café's NPC (`scene_cafe.py`: profile / front);
- forestCabin's squirrel (sit / run).

These were found by reading the code. They were not rendered: those scenes are outside this lane, and their
files are untouched. `scene_npc.draw_layer` is the shared fix if they show the same ghost.

## Library ladder at +1

**Defect.** At ladder +1 the ladder slid 140 px, which put the right stile at x 1110, the wheel at 1116 and the
shadow at 1133: past the artboard's right edge (1080). See `ladder_plus1.webp`, M11 row.

**Fix.** The travel is now asymmetric: -1 → 140 px left, as before; +1 → `LADDER_TRAVEL_R` = 84 px right.
- The rightmost art at +1 is x 1077 (the floor shadow); the stile is at 1054.
- The wheels turn by the distance rolled, and both converters are clamped.
- The contract drag rect stays **(671, 278, 1080, 1221)**: its right edge is the artboard's, clamped, for any
  right travel ≥ 81.
- `ladder_conv` rewrites the two M11 converters' tokens in place, so no id moves.

**Gates.**
- `review_diorama` ladder drag: no pixel changes outside the rect; changed bbox (677, 283, 1077, 1210).
- History-free check: max diff 1/255.

The aim drag maps finger dx / 409 px to `ladder` (Dart, unchanged), so +1 is now a shorter slide than -1.
