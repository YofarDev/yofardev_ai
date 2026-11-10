# app-showcase-film Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Package the yofardev_ai film pipeline as a personal Claude Code skill
(`~/.claude/skills/app-showcase-film/`). The skill has a technical memory, and
a regression test proves it by rebuilding the yofardev_ai film from the
existing captures.

**Architecture:** The skill holds four things:
- the generic pipeline (Python scripts run from the skill with
  `--film <dir>`)
- a Remotion template that is copied into each app's `film/video/` when the
  film is scaffolded
- the capture backends
- the QA scripts and the memory files

Everything specific to one film lives in that app's `film/` directory: its
`film.json`, its scenes, `plans.ts` and `theme.ts`, and a music style
choice. The contract between the edit and the mix stays the existing EDL JSON
(`sections`, `regions`, `hits`), and the contract between the harness and
the pipeline stays the existing `timeline.json`.

**Tech Stack:**
- Python through `uv run` (numpy, pillow, soundfile, scipy, pedalboard,
  pyloudnorm, pretty_midi, pytest)
- ffmpeg/ffprobe
- fluidsynth with `MuseScore_General.sf3`
- Remotion 4.0.541 (React 19, TypeScript 5.9)
- bash and git

**Spec:** `docs/superpowers/specs/2026-11-09-app-showcase-film-skill-design.md`
(in the yofardev_ai repo). Reference implementation: `film/` and
`integration_test/wow_capture_test.dart` in the same repo.

## Global Constraints

- Skill path: `~/.claude/skills/app-showcase-film/`. It is its own local git
  repo with no remote.
- The yofardev_ai `film/` directory and its `film/work/` and `film/out/` are
  **read-only** for this plan. The regression writes only under
  `~/.cache/app-showcase-film/regress/`.
- Python always runs as `uv run --with … python -I` (never bare
  `python`/`pip`). Tests run as
  `uv run --with pytest --with numpy --with pillow --with soundfile --with scipy python -I -m pytest`.
- Remotion pinned at `4.0.541` (all `@remotion/*` packages the same
  version).
- Film format: 1920×1080, 60 fps, H.264 master (CRF 14, AAC 320k) plus a web
  encode (CRF 22, AAC 192k, `+faststart`).
- Mix loudness target: −14 LUFS integrated.
- Never put a real LLM, network or paid API call in a harness. Never fake app
  footage.
- Captures and raw media stay in a git-ignored `film/work/`. Generated music
  stems and wav files are git-ignored too.
- Lesson entry fields (exact keys): `platform` ∈ {macos, android, ios-sim,
  web, any}, `phase` ∈ {capture, harness, sync, edit, music, mix, render},
  `symptom`, `cause`, `fix`, `seen` (one or more lines), `promoted` (`no` or
  a location).
- Promotion threshold: a lesson with ≥ 2 `seen` lines must not stay
  `promoted: no`.
- Regression pass criteria:
  - duration within 1 frame (1/60 s) of the master
  - `sections.json` and `edl.json` identical to the master's
  - each take's sync offset within 1 frame of the existing
    `work/clips/<tag>.json`
  - integrated loudness within 0.5 LU of the master
  - mean PSNR ≥ 35 dB over 20 evenly spaced frames

## Review Focus

1. **Paths with spaces.** The Kokoro source is under `~/Library/Application
   Support/…`, and capture and pipeline scripts must quote every path. Pinned
   in Task 6 (`test_capture_args_quote_spaces`).
2. **A recording shorter than its run** (the recorder stopped early). Expected
   behaviour: `check_take` fails the take with a "recording ends before run"
   message, and `Clip` freezes instead of showing wallpaper. Pinned in Task 5
   (`test_take_short_recording`).
3. **Sentence and start-event count mismatch** (an interrupted reply). Expected
   behaviour: `runaudio` warns and places the pairs it has, and `check_take`
   reports the mismatch as a failure. Pinned in Task 2 (`test_runaudio_count_mismatch`)
   and Task 5.
4. **A costume voice effect without its `_fx.wav`.** Expected behaviour:
   `check_take` fails when the timeline marks `voiceEffect` ≠ `none` and the
   `NN_fx.wav` is missing. Pinned in Task 5 (`test_take_missing_fx`).
