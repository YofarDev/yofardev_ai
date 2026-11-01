# M8 avatar / journey budget (plan ruling 2)

Bytes of the built `.riv` after each step (each step measured by building the generator with the later steps
cut out; the same Rive CLI 1.8.0 build as `rive rive/avatar --once`).

## avatar.riv (budget after M8 ≤ 590,000 B; contract ceiling 614,400 B)

| Step | avatar.riv | Δ | Line (ruling 2) |
|---|---:|---:|---|
| M7 (`927a606`) | 574,335 | | |
| `back` minted and dropped (10 groups) | 548,006 | −26,329 | |
| digit pivots + `TransformConstraint`s + drivers (50 pivots, 10 drivers) | 550,332 | +2,326 | |
| `HandRest` layer (the drivers at identity before `Gesture`) | 550,636 | +304 | digits + drivers + constraints: 2,630 ≤ 6,144 |
| gestures `thumbsUp`, `count`, `grab` (clips, enum values, `gesture_done` events, states) | 556,626 | +5,990 | ≤ 6,144 |
| v11 view-model properties (`jacket`, `tabletWeather` + its enum, `tabletTemp`) | 556,841 | +215 | (not lined) |
| jacket (drawing, upright lock, `Jacket` layer) | 558,595 | +1,754 | ≤ 4,096 |
| `foley` events (4 events, 17 timeline keys) | 558,872 | +277 | ≤ 1,536 |
| tablet weather card (glyphs, 15 segments, 10 formula converters + 14 groups, `TabletWeather` layer) | 564,776 | +5,904 | ≤ 6,144 |
| **M8 (Tasks 2 + 3)** | **564,776** | **−9,559** | ≤ 590,000: 25,224 B kept |

Shrinks made to stay inside the lines (Task 2 gestures first built at +17.8 KB): no hair / cloth
follow-through keys on the new gestures (the head barely moves), the arc keys simplified to 2 px (target) /
0.045 rad (hand), the poses' dips and settles under the frame's bottom edge left out, one foreshortening level
per raised arm, finger pops keyed as overshoot + settle only, constant runs of driver keys dropped. Card: the
two digit slots share their seven segment masks (a blank code), one cloud tinted per weather instead of four.

## journey.riv (budget 163,840 B)

| Step | journey.riv | Δ |
|---|---:|---:|
| M7 (`927a606`) | 20,743 | |
| `JourneyVM.jacket`, the door's peg and jacket | 22,364 | +1,621 |
