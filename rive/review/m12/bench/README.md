# M12 lane W: low-tier bench margin (ruling 3) and the bench gate retry (ruling 4)

CLI bench `rive <scene> --bench=1200 --data=tier=<t>` (rive 1.8.0, headless, 1080x1920 @1x). The Mac was
shared with other lanes the whole time (1-min load 5 to 13 on 10 cores). It never got quiet enough for a clean
p95 run (M11's library record is 0.760 at load 2.7).

## What the bench said pays (ablation, low tier, interleaved, render p50 median)

Each plane was hidden in turn. **library**: Plane2 (the back wall and its two bookcases) holds about 60 % of
the low tier's render time (p50 0.417 to 0.164 ms without it). Inside it the books' gold bands and the 3 px sheen
strips on the book tops (about 330 small rects) each paid about 0.03 x ultra at p95. The books themselves paid
0.08 but are the scene's art, so they stay. Stars, the town's lit windows and the pendulum paid about 0.01 each;
the candle glows and the floor shade paid nothing. **mountainHut**: `WallShade` (the upper wall's dark gradient
overlay, inside the wall's clip next to `WallCool`) paid 0.05 to 0.06; the stars paid about 0.015. The log grain
and the floor shade paid nothing at p95.

Added to the low list (decorative only; the light rig, the time-of-day veils, the NPC, the drag handle and
every contract bind stay):

- library: `CaseLTops`, `CaseRTops` (book-top sheen), `CaseLBands`, `CaseRBands` (gold bands), `Star`, `LitWin`
- mountainHut: `WallShade`, `Star`

## Before / after (M11 file at 2c3d11e vs M12, same session, interleaved, load-waited)

| scene | file | low p95 / ultra (best run) | low p50 / ultra (median) | runs | 1-min load |
|---|---|---:|---:|---:|---|
| library | M11 | 0.665 | 0.724 | 10 | 5.0-5.4 |
| library | M12 | 0.673 | **0.667** | 10 | 5.0-5.4 |
| mountainHut | M11 | 0.701 | 0.713 | 8 | 5.5-7.5 |
| mountainHut | M12 | **0.653** | **0.655** | 8 | 5.5-7.5 |

On a loaded host the best-p95 ratio is noise: library's M11 file measured 0.665 here, against 0.760 on a quiet
run. The p50 median is the stable signal: both scenes drop by about 0.057 x ultra. The ultra and high rows of
both files match each other within noise.

Gate lines (`rive_bench.py`, best p95 of 5 repeats):

- `./scripts/frive.sh library mountainHut`: library low **0.708** (load 5.2), mountainHut low **0.673**
  (load 4.6); high 0.975 / 0.987. All ok.
- standalone `rive_bench.py library mountainHut`: library low 0.749 (load 5.2, 7 redone), mountainHut low
  0.689 (load 5.7). M11 measured library at 0.824 under a similar load.

On a quiet host library is projected at about 0.760 - 0.057 = 0.70, which is borderline. That number is not
measured: the ruling's quiet-run check is left to the orchestrator's numbers of record (Task 5).

## Ultra identity

Ultra and high are compared with M11 (2c3d11e RML) in 14 world states: rest at f1 and f91, rain 1, noon, dusk,
fog 1, festive, parallax, every NPC state, npcX 1, and library's ladder at -1 and -0.5. At rest and in every
world state they match to **0 px**. The awake NPC states differ by at most 1/255 on 4 to 55 px at the drawing's
edges. That comes from the opacity now being keyed by its own layer (ruling 7), not from the tier cuts. Lists:
`../polish/identity_library.txt` and `../polish/identity_mountainHut.txt`. The low before/after sheets are
`low_library.webp` and `low_mountainHut.webp`.

## The gate retry (ruling 4)

`rive_bench.bench_gated`: when a scene's gate fails, the scene is measured once more after the load wait. A
tier fails only if it also failed the first measurement. The gate line then reads
`(...; load L, N redone, retried: first 0.824 over) ok`. The line never contains the word FAIL unless the
re-run fails too. Tests: `rive/tools/tests/test_rive_bench.py`. `rive_bench.py` now writes `bench.md` /
`bench.json` to `--out` (default `rive/review/m12/perf/`), so M11's evidence is never overwritten.