5. **A window that is not at the parked position** (another display layout).
   Expected behaviour: `sync` falls back to the frame search and still finds
   the rect. Pinned in Task 2 (`test_sync_finds_moved_window`).

---

## File map (skill repo)

```
~/.claude/skills/app-showcase-film/
  SKILL.md                     phases, two gates, preflight checklist, retro rules
  LESSONS.md                   memory (seeded)
  TOOLS.md                     tool verdicts (seeded)
  pipeline/
    filmcfg.py                 loads + validates <film>/film.json → FilmConfig
    sync.py  runaudio.py  events.py  mixfilm.py      generalized from film/tools
    build.sh                   sync → events → sections/edl → score → mix → render → mux → web encode
  music/
    engine.py                  MIDI helpers + fluidsynth render (from compose.py)
    styles/storybook.py        the yofardev cue (chords, themes, cycles)
    compose.py  mix.py         style-driven entry points
  capture/
    macos.sh                   from film/capture.sh, config-driven
    macos.md  android.md  ios-sim.md  web.md      (the last three marked UNTESTED)
  harness/
    flutter.md                 how to add a capture harness (points at yofardev files)
    timeline.schema.json       the timeline.json contract
  templates/
    film/                      scaffold: film.json, .gitignore, PLAN.md, README.md
    remotion/                  package.json, remotion.config.ts, scripts/, src/lib/, src/ example film
  qa/
    check_take.py  check_film.py
  scripts/
    new_film.sh                scaffold <app>/film from templates
    lint_memory.py             validates LESSONS.md / TOOLS.md
  regress/
    yofardev.sh  compare.py
  tests/                       pytest, synthetic fixtures under tests/fixtures/
```

`FilmConfig` (shared by every Python script; Task 1 defines it, the rest consume it):

```python
@dataclass(frozen=True)
class FilmConfig:
    film_dir: Path          # <app>/film
    repo_root: Path         # resolved film.json "repoRoot" (default "..")
    work: Path              # film_dir / "work" unless --work overrides
    cap: Path               # work / "cap"   (overridable with --cap)
    clips: Path             # work / "clips"
    fps: int                # 60
    grab_pxr: float         # 0.25
    content_size: tuple[int, int]   # logical px of the app content, e.g. (576, 1024)
    display_origin: tuple[int, int] # where the content is parked in the recording, px
    record_size: tuple[int, int]    # recording frame size, e.g. (1920, 1080)
    keep_events: frozenset[str]
    bpm: int
    music_style: str        # "storybook"
    seed: int
    soundfont: Path         # default ~/.cache/app-showcase-film/sf/MuseScore_General.sf3
    beds_dir: Path | None   # app ambient beds (repo-relative in film.json)
def load(film_dir: Path, work: Path | None = None, cap: Path | None = None) -> FilmConfig
```

Every pipeline script's CLI is `--film <dir> [--work <dir>] [--cap <dir>]`
plus its own positional arguments, if it has any.

---

### Task 1: Skill repo, config loader, memory and its linter

**Files:**
- Create: `SKILL.md` (stub of phases and gates; finalised in Task 8),
  `LESSONS.md`, `TOOLS.md`, `pipeline/filmcfg.py`, `scripts/lint_memory.py`,
  `tests/test_filmcfg.py`, `tests/test_lint_memory.py`, `.gitignore`
  (`__pycache__/`, `.pytest_cache/`, `node_modules/`)

**Interfaces:**
- Produces: `FilmConfig` and `filmcfg.load` (above), and
  `lint_memory.lint(lessons: Path, tools: Path) -> list[str]` (an empty list
  means valid). The CLI exits with code 1 and prints the errors.

- [ ] **Step 1:** `git init` the skill directory and add `.gitignore`.
- [ ] **Step 2: Write the failing tests:**
  - `test_load_defaults`: a minimal `film.json` with
    `{"app": "x", "contentSize": [576, 1024]}` loads with `fps == 60`,
    `grab_pxr == 0.25`, `bpm == 96`, `music_style == "storybook"`,
    `work == film_dir / "work"`.
  - `test_load_overrides_work_and_cap`
  - `test_load_rejects_missing_content_size`: raises `ValueError` mentioning
    `contentSize`.
  - `test_lint_ok_on_seed`: running `lint` on the real `LESSONS.md` and
    `TOOLS.md` returns `[]`.
  - `test_lint_flags_bad_platform`
  - `test_lint_flags_unpromoted_repeat`: an entry with two `seen` lines and
    `promoted: no` gives an error containing `promote`.
