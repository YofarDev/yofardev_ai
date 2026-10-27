# v4 UI M2: Rive UI kit art

> **For agentic workers:** one Rive agent runs this plan from start to finish, in the worktree
> `../yofardev_ai-rive` (branch `ui/m2-rive-art`). Load the `rive` skill before any Rive work.
> A Flutter agent works on `lib/` in a different worktree at the same time.

**Goal:** generate `assets/rive/ui/ui_kit.riv` (five artboards) and four scene posters, using
only the Rive CLI and Python generators, matching every row of `rive/CONTRACT.md`.

**Spec:** `docs/superpowers/specs/2026-10-26-v4-ui-redesign-plan.md` §3.1 (look) and §5 (Rive).
**Contract:** `rive/CONTRACT.md`, section `assets/rive/ui/ui_kit.riv` (committed as `6e3457e`).

## Global Constraints

- Touch only `rive/**`, `assets/rive/**`, `scripts/frive.sh` and this plan. Never touch `lib/`,
  `test/`, `integration_test/` or `pubspec.yaml`.
- CLI only: Python generators → RML → `rive` 1.8.0. No editor work, no bought art, no raster
  images inside the `.riv`.
- Reuse `rive/tools/rml.py` (deterministic ids). New generator: `rive/tools/gen_ui_kit.py`,
  project dir `rive/ui_kit/`. Ids must not collide with other projects (pick a distinct
  `Doc(client=…)` or id range).
- `ui_kit.riv` ≤ 150 KB. No feather/blur/mesh unless one soft glow truly needs it (prefer a radial
  gradient). Every artboard: state machine `Main` with `defaultStateMachineId`, view model
  `<Artboard>VM`, every property name, type and enum value in contract order.
- No Rive events, no listeners (the app owns taps).
- `reduceMotion` = true stops every ambient loop; state changes take ≤ 120 ms then.
- Colors: every visible paint that carries the accent / glyph / track / knob / tint binds to the
  VM `color` property named in the contract. File defaults: accent `F4B860`, ink `16121D`, paper
  `F3EBDD`, outline `3A3046`, surface `211B2B`.
- Look: "Storybook night" (see spec §3.1): warm, soft, rounded, storybook rather than neon. One
  accent; no outlines thicker than the art needs; motion with springy ease, nothing over 500 ms
  except ambient loops.
- Contract changes only if a row cannot be built: edit `rive/CONTRACT.md` in its own commit
  titled `contract: …`, and explain in `rive/CHANGELOG.md`. Report any such change.

## Tasks

### 1. Generator + build wiring

- `rive/tools/gen_ui_kit.py` writes `rive/ui_kit/ui_kit.rml` (+ `rive.yaml`, `main: ComposerOrb`).
- `scripts/frive.sh` also generates and builds the UI kit to `assets/rive/ui/ui_kit.riv` with a
  150 KB budget (`./scripts/frive.sh` with no args must still rebuild everything; with scene
  args it may skip the kit, your call, document it in the script header).
- Extend `rive/tools/check_contract.py` to parse the UI kit table (artboard, VM, SM, property
  names, types, enum values in order) and check the built project and the shipped bytes, like
  the avatar/scenes. Keep the existing checks green.

### 2. The five artboards (contract table + state descriptions)

Build `ComposerOrb`, `StatusGlow`, `ToolIcon`, `Toggle`, `Mark` as described in the contract.
Notes:
- ComposerOrb is shown at 48–56 dp: glyphs must read at that size (mic, arrow, stop, ring).
  The mic → arrow change should read as a morph or a quick swap with overshoot, not a cut.
  Listening: `level` 0 → still ring, 1 → strongest pulse; drive it through data binding (e.g.
  scale/opacity bound or a blend state), not a timeline per level.
- StatusGlow sits behind the composer pill, wider than tall; it must look good over all four
  scenes (dark backgrounds) and never look like a hard-edged ellipse.
- ToolIcon: five glyphs (magnifier, sun/cloud, newspaper, brain-or-bookmark, sparkle); `running`
  adds a small looping motion per glyph (magnifier sweeps, sun rotates, …).
- Toggle: knob slides with a small squash; colors bound.
- Mark: the Yofardev logo sting (a stylised "Y" / the avatar's glasses — your design), ≤ 1.5 s.

### 3. Scene posters

`rive/tools/gen_posters.py`: for each scene, render the rest pose headlessly
(`rive <project> --screenshot=… --advance=1 --viewport=1080x1920` or similar) and convert to WebP
540×960, ≤ 40 KB each, into `assets/rive/posters/<sceneId>.webp` (PIL via `uv run --with pillow`).
Hook it into `frive.sh` or document how to run it.

### 4. Critique loop

Render contact sheets (every artboard × every state, 6–10 frames per animated state) with the
existing `rive/tools/sheet.py` / `review.py` patterns. Judge against the brief: does it read at
48 dp, does it look premium and storybook, any pops/clipping. Iterate at least twice. Log each
iteration (score + what changed) in `rive/CRITIC_ITERATIONS.md` under a new `ui_kit` heading, and
leave the final contact sheets in `rive/ui_kit/review/` (PNG, committed, small).

### 5. Finish

- `./scripts/frive.sh` green (all files, contract check included); sizes listed.
- Add `YYYY-MM-DD · M2 · ui_kit.riv + posters · <notes>` to `rive/CHANGELOG.md`.
- Commit in logical steps (generator, art iterations, posters, checker) ending with the
  Co-Authored-By line given in the dispatch.
- Report: commits, sizes, per-artboard proof (data-dump or screenshots showing each state),
  contract changes (if any), and the path of the final contact sheets.
