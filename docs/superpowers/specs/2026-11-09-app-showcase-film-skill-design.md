# Design: `app-showcase-film` skill

Date: 2026-11-09. Status: draft for owner review.

## Intent

A personal Claude Code skill that turns one of the owner's apps into a
polished portfolio film the way `film/` in yofardev_ai was made. The film uses
real captures of the running app, a scripted story, an original score and a
Remotion edit. The skill gets better with every film because it keeps a memory
of technical mistakes and of the tools that worked, so the next film does not
pay for the same lesson twice.

Why: the first film took many hours, and a lot of them went to problems that
are now known:
- the display slept and the capture device vanished
- a covered window stopped rendering
- clips ran past the recording end and showed the desktop wallpaper
- costume voice effects were dropped from the kept audio
- phones lit up before the avatar walked in

Earlier attempts by other agents were "mid". The bar is the yofardev_ai film.

## Users and scope

- **One user:** the owner, on their own apps, on their Mac, with Claude Code.
  The skill may assume this setup, including a second display, Homebrew tools,
  `uv`, Node and the Remotion skills already installed.
- **Apps are mostly Flutter** (owner's guess, not confirmed for every app).
  Flutter is first-class. Other stacks get the same phases, with harness
  guidance written per stack only when one is first needed. That gap gets
  logged as a lesson.
- **Not always desktop.** Capture must work for a macOS window, an Android
  emulator or device, the iOS simulator, and web.

## Goals

1. The film is produced end to end by the agent, with the owner involved only
   at two gates: the story outline, and the final review.
2. Every app frame is the real app, captured live. The app's own audio is used
   wherever it has any (voice, sound effects).
3. A memory of technical lessons and tool choices is read before work starts.
   It is written at the end of every film and whenever a problem is solved
   mid-film.
4. Each capture run is checked automatically right after it is recorded, so a
   bad take (blank, frozen, wallpaper, wrong window, missing audio) is redone
   at once, not discovered in the edit.

## Non-goals

- Learning the owner's taste (pacing, music style). At most, a short optional
  "taste notes" section in memory. The owner said it matters less than
  technical lessons.
- Vertical, social-media or multi-format cuts in v1. One 16:9 master plus a
  web encode.
- Apps the owner does not own.

## Anti-goals (failure even if it "works")

- Faking the app: UI redrawn in Remotion, mockups or stills passed off as live
  footage. Overlays, callouts and framing are fine. The app inside the frame
  must be real.
- A real LLM, network or paid API call inside the capture harness. Scripts and
  canned responses only, so takes are repeatable and free.
- Captures, raw media or generated music committed to the app's repo
  (git-ignored work dir only). The final web encode and poster may be
  committed.
- Recording before the owner has approved the story outline.

## Owner decisions (as decided)

- **Driving the app:** the skill adds a capture harness to each app. Scripted
  runs, faked network and AI, logged event timings. External tap-and-type
  driving is not the main method.
- **Approval gate:** the story outline (concept, beats, shot list, rough
  timing) gets a yes before anything is recorded.
- **Memory focus:** technical mistakes and tool choices.

## Shape of the skill

Location: `~/.claude/skills/app-showcase-film/`.

```
SKILL.md            phases, gates, checklists (short; points to the rest)
LESSONS.md          the memory: one entry per lesson (format below)
TOOLS.md            the toolbox: what was used per step, verdict, version, notes
capture/            one guide per backend: macos.md, android.md, ios-sim.md, web.md
harness/            harness guide + Flutter reference (event log, grabs, fakes)
templates/          generalized copies of the yofardev_ai pipeline:
  sync.py, events.py, runaudio.py, mixfilm.py   (from film/tools)
  compose.py, mix.py                            (from film/music)
  remotion/         Backdrop, Phone, Clip (with end freeze), Callout, Type,
                    sections-on-bars, plans-from-events
  build.sh, capture.sh
qa/check_take.py    per-take automatic checks
qa/check_film.py    final checks on the master
```

The templates are taken from yofardev_ai's `film/` and stripped of app
specifics (names, colours, scripts). That film's directory stays the worked
example the skill links to.

## Phases

0. **Recon.** Read `LESSONS.md` and `TOOLS.md` first. Then read the app: its
   README and agent docs, the features worth showing, the platforms it builds
   for, its look (colours, fonts) and its own sounds.
1. **Pitch → GATE.** Write `film/PLAN.md`:
   - a one-line concept
   - a beat sheet with seconds and bars
   - a shot list, where each shot names the harness script that captures it
   - the capture backend chosen and why
   - the music section map

   Stop and ask the owner. Nothing is recorded until yes.
2. **Harness.** Add a capture mode to the app on a branch. It needs:
   - scripted runs selected by a define or flag
   - fakes for the AI and network
   - a timeline JSON with a wall-clock epoch and named events
   - sparse in-app grabs used for sync
   - app audio kept per event (including any processed variants, such as the
     `_fx.wav` lesson)

   The app's own tests must still pass.
3. **Capture.** Run the preflight checklist built from `LESSONS.md`, then
   record each run with the backend's guide. Run `check_take.py` on every take
   before moving on, and redo failures right away. Unattended captures (owner
   away) are allowed once the gate is passed.
4. **Sync and index.** Find the window/device rect and the clock offset by
   matching the in-app grabs. Build the events index and per-run audio.
5. **Edit.** Remotion at 1920×1080, 60 fps. Every cut hangs on a harness
   event, never on hand-typed seconds. Sections are rounded to musical bars.
   Clips freeze before the recording ends.
6. **Score and mix.** Original music composed from the section map, with the
   music ducked under app audio. Target loudness is −14 LUFS.
7. **Render and QA → GATE.** Run `check_film.py` (below), then build a contact
   sheet and send the master to the owner for review. Fix and re-render on
   feedback.
8. **Retro.** Append new lessons and tool verdicts. Promote any lesson that
   has fired twice (rule below). Report what was added.

`check_film.py` checks for:
- black, frozen or wallpaper frames
- A/V offset
- loudness
- silence where voice is expected
- the duration matching the plan

## Memory

**`LESSONS.md` entries** use one block per lesson:

```
### <short title>
- platform: macos | android | ios-sim | web | any
- phase: capture | harness | sync | edit | music | mix | render
- symptom: what was seen (e.g. "last 0.5 s of clip shows desktop wallpaper")
- cause: why
- fix: what to do / check (command or code pointer)
- seen: <film/app>, <date>  [one line per occurrence]
- promoted: no | <where in SKILL.md / which check>
```

**Promotion:** a lesson seen twice becomes part of the machinery, not just a
note. It turns into a preflight checklist line in `SKILL.md`, an automatic
check in `check_take.py` or `check_film.py`, or a template default (for
example, the end freeze in `Clip`). Then it is marked `promoted`.

**When it is written:** on the spot when a problem is solved mid-film (so a
compaction cannot lose it), plus a full retro at the end.

**`TOOLS.md`** lists for each step:
- the tool and version used
- a verdict: keep, replace or avoid
- why
- the alternatives tried

Example: "Remotion 4.0.541 — keep"; "kill -9 the recorder — avoid, use SIGINT
then wait".

**Seed:** the skill starts with the yofardev_ai lessons already in it:
- display sleep needs `caffeinate -d -u`
- a covered window freezes the app, so park it on a free display
- avfoundation needs the right device index
- a stuck recorder needs SIGINT → wait → kill
- a clip past the recording end shows wallpaper, so freeze 1.3 s before the end
- keep `_fx.wav` alongside the dry voice
- costume windows are timed on the walk-in (`presenceDone`), not the request
- sync needs JSON ints, not numpy types
- a recording made while the display wakes comes out blank, so re-shoot it

## Capture backends (the builder confirms each on first use)

| Platform | Recorder (first choice) | Notes known now |
|---|---|---|
| macOS window | ffmpeg avfoundation on a second display, 60 fps | proven here |
| Android | `scrcpy --record` (owner already uses scrcpy) | `adb screenrecord` caps at 3 min and has a variable frame rate; prefer the emulator for repeatability |
| iOS simulator | `xcrun simctl io booted recordVideo` | untested |
| Web | headless browser recording (e.g. Playwright) or ffmpeg of a browser window | untested |

Sync by matching in-app grabs is the same on every platform. Only the grab
call differs.

## Constraints

- The project rules of each app apply to the harness code (for yofardev_ai:
  the architecture test, `Result<T>`, typed code).
- Raw captures can be 15 GB+. Keep them in a git-ignored `film/work/` and say
  the size at the end.
- Outward actions (pushing, publishing the video, deleting captures) need the
  owner's yes, as usual.

## Definition of done (owner decided)

Packaging plus a regression test. The skill files, seed memory, templates
and QA scripts exist. Using only the skill's templates, the yofardev_ai film
is rebuilt from its existing captures in `film/work/cap`. The test covers
sync → events → audio → edit → score → mix → render → `check_film.py`, and
the result must match the current master: same duration, same cut points
within a frame, loudness within 0.5 LU. It also runs `check_take.py` over
the existing takes. No new capture is needed. The Android, iOS-simulator and
web backends ship as guides marked untested, and are confirmed on first real
use.

## Designer's calls (not yet confirmed by the owner)

- **The harness stays in the app.** After the film it is merged to the app's
  main branch, as in yofardev_ai, so later reshoots cost nothing. It lives
  under the test directories plus debug-only hooks (DI parameters that are null
  in production, debug fakes). It must pass the app's architecture tests for
  good.
- **Music is composed by the agent by default** (MIDI + soundfont + mastering,
  as in `compose.py`). Because `score.wav` is the only music input, the owner
  can drop in a generated or licensed track at any time. The skill writes a
  matching prompt (as `film/README.md` does), but never waits on one.
- **The skill is its own git repo**: `git init` inside
  `~/.claude/skills/app-showcase-film/`, local only, no remote unless the owner
  adds one. The retro phase ends with a commit of the memory and any promoted
  checks.

## Left to the builder

- How to generalize each template (which parameters, how the plan feeds them).
- The exact checks inside `check_take.py` and `check_film.py`, within the
  list above.
- The harness design for non-Flutter stacks, done when first needed.
- Whether the music generator keeps one style with parameters or offers a few
  presets.
- SKILL.md wording and length, following the skill-creator guidance.
