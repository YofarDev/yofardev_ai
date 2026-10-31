"""Assembles a wow captured by the running macOS app (moonshot M6 Task 6, rulings 6-7).

    uv run --with pillow --with numpy rive/tools/wow_capture.py <wow dir> <out dir>

`<wow dir>` is what `integration_test/wow_capture_test.dart` printed as `WOW_DIR`
(`timeline.json`, `frames/NNNN.rgba`, `audio/NN.wav`; `wet.rgba` / `dry.rgba` for wow1). A
`<wow dir>_timing` sibling (the CAPTURE=false run) adds `frame_cost.json`. Writes to `<out dir>`:
- `<wow>.gif`: 8 fps real time, 280 px wide, 64 colours (narrower if over 4 MB), from just before the user
  types to the end;
- `<wow>.mp4`: 15 fps, the whole run, the window's size, with the sentence WAVs muxed where their captions
  appeared (ffmpeg);
- `<wow>_beats.png`: the storyboard beats, each the captured frame nearest its moment;
- `<wow>_gates.txt`: one `ok` / `FAIL` line per gate (ruling 7), exit 1 on a FAIL;
- `<wow>_frame_cost.json` when the timing run exists.

M10 (rulings 11, 18, 20) adds `wardrobe`, `persona` and `caption` (several user turns each): no GIF; one silent
`<wow>.mp4` reel (<= 12 s, 10 fps, <= 720 px: the four signatures / the middle of each persona's speech / the
default caption pass), a `<wow>_sheet.webp` contact sheet and the gates.

M9 (ruling 20) adds `scene_<sceneId>` (an NPC poke, an in-app drag, one reply; the beach's gulls), `pairs`
(all 42 ordered journeys, frames at 2 fps: a 1 fps GIF at 8x, a 4x silent MP4, a 42-cell beat grid) and
`tour7` (seven scenes on a December night at a full moon).

M11 (contract v14): the scene list, the moon and festive scenes come from rive/CONTRACT.md (ten scenes,
`pairs` = all 90 ordered journeys); the path family joins the three open-air scenes (M11 ruling 6).
"""

from __future__ import annotations

import json
from pathlib import Path
import re
import shutil
import statistics
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_contract  # noqa: E402

GIF_FPS = 8
GIF_W = 280
GIF_COLOURS = 64
MP4_FPS = 15
GIF_MAX = 4 * 1024 * 1024


# ---------------------------------------------------------------- timeline helpers (tested)
def bilabial_words(text: str) -> int:
    """Words whose first letter is p, b or m (inline cues like `[g:nod]` dropped)."""
    text = re.sub(r"\[[a-z]:[^\]]*\]", " ", text)
    return sum(1 for w in re.findall(r"[A-Za-z']+", text) if w[0].lower() in "pbm")


def closures(samples: list[dict]) -> int:
    """Separate runs of closed lips (lipPress >= 0.5, jaw <= 0.1) while speaking."""
    runs, inside = 0, False
    for s in samples:
        closed = s["speaking"] and s["press"] >= 0.5 and s["jaw"] <= 0.1
        if closed and not inside:
            runs += 1
        inside = closed
    return runs


def audio_offsets(events: list[dict], audio: list[dict], t0: int) -> list[tuple[str, int]]:
    """(wav, ms after t0) for each caption, matched in order to the synthesised sentence of the
    same text."""
    used: set[int] = set()
    out = []
    for e in events:
        if e["type"] != "caption":
            continue
        for i, a in enumerate(audio):
            if i not in used and a["text"].strip() == e["text"].strip():
                used.add(i)
                out.append((a["file"], e["ms"] - t0))
                break
    return out


def foley_offsets(events: list[dict], t0: int, root: Path | None = None) -> list[tuple[str, int]]:
    """(wav, ms after t0) for each logged foley sound (M8: the harness logs the asset it played)."""
    base = root or Path(__file__).resolve().parents[2]
    return [(str(base / e["file"]), e["ms"] - t0) for e in events
            if e["type"] == "foley" and e.get("file") and (base / e["file"]).exists()]


