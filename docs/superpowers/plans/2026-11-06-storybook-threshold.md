# The Storybook Threshold Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the `door` journey family with a standing pop-up storybook (cover swing, page riffle, destination pop-up vignette, ribbon bookmark) across `journey.riv`, its Dart choreography, gates and evidence.

**Architecture:** The Rive file stays history-free — the app ramps `open` and `unfold` with piecewise curves per beat; all stagger lives in clamp-windowed formula converters inside the file. The right page block is the static occluder at the unchanged threshold x 640, so the walk-through clip, every `JourneyPhase` beat, the jacket hook point (628, 560) and the reduce-motion path all survive untouched.

**Tech Stack:** Python RML generators (`rive/tools/`, built by `./scripts/frive.sh`), Rive runtime for Flutter, flutter_bloc, `FoleyService` (`lib/core/services/audio/`).

**Spec:** `docs/superpowers/specs/2026-11-06-storybook-threshold-design.md` — read it first; this plan argues from it.

## Global Constraints

- `journey.riv` must stay ≤ 160 KB (contract; checked by `check_contract.py`).
- New file element ids mint from `V15_ID_START = 6000` in `gen_journeys.py` (existing: base 10…, M8 5000…). Never renumber existing ids.
- The journey file: no listeners, no events, everything driven by `JourneyVM` numbers/colors through `c + k·x` formula converters (+ `min`/`max` clamp windows); at every number 0 the artboard draws nothing.
- Every colour outside `emit*` nodes goes through `fit()` (all scenes' colour scripts); lights through `bound_fill`/`bound_line` on `lightKey`/`lightAmbient`.
- Ease interpolators used by the ambient loop live in the `Journey` artboard (M12 lesson; single artboard here, so satisfied by construction).
- All user-facing strings through `AppLocalizations` (none expected in this change). Explicit types (`always_specify_types`). Relative imports.
- `getIt` only in `service_locator.dart` / `app.dart` / `app_router.dart` — new `FoleyService` injection into `AvatarCubit` happens at its registration site in `lib/core/di/service_locator.dart`.
- Foley behind the sound-effects setting (`FoleyService` already gates); play with `haptic: false` (world event, not a touch).
- Locked timings (spec): `JourneyTiming.open = 1400 ms`, `close = 640 ms`, `arriveOpenOf(book) = 1000 ms`; windows below in Task 3.
- Quality gate before finishing: `dart fix --apply && dart format . && ./scripts/fverify.sh`.
- Rebuild pipeline: `./scripts/frive.sh` (builds `journey.riv`, runs gates; `FRIVE_GATES=0` skips the long ones). Fast iteration: `uv run rive/tools/gen_journeys.py` then `./scripts/frive.sh` once the RML is sound. Never hand-edit built assets; `assets/rive/journeys/journey.riv` is committed rebuilt.
- Evidence directory (new): `rive/review/book-threshold/` — strips, gates, wows, README.

---

### Task 1: The book in the generator — occluder, cover swing, medallion, ribbon

**Files:**
- Modify: `rive/tools/gen_journeys.py` (replace `door()`/`door_peg()` with `book()`/`ribbon()`; new VM props `book`, `unfold`, `dest*`; `V15_ID_START`)
- Modify (built, via `frive.sh`): `assets/rive/journeys/journey.riv`, `rive/journeys/journeys.rml`

**Interfaces:**
- Produces (VM): `book`, `unfold` numbers (0–1); `dest*` = one number per `AvatarScene` name lower-cased first letter: `destLivingRoom`, `destCampfire`, `destBeach`, `destDeepSpace`, `destCafe`, `destRooftop`, `destMountainHut`, `destForestCabin`, `destTrainCompartment`, `destLibrary`. `open` now drives the cover swing. `lift`, `jacket`, `lightKey`, `lightAmbient` unchanged. `door` is gone.
- Produces (Python, for Task 6): `BOOK` layout constants (`BLOCK_X0 = 640`, cover length, `V15_ID_START`) importable from `gen_journeys`.

**Geometry (anchor: ground y 1000, gutter x 640):**

- **Right page block** (static occluder): rounded slab from x 640 to 1120, y −720…40 (top rounded 60). Outer face: leather `fit("FF6A4330")` gradient like the old leaf, ink outline 5, page fore-edge stripes (3 thin `fit("FFE8DCC8")` lines) on its left edge near the gutter. Gate target: covers BAND (650–790, 200–990) at open 0 **and** 1 — width 480 guarantees it.
- **Interior glow**: `emitBookGlow` — a vertical warm gradient strip just left of the gutter (x 600–680), opacity = clamp-window of `open` (visible only 0.05 < open < 0.95 — the crack and the passage), plus `emitBookSpill` floor pool (ellipse, y 20, radius x 520) with opacity and scaleX bound to `unfold` (spill widens as the vignette erects) — the old door's spill binding pattern (`conv(0.85)`), upgraded.
- **Front cover** (`BookCover`, hinged at the gutter): length 430, drawn pointing LEFT from x 640 (its open pose), so the swing is `scaleX = f(open)` around the hinge at rest pose RIGHT:
  - closed (open 0): rotation 0 means lying on the block pointing right — implement by binding the node's `scaleX` to `open` through a **cosine-look piecewise linear converter table**: RML formulas are linear, so decompose: node x-offset = `conv(k_x, c_x)` on `open`, scaleX = `conv(k_s, c_s)` with a **clamped** mid-zero: `scaleX = 1 − 1.9·clamp01(open·1.25)` (goes 1 → −0.9: sign flip = the edge crossing the hinge — the free edge sweeps from x 1070 to x 253 through a razor-thin edge-on at open ≈ 0.42). Tune the two constants against the strips (Task 6) until the swing reads as rotation, not a flip: the trick is the **edge highlight** (`emitCoverEdge`, 6 px light stroke on the free edge) brightening to full at edge-on and dimming after, opacity = `1 − |1 − 2·open|` shape via a clamped formula.
  - **faces crossfade**: `CoverOuter` (leather + medallion) opacity = clamp of `0.5 − open`; `CoverInner` (paper `fit("FFF3EBDD")`, ink margin frame) opacity = clamp of `open − 0.5`. Standard card-flip trick.
- **Medallion** (`BookMedallion`, on `CoverOuter`, centre ≈ x 850 in closed pose): a stamped disc (r 120, leather-deep fill, double ink ring) whose **emblem glyph is dest-selected**: ten emblem groups (Task 2) each also draw a small copy inside the medallion, each group gated by its own `dest*` number — closed and resting, the cover shows where we're going.
- **Ribbon** (replaces `door_peg`, M8 id range is fine to keep — same element, renamed): knob + tail from the block's top edge (x 648, y −700) draping down to the **hook point (628, 560)**; the jacket (`jacket_art.jacket`, unchanged ids) hangs from the tail tip, opacity `JourneyVM.jacket` as today. The tail's rotation binds `open` (`conv(−18°, 8°)` in degrees→rad units as Rive expects) so it lifts with the cover and whips out at the close. Draw order inside `Book`: block → interior glow → cover → ribbon tail + jacket (in front, near side).

- [ ] **Step 1: Add the VM props and the id range**

In `gen_journeys.py`, extend `PROPS` (after `lift`): `("book", "number", 0.0), ("unfold", "number", 0.0)` and the ten `("destLivingRoom", "number", 0.0) … ("destLibrary", "number", 0.0)`; delete `("door", "number", 0.0)`. Add `V15_ID_START = 6000` and `d15 = Doc(client=0, start=V15_ID_START)` beside `d8`; all new elements below are minted from `d15` (M8's pattern).

- [ ] **Step 2: Write `book()` — block, glow, cover, ribbon**

Replace `door()` and `door_peg()` with the geometry above. Keep the module docstring's family list in sync (`door` → `book`, described as "a standing pop-up storybook; the cover swings open, pages riffle and the destination rises as a paper-cut vignette"). Bind the family appear exactly as the door did: `bind("book", 18), bind("book", 16, conv(0.08, 0.92)), bind("book", 17, conv(0.08, 0.92))` on the root `Book` node at `(BLOCK_X0, GROUND_Y)`.

- [ ] **Step 3: Build and eyeball the rest poses**

```bash
uv run rive/tools/gen_journeys.py && ./scripts/frive.sh
```
Expected: build succeeds, `check_contract.py` will FAIL on the VM table until Task 4 (expected; note it and continue). Then check size:

```bash
ls -la assets/rive/journeys/journey.riv   # must stay ≤ 160 KB
```

- [ ] **Step 4: Commit**

```bash
git add rive/tools/gen_journeys.py rive/journeys/ assets/rive/journeys/journey.riv
git commit -m "feat(rive): storybook threshold — block, cover swing, medallion, ribbon (v15)"
```

---

### Task 2: The vignette — riffle flaps, panels, emblems, motes, ambient

**Files:**
- Modify: `rive/tools/gen_journeys.py` (add `vignette()`, `emblems()`, `motes()`; extend `amb_tracks`)
- Modify (built): `assets/rive/journeys/journey.riv`, `rive/journeys/journeys.rml`

**Interfaces:**
- Consumes: `unfold`, `dest*` VM numbers, `bound_fill`/`bound_line` lights, `star4`, `fit`, the clamp-converter pattern `F.fn("min"/"max", …)` (rocket flame precedent at `gen_journeys.py:409-419`).
- Produces: the finished `Journey` artboard (with Task 1) — everything the gates and Dart tasks consume.

**The clamp-window recipe (used everywhere below):** window `[a, b]` of `unfold` →
`min(1, max(0, (x − a)/(b − a)))` built as `conv_tokens(*F.fn("min", [F.val(1)], [*F.fn("max", [F.val(0)], [*F.val(1/(b-a)), F.op("*"), *F.inp(), F.op("+"), F.val(-a/(b-a))]), ])))` — one shared helper `window(a, b)` returning the converter; reuse one instance per (a, b) like `conv` does.

- **Riffle flaps** (3): small page quads (≈ 180×260) stacked at the gutter, each with `rotation` bound through `window()` with staggered ranges on `unfold`: flap 1 `window(0.00, 0.18)`, flap 2 `window(0.06, 0.27)`, flap 3 `window(0.14, 0.38)` → rotation 0→~2.4 rad (flip spine-ward) via `conv` on the windowed value (compose: bind rotation to `conv(k)` whose input is the window converter's output — chain converter-to-converter as the flame does with `lift`). Paper fill + ink edge 2.
- **Panels** (3 paper-cut layers rising from the gutter, drawn left of x 640, tallest at the gutter): `PanelFar` (ambient-tinted ridge silhouette, `bound_fill("lightAmbient", …)`, opacity 0.55), `PanelMid` (horizon shapes, paper fill with `bound_line("lightKey", …)` rim), `PanelNear` = the **emblem group** (paper `fit("FFF3EBDD")`, ink lines 3). Each panel node: `rotation` from ~90° (flat) to 0 (erect) via `window()`: Far `window(0.10, 0.55)`, Mid `window(0.22, 0.72)`, Near `window(0.38, 1.0)`; pivot at the gutter base. The overshoot lives in the app's ramp curve (Task 3), so converters stay monotonic.
- **Ten emblem groups** (each 2–5 shapes, all inside `PanelNear`, each root gated `bind("dest<Scene>", 18)`): livingRoom armchair + floor lamp; campfire tent + flame (`emit` flame glow); beach palm + sun disc; deepSpace ringed planet + `star4`; cafe cup + steam curl; rooftop railing + moon; mountainHut hut gable + peak; forestCabin pine pair; trainCompartment window arch + rail; library book stack + lamp. Each also drops the same glyph small (scale 0.22, static transform) into `BookMedallion`. Same ids mints from `d15`.
- **Light shaft + motes**: `emitBookShaft` — a translucent quad from the gutter mouth up-left (emit gradient, opacity via `window(0.3, 0.9)` of `unfold`). Seven mote dots (`E("emitBookMote<i>", …, 6–10 px, emit fill)`, positions spread x 380–620, y 300–700) on the ambient loop: each rises 60 px and fades over `AMB_FRAMES` with phase `i·34` (the portal-spark pattern, `keys = sorted({(0,0.15), (ph,0.15), (ph+90,0.9), (ph+180,0.15), (240,0.15)})` plus a `y` track −60). Glow breathing: extend the door's old glow-breath track onto `emitBookGlow` (opacity 0.88↔1.0).
- **Ambient loop stays seamless**: every added track keys frame 0 == frame 240.

- [ ] **Step 1: Write `window()` helper + `vignette()`/`emblems()`/`motes()`** per above; call from `book()`; add the amb tracks.
- [ ] **Step 2: Build + size check**

```bash
uv run rive/tools/gen_journeys.py && ./scripts/frive.sh
```
Expected: builds; `journey.riv` estimated 45–65 KB (cap 160 KB). If over: drop page fore-edge stripes and two motes first (cheapest), never the panels.

- [ ] **Step 3: Commit**

```bash
git add rive/tools/gen_journeys.py rive/journeys/ assets/rive/journeys/journey.riv
git commit -m "feat(rive): storybook vignette — riffle, panels, dest emblems, motes (v15)"
```

---

### Task 3: Contract v15 + Dart mirror + enum rename + timings + choreography

**Files:**
- Modify: `rive/CONTRACT.md` (journey section → v15), `rive/CHANGELOG.md` (v15 entry)
- Modify: `lib/features/avatar/presentation/rive/avatar_rive_contract.dart:590-617`
- Modify: `lib/features/avatar/domain/models/journey.dart` (enum `door`→`book`; `JourneyTiming`), `journey_planner.dart` (doc comment only)
- Modify: `lib/features/avatar/presentation/rive/journey_choreography.dart` (windows, curves, `unfold`, `destination`)
- Test: `test/features/avatar/domain/services/journey_planner_test.dart`, `test/features/avatar/presentation/rive/journey_choreography_test.dart`

**Interfaces:**
- Produces: `JourneyFamily.book`; `JourneyTiming.open = 1400 ms`, `close = 640 ms`, `closeOf(book) = 640`, `arriveOpenOf(book) = 1000 ms` (hold 120 + staged 880); `JourneyFrame.unfold` (double), `JourneyFrame.destination` (`AvatarScene?`, non-null only for `book`); `AvatarRiveContract.journeyPropBook = 'book'`, `journeyPropUnfold = 'unfold'`, `journeyDestProp(AvatarScene) → String`.

**Locked choreography windows (ms, within each beat; `ramp(start, len, curve)` exactly as today):**

| Phase | `show` | `open` | `unfold` |
|---|---|---|---|
| `open` (1400) | `ramp(0, 300, easeOut)` | piecewise **swing curve** over 300→1010: crack (300–390, first 15% of the curve's span, slow) then heavy `easeInOutCubic` | `ramp(850, 750, easeOut)` — riffle windows live in the file |
| `grab`/`exit` | 1 | 1 | 1 |
| `close` (640) | 1 | **fall curve** over 200→640: `easeInCubic` to 580, then a rebound to 0.96 and back to 0 by 640 | `1 − ramp(0, 200, easeOut)` (fold snaps first) |
| `cut` | 1 | 0 | 0 |
| `arriveOpen` (1000) | 1 | swing curve over 120→570 (no crack segment) | `ramp(470, 510, easeOut)` |
| `enter`/`hang` | 1 | 1 | 1 |
| `arriveClose` (640) | 1 | fall curve | fold, as `close` |
| `vanish` | `1 − ramp(0, 300)` | 0 | 0 |

`destination`: `phase.index >= JourneyPhase.cut.index ? journey.from : journey.to` (arrival shows the **origin**), null for non-book families. Reduce motion: existing jump-to-end semantics per ramp; the piecewise curves collapse to their end values (`ms >= end ? 1 : 0` per segment).

- [ ] **Step 1: Write the failing tests**

In `journey_choreography_test.dart` — rename `JourneyFamily.door` → `JourneyFamily.book` everywhere, then add:

```dart
test('the book stages crack-swing then riffle-unfold, overlapping', () {
  expect(_at(JourneyPhase.open, 290).show, lessThan(1));      // still appearing
  expect(_at(JourneyPhase.open, 395).open, lessThan(0.06));   // crack: barely cracked
  expect(_at(JourneyPhase.open, 700).open, allOf(greaterThan(0.25), lessThan(0.8)));
  expect(_at(JourneyPhase.open, 1010).open, 1);               // cover landed
  expect(_at(JourneyPhase.open, 849).unfold, 0);              // riffle not yet
  expect(_at(JourneyPhase.open, 900).unfold, greaterThan(0)); // overlap with the swing
  expect(_at(JourneyPhase.open, 1600).unfold, 1);             // settled past the beat
});

test('the close folds the vignette before the cover falls, with a rebound', () {
  expect(_at(JourneyPhase.close, 100).unfold, lessThan(0.5)); // folding fast
  expect(_at(JourneyPhase.close, 100).open, 1);               // cover still open
  expect(_at(JourneyPhase.close, 580).open, 0);               // landed
  final double rebound = _at(JourneyPhase.close, 610).open;   // 60ms rebound tail
  expect(rebound, greaterThan(0)); expect(rebound, lessThan(0.05));
  expect(_at(JourneyPhase.close, 640).open, 0);
});

test('the arrival vignette shows the origin, the exit the destination', () {
  expect(_at(JourneyPhase.open, 999).destination, AvatarScene.beach);
  expect(_at(JourneyPhase.arriveOpen, 999).destination, AvatarScene.livingRoom);
  expect(_at(JourneyPhase.arriveOpen, 999, family: JourneyFamily.rocket).destination, isNull);
});
```

In `journey_planner_test.dart`: replace expected `JourneyFamily.door` with `JourneyFamily.book` (66 pairs) and fix the doc count if asserted.

- [ ] **Step 2: Run — expect compile failures (`book` undefined, `unfold`/`destination` missing)**

```bash
flutter test test/features/avatar/presentation/rive/journey_choreography_test.dart test/features/avatar/domain/services/journey_planner_test.dart
```

- [ ] **Step 3: Implement** — `journey.dart`: rename the enum value with its doc; `JourneyTiming.open/close` new values; `arriveOpenOf`: `book → const Duration(milliseconds: 1000)`. `journey_choreography.dart`: two private `Curve` classes — `_SwingCurve` (piecewise: first 15% of span maps 0→0.03 (crack), rest `Curves.easeInOutCubic` over the remaining value) and `_FallCurve` (`Curves.easeInCubic` to 0.97…0 by 90% of span, then a dip to −0.04 and back to 0 — the rebound); `JourneyFrame` gains `unfold` + `destination` (update `==`, `hashCode`, `toString`); `settleOf`: `open → const Duration(milliseconds: 1500)`, `close/arriveClose → 660`, `arriveOpen → 1050`. `avatar_rive_contract.dart`: swap `journeyPropDoor`→`journeyPropBook = 'book'`, add `journeyPropUnfold = 'unfold'` and `static String journeyDestProp(AvatarScene scene) => 'dest${scene.name[0].toUpperCase()}${scene.name.substring(1)}';` (verify against the generator's ten names — they must match exactly).
- [ ] **Step 4: CONTRACT.md v15** — rewrite the journey section: family table (`book` replaces `door`: "how much of the storybook shows"), `open` ("the front cover swings around the spine hinge"), `unfold` ("the riffle and the pop-up vignette"), the ten `dest*` rows ("exactly one nonzero — the vignette and the medallion of that scene; the exit side shows the destination, the arrival side the origin"), ribbon/jacket paragraph replacing the peg one (hook point unchanged), band rule now "the right page block covers x ≥ 640 from y 200 to the ground whether open or closed", id range `V15_ID_START = 6000`. Add `rive/CHANGELOG.md` v15 entry.
- [ ] **Step 5: Run the contract checker**

```bash
uv run rive/tools/check_contract.py
```
Expected: journey section parses; `journey.riv` ≤ 160 KB; VM property set matches the built file exactly (this is what proves Task 1–2's names against Task 3's mirror).

- [ ] **Step 6: Full focused tests green, then commit**

```bash
flutter test test/features/avatar/
git add -A && git commit -m "feat(journey): book family, staged choreography, contract v15 mirror"
```

---

### Task 4: JourneyLayer writes the new numbers

**Files:**
- Modify: `lib/features/avatar/presentation/widgets/rive/journey_layer.dart:241-272`
- Test: `test/features/avatar/presentation/widgets/journey_layer_test.dart`

**Interfaces:**
- Consumes: `JourneyFrame.unfold`, `JourneyFrame.destination`, `AvatarRiveContract.journeyPropBook/Unfold/journeyDestProp`.
- Produces: the layer writes `book`, `open`, `unfold`, ten `dest*` (destination's = `show`, others 0), `lift`, `jacket`, lights — per frame, change-gated as today.

- [ ] **Step 1: Failing test** — in `journey_layer_test.dart`, extend the existing write-coverage test (it asserts which VM numbers a frame produces; follow its existing fake-binding pattern): a `grab`-phase book journey with `jacket: 1` writes `book: 1`, `unfold: 1`, `destBeach: 1`, `destCampfire: 0`, `open: 1`, `jacket: 1`; an `arriveOpen` frame writes `destLivingRoom: 1`; a rocket journey writes all `dest*` 0 and `book` 0.
- [ ] **Step 2: Run to see it fail** — `flutter test test/features/avatar/presentation/widgets/journey_layer_test.dart`
- [ ] **Step 3: Implement** — in `_write`, replace the family loop's door branch with `journeyPropBook`; after the `open` write add `number(AvatarRiveContract.journeyPropUnfold, frame.unfold);` and a loop over `AvatarScene.values` writing `number(AvatarRiveContract.journeyDestProp(s), frame.destination == s ? frame.show : 0)`. Update the doc comment (book, unfold, dest).
- [ ] **Step 4: Green, commit** — `flutter test test/features/avatar/presentation/widgets/journey_layer_test.dart && git add -A && git commit -m "feat(journey): layer writes book/unfold/dest numbers"`

---

### Task 5: Cubit beat timings + foley hooks

**Files:**
- Modify: `lib/features/avatar/presentation/bloc/avatar_cubit.dart:520-630` (open/close/arrive waits already read `JourneyTiming` — they pick the new values up automatically; add foley), constructor + `lib/core/di/service_locator.dart` (AvatarCubit registration)
- Test: `test/features/avatar/avatar_cubit_test.dart`

**Interfaces:**
- Consumes: `FoleyService.play(String kind, {bool haptic})` (`lib/core/services/audio/foley_service.dart:147`).
- Produces: optional named ctor param `FoleyService? foley` on `AvatarCubit` (null-safe, default null — existing tests unchanged); helper `Future<void> _foleyLater(Duration delay, String kind, bool Function() gone)`.

- [ ] **Step 1: Failing test** — in `avatar_cubit_test.dart` (existing journey test fixture): with a `foley` fake (record kind + elapsed beat time), a book journey plays `paper` during the open beat (≈850 ms in), `paper` during arriveOpen (≈470 ms in) and `click` during close (≈580 ms in); a journey stopped mid-beat (chat switch) plays nothing further; reduced-motion journeys play nothing.
- [ ] **Step 2: Run to fail.**
- [ ] **Step 3: Implement** — ctor param + field; `_foleyLater` = `Future<void>.delayed(delay)` then `if (!gone() && !isClosed) _foley?.play(kind, haptic: false);`. Calls: at the `open` beat emit → `unawaited(_foleyLater(const Duration(milliseconds: 850), 'paper', gone))`; at `close` and `arriveClose` → 580 ms `'click'`; at `arriveOpen` → 470 ms `'paper'`. Wire the real service at the AvatarCubit registration in `service_locator.dart` (`foley: getIt<FoleyService>()`). Beat waits need no edit (they read `JourneyTiming`/`closeOf`/`arriveOpenOf`).
- [ ] **Step 4: Green + planner/cubit suite, commit** — `flutter test test/features/avatar/ && git add -A && git commit -m "feat(journey): staged beat waits + paper/click foley for the book"`

---

### Task 6: Gates and strips re-aimed at the book

**Files:**
- Modify: `rive/tools/review_journey.py` (family list, strips, gates)
- Output: `rive/review/book-threshold/` (strips, sheet, gates.txt)

**Interfaces:**
- Consumes: `gen_journeys` layout constants; `JourneyRenderer.render(data)` (pose dict of VM numbers).

- [ ] **Step 1: Update the strips** — family rename `door`→`book`; book strip columns: `{book: 1}` (closed, medallion visible — assert the medallion's dest glyph pixels), `{book: 1, open: 0.5}` (edge-on), `{book: 1, open: 1}` (open, folded), `{book: 1, open: 1, unfold: 0.3}` (riffle up, panels down), `{book: 1, open: 1, unfold: 1, destBeach: 1}` (fully erected, beach), and the jacket column `{book: 1, open: 1, jacket: 1}`. Other families' strips unchanged.
- [ ] **Step 2: Rewrite the book gates** (replace the door lines in `gates()`):
  - closed AND open cover ≥ 85% of BAND (650–790, 200–990) at alpha > 0.5 — the static block (stronger than the door's open-only gate);
  - `open` changes pixels in the left band (260–640, 200–990) between open 0 and 1 (the sweep lands in-frame);
  - `unfold` changes pixels in the left band between unfold 0 and 1 **and** the riffle window moves pixels at unfold 0.2 while `PanelNear` has not (dest glyph pixels at unfold 0.2 == unfold 0, differ at 0.6);
  - each `dest*` erects alone: left-band pixels with `destX: 1` differ pairwise between scenes at unfold 1 (≥ 1% pairwise diff);
  - everything else unchanged (nothing at zero, family isolation incl. `book`, rocket gates, loop seam frame 0 vs 240 with book at 1 + unfold 1 + a dest).
- [ ] **Step 3: Run + save evidence**

```bash
uv run --with pillow --with numpy rive/tools/review_journey.py --out=rive/review/book-threshold
```
Expected: all gates `ok`. Tune the swing constants from Task 1 here (this is the render loop: adjust `conv` constants → `gen_journeys.py` → re-run) until the swing reads as rotation on the strip — edge highlight bright at 0.5, cover thin there, wide at both ends.

- [ ] **Step 4: Commit** — `git add rive/tools/review_journey.py rive/review/book-threshold && git commit -m "test(rive): book threshold gates + strips (v15)"`

---

### Task 7: Wow re-captures + evidence index

**Files:**
- Modify: `integration_test/wow_capture_test.dart` (comments at :509/:544; any gate asserting family `door` → `book`)
- Output: `rive/review/book-threshold/wow/` (wow3 + tour, mp4/beats/gates), `rive/review/book-threshold/README.md`
- Modify: `AGENTS.md` (one gotcha line, contract v15), `rive/CHANGELOG.md` if not already

- [ ] **Step 1: Update the harness expectations** — grep `door` in `wow_capture_test.dart`; the wow3 gate asserts the journey family — change to `book`; fix comments.
- [ ] **Step 2: Capture**

```bash
flutter test integration_test/wow_capture_test.dart -d macos --dart-define=WOW=wow3
flutter test integration_test/wow_capture_test.dart -d macos --dart-define=WOW=tour
uv run --with pillow --with numpy rive/tools/wow_capture.py ~/Library/Caches/fr.yofardev.yofardevAi/wow/wow3 rive/review/book-threshold/wow
uv run --with pillow --with numpy rive/tools/wow_capture.py ~/Library/Caches/fr.yofardev.yofardevAi/wow/tour rive/review/book-threshold/wow
```
(macOS: keep the window unoccluded — covered windows stop rendering.)
- [ ] **Step 3: README.md** — one row per evidence set (strips, gates, wow3, tour), self-check notes (gates output), known limits (portrait shows the left band; `say` speaks), regenerate commands. Mirror `rive/review/m7/README.md`'s structure.
- [ ] **Step 4: AGENTS.md gotcha line** — append one bullet after the M12 bullet: "**Storybook threshold (contract v15, 2026-11-06):** the `door` family is now `book` …" listing: the staged `open`/`unfold` choreography, `dest*` numbers (exit = destination, arrival = origin), ribbon replaces the peg at the same hook, `V15_ID_START = 6000`, evidence in `rive/review/book-threshold/`.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "docs(evidence): book-threshold wows, gates index, AGENTS v15 note"`

---

### Task 8: Quality gate

- [ ] **Step 1:** `dart fix --apply && dart format .`
- [ ] **Step 2:** `./scripts/fverify.sh` — format check + analyze + full tests (includes `architecture_test.dart`; Rive types stay in the avatar presentation layer, no violations expected).
- [ ] **Step 3:** `./scripts/frive.sh` once more end-to-end (build + journey gates green, file ≤ 160 KB).
- [ ] **Step 4:** Manual pass on the device/emulator: run one door-pair journey (e.g. livingRoom → cafe) and one arrival; watch: medallion legible at appear, crack-sliver, sweep into frame, riffle sound at 850 ms, panels springing, avatar gone behind the block, fold-flutter-fall-click, arrival origin vignette, ribbon whip. Fix and re-run Task 6's render loop for any beat that reads wrong.
- [ ] **Step 5:** Final commit if anything moved: `git add -A && git commit -m "chore: storybook threshold quality gate"`

## Self-review notes

- Spec coverage: reveal-direction fix (Task 1 swing + Task 6 gate "open changes left-band pixels"), close-≠-reverse (Task 3 fall curve + fold-first), arrival origin vignette (Task 3 destination rule + Task 4 write), medallion (Tasks 1–2), per-move eases + overlap (Task 3 windows), secondary motion (Task 2 ambient + ribbon), static occluder gate at open 0 **and** 1 (Task 6), foley (Task 5), interruption safety (`gone()` guards, pure-function frames — Task 5 test), reduce motion untouched (existing tests), budget (Tasks 1/6 checks), evidence + AGENTS (Task 7).
- Name consistency: `book`/`unfold`/`dest*` identical across generator (Task 1), contract + mirror `journeyDestProp` (Task 3), layer writes (Task 4); hook point (628, 560) unchanged everywhere; `V15_ID_START = 6000` single definition.
- Known risk flagged for the executor: the swing's scaleX sign-flip constant pair is the one number pair that cannot be derived, only tuned — Task 6 Step 3 is the tuning loop, budget up to three iterations.