- [ ] **Step 3: Run them** with the test command from Global Constraints.
  Expected: FAIL (import errors).
- [ ] **Step 4: Implement** `filmcfg.py` and `lint_memory.py`. The lessons
  parser splits on `### `; the fields are `- key: value` lines.
- [ ] **Step 5: Write the seed `LESSONS.md`.** One entry per spec seed item:
  - display sleep: `caffeinate -d -u`
  - covered window: park it on a free display
  - avfoundation device index: use `2:none` and list devices with
    `ffmpeg -f avfoundation -list_devices true -i ""`
  - stuck recorder: SIGINT → wait 10 s → kill
  - clip past the recording end: freeze 1300 ms before the end
  - costume voice: keep `NN_fx.wav`
  - walk-in timing: key on `presenceDone`
  - numpy ints in JSON: cast to `int()`
  - blank take while the display wakes: re-shoot it, and `check_take` catches it

  Each entry has `seen: yofardev_ai film, 2026-11-07/08` and the
  `promoted:` target it will get in Tasks 2–8. Use a placeholder `no` only
  where nothing promotes it.

  **`TOOLS.md`** lists, with versions and verdicts:
  - ffmpeg avfoundation + h264_videotoolbox (keep)
  - image-match sync (keep)
  - Remotion 4.0.541 (keep)
  - pretty_midi + fluidsynth + MuseScore_General.sf3 + pedalboard (keep)
  - pyloudnorm −14 LUFS (keep)
  - `kill -9` of the recorder (avoid)
  - Suno (optional drop-in, never waited on)
- [ ] **Step 6: Run the tests and the lint CLI.** Expected: all PASS, and
  `lint_memory.py` prints `ok`.
- [ ] **Step 7: Commit** with the message
  `feat: skill skeleton, film config, seeded memory + linter`.

### Task 2: Pipeline: sync, run audio, events

**Files:**
- Create: `pipeline/sync.py`, `pipeline/runaudio.py`, `pipeline/events.py`
  (ported from yofardev `film/tools/`, with every hard-coded path, size and
  `KEEP` replaced by `FilmConfig`), `tests/fixtures/make_take.py`,
  `tests/test_sync.py`, `tests/test_runaudio.py`, `tests/test_events.py`

**Interfaces:**
- Consumes: `filmcfg.load`.
- Produces the same output files as the originals:
  - `clips/<tag>.mp4`
  - `clips/<tag>.json` (keys `offset`, `rect`, `duration`, `residuals`)
  - `clips/<tag>_voice.wav` and `clips/<tag>_foley.wav`
  - the events index at `<film>/video/src/data/events.json`

  Function signatures: `sync.main(cfg, tag) -> dict`,
  `runaudio.main(cfg, tag) -> list[tuple]` and `events.main(cfg) -> dict`.
  Foley paths resolve against `cfg.repo_root`.

- [ ] **Step 1: Write the fixture generator.**
  `make_take.py::make_take(dir, tag, *, offset_ms, rect, n_grabs, record_s, voice_effect=None, starts=None, sentences=None)`.
  It writes a tiny synthetic take:
  - an ffmpeg-made `.mov` of moving noise patches inside `rect` on a 1920×1080
    canvas
  - a `.recstart` file
  - a `wow/run/timeline.json` with grabs cut from the same frames at PXR
    0.25, plus events and audio entries
  - sine WAVs, plus `NN_fx.wav` when `voice_effect` is set
- [ ] **Step 2: Write the failing tests:**
  - `test_sync_parked_window`: the offset found is within 17 ms of
    `offset_ms`, and the rect equals the parked rect.
  - `test_sync_finds_moved_window`: the rect is 200 px off the parked spot and
    is still found.
  - `test_sync_json_is_plain`: `json.loads` round-trips, and no numpy types
    leak.
  - `test_runaudio_uses_fx`: the voice track RMS matches the fx sine, not the
    dry one.
  - `test_runaudio_count_mismatch`: 3 starts and 2 sentences place 2 and print
    `warning`.
  - `test_events_keeps_configured_types`