def longest_closure(samples: list[dict]) -> dict:
    """The sample in the middle of the longest closed-lips run while speaking (a single grabbed frame
    lands inside a 66 ms window, so the middle of the longest run is the one most likely shown)."""
    best: list[dict] = []
    run: list[dict] = []
    for s in samples:
        if s["speaking"] and s["press"] >= 0.5 and s["jaw"] <= 0.1:
            run.append(s)
            if len(run) > len(best):
                best = list(run)
        else:
            run = []
    return best[len(best) // 2] if best else max(samples, key=lambda x: x["press"])


def _between(samples: list[dict], a: float, b: float) -> list[dict]:
    return [s for s in samples if a <= s["ms"] <= b]


def _first(events: list[dict], kind: str, after: float = -1) -> dict | None:
    return next((e for e in events if e["type"] == kind and e["ms"] > after), None)


def _line(text: str, ok: bool) -> str:
    return f"{text}: {'ok' if ok else 'FAIL'}"


def _common(tl: dict) -> list[str]:
    g = [_line(f"captured frames: {len(tl['frames'])}", len(tl["frames"]) > 0),
         _line(f"network attempts during the run: {tl['network_attempts']}", tl["network_attempts"] == 0)]
    if tl["samples"] and "shotSerial" in tl["samples"][0]:
        # M7: the stage camera cuts only at sentence starts (ruling 3)
        cuts, ok = cuts_at_sentences(tl["samples"], tl["events"])
        shots = sorted({x["shot"] for x in tl["samples"]})
        g.append(_line(f"camera cuts only at sentence starts: {ok} of {cuts} (shots seen: {', '.join(shots)})",
                       ok == cuts))
    return g


def gates_wow1(tl: dict, front_visible: bool) -> list[str]:
    s, ev = tl["samples"], tl["events"]
    g = _common(tl)
    g.append(_line(f"campfire at rain 1 in every sample ({len(s)})",
                   all(x["scene"] == "campfire" and x["rain"] >= 0.999 for x in s)))
    typing, send = _first(ev, "typing"), _first(ev, "send")
    lean = max((x["lean"] for x in _between(s, typing["ms"], send["ms"] + 300)), default=0.0)
    g.append(_line(f"listening lean while the user types: max {lean:.2f} (want > 0.3)", lean > 0.3))
    start = _first(ev, "start")
    breath = max((x["breath"] for x in _between(s, start["ms"] - 400, start["ms"] + 100)), default=0.0) \
        if start else 0.0
    g.append(_line(f"inhale before the first audio: breath max {breath:.2f} in the 400 ms before it (want > 0.5)",
                   breath > 0.5))
    words, runs = bilabial_words(tl["reply"]), closures(s)
    g.append(_line(f"lip closures while speaking: {runs} for {words} p/b/m words (want >= {0.7 * words:.1f})",
                   runs >= 0.7 * words))
    caps = [e for e in ev if e["type"] == "caption"]
    last = caps[-1] if caps else None
    stop = _first(ev, "stop", last["ms"]) if last else None
    brow = 0.0
    if last and stop:
        brow = max((x["browInner"] + x["browOuter"] for x in _between(s, stop["ms"] - 600, stop["ms"])), default=0.0)
    g.append(_line(f"brows up at the question's end: inner + outer max {brow:.2f} in its last 600 ms (want >= 0.3)",
                   brow >= 0.3))
    g.append(_line("front rain drawn over the avatar (wet vs dry frame, avatar box)", front_visible))
    return g


def gates_wow2(tl: dict) -> list[str]:
    s, ev = tl["samples"], tl["events"]
    g = _common(tl)
    tool = [x for x in s if x["tool"] == "getCurrentWeather"]
    span = (tool[-1]["ms"] - tool[0]["ms"]) if tool else 0
    g.append(_line(f"tool getCurrentWeather running for {span} ms (want >= 2000)", span >= 2000))
    tablet = sum(1 for x in tool if x["prop"] == "tablet") / len(tool) if tool else 0.0
    g.append(_line(f"tablet out while the tool runs: {tablet:.0%} of its samples (want >= 80%)", tablet >= 0.8))
    if tool and "tabletWeather" in tool[0]:
        # M8 ruling 14: the looked-up city's weather on the screen once the canned report is in
        # the report lands as the tool ends: look from the tool's start to the end of the run
        card = [x for x in s if x["ms"] >= tool[0]["ms"] and x["prop"] == "tablet" and x["tabletWeather"] != "none"]
        right = [x for x in card if x["tabletWeather"] == "rain" and x["tabletTemp"] == 18]
        g.append(_line(f"Tokyo on the tablet: rain 18 °C in {len(right)} samples, {len(card) - len(right)} wrong",
                       bool(right) and len(right) == len(card)))
    yaw = statistics.median(abs(x["yaw"]) for x in tool) if tool else 0.0
    g.append(_line(f"head turned while the tool runs: median |yaw| {yaw:.2f} (want >= 0.3)", yaw >= 0.3))
    start = _first(ev, "start", tool[-1]["ms"]) if tool else None
    g.append(_line("the answer is spoken after the tool", start is not None))
    if start:
        stop = _first(ev, "stop", start["ms"])
        answer = _between(s, start["ms"] + 1000, stop["ms"] if stop else 1e12)
        held = sum(1 for x in answer if x["prop"] != "none")
        g.append(_line(f"tablet put away 1 s into the answer: {held} samples still holding a prop", held == 0
                       and bool(answer)))
        ay = statistics.median(abs(x["yaw"]) for x in answer) if answer else 1.0
        g.append(_line(f"facing the user while answering: median |yaw| {ay:.2f} (want <= 0.15)", ay <= 0.15))
    return g


# ---------------------------------------------------------------- M7: journeys
# M8: the door family adds `grab` (after open) and `hang` (after enter)
PHASES = ["pullBack", "open", "grab", "exit", "close", "cut", "arriveOpen", "enter", "hang", "arriveClose",
          "vanish"]
# beats in which the avatar is clipped at the threshold (journey_choreography.dart)
CLIPPED = {"open", "grab", "exit", "close", "cut", "arriveOpen", "enter", "hang", "arriveClose"}


def journeys(samples: list[dict]) -> list[list[dict]]:
    """The samples of each journey (consecutive runs with a journey phase)."""
    runs: list[list[dict]] = []
    current: list[dict] = []
    for x in samples:
        if x.get("journey"):
            current.append(x)
        elif current:
            runs.append(current)
            current = []
    if current:
        runs.append(current)
    return runs


def phase_order(run: list[dict]) -> list[str]:
    seen: list[str] = []
    for x in run:
        if not seen or seen[-1] != x["journey"]:
            seen.append(x["journey"])
    return seen


def _journey_gates(run: list[dict], want_family: str, to: str) -> list[str]:
    g = []
    order = phase_order(run)
    # a short beat can fall between two samples (33 ms): keep the order, allow gaps
    in_order = [PHASES.index(p) for p in order] == sorted(PHASES.index(p) for p in order)
    # the cut lasts one frame when the preload is ready: it may fall between two samples
    g.append(_line(f"journey {want_family} → {to}: beats {'/'.join(order)} in order", in_order and
                   {"exit", "enter"} <= set(order) and bool({"cut", "arriveOpen"} & set(order))))
    fam = {x["family"] for x in run}
    g.append(_line(f"journey {want_family} → {to}: family {sorted(fam)}", fam == {want_family}))
    after_pull = [x for x in run if x["journey"] != "pullBack"]
    wide = sum(1 for x in after_pull if x["shot"] == "wide") / len(after_pull) if after_pull else 0.0
    g.append(_line(f"journey {want_family} → {to}: camera wide after the pull-back in {wide:.0%} of samples "
                   f"(want >= 95%)", wide >= 0.95))
    off = [x for x in run if x["presence"] != "onScreen"]
    unclipped = [x for x in off if x["journey"] not in CLIPPED]
    g.append(_line(f"journey {want_family} → {to}: avatar off screen only while clipped ({len(unclipped)} of "
                   f"{len(off)} samples not)", not unclipped))
    first_new = next((x for x in run if x["scene"] == to), None)
    at_cut = first_new is not None and PHASES.index(first_new["journey"]) >= PHASES.index("cut")
    g.append(_line(f"journey {want_family} → {to}: scene switched behind the closed threshold "
                   f"(first sample in {to}: {first_new['journey'] if first_new else 'never'})", at_cut))
    return g


def cuts_at_sentences(samples: list[dict], events: list[dict]) -> tuple[int, int]:
    """(camera cuts, those within 300 ms after a caption: a sentence start)."""
    caps = [e["ms"] for e in events if e["type"] == "caption"]
    cuts, ok = 0, 0
    last = None
    for x in samples:
        serial = x.get("shotSerial")
        if last is not None and serial != last and x.get("move") == "cut":
            cuts += 1
            if any(0 <= x["ms"] - c <= 300 for c in caps):
                ok += 1
        last = serial
    return cuts, ok


def gates_wow3(tl: dict) -> list[str]:
    s, ev = tl["samples"], tl["events"]
    g = _common(tl)
    runs = journeys(s)
    g.append(_line(f"journeys during the run: {len(runs)} (want 1)", len(runs) == 1))
    if runs:
        g += _journey_gates(runs[0], "door", "beach")
    beach = [x for x in s if x["scene"] == "beach"]
    dusk = min((x["dusk"] for x in beach), default=0.0)
    g.append(_line(f"the beach at the local sunset: dusk min {dusk:.2f} (want >= 0.5)", dusk >= 0.5 and bool(beach)))
    g.append(_line("the reply is spoken", _first(ev, "start") is not None))
    if runs and "jacket" in runs[0][0]:
        g += jacket_gates(runs[0], ev)
    send = _first(ev, "send")
    if runs and send:
        g.append(f"journey timing: starts {(runs[0][0]['ms'] - send['ms']) / 1000:.2f} s after send, lasts "
                 f"{(runs[0][-1]['ms'] - runs[0][0]['ms']) / 1000:.2f} s: info")
    return g


# ---------------------------------------------------------------- M8: the jacket, foley, NPCs
FOLEY_MIN_STEPS = 6  # footfalls per walk (a 1.6 s walk over 850 px at a 170 px stride: about 5 strides)


def foley(events: list[dict], kind: str | None = None) -> list[dict]:
    return [e for e in events if e["type"] == "foley" and (kind is None or e["kind"] == kind)]


def jacket_gates(run: list[dict], events: list[dict]) -> list[str]:
    """The door journey's jacket (M8 rulings 5-6, 18): grabbed before the walk out, hung after the walk in,
    always on exactly one of the peg and the hand, steps during both walks and a cloth sound at each contact."""
    g = []
    order = phase_order(run)
    g.append(_line(f"jacket beats: grab before exit, hang after enter ({'/'.join(order)})",
                   "grab" in order and "hang" in order and order.index("grab") < order.index("exit")
                   and order.index("hang") > order.index("enter")))
    shown = [x for x in run if x["journey"] not in ("pullBack", "vanish")]
    both = [x for x in shown if x["jacket"] and x["journeyJacket"] > 0.5]
    none_ = [x for x in shown if not x["jacket"] and x["journeyJacket"] < 0.5]
    g.append(_line(f"one jacket at a time: {len(both)} samples with two, {len(none_)} with none "
                   f"(of {len(shown)})", not both and not none_))
    held = [x for x in run if x["journey"] in ("exit", "enter")]
    g.append(_line(f"the jacket in the hand on both walks: {sum(1 for x in held if x['jacket'])} of {len(held)}",
                   bool(held) and all(x["jacket"] for x in held)))
    for walk in ("exit", "enter"):
        xs = [x["ms"] for x in run if x["journey"] == walk]
        steps = [e for e in foley(events, "step") if xs and xs[0] - 50 <= e["ms"] <= xs[-1] + 200] if xs else []
        g.append(_line(f"footsteps during {walk}: {len(steps)} (want >= {FOLEY_MIN_STEPS})",
                       len(steps) >= FOLEY_MIN_STEPS))
    contacts = []
    for beat in ("grab", "hang"):
        xs = [x["ms"] for x in run if x["journey"] == beat]
        if xs:
            contacts.append(sum(1 for e in foley(events, "cloth") if xs[0] <= e["ms"] <= xs[-1] + 100))
    g.append(_line(f"a cloth sound at each contact: {contacts} (want [1, 1])", contacts == [1, 1]))
    end = run[-1]
    g.append(_line(f"the jacket left with the door: hand {end['jacket']} at the last journey sample",
                   not end["jacket"]))
    return g


def npc_states(samples: list[dict]) -> list[str]:
    seen: list[str] = []
    for x in samples:
        if x.get("npc") and (not seen or seen[-1] != x["npc"]):
            seen.append(x["npc"])
    return seen


def gates_npc(tl: dict) -> list[str]:
    """`WOW=npc` (M8 ruling 18): poke the cat, name it, then a sad reply; the cat's intents follow."""
    s, ev = tl["samples"], tl["events"]
    g = _common(tl)
    g.append(_line(f"living room in every sample ({len(s)})", all(x["scene"] == "livingRoom" for x in s)))
    poke = _first(ev, "poke")
    after = [x for x in s if poke and x["ms"] >= poke["ms"]]
    react = next((x for x in after if x["npc"] == "react"), None)
    g.append(_line(f"poked: react {((react['ms'] - poke['ms']) if react and poke else -1)} ms after the tap "
                   f"(want <= 500)", bool(react and poke and react["ms"] - poke["ms"] <= 500)))
    send = _first(ev, "send")
    named = [x for x in s if send and x["ms"] >= send["ms"]]
    g.append(_line("named in the message: notice", any(x["npc"] == "notice" for x in named)))
    moved = [x for x in named if x["npc"] == "move"]
    reached = max((x["npcX"] for x in named), default=0.0)
    g.append(_line(f"the sad reply: the cat walks to the rug (move in {len(moved)} samples, npcX max "
                   f"{reached:.2f}, want >= 0.95)", bool(moved) and reached >= 0.95))
    x_jump = max((abs(b["npcX"] - a["npcX"]) for a, b in zip(s, s[1:])), default=0.0)
    g.append(_line(f"npcX moves smoothly: largest step between samples {x_jump:.3f} (want <= 0.1)", x_jump <= 0.1))
    g.append(f"cat states: {'/'.join(npc_states(s))}: info")
    return g


TOUR_FAMILIES = {"campfire": "door", "beach": "path", "deepSpace": "rocket", "livingRoom": "portal"}


def gates_tour(tl: dict) -> list[str]:
    s = tl["samples"]
    g = _common(tl)
    runs = journeys(s)
    want = tl.get("tour", [])
    g.append(_line(f"journeys during the run: {len(runs)} (want {len(want)})", len(runs) == len(want)))
    for run, to in zip(runs, want):
        g += _journey_gates(run, TOUR_FAMILIES[to], to)
    families = {x["family"] for run in runs for x in run}
    g.append(_line(f"every threshold family played: {sorted(families)}", families == set(TOUR_FAMILIES.values())))
    return g


# ---------------------------------------------------------------- M9: scenes, drags, gulls, pairs, December
# M11: the contract's scene table, in its order (contract v14: ten scenes)
_CONTRACT = check_contract.parse_contract()
SCENES = list(_CONTRACT["scenes"])
NPC_REACT_MS = 200
# the scenes whose file draws the moon / the festive dressing (M9 rulings 12-13; the contract's binders)
MOON_SCENES = set(_CONTRACT["v12_binders"]["moonPhase"])
FESTIVE_SCENES = set(_CONTRACT["v12_binders"]["festive"])
# the open-air scenes whose journeys between each other take the path (M9 ruling 5, M11 ruling 6)
PATH_SCENES = {"campfire", "beach", "forestCabin"}
# the pull's action per handle (ruling 8): the scene events it may fire
PULL_ACTIONS = {"cord": {"lightsOff", "lightsOn"}, "rope": {"bell"},
                "chain": {"whistle"}}   # M11 ruling 8: the train's whistle chain


def ruled_family(origin: str, to: str) -> str:
    """M9 ruling 5, M11 ruling 6: to deepSpace rocket, from deepSpace portal, between two of the open-air
    scenes (campfire, beach, forestCabin) path, else door."""
    if to == "deepSpace":
        return "rocket"
    if origin == "deepSpace":
        return "portal"
    if origin in PATH_SCENES and to in PATH_SCENES:
        return "path"
    return "door"


def _kind(tl: dict) -> str:
    """The run's script (`scene_<id>` runs are `scene`)."""
    return tl.get("kind", tl["wow"])


def _values(xs: list[dict], key: str) -> list[float]:
    return [x["drag"].get(key, 0.0) for x in xs if x.get("drag")]


def _speaking_common(tl: dict) -> list[str]:
    """`_common`, with the camera's sentence rule checked while the avatar speaks (a drag's scene event
    pulls the camera back before the reply; M7 ruling 3 is about speech)."""
    g = [_line(f"captured frames: {len(tl['frames'])}", len(tl["frames"]) > 0),
         _line(f"network attempts during the run: {tl['network_attempts']}", tl["network_attempts"] == 0)]
    ev = tl["events"]
    starts = [e["ms"] for e in ev if e["type"] == "start"]
    stops = [e["ms"] for e in ev if e["type"] == "stop"]
    if starts:
        talk = _between(tl["samples"], starts[0] - 300, (stops[-1] if stops else 1e12))
        cuts, ok = cuts_at_sentences(talk, ev)
        shots = sorted({x["shot"] for x in tl["samples"]})
        g.append(_line(f"camera cuts while speaking only at sentence starts: {ok} of {cuts} "
                       f"(shots seen: {', '.join(shots)})", ok == cuts))
    return g


def drag_gates(tl: dict) -> list[str]:
    """The in-app drag (M9 rulings 7-9): the handle's numbers moved as its kind says, the file got them
    (read back from the scene's view model), the action fired, and at least one drag haptic."""
    s, ev, info = tl["samples"], tl["events"], tl.get("drag") or {}
    start, end = _first(ev, "dragStart"), _first(ev, "dragEnd")
    if info.get("missing") or not start or not end:
        return [_line(f"drag performed on the scene's handle ({info.get('id', '?')})", False)]
    hid, kind, primary = info["id"], info["kind"], info["primary"]
    during = _between(s, start["ms"], end["ms"])
    after = _between(s, end["ms"], end["ms"] + 3000)
    g = [_line(f"{hid} ({kind}): the drag surface took the touch ({sum(1 for x in during if x['dragging'])} "
               f"dragging samples of {len(during)})", any(x["dragging"] for x in during))]
    reads = [abs(x["dragRead"]) for x in during + after if x.get("dragRead") is not None]
    want_read = {"pull": 0.5, "poke": 0.5, "trail": 4, "spin": 0.05, "aim": 0.2}[kind]
    g.append(_line(f"{hid}: {primary} read back from the scene file: max {max(reads, default=0.0):.2f} "
                   f"(want >= {want_read})", max(reads, default=0.0) >= want_read))
    if kind == "pull":
        peak = max(_values(during, primary), default=0.0)
        g.append(_line(f"{hid} pulled: peak {peak:.2f} (want >= 0.6)", peak >= 0.6))
        rest = _values(after, primary)
        g.append(_line(f"{hid} springs back: {rest[-1] if rest else -1:.2f} 3 s after the release (want <= 0.05)",
                       bool(rest) and rest[-1] <= 0.05))
        want = PULL_ACTIONS.get(hid, set())
        fired = [e["name"] for e in ev if e["type"] == "sceneEvent" and start["ms"] <= e["ms"] <= end["ms"] + 800]
        g.append(_line(f"{hid}: the action fired ({', '.join(fired) or 'none'}; want one of {sorted(want)})",
                       bool(want & set(fired))))
        if hid == "rope":
            bells = [e for e in foley(ev, "bell") if start["ms"] <= e["ms"] <= end["ms"] + 800]
            g.append(_line(f"rope: the bell rang ({len(bells)} bell sounds)", len(bells) >= 1))
    elif kind == "poke":
        peak = max(_values(during, "poke"), default=0.0)
        g.append(_line(f"poke: the stick came in (poke peak {peak:.2f}, want >= 0.99)", peak >= 0.99))
        xs, ys = _values(during, "pokeX"), _values(during, "pokeY")
        rx = (max(xs) - min(xs)) if xs else 0.0
        ry = (max(ys) - min(ys)) if ys else 0.0
        g.append(_line(f"poke: the tip followed the stir (pokeX range {rx:.2f}, pokeY range {ry:.2f}, want >= 0.3 "
                       f"each)", rx >= 0.3 and ry >= 0.3))
        rest = _values(after, "poke")
        g.append(_line(f"poke: eased out after the release (poke {rest[-1] if rest else -1:.2f} 3 s later, "
                       f"want <= 0.01)", bool(rest) and rest[-1] <= 0.01))
        flares = [e for e in ev if e["type"] == "sceneEvent" and e["name"] == "flare"
                  and start["ms"] <= e["ms"] <= end["ms"] + 800]
        g.append(f"poke: the fast stir flared {len(flares)} time(s) (not required): info")
    elif kind == "trail":
        n = max(_values(during + after, "trailN"), default=0.0)
        g.append(_line(f"{hid}: dots drawn (trailN max {n:.0f}, want >= 4)", n >= 4))
        fade = min(_values(during, "trailFade"), default=1.0)
        g.append(_line(f"{hid}: the trail shows while drawing (trailFade min {fade:.2f}, want <= 0.1)", fade <= 0.1))
        settled = _first(ev, "dragSettled")
        if hid == "wipe" and settled:
            # the cafe's window mists back over 20 s (ruling 8); the run waits for it
            last = s[-1]["drag"] if s and s[-1].get("drag") else {}
            back = settled["ms"] - end["ms"]
            g.append(_line(f"wipe: misted back {back / 1000:.1f} s after the stroke (trailFade "
                           f"{last.get('trailFade', 0.0):.2f}, trailN {last.get('trailN', -1):.0f} at the end; "
                           f"want 1 and 0)", last.get("trailFade", 0.0) >= 0.99 and last.get("trailN", -1) == 0))
    elif kind == "spin":
        # the handle's own number (deepSpace `spin`; M11 forestCabin `pinwheel`)
        vals = _values(during + after, primary)
        moved = max((min(v, 1 - v) for v in vals), default=0.0)
        g.append(_line(f"{primary} moved: {moved:.2f} of a turn at most (want >= 0.1)", moved >= 0.1))
        tail = [x["drag"].get(primary, 0.0) for x in after if x["ms"] >= end["ms"] + 2000]
        g.append(_line(f"{primary}: the inertia settled within 2 s ({len({round(v, 4) for v in tail})} distinct "
                       f"values after)", bool(tail) and max(tail) - min(tail) <= 1e-3))
    elif kind == "aim":
        # the handle's own number (rooftop `aim`; M11 library `ladder`)
        at_release = _values(_between(s, end["ms"] - 100, end["ms"]), primary)
        a = at_release[-1] if at_release else 0.0
        later = _values(after, primary)
        drift = max((abs(v - a) for v in later), default=1.0)
        g.append(_line(f"{primary} moved: {a:.2f} at the release (want |{primary}| >= 0.2)", abs(a) >= 0.2))
        g.append(_line(f"{primary} holds where left: drift {drift:.3f} in the 3 s after (want <= 0.02)", drift <= 0.02))
    haptics = [e for e in ev if e["type"] == "haptic" and start["ms"] - 50 <= e["ms"] <= end["ms"] + 1500]
    kinds = sorted({e["kind"] for e in haptics})
    g.append(_line(f"{hid}: drag haptics {len(haptics)} ({', '.join(kinds) or 'none'}; want >= 1)", len(haptics) >= 1))
    return g


def npc2_states(samples: list[dict]) -> list[str]:
    seen: list[str] = []
    for x in samples:
        if x.get("npc2") and (not seen or seen[-1] != x["npc2"]):
            seen.append(x["npc2"])
    return seen


def gull_gates(tl: dict) -> list[str]:
    """The beach's gulls (M9 ruling 10): landed after the calm, then a poke sends them off."""
    s, ev = tl["samples"], tl["events"]
    wait, poke = _first(ev, "gullWait"), _first(ev, "gullPoke")
    if not wait or not poke:
        return [_line("gulls: waited for the landing, then poked", False)]
    before = [x for x in s if x["ms"] < poke["ms"]]
    landed = next((x for x in before if x["npc2"] == "idle" and x["npc2X"] <= 0.01), None)
    order = npc2_states(before)
    g = [_line(f"gulls landed before the poke ({'/'.join(order)}; idle at npc2X 0 at "
               f"{(landed['ms'] / 1000) if landed else -1:.1f} s)",
               landed is not None and "move" in order and order.index("move") < order.index("idle"))]
    after = [x for x in s if x["ms"] >= poke["ms"]]
    react = next((x for x in after if x["npc2"] == "react"), None)
    g.append(_line(f"gulls startled: react {(react['ms'] - poke['ms']) if react else -1} ms after the poke "
                   f"(want <= {NPC_REACT_MS})", bool(react and react["ms"] - poke["ms"] <= NPC_REACT_MS)))
    flying = [x for x in after if x["npc2"] == "move"]
    gone = next((x for x in after if x["npc2"] == "away" and flying and x["ms"] > flying[0]["ms"]), None)
    top = max((x["npc2X"] for x in flying), default=0.0)
    g.append(_line(f"gulls flew off: move in {len(flying)} samples to npc2X {top:.2f}, then away "
                   f"{'at %.1f s' % (gone['ms'] / 1000) if gone else 'never'}", bool(flying) and gone is not None))
    return g


def gates_scene(tl: dict) -> list[str]:
    """`WOW=scene` (M9 ruling 20): one scene, its NPC poked, its handle dragged in the app, one reply."""
    s, ev = tl["samples"], tl["events"]
    scene = tl["scene"]
    g = _speaking_common(tl)
    g.append(_line(f"{scene} in every sample, no journey ({len(s)})",
                   all(x["scene"] == scene and not x["journey"] for x in s)))
    g.append(_line(f"the {scene} file on screen in every sample",
                   all(x.get("fileScene") == scene for x in s)))
    if scene == "beach":
        g += gull_gates(tl)
    poke = next((e for e in ev if e["type"] == "poke"), None)
    after = [x for x in s if poke and x["ms"] >= poke["ms"]]
    react = next((x for x in after if x["npc"] == "react"), None)
    g.append(_line(f"NPC poked ({poke['prop'] if poke else '?'}): react "
                   f"{(react['ms'] - poke['ms']) if react and poke else -1} ms after the poke (want <= {NPC_REACT_MS})",
                   bool(react and poke and react["ms"] - poke["ms"] <= NPC_REACT_MS)))
    g += drag_gates(tl)
    g.append(_line("the reply is spoken", _first(ev, "start") is not None))
    played = sorted({e["name"] for e in ev if e["type"] == "sceneEvent"})
    g.append(f"scene events: {', '.join(played) or 'none'}; NPC states: {'/'.join(npc_states(s))}: info")
    return g


def _runs_with_pairs(tl: dict) -> list[tuple[list[dict], str, str]]:
    """Each journey's samples with the (from, to) the harness asked for."""
    asked = [(e["from"], e["to"]) for e in tl["events"] if e["type"] == "journey"]
    return [(run, a, b) for run, (a, b) in zip(journeys(tl["samples"]), asked)]


def _drawn_after_cut(tl: dict, run: list[dict], origin: str, to: str) -> tuple[bool, str]:
    """The destination's file was loaded behind the closed threshold and drawn before the journey's end,
    and the origin's file stayed until then."""
    early = [x for x in run if x.get("fileScene") == to and x["journey"] in PHASES
             and PHASES.index(x["journey"]) < PHASES.index("close")]
    first = next((x for x in run if x.get("fileScene") == to), None)
    if first is None:
        return False, "never drawn during the journey"
    if early:
        return False, f"drawn early ({early[0]['journey']})"
    return True, f"drawn at {first['journey']}"


def gates_pairs(tl: dict) -> list[str]:
    """`WOW=pairs` (M9 ruling 20; M11: 90 pairs): every ordered pair of `SCENES` once, each in its ruled family, the destination drawn
    after every cut, one jacket at a time on the door, no blank frame (checked on the frames), 0 network."""
    g = _common(tl)
    runs = _runs_with_pairs(tl)
    asked = [(e["from"], e["to"]) for e in tl["events"] if e["type"] == "journey"]
    every = {(a, b) for a in SCENES for b in SCENES if a != b}
    g.append(_line(f"journeys during the run: {len(journeys(tl['samples']))} (want {len(every)})",
                   len(journeys(tl["samples"])) == len(every)))
    g.append(_line(f"every ordered pair once: {len(set(asked))} distinct of {len(asked)} asked "
                   f"({len(every - set(asked))} missing)", set(asked) == every and len(asked) == len(every)))
    bad_family, bad_beats, bad_scene, bad_drawn = [], [], [], []
    two = none_ = shown_n = doors = 0
    for run, a, b in runs:
        want = ruled_family(a, b)
        fam = {x["family"] for x in run}
        if fam != {want}:
            bad_family.append(f"{a}->{b} {sorted(fam)} (want {want})")
        order = phase_order(run)
        in_order = [PHASES.index(p) for p in order] == sorted(PHASES.index(p) for p in order)
        if not (in_order and {"exit", "enter"} <= set(order)):
            bad_beats.append(f"{a}->{b} {'/'.join(order)}")
        if run[0]["scene"] != a or run[-1]["scene"] != b:
            bad_scene.append(f"{a}->{b} ({run[0]['scene']}..{run[-1]['scene']})")
        ok, why = _drawn_after_cut(tl, run, a, b)
        if not ok:
            bad_drawn.append(f"{a}->{b} {why}")
        if want == "door" and run and "jacket" in run[0]:
            doors += 1
            shown = [x for x in run if x["journey"] not in ("pullBack", "vanish")]
            shown_n += len(shown)
            two += sum(1 for x in shown if x["jacket"] and x["journeyJacket"] > 0.5)
            none_ += sum(1 for x in shown if not x["jacket"] and x["journeyJacket"] < 0.5)
    g.append(_line(f"family per ruling 5: {len(runs) - len(bad_family)}/{len(runs)}"
                   + (f" (wrong: {'; '.join(bad_family)})" if bad_family else ""), not bad_family and bool(runs)))
    g.append(_line(f"beats in order with both walks: {len(runs) - len(bad_beats)}/{len(runs)}"
                   + (f" (bad: {'; '.join(bad_beats)})" if bad_beats else ""), not bad_beats and bool(runs)))
    g.append(_line(f"from and to scenes as asked: {len(runs) - len(bad_scene)}/{len(runs)}"
                   + (f" (bad: {'; '.join(bad_scene)})" if bad_scene else ""), not bad_scene and bool(runs)))
    g.append(_line(f"destination file drawn after the cut: {len(runs) - len(bad_drawn)}/{len(runs)}"
                   + (f" (bad: {'; '.join(bad_drawn)})" if bad_drawn else ""), not bad_drawn and bool(runs)))
    g.append(_line(f"door journeys ({doors}): one jacket at a time: {two} samples with two, {none_} with none "
                   f"(of {shown_n})", doors > 0 and not two and not none_))
    fams = {}
    for run, a, b in runs:
        fams[ruled_family(a, b)] = fams.get(ruled_family(a, b), 0) + 1
    lengths = [(run[-1]["ms"] - run[0]["ms"]) / 1000 for run, _, _ in runs]
    if lengths:
        g.append(f"journeys per family {dict(sorted(fams.items()))}; length mean {statistics.mean(lengths):.2f} s, "
                 f"max {max(lengths):.2f} s: info")
    return g


def gates_tour7(tl: dict) -> list[str]:
    """`WOW=tour7` (M9 ruling 20): the seven scenes on a December night at a full moon."""
    s = tl["samples"]
    g = _common(tl)
    runs = journeys(s)
    want = tl.get("tour", [])
    g.append(_line(f"journeys during the run: {len(runs)} (want {len(want)})", len(runs) == len(want)))
    origin = tl["scene"]
    for run, to in zip(runs, want):
        g += _journey_gates(run, ruled_family(origin, to), to)
        origin = to
    world = max(abs(x["moonPhase"] - 0.5) for x in s)
    g.append(_line(f"moon phase near full: |moonPhase - 0.5| max {world:.3f} (want <= 0.05)", world <= 0.05))
    reads = {}
    for x in s:
        f = x.get("fileScene")
        if f in MOON_SCENES and f == x["scene"] and x.get("moonRead") is not None:
            reads.setdefault(f, []).append(x["moonRead"])
    seen = {x["scene"] for x in s} & MOON_SCENES
    worst = max((abs(v - 0.5) for vs in reads.values() for v in vs), default=1.0)
    g.append(_line(f"moonPhase written to every moon scene's file: {len(reads)}/{len(seen)} scenes read back, worst "
                   f"|read - 0.5| {worst:.3f} (want <= 0.05)", set(reads) == seen and worst <= 0.05))
    fest = min(x["festive"] for x in s)
    g.append(_line(f"December: festive {fest:.2f} in every sample (want 1)", fest >= 0.999))
    freads = {}
    for x in s:
        f = x.get("fileScene")
        if f in FESTIVE_SCENES and f == x["scene"] and x.get("festiveRead") is not None:
            freads.setdefault(f, []).append(x["festiveRead"])
    fseen = {x["scene"] for x in s} & FESTIVE_SCENES
    fmin = min((v for vs in freads.values() for v in vs), default=0.0)
    g.append(_line(f"festive written to the indoor scenes' files: {len(freads)}/{len(fseen)} read back, min {fmin:.2f} "
                   f"(want 1)", set(freads) == fseen and fmin >= 0.999))
    hats = sorted({x["hat"] for x in s})
    tops = sorted({x["top"] for x in s})
    g.append(_line(f"the December outfit shown: hat {hats}, top {tops} (want santaHat, christmasSweater)",
                   hats == ["santaHat"] and tops == ["christmasSweater"]))
    families = {x["family"] for run in runs for x in run}
    g.append(_line(f"every threshold family played: {sorted(families)}",
                   families == {"door", "path", "portal", "rocket"}))
    return g


# ---------------------------------------------------------------- M10: wardrobe, personas, captions
M10_KINDS = {"wardrobe", "persona", "caption"}
COSTUMES = ["batman", "robocop", "soubrette", "singularity"]
# the signature clip is <= 1.2 s (ruling 6); its gesture_done must land within this after the trigger
SIGNATURE_DONE_MS = 2500
# (topTint drawn, hatTint drawn, costume) at each wardrobe turn's end
WARDROBE_WANT = {"topTint blue": (True, False, "none"), "hatTint red": (True, True, "none"),
                 **{c: (False, False, c) for c in COSTUMES}, "back to normal": (False, True, "none")}
PERSONA_ORDER = ["doomer", "philosopher", "coach"]  # mean pitch ascending (body_language.dart postures)
CAPTION_PASSES = ["default", "reduceMotion", "textScale"]
BUBBLE_SHARE_MIN = 0.5
ANCHOR_SHARE_MIN = 0.9
BUBBLE_MOVE_DP = 1.0
# evidence caps (ruling 18): one silent reel per run, the contact sheet as WebP
REEL_MAX_S = 12.0
REEL_FPS = 10
REEL_MAX_W = 720


def turn_windows(tl: dict) -> list[tuple[dict, float, float]]:
    """(the `turn` event, its start, its end) per user turn: from the `turn` event to its `turnEnd` (else the
    next turn, else the last sample)."""
    ev = tl["events"]
    turns = [e for e in ev if e["type"] == "turn"]
    last = tl["samples"][-1]["ms"] if tl["samples"] else 0
    out = []
    for k, t in enumerate(turns):
        end = next((e["ms"] for e in ev if e["type"] == "turnEnd" and e.get("i") == t.get("i")), None)
        if end is None:
            end = turns[k + 1]["ms"] if k + 1 < len(turns) else last
        out.append((t, t["ms"], end))
    return out


def alpha(argb: int | None) -> int:
    return -1 if argb is None else (int(argb) >> 24) & 0xFF


def _hex(argb: int | None) -> str:
    return "none" if argb is None else f"#{int(argb) & 0xFFFFFFFF:08X}"


def _in(ev: list[dict], kind: str, a: float, b: float, **match: object) -> list[dict]:
    return [e for e in ev if e["type"] == kind and a <= e["ms"] <= b and all(e.get(k) == v for k, v in match.items())]


def _m10_common(tl: dict) -> list[str]:
    """Frames and the network as gates; the camera's sentence rule as info (the M10 runs walk and gesture
    between sentences)."""
    g = [_line(f"captured frames: {len(tl['frames'])}", len(tl["frames"]) > 0),
         _line(f"network attempts during the run: {tl['network_attempts']}", tl["network_attempts"] == 0)]
    if tl["samples"] and "shotSerial" in tl["samples"][0]:
        cuts, ok = cuts_at_sentences(tl["samples"], tl["events"])
        shots = sorted({x["shot"] for x in tl["samples"]})
        g.append(f"camera cuts at sentence starts {ok} of {cuts} (shots seen: {', '.join(shots)}): info")
    return g


def _settled(samples: list[dict], end: float, n: int = 10) -> list[dict]:
    """The last [n] samples before a turn's end (its settled state)."""
    return [x for x in samples if x["ms"] <= end][-n:]


def gates_wardrobe(tl: dict) -> list[str]:
    """`WOW=wardrobe` (M10 rulings 5-6, 20): each tint read back from the file as written (a colour, then
    transparent under a costume); each costume plays `signature` once, ended by the file's `gesture_done`;
    the plain outfit plays none; every turn walks off and back (two `presence_done`)."""
    s, ev = tl["samples"], tl["events"]
    g = _m10_common(tl)
    g.append(_line(f"living room in every sample ({len(s)})", all(x["scene"] == "livingRoom" for x in s)))
    turns = turn_windows(tl)
    labels = [t["label"] for t, _, _ in turns]
    g.append(_line(f"wardrobe turns: {len(turns)} ({', '.join(labels)}; want {len(WARDROBE_WANT)})",
                   labels == list(WARDROBE_WANT)))
    read: dict[str, dict] = {}
    for t, a, b in turns:
        label = t["label"]
        want = WARDROBE_WANT.get(label)
        last = _settled(s, b)
        if want is None or not last:
            g.append(_line(f"{label}: settled samples", False))
            continue
        top_on, hat_on, costume = want
        x = last[-1]
        read[label] = x
        exact = all(y.get("vmTopTint") == y["tintTopWant"] and y.get("vmHatTint") == y["tintHatWant"] for y in last)
        shape = (alpha(x.get("vmTopTint")) > 0) == top_on and (alpha(x.get("vmHatTint")) > 0) == hat_on \
            and alpha(x.get("vmTopTint")) >= 0 and alpha(x.get("vmHatTint")) >= 0
        g.append(_line(f"{label}: tints read back topTint {_hex(x.get('vmTopTint'))} (want "
                       f"{'a colour' if top_on else 'transparent'}), hatTint {_hex(x.get('vmHatTint'))} (want "
                       f"{'a colour' if hat_on else 'transparent'}), as written in the last {len(last)} samples",
                       exact and shape))
        g.append(_line(f"{label}: costume read back {x.get('vmCostume')} (want {costume})",
                       all(y.get("vmCostume") == costume for y in last)))
        walks = _in(ev, "presenceDone", a, b)
        g.append(_line(f"{label}: walked off and back ({len(walks)} presence_done, want >= 2)", len(walks) >= 2))
        sigs = _in(ev, "gesture", a, b, name="signature")
        if label in COSTUMES:
            done = [d for sig in sigs[:1] for d in _in(ev, "gestureDone", sig["ms"] + 1, sig["ms"] + SIGNATURE_DONE_MS)]
            vm = [y for sig in sigs[:1] for y in _between(s, sig["ms"], sig["ms"] + 1500)
                  if y.get("vmGesture") == "signature"]
            worn = sigs[0].get("costume") if sigs else None
            g.append(_line(f"{label}: signature played {len(sigs)} time(s) (want 1) in {worn}, gestureId read back "
                           f"signature in {len(vm)} samples, gesture_done "
                           f"{(done[0]['ms'] - sigs[0]['ms']) if done else -1} ms after it "
                           f"(want <= {SIGNATURE_DONE_MS})",
                           len(sigs) == 1 and worn == label and bool(vm) and bool(done)))
        else:
            g.append(_line(f"{label}: no signature ({len(sigs)} played)", not sigs))
        played = [e["name"] for e in _in(ev, "gesture", a, b)]
        g.append(f"{label}: gestures {', '.join(played) or 'none'}: info")
    for key, on, off in (("vmTopTint", "topTint blue", "batman"), ("vmHatTint", "hatTint red", "batman")):
        if on in read and off in read:
            ok = alpha(read[on].get(key)) > 0 and alpha(read[off].get(key)) == 0
            g.append(_line(f"{key[2:3].lower()}{key[3:]}: a colour after '{on}' ({_hex(read[on].get(key))}), "
                           f"transparent under {off} ({_hex(read[off].get(key))})", ok))
    return g


def _mean(xs: list[float]) -> float:
    return statistics.mean(xs) if xs else float("nan")


def persona_runs(tl: dict) -> dict[str, dict]:
    """Per persona turn: the gestures sent to the file and the AvatarVM lean / pitch / roll read back while
    speaking."""
    s, ev = tl["samples"], tl["events"]
    out: dict[str, dict] = {}
    for t, a, b in turn_windows(tl):
        send = next((e["ms"] for e in _in(ev, "send", a, b)), a)
        spk = [x for x in _between(s, send, b) if x["speaking"]]
        read = [x for x in spk if x.get("vmPitch") is not None]
        out[t["persona"]] = {
            "armed": bool(t.get("profileArmed")),
            "spoke": bool(_in(ev, "start", send, b)),
            "gestures": [e["name"] for e in _in(ev, "gesture", send, b)],
            "speaking": len(spk), "read": len(read),
            "pitch": _mean([x["vmPitch"] for x in read]),
            "lean": _mean([x["vmLean"] for x in read if x.get("vmLean") is not None]),
            "leanMax": max((x["vmLean"] for x in read if x.get("vmLean") is not None), default=float("nan")),
            "roll": _mean([x["vmRoll"] for x in read if x.get("vmRoll") is not None]),
            "listenLean": max((x["lean"] for x in _between(s, a, send)), default=0.0),
        }
    return out


def gates_persona(tl: dict) -> list[str]:
    """`WOW=persona` (M10 ruling 11): one scripted reply as the doomer, the coach and the philosopher; the
    runs differ (gesture lists pairwise, mean AvatarVM pitch doomer < philosopher < coach)."""
    g = _m10_common(tl)
    runs = persona_runs(tl)
    g.append(_line(f"persona runs: {', '.join(runs)} (want {', '.join(sorted(PERSONA_ORDER))})",
                   set(runs) == set(PERSONA_ORDER)))
    for p, r in runs.items():
        g.append(_line(f"{p}: profile armed before the user typed", r["armed"]))
        g.append(_line(f"{p}: the reply is spoken", r["spoke"]))
        share = r["read"] / r["speaking"] if r["speaking"] else 0.0
        g.append(_line(f"{p}: pitch read back from AvatarVM in {share:.0%} of {r['speaking']} speaking samples "
                       f"(want >= 90%)", share >= 0.9))
        g.append(f"{p}: gestures {', '.join(r['gestures']) or 'none'}; mean pitch {r['pitch']:.3f}, lean "
                 f"{r['lean']:.3f} (max {r['leanMax']:.3f}), roll {r['roll']:.3f}; listening lean "
                 f"{r['listenLean']:.2f}: info")
    if set(runs) == set(PERSONA_ORDER):
        lists = [tuple(runs[p]["gestures"]) for p in PERSONA_ORDER]
        distinct = len(set(lists)) == len(lists)
        shown = " | ".join(",".join(x) or "-" for x in lists)
        g.append(_line(f"the three runs' gesture lists differ pairwise ({shown})", distinct))
        pitches = [runs[p]["pitch"] for p in PERSONA_ORDER]
        ordered = all(x < y for x, y in zip(pitches, pitches[1:]))
        g.append(_line("mean pitch " + " < ".join(f"{p} {v:.3f}" for p, v in zip(PERSONA_ORDER, pitches)), ordered))
    return g


def _runs_of(flags: list[bool]) -> list[int]:
    """The lengths of the runs of True in [flags]."""
    out, n = [], 0
    for f in flags:
        if f:
            n += 1
        elif n:
            out.append(n)
            n = 0
    if n:
        out.append(n)
    return out


def bubble_moves(samples: list[dict]) -> dict[int, int]:
    """Per sentence (`captionSeq`), how often the visible bubble moved by more than [BUBBLE_MOVE_DP] between
    two consecutive visible samples."""
    moves: dict[int, int] = {}
    prev: dict[int, list[float]] = {}
    for x in samples:
        rect = x.get("bubbleRect")
        if not x.get("bubble") or not rect:
            continue
        seq = x["captionSeq"]
        moves.setdefault(seq, 0)
        p = prev.get(seq)
        if p and (abs(rect[0] - p[0]) > BUBBLE_MOVE_DP or abs(rect[1] - p[1]) > BUBBLE_MOVE_DP):
            moves[seq] += 1
        prev[seq] = rect
    return moves


def caption_passes(tl: dict) -> dict[str, list[dict]]:
    """Per pass, its samples from the send to the turn's end."""
    s, ev = tl["samples"], tl["events"]
    out = {}
    for t, a, b in turn_windows(tl):
        send = next((e["ms"] for e in _in(ev, "send", a, b)), a)
        out[t["label"]] = _between(s, send, b)
    return out


def gates_caption(tl: dict) -> list[str]:
    """`WOW=caption` (M10 rulings 12-14): the bubble carries most of the default pass's sentences, the mouth
    anchor is read, the bubble and the classic caption never show together (a one-sample cross-fade
    tolerated), reduce motion places the bubble once per sentence (one re-placement jump allowed when the face
    comes under it), text scale 1.6 shows only the classic caption."""
    g = _m10_common(tl)
    passes = caption_passes(tl)
    g.append(_line(f"caption passes: {', '.join(passes)} (want {', '.join(CAPTION_PASSES)})",
                   list(passes) == CAPTION_PASSES))
    allx = [x for xs in passes.values() for x in xs]
    both = _runs_of([bool(x.get("bubble")) and bool(x.get("classic")) for x in allx])
    g.append(_line(f"never both captions: {sum(both)} samples with both visible, longest run {max(both, default=0)} "
                   f"(want <= 1: a cross-fade)", max(both, default=0) <= 1))
    for name in CAPTION_PASSES:
        xs = passes.get(name, [])
        spk = [x for x in xs if x["speaking"] and x.get("captionOn")]
        if not spk:
            g.append(_line(f"{name}: speaking samples with a caption", False))
            continue
        bub = sum(1 for x in spk if x.get("bubble")) / len(spk)
        cla = sum(1 for x in spk if x.get("classic")) / len(spk)
        shots = sorted({x["shot"] for x in spk})
        g.append(f"{name}: bubble {bub:.0%}, classic {cla:.0%} of {len(spk)} speaking samples (shots "
                 f"{', '.join(shots)}): info")
        if name == "default":
            g.append(_line(f"default: the bubble shows in {bub:.0%} of the speaking samples (want >= "
                           f"{BUBBLE_SHARE_MIN:.0%})", bub >= BUBBLE_SHARE_MIN))
            anchor = sum(1 for x in spk if x.get("anchor")) / len(spk)
            g.append(_line(f"default: the mouth anchor read in {anchor:.0%} of them (want >= {ANCHOR_SHARE_MIN:.0%})",
                           anchor >= ANCHOR_SHARE_MIN))
            moves = bubble_moves(xs)
            g.append(f"default: the bubble followed the mouth ({sum(moves.values())} moves over "
                     f"{len(moves)} sentences): info")
        elif name == "reduceMotion":
            moves = bubble_moves(xs)
            g.append(_line(f"reduceMotion: the bubble placed per sentence ({len(moves)} sentences with it, moves "
                           f"{[moves[k] for k in sorted(moves)]}; want >= 1 sentence, <= 1 move each)",
                           bool(moves) and all(v <= 1 for v in moves.values())))
        elif name == "textScale":
            n = sum(1 for x in xs if x.get("bubble"))
            g.append(_line(f"textScale 1.6: classic only ({n} samples with the bubble, classic in {cla:.0%} of the "
                           f"speaking samples, want 0 and >= {BUBBLE_SHARE_MIN:.0%})",
                           n == 0 and cla >= BUBBLE_SHARE_MIN))
    return g


def beats_m10(tl: dict) -> list[tuple[str, float, float]]:
    """The M10 contact sheets: the wardrobe's states and signatures; per persona listening, speaking and its
    first gesture; per caption pass the middle of each sentence."""
    s, ev = tl["samples"], tl["events"]
    first, last = tl["frames"][0]["ms"], tl["frames"][-1]["ms"]
    kind = _kind(tl)
    out: list[tuple[str, float, float]] = []
    if kind == "wardrobe":
        out.append(("1 start: pink hoodie, no hat", first + 800, 1.0))
        for t, a, b in turn_windows(tl):
            label, n = t["label"], len(out) + 1
            sig = _in(ev, "gesture", a, b, name="signature")
            if sig:
                out.append((f"{n} {label}: signature", sig[0]["ms"] + 600, 1.0))
            else:
                x = (_settled(s, b) or [{}])[-1]
                out.append((f"{n} {label}: top {_hex(x.get('vmTopTint'))} hat {_hex(x.get('vmHatTint'))}",
                            b - 300, 1.0))
        return out
    if kind == "persona":
        runs = persona_runs(tl)
        for t, a, b in turn_windows(tl):
            p = t["persona"]
            send = next((e["ms"] for e in _in(ev, "send", a, b)), a)
            spk = [x for x in _between(s, send, b) if x["speaking"]]
            gest = _in(ev, "gesture", send, b)
            out.append((f"{p}: listening", send - 200, 1.0))
            if spk:
                out.append((f"{p}: speaking, pitch {runs[p]['pitch']:.2f}", spk[len(spk) // 2]["ms"], 1.0))
            if gest:
                out.append((f"{p}: {gest[0]['name']}", gest[0]["ms"] + 500, 1.0))
        return out
    per_pass = {"default": 4, "reduceMotion": 2, "textScale": 2}
    for name, xs in caption_passes(tl).items():
        seqs: dict[int, list[dict]] = {}
        for x in xs:
            if x["speaking"] and x.get("captionOn"):
                seqs.setdefault(x["captionSeq"], []).append(x)
        for k, seq in enumerate(sorted(seqs)[:per_pass.get(name, 2)]):
            mid = seqs[seq][len(seqs[seq]) // 2]
            shown = "bubble" if mid.get("bubble") else "classic" if mid.get("classic") else "none"
            out.append((f"{name} s{k + 1}: {shown}, {mid['shot']}", mid["ms"], 1.0))
    return out or [("run", (first + last) / 2, 1.0)]


def reel_segments(tl: dict) -> list[tuple[float, float]]:
    """The MP4's segments (ms), at most [REEL_MAX_S] in all: the four signatures; the middle of each persona's
    speech; the default caption pass from its first caption."""
    s, ev = tl["samples"], tl["events"]
    kind = _kind(tl)
    segs: list[tuple[float, float]] = []
    if kind == "wardrobe":
        segs = [(e["ms"] - 300, e["ms"] + 2200) for e in ev if e["type"] == "gesture" and e["name"] == "signature"]
        if not segs:
            segs = [(b - 1500, b) for _, _, b in turn_windows(tl)]
    elif kind == "persona":
        for _, a, b in turn_windows(tl):
            spk = [x["ms"] for x in _between(s, a, b) if x["speaking"]]
            if spk:
                mid = spk[len(spk) // 2]
                segs.append((mid - 2000, mid + 2000))
    else:
        windows = turn_windows(tl)
        cap = next((e["ms"] for e in ev if e["type"] == "caption"), None)
        if windows and cap is not None:
            segs = [(cap - 300, min(windows[0][2], cap - 300 + REEL_MAX_S * 1000))]
    out, total = [], 0.0
    for a, b in segs:
        room = REEL_MAX_S * 1000 - total
        if room <= 0:
            break
        b = min(b, a + room)
        out.append((a, b))
        total += b - a
    return out


def reel_indices(frames: list[dict], segs: list[tuple[float, float]], fps: float = REEL_FPS) -> list[int]:
    """One frame per 1/fps tick through each segment (nearest earlier capture), segments back to back."""
    out: list[int] = []
    for a, b in segs:
        inside = [f for f in frames if f["ms"] <= b]
        if not inside:
            continue
        j = 0
        for k in range(int((b - a) * fps / 1000)):
            t = a + k * 1000 / fps
            while j + 1 < len(inside) and inside[j + 1]["ms"] <= t:
                j += 1
            out.append(inside[j]["i"])
    return out


def write_reel(wow_dir: Path, tl: dict, size: tuple[int, int], out: Path) -> tuple[float, int]:
    """The run's one silent MP4 (ruling 18): <= 12 s, 10 fps, <= 720 px wide. Returns (seconds, width)."""
    idx = reel_indices(tl["frames"], reel_segments(tl))
    width = min(REEL_MAX_W, size[0]) // 2 * 2
    if not idx:
        return 0.0, width
    with tempfile.TemporaryDirectory() as tmp:
        for k, i in enumerate(idx):
            load_frame(wow_dir / "frames" / f"{i:04d}.rgba", size).save(Path(tmp) / f"{k:05d}.png")
        cmd = ["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(REEL_FPS), "-i", f"{tmp}/%05d.png",
               "-vf", f"scale={width}:-2,format=yuv420p", "-an", "-c:v", "libx264", "-crf", "24", "-pix_fmt",
               "yuv420p", str(out)]
        subprocess.run(cmd, check=True)
    return len(idx) / REEL_FPS, width


# ---------------------------------------------------------------- frames
def load_frame(path: Path, size: tuple[int, int]) -> Image.Image:
    return Image.frombytes("RGBA", size, path.read_bytes()).convert("RGB")


def resample(frames: list[dict], fps: float) -> list[int]:
    """Frame indices, one per 1/fps tick from the first capture to the last (nearest earlier)."""
    if not frames:
        return []
    t0, t1 = frames[0]["ms"], frames[-1]["ms"]
    out, j = [], 0
    for k in range(int((t1 - t0) * fps / 1000) + 1):
        t = t0 + k * 1000 / fps
        while j + 1 < len(frames) and frames[j + 1]["ms"] <= t:
            j += 1
        out.append(frames[j]["i"])
    return out


def nearest(frames: list[dict], ms: float) -> int:
    return min(frames, key=lambda f: abs(f["ms"] - ms))["i"]


def front_visible(wow_dir: Path, size: tuple[int, int]) -> tuple[bool, float]:
    """Wet vs dry frame inside the avatar's hoodie. The avatar is opaque there, so the scene's own
    rain is behind it and only the front layer can change it; at any one instant the sparse near
    streaks may miss the box, but the rain mist darkens all of it. Passes when the wet median
    luminance is at most 0.97 of the dry one (idle motion moves edges, not the median)."""
    wet, dry = wow_dir / "wet.rgba", wow_dir / "dry.rgba"
    if not (wet.exists() and dry.exists()):
        return False, 1.0
    weights = np.array([0.2126, 0.7152, 0.0722])
    a = np.asarray(load_frame(wet, size)).astype(float) @ weights
    b = np.asarray(load_frame(dry, size)).astype(float) @ weights
    w, h = size
    box = (slice(int(h * 0.66), int(h * 0.84)), slice(int(w * 0.38), int(w * 0.62)))
    ratio = float(np.median(a[box]) / max(np.median(b[box]), 1e-6))
    return ratio <= 0.97, ratio


def blank_frame(a: np.ndarray) -> bool:
    """A frame with nothing on it: uniform (std < 5), or (M9) a near-black stage: the band between the top
    chips and the composer (rows 12-72 %) uniform or darker than mean 6 (the chrome alone keeps a black
    stage from looking uniform)."""
    h = a.shape[0]
    band = a[int(h * 0.12):int(h * 0.72)]
    return bool(a.std() < 5 or band.std() < 5 or band.mean() < 6)


def beats(tl: dict) -> list[tuple[str, float, float]]:
    """(label, ms, zoom) of the storyboard beats found in the timeline."""
    s, ev = tl["samples"], tl["events"]
    first = tl["frames"][0]["ms"]
    start = _first(ev, "start")
    stop_all = [e for e in ev if e["type"] == "stop"]
    end = stop_all[-1]["ms"] if stop_all else tl["frames"][-1]["ms"]
    speaking = [x for x in s if x["speaking"]]
    kind = _kind(tl)
    if kind in M10_KINDS:
        return beats_m10(tl)
    if kind in ("scene", "pairs", "tour7"):
        return beats_m9(tl)
    if tl["wow"] == "npc":
        def first_state(state: str, after: float = 0) -> float:
            return next((x["ms"] for x in s if x["npc"] == state and x["ms"] >= after), s[-1]["ms"])
        poke, send = _first(ev, "poke"), _first(ev, "send")
        moving = [x for x in s if x["npc"] == "move"]
        rug = next((x["ms"] for x in s if x["npcX"] >= 0.99), s[-1]["ms"])
        return [("1 the cat asleep", first + 800, 1.0),
                ("2 poked: it reacts", first_state("react", poke["ms"] if poke else 0) + 300, 1.0),
                ("3 named: it notices", first_state("notice", send["ms"] if send else 0) + 300, 1.0),
                ("4 the avatar is sad: the cat walks over", moving[len(moving) // 2]["ms"] if moving else rug, 1.0),
                ("5 by the avatar on the rug", min(rug + 800, tl["frames"][-1]["ms"]), 1.0)]
    if tl["wow"] in ("wow3", "tour"):
        out: list[tuple[str, float, float]] = []
        runs = journeys(s)
        if tl["wow"] == "wow3":
            send = _first(ev, "send")
            out.append(("1 the user asks", send["ms"] - 300, 1.0))
        for k, run in enumerate(runs):
            def at(phase: str, frac: float = 0.0) -> float:
                xs = [x for x in run if x["journey"] == phase]
                return xs[min(len(xs) - 1, int(frac * len(xs)))]["ms"] if xs else run[0]["ms"]
            tag = f"{run[0]['family']} → {run[-1]['scene']}"
            if tl["wow"] == "wow3":
                grabbed = any(x["journey"] == "grab" for x in run)
                out += [("2 wide: the camera pulls back", at("open"), 1.0),
                        ("3 grabs the jacket from the peg" if grabbed else "3 the door opens, gaze leads",
                         at("grab", 0.45) if grabbed else at("open", 0.9), 1.0),
                        ("4 walks out through it", at("exit", 0.5), 1.0),
                        ("5 match cut: the same door, the beach", at("arriveOpen", 0.2), 1.0),
                        ("6 walks in at sunset", at("enter", 0.6), 1.0)]
                if any(x["journey"] == "hang" for x in run):
                    out.append(("7 hangs the jacket on the door", at("hang", 0.5), 1.0))
                out.append(("8 settled" if grabbed else "7 settled",
                            min(run[-1]["ms"] + 1500, tl["frames"][-1]["ms"]), 1.0))
            else:
                out += [(f"{2 * k + 1} {tag}: walks out", at("exit", 0.5), 1.0),
                        (f"{2 * k + 2} {tag}: walks in", at("enter", 0.5), 1.0)]
        return out
    if tl["wow"] == "wow1":
        typing, send = _first(ev, "typing"), _first(ev, "send")
        lean = max(_between(s, typing["ms"], send["ms"] + 300), key=lambda x: x["lean"])
        pre = max(_between(s, start["ms"] - 400, start["ms"] + 100), key=lambda x: x["breath"])
        closed = longest_closure(s)
        caps = [e for e in ev if e["type"] == "caption"]
        q_stop = _first(ev, "stop", caps[-1]["ms"])
        brow = max(_between(s, q_stop["ms"] - 600, q_stop["ms"]), key=lambda x: x["browInner"] + x["browOuter"])
        mid = speaking[len(speaking) // 2]
        return [("1 wide: rain, steam, firelight", first + 800, 1.0),
                (f"2 listening lean {lean['lean']:.2f} while typing", lean["ms"], 1.0),
                (f"3 inhale: breath {pre['breath']:.2f}", pre["ms"], 1.6),
                (f"4 lips closed (press {closed['press']:.2f})", closed["ms"], 2.2),
                (f"5 question brows ({brow['browInner'] + brow['browOuter']:.2f})", brow["ms"], 1.6),
                ("6 firelight on the cheek", mid["ms"], 2.2),
                ("7 settles after the stop", min(end + 900, tl["frames"][-1]["ms"]), 1.0)]
    tool = [x for x in s if x["tool"] == "getCurrentWeather"]
    answer = [x for x in speaking if x["ms"] > tool[-1]["ms"]] if tool else speaking
    send = _first(ev, "send")
    card = [x for x in s if tool and x["ms"] >= tool[0]["ms"] and x["prop"] == "tablet"
            and x.get("tabletWeather", "none") != "none"]
    out = [("1 the user asks", send["ms"] - 300, 1.0),
           ("2 tool starts: head turns", tool[0]["ms"] + 350, 1.0),
           ("3 tablet out, screen lights the face", tool[0]["ms"] + 1200, 1.0),
           ("4 eyes on the screen", tool[len(tool) * 3 // 4]["ms"], 1.6)]
    if card:
        # M8: the looked-up city's weather on the screen (ruling 14)
        out.append((f"4b Tokyo on the screen: {card[0]['tabletWeather']} {card[0]['tabletTemp']} °C",
                    card[len(card) // 2]["ms"], 2.0))
    gone = (card[-1]["ms"] + 500) if card else tool[-1]["ms"] + 1300
    return out + [("5 glances back, tablet away", gone, 1.0),
                  ("6 answers (nod)", answer[len(answer) // 3]["ms"] if answer else end, 1.0)]



def beats_m9(tl: dict) -> list[tuple[str, float, float]]:
    """The M9 runs' beats: a scene's NPC, drag and reply; one arrival per pair; the December tour."""
    s, ev = tl["samples"], tl["events"]
    first, last = tl["frames"][0]["ms"], tl["frames"][-1]["ms"]
    kind = _kind(tl)
    if kind in ("pairs", "tour7"):
        out: list[tuple[str, float, float]] = []
        if kind == "tour7":
            out.append(("1 livingRoom, Christmas Eve, full moon", first + 800, 1.0))
        asked = [(e["from"], e["to"]) for e in ev if e["type"] == "journey"]
        for k, (run, (a, b)) in enumerate(zip(journeys(s), asked)):
            enter = [x for x in run if x["journey"] == "enter"]
            ms = enter[int(len(enter) * (0.6 if kind == "tour7" else 0.5))]["ms"] if enter else run[-1]["ms"]
            if kind == "tour7":
                out.append((f"{k + 2} {ruled_family(a, b)} -> {b}: walks in", ms, 1.0))
            else:
                out.append((f"{k + 1} {a} -> {b} ({ruled_family(a, b)})", ms, 1.0))
        return out
    out = [("1 establishing", first + 800, 1.0)]
    gp = _first(ev, "gullPoke")
    if gp:
        fly = next((x["ms"] for x in s if x["ms"] >= gp["ms"] and x["npc2"] == "move"), gp["ms"])
        out += [("2 the gulls landed", gp["ms"] - 300, 1.0), ("3 poked: they take off", fly + 400, 1.0)]
    poke = next((e for e in ev if e["type"] == "poke"), None)
    react = next((x["ms"] for x in s if poke and x["ms"] >= poke["ms"] and x["npc"] == "react"),
                 poke["ms"] if poke else first)
    n = len(out) + 1
    out.append((f"{n} poked: the {poke['prop'] if poke else 'NPC'} reacts", react + 250, 1.0))
    ds, de = _first(ev, "dragStart"), _first(ev, "dragEnd")
    info = tl.get("drag") or {}
    if ds and de and not info.get("missing"):
        during = _between(s, ds["ms"], de["ms"])
        key = info["primary"]
        peak = max(during, key=lambda x: abs(x["drag"].get(key, 0.0)), default=None) if during else None
        mid = peak["ms"] if peak and key != "trailN" else (ds["ms"] + de["ms"]) / 2
        out.append((f"{n + 1} drag {info['id']} ({info['kind']})", mid, 1.0))
        out.append((f"{n + 2} after the drag", min(de["ms"] + 800, last), 1.0))
    speaking = [x for x in s if x["speaking"]]
    if speaking:
        out.append((f"{len(out) + 1} speaks", speaking[len(speaking) // 2]["ms"], 1.0))
    out.append((f"{len(out) + 1} settled", last - 300, 1.0))
    return out


def crop_zoom(im: Image.Image, zoom: float) -> Image.Image:
    """The face-centred crop the storyboard's close-ups used before M7's camera (the avatar's head
    sits ~43 % down); a capture with the stage camera is never cropped (`beat_sheet`)."""
    if zoom == 1.0:
        return im
    w, h = im.size
    cw, ch = int(w / zoom), int(h / zoom)
    x0, y0 = (w - cw) // 2, max(0, min(h - ch, int(h * 0.43 - ch / 2)))
    return im.crop((x0, y0, x0 + cw, y0 + ch)).resize((w, h), Image.LANCZOS)


def beat_sheet(wow_dir: Path, tl: dict, size: tuple[int, int], out: Path) -> None:
    cells = []
    many = _kind(tl) == "pairs"
    m10 = _kind(tl) in M10_KINDS
    cw = 150 if many else 240 if m10 else 300
    cols = 7 if many else 4 if m10 else 8
    chh = int(size[1] * cw / size[0])
    camera = bool(tl["samples"]) and "shot" in tl["samples"][0]
    for label, ms, zoom in beats(tl):
        if camera:
            zoom = 1.0   # M7: the frames are already framed by the stage camera
        i = nearest(tl["frames"], ms)
        im = crop_zoom(load_frame(wow_dir / "frames" / f"{i:04d}.rgba", size), zoom).resize((cw, chh))
        cell = Image.new("RGB", (cw, chh + 34), (22, 18, 29))
        cell.paste(im, (0, 0))
        d = ImageDraw.Draw(cell)
        d.text((6, chh + 4), label, fill=(244, 184, 96))
        d.text((6, chh + 18), f"t = {(ms - tl['frames'][0]['ms']) / 1000:.2f} s, frame {i}", fill=(200, 200, 200))
        cells.append(cell)
    cols = min(cols, len(cells))
    rows = -(-len(cells) // cols)
    sheet = Image.new("RGB", (cols * (cw + 6) - 6, rows * (chh + 40) - 6), (10, 10, 10))
    for k, c in enumerate(cells):
        sheet.paste(c, ((k % cols) * (cw + 6), (k // cols) * (chh + 40)))
    if out.suffix == ".webp":
        sheet.save(out, quality=80, method=6)
    else:
        sheet.save(out)


# M9: (frames per second taken from the capture, playback speed-up) per run kind; the rest: GIF_FPS real time
GIF_PLANS = {"pairs": (1, 8), "tour7": (6, 1)}


def gif_start(tl: dict) -> float:
    """Where the GIF starts: just before the user types (the tours: the first journey; a scene run: its
    first action)."""
    ev = tl["events"]
    kind = _kind(tl)
    if kind in ("tour", "pairs", "tour7"):
        e = _first(ev, "journey")
        return e["ms"] - 800 if e else tl["frames"][0]["ms"]
    if kind == "scene":
        acts = [e["ms"] for e in ev if e["type"] in ("gullWait", "poke")]
        return min(acts) - 1500 if acts else tl["frames"][0]["ms"]
    e = _first(ev, "typing")
    return e["ms"] - 800 if e else tl["frames"][0]["ms"]


def write_gif(wow_dir: Path, tl: dict, size: tuple[int, int], out: Path) -> int:
    fps, speed = GIF_PLANS.get(_kind(tl), (GIF_FPS, 1))
    frames = [f for f in tl["frames"] if f["ms"] >= gif_start(tl)]
    cache: dict[int, Image.Image] = {}

    def frame(i: int) -> Image.Image:
        if i not in cache:
            im = load_frame(wow_dir / "frames" / f"{i:04d}.rgba", size)
            cache[i] = im.resize((GIF_W, int(size[1] * GIF_W / size[0])), Image.LANCZOS)
        return cache[i]
    # narrower first, then fewer frames (the long M9 runs), until under the budget
    plans = [(w, fps) for w in (GIF_W, GIF_W - 40, GIF_W - 80)]
    plans += [(GIF_W - 80, fps * k) for k in (0.75, 0.5, 0.35, 0.25)]
    for width, f in plans:
        idx = resample(frames, f)
        h = int(size[1] * width / size[0])
        ims = [frame(i) if width == GIF_W else frame(i).resize((width, h), Image.LANCZOS) for i in idx]
        pal = [im.quantize(colors=GIF_COLOURS, method=Image.Quantize.MEDIANCUT) for im in ims]
        pal[0].save(out, save_all=True, append_images=pal[1:], duration=round(1000 / (f * speed)), loop=0,
                    optimize=True)
        if out.stat().st_size <= GIF_MAX:
            break
    return out.stat().st_size


def write_mp4(wow_dir: Path, tl: dict, size: tuple[int, int], out: Path) -> None:
    # M9 pairs: the 2 fps capture played 4x fast, silent (hundreds of footsteps)
    timelapse = _kind(tl) == "pairs"
    idx = resample(tl["frames"], 2 if timelapse else MP4_FPS)
    with tempfile.TemporaryDirectory() as tmp:
        for k, i in enumerate(idx):
            load_frame(wow_dir / "frames" / f"{i:04d}.rgba", size).save(Path(tmp) / f"{k:05d}.png")
        cmd = ["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(8 if timelapse else MP4_FPS), "-i",
               f"{tmp}/%05d.png"]
        clips = [] if timelapse else audio_offsets(tl["events"], tl["audio"], tl["frames"][0]["ms"]) + \
            foley_offsets(tl["events"], tl["frames"][0]["ms"])
        for f, _ in clips:
            cmd += ["-i", f]
        w, h = size[0] // 2 * 2, size[1] // 2 * 2
        vf = f"[0:v]crop={w}:{h}:0:0,format=yuv420p[v]"
        if clips:
            delays = ";".join(f"[{k + 1}:a]adelay={max(0, ms)}|{max(0, ms)}[a{k}]" for k, (_, ms) in enumerate(clips))
            mix = "".join(f"[a{k}]" for k in range(len(clips))) + \
                f"amix=inputs={len(clips)}:normalize=0,apad[a]"
            cmd += ["-filter_complex", f"{vf};{delays};{mix}", "-map", "[v]", "-map", "[a]", "-shortest",
                    "-c:a", "aac"]
        else:
            cmd += ["-filter_complex", vf, "-map", "[v]"]
        cmd += ["-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p", str(out)]
        subprocess.run(cmd, check=True)


def frame_cost(timing_dir: Path) -> dict | None:
    p = timing_dir / "timeline.json"
    if not p.exists():
        return None
    t = json.loads(p.read_text())["frame_timings"]
    if not t:
        return None

    def pct(xs: list[float], q: float) -> float:
        xs = sorted(xs)
        return round(xs[min(len(xs) - 1, int(q * len(xs)))], 2)
    b, r = [x["build"] for x in t], [x["raster"] for x in t]
    over = sum(1 for x in t if x["build"] > 16.6 or x["raster"] > 16.6)
    return {"frames": len(t), "build_p50": pct(b, 0.5), "build_p95": pct(b, 0.95), "raster_p50": pct(r, 0.5),
            "raster_p95": pct(r, 0.95), "over_16_6_share": round(over / len(t), 4),
            "note": "macOS desktop (debug build, Skia; not a device tier)"}


def main_m10(wow_dir: Path, out: Path, tl: dict, size: tuple[int, int], gates: list[str]) -> int:
    """The M10 runs (ruling 18): gates, one silent reel (<= 12 s, 10 fps, <= 720 px) and a WebP contact sheet;
    no GIF. The sheet is written even when a gate fails (it is how a failure is looked at)."""
    wow = tl["wow"]
    try:
        gates += {"wardrobe": gates_wardrobe, "persona": gates_persona, "caption": gates_caption}[_kind(tl)](tl)
    except (TypeError, ValueError, IndexError, KeyError, AttributeError) as e:
        gates.append(_line(f"timeline incomplete ({type(e).__name__}: {e})", False))
    if shutil.which("ffmpeg"):
        secs, width = write_reel(wow_dir, tl, size, out / f"{wow}.mp4")
        mp4 = out / f"{wow}.mp4"
        gates.append(_line(f"{wow}.mp4: {secs:.1f} s at {REEL_FPS} fps, {width} px wide, "
                           f"{mp4.stat().st_size if mp4.exists() else 0} B (want <= {REEL_MAX_S:.0f} s, <= 12 fps, "
                           f"<= {REEL_MAX_W} px)", 0 < secs <= REEL_MAX_S and width <= REEL_MAX_W))
    sheet = out / f"{wow}_sheet.webp"
    beat_sheet(wow_dir, tl, size, sheet)
    gates.append(f"{sheet.name} {sheet.stat().st_size} B: info")
    (out / f"{wow}_gates.txt").write_text("\n".join(gates) + "\n")
    print("\n".join(gates))
    return 1 if any(g.endswith("FAIL") for g in gates) else 0


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__)
        return 2
    wow_dir, out = Path(argv[0]), Path(argv[1])
    out.mkdir(parents=True, exist_ok=True)
    tl = json.loads((wow_dir / "timeline.json").read_text())
    wow = tl["wow"]
    size = (int(tl["size"][0]), int(tl["size"][1]))
    gates = []
    empty = []
    for f in tl["frames"]:
        a = np.asarray(load_frame(wow_dir / "frames" / f"{f['i']:04d}.rgba", size))
        if blank_frame(a):
            empty.append(f["i"])
    gates.append(_line(f"every frame non-empty ({len(empty)} blank or near-black on the stage"
                       f"{': ' + ', '.join(map(str, empty[:10])) if empty else ''})", not empty))
    if _kind(tl) in M10_KINDS:
        return main_m10(wow_dir, out, tl, size, gates)
    try:
        if wow == "wow1":
            ok, share = front_visible(wow_dir, size)
            gates += [g.replace("(wet vs dry frame, avatar box)",
                                f"(rain mist: wet / dry median luminance inside the hoodie {share:.3f}, "
                                f"want <= 0.97)")
                      for g in gates_wow1(tl, ok)]
        elif wow == "wow3":
            gates += gates_wow3(tl)
        elif wow == "tour":
            gates += gates_tour(tl)
        elif wow == "npc":
            gates += gates_npc(tl)
        elif _kind(tl) == "scene":
            gates += gates_scene(tl)
        elif wow == "pairs":
            gates += gates_pairs(tl)
        elif wow == "tour7":
            gates += gates_tour7(tl)
        else:
            gates += gates_wow2(tl)
    except (TypeError, ValueError, IndexError, KeyError, AttributeError) as e:
        # an event or a sample the gates need is missing: a verdict, not a crash
        gates.append(_line(f"timeline incomplete ({type(e).__name__}: {e})", False))
    size_gif = write_gif(wow_dir, tl, size, out / f"{wow}.gif")
    gates.append(_line(f"{wow}.gif {size_gif} B (budget {GIF_MAX})", size_gif <= GIF_MAX))
    if shutil.which("ffmpeg"):
        write_mp4(wow_dir, tl, size, out / f"{wow}.mp4")
        gates.append(f"{wow}.mp4 {(out / f'{wow}.mp4').stat().st_size} B: info")
    if not any(g.endswith("FAIL") for g in gates):
        beat_sheet(wow_dir, tl, size, out / f"{wow}_beats.png")
    cost = frame_cost(Path(str(wow_dir) + "_timing"))
    if cost:
        (out / f"{wow}_frame_cost.json").write_text(json.dumps(cost, indent=1) + "\n")
        gates.append(f"frame cost (macOS desktop, not a tier): build P95 {cost['build_p95']} ms, raster P95 "
                     f"{cost['raster_p95']} ms, over 16.6 ms {cost['over_16_6_share']:.1%}: info")
    (out / f"{wow}_gates.txt").write_text("\n".join(gates) + "\n")
    print("\n".join(gates))
    return 1 if any(g.endswith("FAIL") for g in gates) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
