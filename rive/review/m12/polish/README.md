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

# M12 lane Q: the remaining ghost blends (ruling 7), the rooftop band and the café wipe (ruling 8)

Lane Q extended `scene_npc.draw_layer` so that a state can show:
- several copies (a tuple: both gulls' wings);
- no copy (None);
- a stepped `notice` (a list of (look, shown) steps).

`layer` passes the slot (`npc2`) through.

Lane Q's own ids mint from `scene_npc.M12_ID_START = 880000`, through `scene_npc.own_m12(sc)`: one document per scene,
shared by every lane Q addition in that scene. No existing id moves; only the removed opacity keys free theirs.
`idcmp` reports 0 changed attributes except the deliberate ones listed below.

## Which NPCs swapped drawing copies

| scene | NPC | copies (states) | fixed |
|---|---|---|---|
| livingRoom | cat | `CatAsleep` (away, rest) / `CatAwake` (idle, notice, react) / `CatWalk` (move) | yes, `NpcDraw` |
| deepSpace | alien | `Alien` (v10; away, rest) / `AlienNpc` (M8; idle, move, notice, react) | yes, `NpcDraw` (see below) |
| beach | gulls (`npc2`) | `Gull<i>Wing` folded (away, rest, idle, notice) / `Gull<i>WingNear` + `Far` (move, react) | yes, `Npc2Draw` |
| forestCabin | squirrel | `SqSit` (all but move) / `SqRun` (move) | yes, `NpcDraw` |
| cafe | fish | `FishProfile` / `FishFront` (front only in notice, near look 0) | yes, `NpcDraw` (see below) |

**The alien.** The alien's `away` hid the `Alien` copy itself, with no parent fade. A wrapper `AlienShown` at
identity now holds `AlienNpc` and `Alien`. The pose layer keys it at 1, or 0 in away, so `away` keeps its 200 ms
fade, and `NpcDraw` keys only the copies.

**The fish.** The 1D notice blend on `npcLook` mixed the copies at any look between the steps. The director's notice
look is ±0.7, so M11 drew a lasting 70/30 mix of profile and front, not only during the 200 ms blend. `NpcDraw`'s
notice is now a 1D blend whose steps sit 1e-4 apart:
- profile at |look| ≥ 0.5;
- front nearer 0.

The poses still blend on `Npc`.

**Without a copy swap (untouched).** In these NPCs a single drawing only shows or hides a part:
- campfire owl (the hoot mouth);
- beach crab;
- rooftop pigeon (the far wing in react);
- trainCompartment ladybug (the wing in react);
- library mouse and mountainHut dog (lane W).

**Not fixed: sub-part swaps inside one drawing.** These parts are swapped with timed holds inside the cat's idle
clip:
- the raised paw vs the front leg;
- open eyes vs shut lids;
- the tongue.

They still cross-fade if the state changes mid-lick (≤ 200 ms, inside the same drawing).

**Proof.**
- `ghost_<scene>.webp` and `ghost_<scene>.txt`: lane W's measure (`scratchpad/w/ghost.py`, generalised to any slot
  and look), HEAD (`before`) vs the working tree (`after`), frames +0 to +14.
  - Before: cat 91–98 %, squirrel 86–96 %, gulls 43–86 %, alien 52 % (react → rest), fish 99 % (rest → notice@0).
    These are the worst ghost shares on the transitions that have outgoing-only pixels.
  - After: 0.0 % on every measured transition.
  - The `n/a` rows (the incoming drawing covers the outgoing one) are judged in the strips.
- The fish's settled notice at -0.7 differs from HEAD by 1,232 px (`identity_cafe.txt`): the 30 % front ghost is gone.
- `npc_states_q.webp`: every state still renders (rest, idle, move, notice ±1, react, away; the fish also at -0.7
  and 0).
- `review_npc.py --gates-only` passes every state, loop, away and pointer gate in the five scenes and in rooftop.
  Four FAIL lines remain, and they already failed at HEAD: they compare with M7 `927a606`.
  - livingRoom and beach scene bytes over M7 + 31,744 B: HEAD was already +37,037 / +34,639 B.
  - The livingRoom poster is unchanged since M7.
  - The beach `SceneFront` differs from M7 by 0.0373 %: lane F's splash fix. It is 0 px vs HEAD.