- [ ] **Step 3: Run the tests.** Expected: FAIL.
- [ ] **Step 4: Port the three scripts.** Keep the matching algorithms
  unchanged; the regression depends on them.
- [ ] **Step 5: Run the tests.** Expected: PASS.
- [ ] **Step 6: Commit** with the message `feat: config-driven sync, run audio and event index`.

### Task 3: Music engine and storybook style

**Files:**
- Create: `music/engine.py`, `music/styles/__init__.py`,
  `music/styles/storybook.py`, `music/compose.py`, `music/mix.py`,
  `tests/test_music.py`

**Interfaces:**
- Consumes: `FilmConfig` (`bpm`, `seed`, `soundfont`, `music_style`), and
  `<film>/music/sections.json` (list of `{id, bars, from, dur, startBar}`).
- Produces:
  - `compose.main(cfg) -> list[Path]` (stems written to
    `<film>/music/stems/`)
  - `mix.main(cfg) -> Path` (writes `<film>/music/score.wav`, 48 kHz)
  - the style protocol, a module with
    `build(sections: list[dict], rng: random.Random, eng: Engine) -> dict[str, pretty_midi.PrettyMIDI]`
    (one MIDI per stem name)

  The storybook style must accept the section ids
  `cold, title, listen, tools, wardrobe, journey, world, hood, finale`, and map
  any unknown id to the `listen` role.

- [ ] **Step 1: Write the failing tests:**
  - `test_storybook_deterministic`: the same seed gives identical MIDI note
    lists.
  - `test_unknown_section_id_falls_back`
  - `test_compose_and_mix_length`: skipped if fluidsynth or the soundfont is
    missing. A two-section `sections.json` (4 + 2 bars at 96 BPM) gives a
    `score.wav` of ≈ (6 + 3 tail) × 2.5 s ± 0.5 s, at −14 ± 1 LUFS.
- [ ] **Step 2: Run the tests.** Expected: FAIL.
- [ ] **Step 3: Split yofardev `music/compose.py`.**
  - helpers (`t`, `root`, `tones`, `voiced`, the fluidsynth render) →
    `engine.py`
  - chords, cycles, themes and per-section writing → `styles/storybook.py`
  - Keep the random call order identical, so seed 7 reproduces the existing
    score.

  Port `mix.py` with its `CHAINS` unchanged. If the soundfont is missing,
  `engine.py` downloads it to the default path, and logs that it did.
- [ ] **Step 4: Run the tests.** Expected: PASS (or SKIP for the fluidsynth
  test, with the reason printed).
- [ ] **Step 5: Commit** with the message `feat: style-driven score engine with the storybook style`.

### Task 4: Film mix and Remotion template

**Files:**
- Create: `pipeline/mixfilm.py` (ported; reads `<film>/work/edl.json`,
  `<film>/music/score.wav`, the run WAVs in `clips/`, and beds from
  `cfg.beds_dir`), `templates/remotion/**`, `tests/test_mixfilm.py`
- Template contents:
  - `package.json` (the exact dependency versions of yofardev
    `film/video/package.json`), `remotion.config.ts`, `tsconfig.json`
  - `scripts/sections.ts` and `scripts/edl.ts`, unchanged in behaviour
  - `src/lib/`: `Backdrop`, `Phone`, `Clip` (keeps its Freeze at
    `runDuration - 1300 ms`), `Callout`, `Type`, `ToolChip`, `Cards`,
    `CodeWall`, `segtypes.ts`, `consts.ts`, `theme.ts`
  - `src/` example film: `Root.tsx`, `Film.tsx`, `sections.ts`, `plans.ts`,
    `audio.ts`, and `scenes/Example.tsx`, using one synthetic clip

**Interfaces:**
- Consumes: the EDL contract `{sections:[{id,bars,from,dur}], regions:[Region], hits:[{at,kind}]}`, with `Region` exactly as in yofardev
  `film/video/src/audio.ts`.
