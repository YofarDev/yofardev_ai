# Raw run summaries (copied from `build/spikes/`)

`build/spikes/` is local and not preserved; these copies keep the key numbers traceable.
Layout mirrors the tier labels used in the findings: `macos/` (Skia) and `emu/` (Impeller,
emulator-5554, not throttled).

Copied:

- `<tier>/*.timeline_summary.json`: Flutter timeline summaries (capability cases, `_stress`
  variants, `baseline_avatar`, and `tierbench_<a..f>_r<N>_*` runs from the tier benchmark),
  with the added `renderer` and `probe` fields. They include the four per-frame arrays
  (`frame_build_times`, `frame_rasterizer_times`, `frame_begin_times`,
  `frame_rasterizer_begin_times`). The VM timeline is a ring buffer, so 10 s and 20 s runs
  hold only the newest ~273-314 frames (see the README measurement caveats).
- `<tier>/drive_procmotion_stress.json`: Dart-driven spring step cost (ticks, µs per step).

Not copied (size cap ~2 MB, total added is about 1.2 MB):

- `build/spikes/<tier>/tierbench_<x>_frames.json` (per-frame `FrameTiming` series, 70-300 KB
  each) and `tierbench_<x>_sf.jsonl` (gfxinfo framestats, emu only, 180-610 KB each). Their
  per-run P95s are in `tiers.md`.
- All PNG/GIF screenshots.
- `lipsync_drift*.json` and the phoneme outputs: already under `../phoneme-timing/data/`.
- `*.failure.json`: none were produced in this run.