- Pytest: `test_drawing_switch_cuts_on_its_own_layer[*]`, `test_fish_notice_shows_the_front_only_near_look_zero`,
  `test_alien_away_fades_through_its_wrapper`, `test_gulls.py` (the wings on `Npc2Draw`).

## Rooftop: the telescope tip and the pigeon at the avatar band's edge

**Telescope.** At rest, the dew shield reached x 735, inside the band (x 330..750).
- The tube now rests at `TUBE_SHOWN` = 0.9 rad (52°, M11: 40°). Its rim ends at x ~758.
- Its extremes stay `TUBE_REST ± AIM_SWING` (aim -1 / +1): the `aim` converter's tokens are rewritten in place (its
  id stays) to `0.813 × clamp(aim, -1, 0) + 0.409 × clamp(aim, 0, 1)`.
- `aim_rect()` is unchanged, as is the contract rect **(710, 1011, 978, 1317)**.
- Below 0 the drag now swings 46.6° per unit, above 0 it swings 23.4° (as lane W's asymmetric ladder).

**Pigeon.** `PIGEON_WAYPOINTS` moved 16 px right (816 → 1016). The path keeps its 200 px, so
`pigeon_walk_speed` stays 0.354 npcX/s, the Dart `pigeonWalkRate`. Measured over the bare scene:
- rest: x 760–882 (M11: 744–866);
- the idle peck reaches 747 (M11: 730);
- at npcX 1 the tail reaches 1077 (M11: 1061), inside the artboard.

`Hit_pigeon` rides along; it is not a contract rect. The phone-crop note on the pigeon at npcX 1 is slightly
worse (16 px) and stays kept.

**Evidence and gates.**
- `rooftop_band.webp`: M11 vs M12 at rest, at the peck, at aim -1 / +1 and at npcX 1. The red dashes mark x 750.
- The `aim` gate passes: pixels change only inside the rect.
- Every rooftop state, path and pointer gate passes.
- `identity_rooftop.txt`: in every tier and world state, the differences sit inside (737, 901, 1079, 1247): the
  telescope and the pigeon. The `SceneFront` is 0 px.
- `frive.sh`'s `review_time` gate "rooftop night identical to HEAD" FAILs at 0.809 %. This is this deliberate rest
  change measured against the uncommitted HEAD; it reads ok once the change is committed.
- The poster changes: 22,386 → 21,864 B.

## Café: the wipe stroke's outline

The mist rings now sit within 5.5 px of the stroke's edge:
- M12: `WIPE_RINGS` = ((29, 0.5), (27.5, 0.3), (26, 0.15), (24.5, 0.05)).
- M10: within 16 px, ((26, 0.72), (22, 0.46), (18, 0.24), (14, 0.08)).

The inner rings' discs, 22–24 px apart along a stroke, drew the scalloped, violet-grey band. The stroke now reads
as clean glass with a thin soft edge.
- Only attribute values change (ellipse sizes, ring opacities, the thinning formula's literals), so no id moves.
- `cafe_wipe.webp`: M11 vs M12 at trailFade 0 / 0.5 / 0.9, at noon and at rain 1, 1.4×.
- At the defaults (trailN 0) the café is 0 px vs HEAD in every case of `identity_cafe.txt`, except the fish's
  notice at -0.7, the ghost fix above.

## Ultra identity (lane Q's six rebuilt scenes)

`identity_<scene>.txt` compares the working tree's RML with HEAD's:
- ultra: rest f1 / f91, rain 1, noon, dusk, night, fog, festive, parallax, each NPC state, npcX 1 (and the gulls'
  states);
- high and low: rest, rain 1, npc move;
- `SceneFront` at rain 1 (ultra / low).

Results:
- All world states: 0 px in livingRoom, deepSpace, beach, cafe and forestCabin.
- Settled NPC states: at most 27 px at 1/255 (edge noise), all in the NPC's box.
- The deliberate changes: the rooftop telescope and pigeon, and the fish's notice at -0.7.