- Produces:
  - `mixfilm.main(cfg) -> Path` (writes `work/soundtrack.wav`)
  - a template whose `src/lib` is **API-compatible** with yofardev's: same
    file names, exports and props. Only `theme.ts` and `consts.ts` carry
    app-specific values (colours, fonts, the scene accent map, `BPM`). Every
    other lib file reads colours and fonts from `theme.ts`, never hard-coded.

- [ ] **Step 1: Write the failing tests:**
  - `test_mixfilm_loudness`: a synthetic EDL (one region, one `whoosh` hit),
    a sine `score.wav` and a voice WAV → `soundtrack.wav` at −14 ± 0.5 LUFS.
  - `test_mixfilm_ducks_under_voice`: the music level during the voice region
    is at least 6 dB lower than outside it.
- [ ] **Step 2: Run the tests.** Expected: FAIL.
- [ ] **Step 3: Port `mixfilm.py`** with the SFX designs and ducking
  unchanged.
- [ ] **Step 4: Run the tests.** Expected: PASS.
- [ ] **Step 5: Build the Remotion template.** Copy and generalize from
  yofardev `film/video/src/lib`. A grep of the lib (excluding `theme.ts` and
  `consts.ts`) must show no hex colour literals.
- [ ] **Step 6: Verify the template.** In a temp copy, run
  `npm ci && npx tsc --noEmit && npx remotion still Film /tmp/x.png --frame=30`.
  Expected: exit 0, and the PNG exists.
- [ ] **Step 7: Commit** with the message `feat: film mix and Remotion template`.

### Task 5: QA scripts

**Files:**
- Create: `qa/check_take.py`, `qa/check_film.py`, `tests/test_check_take.py`,
  `tests/test_check_film.py`

**Interfaces:**
- Consumes: `FilmConfig`, the take layout from Task 2, and the fixture
  generator.
- Produces:
  - `check_take.check(cfg, tag) -> list[str]` (failure messages; empty means
    pass). CLI: `--film <dir> [--cap] [tag…|--all]`, exit code 1 on any
    failure.
  - `check_film.check(master: Path, *, expected_s: float, edl: Path | None) -> list[str]`

`check_take` fails on:
- a recording with no frames, or one that ends before the timeline's last
  sample (`recording ends before run`)
- a frozen stretch over 2 s while timeline samples change
- frames inside the rect that are more than 90 % black (`blank frames`)
- the number of `start` events ≠ the number of sentences
- `voiceEffect` ≠ `none` with a missing `NN_fx.wav`
- an `.ffmpeg.log` containing `error`

`check_film` fails on:
- a black run of 0.5 s or more, or a frozen run of 3 s or more outside
  `hold` sections
- duration ≠ `expected_s` ± 1 frame
- integrated loudness outside −14 ± 0.5
- an audio/video stream duration gap over 1 frame
- RMS below −45 dBFS inside an EDL region whose `voice` > 0

- [ ] **Step 1: Write the failing tests:**
  - `test_take_ok`
  - `test_take_short_recording`
  - `test_take_blank`
  - `test_take_count_mismatch`
  - `test_take_missing_fx`
  - `test_film_ok`
  - `test_film_black_gap`
  - `test_film_loudness_off`
  - `test_film_silent_voice_region`

  The film tests build small synthetic MP4s with ffmpeg `lavfi`.
- [ ] **Step 2: Run the tests.** Expected: FAIL.
- [ ] **Step 3: Implement** with ffmpeg `blackdetect`, `freezedetect` and
  `ebur128` (or pyloudnorm on the decoded audio), using the thresholds above.
- [ ] **Step 4: Run the tests.** Expected: PASS.
- [ ] **Step 5: Mark the promoted lessons.** In `LESSONS.md`, mark the
  lessons now enforced by checks (display wake blank, clip past end, missing
  `_fx`) as `promoted: qa/check_take.py`. Run `lint_memory.py`.
- [ ] **Step 6: Commit** with the message `feat: per-take and final film QA checks`.

### Task 6: Capture backends, harness guide, scaffolder, build script

**Files:**
- Create: `capture/macos.sh`, `capture/macos.md`, `capture/android.md`,
  `capture/ios-sim.md`, `capture/web.md`, `harness/flutter.md`,
  `harness/timeline.schema.json`, `scripts/new_film.sh`,
  `templates/film/{film.json,.gitignore,PLAN.md,README.md}`,
  `pipeline/build.sh`, `tests/test_capture_args.py`, `tests/test_new_film.py`

**Interfaces:**
- Consumes: `FilmConfig` (Task 1), Tasks 2–5 entry points, `templates/remotion` (Task 4).
- Produces:
  - `capture/macos.sh --film <dir> <tag> [-- harness args…]`. It reads the
    display device, window placement and harness command template from
    `film.json`, and it has the yofardev `capture.sh` behaviours:
    - frame-flow wait
    - `caffeinate -d -u` wrapping the run
    - SIGINT → wait → kill
    - `check_take` run on the take at the end, which exits non-zero on failure
  - `new_film.sh <app_repo>`, which creates `<app_repo>/film/` with
    `film.json`, `.gitignore` (`work/ node_modules/ out/ music/stems/ music/*.wav`),
    `PLAN.md` (the beat-sheet template from the spec's Pitch phase) and
    `video/` (copied from `templates/remotion`). It refuses to overwrite an
    existing `film/`.
  - `build.sh --film <dir> [render]`, which runs:
    1. sync and run audio for unsynced takes
    2. events
    3. `sections.ts`/`edl.ts`
    4. compose and mix
    5. mixfilm
    6. Remotion render (`--codec=h264 --crf=14 --muted --concurrency=6`)
    7. the mux (AAC 320k)
    8. `check_film`
    9. the web encode
    10. a 4×4 contact sheet `<film>/out/contact.jpg` (ffmpeg `tile`)
    11. a last line with the size of `work/` (`du -sh`)

    The output paths are `<film>/out/<app>-film.mp4` and
    `<film>/<app>-film.mp4`. When `film.json` has `"musicStyle": "dropin"`,
    steps 4's compose and mix are skipped, and `<film>/music/score.wav` (the
    owner's track) must exist, or the build exits with that message.

  The `film.json` harness command template uses `{tag}`, `{x}`, `{y}`,
  `{w}`, `{h}` and `{out}` placeholders, and each one is substituted as a
  single argument.

- [ ] **Step 1: Write the failing tests:**
  - `test_capture_args_quote_spaces`: a harness template with
    `--dart-define=KOKORO_SRC=/a b/c` and `{out}` set to a path with spaces
    produces an argv where each define is one element. Test the pure
    `build_argv(cfg, tag, extra)` helper that `macos.sh` calls through
    `uv run`.
  - `test_new_film_scaffold`: the tree exists, the `.gitignore` lines are
    present, and `film.json` loads with `filmcfg.load`.
  - `test_new_film_refuses_existing`
- [ ] **Step 2: Run the tests.** Expected: FAIL.
- [ ] **Step 3: Implement.** The `.md` guides for android, ios-sim and web
  start with a line marking them UNTESTED, and they list the recorder from the
  spec's backend table plus its known limits:
  - `adb screenrecord` caps at 3 min and has a variable frame rate
  - `scrcpy --record` is preferred
  - the emulator is preferred over a phone

  `harness/flutter.md` points at yofardev `integration_test/wow_capture_test.dart`,
  `integration_test/support/kokoro_capture_synthesizer.dart` and the
  `setupServiceLocator(...)` hooks. It lists the required timeline fields and
  matches `timeline.schema.json`: `size`, `frames`, `clockStartEpochMs`,
  `events[{ms,type,…}]`, `samples[{ms,…}]` and `audio[{file,text}]`.
- [ ] **Step 4: Run the tests.** Expected: PASS.
- [ ] **Step 5: Commit** with the message
  `feat: macOS capture, platform guides, scaffolder and build script`.

### Task 7: Regression: rebuild the yofardev_ai film

**Files:**
- Create: `regress/yofardev.sh`, `regress/compare.py`, `tests/test_compare.py`

**Interfaces:**
- Consumes: everything above.
- Produces:
  - `compare.compare(master: Path, new: Path, *, master_edl: Path, new_edl: Path, master_sections: Path, new_sections: Path, master_sync: Path, new_sync: Path) -> list[str]`,
    which checks the regression pass criteria from Global Constraints
  - `regress/yofardev.sh`, which:
    1. scaffolds `~/.cache/app-showcase-film/regress/yofardev/film`
       (deleting only that directory first)
    2. writes a `film.json` with yofardev values: content size 576×1024,
       PXR 0.25, BPM 96, style storybook, seed 7, beds from yofardev
       `assets/foley`, and `repoRoot` = the yofardev repo
    3. overlays yofardev's film-specific edit files: `video/src/{Film.tsx,
       Root.tsx, plans.ts, sections.ts, audio.ts, scenes/, data/code.json,
       lib/theme.ts, lib/consts.ts}` (never the other `lib/` files, so the
       template lib is what's tested)
    4. points `--cap` at yofardev `film/work/cap` (read-only) and symlinks
       its soundfont
    5. runs `check_take --all`, `build.sh`, then `compare.py` against
       yofardev `film/out/yofardev-ai-film.mp4`, `film/work/edl.json`,
       `film/music/sections.json` and `film/work/clips/*.json`
    6. prints `REGRESSION PASS` or the failures

- [ ] **Step 1: Write the failing tests:**
  - `test_compare_identical`: the same file twice gives `[]`.
  - `test_compare_duration_off`: a 2-frame-longer synthetic gives a failure
    naming `duration`.
  - `test_compare_edl_diff`
- [ ] **Step 2: Run the tests.** Expected: FAIL.
- [ ] **Step 3: Implement `compare.py` and `yofardev.sh`.** PSNR comes from
  `ffmpeg -lavfi psnr` on 20 frames sampled at even intervals, and loudness
  from `ebur128` on both files.
- [ ] **Step 4: Run the tests.** Expected: PASS.
- [ ] **Step 5: Run the regression in the background.** Captures are ~15 GB
  and the render takes tens of minutes. Run
  `bash ~/.claude/skills/app-showcase-film/regress/yofardev.sh 2>&1 | tee ~/.cache/app-showcase-film/regress/last.log`.
  Expected: `check_take` reports every take OK or lists known issues, and the
  run ends with `REGRESSION PASS`.

  If it fails, fix the ported code, not the thresholds. If one take was
  really bad in the original, record it in `LESSONS.md` and say so in the
  report.
- [ ] **Step 6: Commit** with the message `test: yofardev film regression`.

### Task 8: SKILL.md, retro procedure, final memory pass

**Files:**
- Modify: `SKILL.md` (full), `LESSONS.md`, `TOOLS.md`

**Interfaces:**
- Consumes: every script path above (SKILL.md is the index to them).

- [ ] **Step 1: Write `SKILL.md`** under 250 lines. It covers:
  - the frontmatter `name: app-showcase-film`, with a description that
    triggers on "showcase video", "portfolio film", "demo video of my app"
    and "trailer for the app"
  - Phases 0–8 as in the spec, each naming its script
  - **Gate 1** (story outline: `film/PLAN.md` approved before any capture)
    and **Gate 2** (final review)
  - the preflight checklist generated from every `promoted:` lesson that
    points at `SKILL.md#preflight`
  - the rule "read LESSONS.md and TOOLS.md first"
  - the rule "write a lesson the moment a problem is solved"
  - the retro steps: append lessons and `seen` lines, promote anything at
    ≥ 2, run `lint_memory.py`, commit the skill repo with the message
    `memory: <app> film`
  - the anti-goals verbatim from the spec
  - in the music phase: write a Suno-style prompt matching `sections.json`
    into `film/README.md` (as yofardev's does) so the owner can drop in a
    track (`"musicStyle": "dropin"`), and never wait on one
  - in the review gate: send the master and `out/contact.jpg`
- [ ] **Step 2: Fill the remaining `promoted:` targets.** Point every seed
  lesson at its preflight line, check or template default (end freeze →
  `templates/remotion/src/lib/Clip.tsx`; caffeinate, SIGINT and device index →
  `capture/macos.sh`). Run `lint_memory.py`. Expected: `ok`.
- [ ] **Step 3: Run the full test suite and the lint.** Expected: all PASS,
  with only the fluidsynth test allowed to SKIP.
- [ ] **Step 4: Commit** with the message `docs: SKILL.md with phases, gates and retro`.
