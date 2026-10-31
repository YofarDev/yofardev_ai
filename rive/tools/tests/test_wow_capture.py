"""Tests for the wow capture's gates and audio timing (moonshot M6 Task 6, ruling 7)."""

from __future__ import annotations

from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import wow_capture as wc  # noqa: E402
from wow_capture import audio_offsets, bilabial_words, closures, gates_wow1, gates_wow2  # noqa: E402


def _s(ms: int, **kw: object) -> dict:
    base = {"ms": ms, "phase": "idle", "tool": None, "prop": "none", "lean": 0.0, "yaw": 0.0, "speaking": False,
            "jaw": 0.0, "press": 0.0, "browInner": 0.0, "browOuter": 0.0, "breath": 0.0, "tuck": 0.0,
            "scene": "campfire", "rain": 1.0}
    return {**base, **kw}


REPLY1 = "Picture a big bright moon above the pines. Maybe the rain will pass by morning. Do you hear the logs hissing?"


def test_bilabial_words() -> None:
    assert bilabial_words("Picture a big bright moon above the pines. Maybe the rain will pass by morning.") == 9
    assert bilabial_words("[g:nod] It's eighteen degrees.") == 0


def test_closures_counts_separate_runs_while_speaking() -> None:
    tl = [_s(0, speaking=True), _s(33, speaking=True, press=0.6, jaw=0.05), _s(66, speaking=True, press=0.7, jaw=0.0),
          _s(99, speaking=True, jaw=0.4), _s(132, speaking=True, press=0.5, jaw=0.1),
          _s(165, speaking=False, press=0.9)]  # not speaking: does not count
    assert closures(tl) == 2


def test_audio_offsets_follow_captions() -> None:
    events = [{"ms": 900, "type": "caption", "text": "Picture a big bright moon above the pines."},
              {"ms": 3100, "type": "caption", "text": "Maybe the rain will pass by morning."}]
    audio = [{"text": "Picture a big bright moon above the pines.", "file": "/x/00.wav"},
             {"text": "Maybe the rain will pass by morning.", "file": "/x/01.wav"},
             {"text": "never played", "file": "/x/02.wav"}]
    assert audio_offsets(events, audio, t0=500) == [("/x/00.wav", 400), ("/x/01.wav", 2600)]


def _wow1(**over: object) -> dict:
    samples = [_s(t) for t in range(0, 2000, 33)]
    samples += [_s(t, lean=0.5) for t in range(2000, 5000, 33)]                       # typing
    samples += [_s(t, breath=0.7) for t in range(5000, 5300, 33)]                      # pre-roll
    speak = []
    for i, t in enumerate(range(5300, 12000, 33)):
        closed = i % 12 == 0
        speak.append(_s(t, speaking=True, press=0.8 if closed else 0.0, jaw=0.0 if closed else 0.4))
    speak += [_s(t, speaking=True, browInner=0.3, browOuter=0.2) for t in range(12000, 12600, 33)]
    samples += speak + [_s(t) for t in range(12600, 14000, 33)]
    tl = {"wow": "wow1", "scene": "campfire", "rain": 1, "reply": REPLY1, "frames": [{"i": 0, "ms": 0}],
          "samples": samples,
          "events": [{"ms": 2000, "type": "typing"}, {"ms": 4900, "type": "send"},
                     {"ms": 5300, "type": "start"}, {"ms": 5300, "type": "caption", "text": "a"},
                     {"ms": 9000, "type": "caption", "text": "b"},
                     {"ms": 10600, "type": "caption", "text": "Do you hear the logs hissing?"},
                     {"ms": 12600, "type": "stop"}],
          "network_attempts": 0}
    tl.update(over)
    return tl


def test_wow1_gates_pass_and_fail() -> None:
    ok = gates_wow1(_wow1(), front_visible=True)
    assert all(g.endswith("ok") for g in ok), ok
    bad = gates_wow1(_wow1(samples=[{**s, "lean": 0.0} for s in _wow1()["samples"]]), front_visible=True)
    assert any("lean" in g and g.endswith("FAIL") for g in bad)
    bad = gates_wow1(_wow1(samples=[{**s, "browInner": 0.0, "browOuter": 0.0} for s in _wow1()["samples"]]),
                     front_visible=True)
    assert any("brows" in g and g.endswith("FAIL") for g in bad)
    bad = gates_wow1(_wow1(samples=[{**s, "breath": 0.0} for s in _wow1()["samples"]]), front_visible=True)
    assert any("breath" in g and g.endswith("FAIL") for g in bad)
    bad = gates_wow1(_wow1(samples=[{**s, "press": 0.0} for s in _wow1()["samples"]]), front_visible=True)
    assert any("closures" in g and g.endswith("FAIL") for g in bad)
    assert any("front" in g and g.endswith("FAIL") for g in gates_wow1(_wow1(), front_visible=False))
    assert any("network" in g and g.endswith("FAIL") for g in gates_wow1(_wow1(network_attempts=2), front_visible=True))


def _wow2(**over: object) -> dict:
    samples = [_s(t, scene="livingRoom", rain=0.0) for t in range(0, 3000, 33)]
    samples += [_s(t, scene="livingRoom", rain=0.0, tool="getCurrentWeather", prop="tablet", yaw=0.6)
                for t in range(3000, 5600, 33)]
    samples += [_s(t, scene="livingRoom", rain=0.0, prop="none", speaking=True, phase="speaking")
                for t in range(5600, 9000, 33)]
    tl = {"wow": "wow2", "scene": "livingRoom", "rain": 0, "reply": "x", "frames": [{"i": 0, "ms": 0}],
          "samples": samples, "events": [{"ms": 5600, "type": "start"}, {"ms": 9000, "type": "stop"}],
          "network_attempts": 0}
    tl.update(over)
    return tl


def test_wow2_gates_pass_and_fail() -> None:
    ok = gates_wow2(_wow2())
    assert all(g.endswith("ok") for g in ok), ok
    short = [{**s, "tool": None, "prop": "none", "yaw": 0.0} if 4000 <= s["ms"] < 5600 else s for s in _wow2()["samples"]]
    assert any("tool" in g and g.endswith("FAIL") for g in gates_wow2(_wow2(samples=short)))
    no_tablet = [{**s, "prop": "none"} for s in _wow2()["samples"]]
    assert any("tablet" in g and g.endswith("FAIL") for g in gates_wow2(_wow2(samples=no_tablet)))
    held = [{**s, "prop": "tablet"} if s["ms"] >= 5600 else s for s in _wow2()["samples"]]
    assert any("put away" in g and g.endswith("FAIL") for g in gates_wow2(_wow2(samples=held)))
    turned = [{**s, "yaw": 0.6} for s in _wow2()["samples"]]
    assert any("answer" in g and g.endswith("FAIL") for g in gates_wow2(_wow2(samples=turned)))


def _journey_samples(t0: int, to: str, family: str, origin: str = "livingRoom", clipped: bool = True,
                     switch_at: str = "cut", wide: bool = True) -> list[dict]:
    phases = ["pullBack", "open", "exit", "close", "cut", "arriveOpen", "enter", "arriveClose", "vanish"]
    out = []
    ms = t0
    for p in phases:
        for _ in range(3):
            off = p in ("exit", "close", "cut", "arriveOpen")
            out.append({"ms": ms, "journey": p, "family": family,
                        "presence": "outOfScreen" if off else "onScreen",
                        "scene": to if wc.PHASES.index(p) >= wc.PHASES.index(switch_at) else origin,
                        "shot": "wide" if (wide or p == "pullBack") else "medium", "move": "ease",
                        "shotSerial": 1, "dusk": 1.0})
            ms += 33
    if not clipped:
        out[1]["presence"] = "outOfScreen"   # off screen during the pull-back: not clipped
    return out


def _wow3(**kw: object) -> dict:
    s = [{"ms": 0, "journey": None, "family": None, "presence": "onScreen", "scene": "livingRoom",
          "shot": "medium", "move": "ease", "shotSerial": 0, "dusk": 1.0}]
    s += _journey_samples(100, "beach", "door", **kw)
    s += [{"ms": 2000, "journey": None, "family": None, "presence": "onScreen", "scene": "beach",
           "shot": "wide", "move": "ease", "shotSerial": 1, "dusk": 1.0},
          {"ms": 2300, "journey": None, "family": None, "presence": "onScreen", "scene": "beach",
           "shot": "medium", "move": "cut", "shotSerial": 2, "dusk": 1.0}]
    ev = [{"ms": 50, "type": "send"}, {"ms": 2200, "type": "start"}, {"ms": 2210, "type": "caption", "text": "x"}]
    return {"frames": [{"i": 0, "ms": 0}], "network_attempts": 0, "samples": s, "events": ev}


def test_wow3_gates_pass_and_fail() -> None:
    ok = wc.gates_wow3(_wow3())
    assert not [g for g in ok if g.endswith("FAIL")], ok
    assert any(g.endswith("FAIL") for g in wc.gates_wow3(_wow3(clipped=False)))
    assert any(g.endswith("FAIL") for g in wc.gates_wow3(_wow3(switch_at="close")))
    assert any(g.endswith("FAIL") for g in wc.gates_wow3(_wow3(wide=False)))
    bad_cut = _wow3()
    bad_cut["events"][-1]["ms"] = 1000   # the cut lands 1.3 s after the caption: not a sentence start
    assert any(g.endswith("FAIL") and "sentence" in g for g in wc.gates_wow3(bad_cut))


def test_tour_gates_need_every_family() -> None:
    s = []
    origin = "livingRoom"
    for k, to in enumerate(["campfire", "beach", "deepSpace", "livingRoom"]):
        s += _journey_samples(k * 1000, to, wc.TOUR_FAMILIES[to], origin=origin)
        s.append({"ms": k * 1000 + 990, "journey": None, "family": None, "presence": "onScreen", "scene": to,
                  "shot": "wide", "move": "ease", "shotSerial": 1, "dusk": 0.0})
        origin = to
    tl = {"frames": [{"i": 0, "ms": 0}], "network_attempts": 0, "samples": s, "events": [],
          "tour": ["campfire", "beach", "deepSpace", "livingRoom"]}
    ok = wc.gates_tour(tl)
    assert not [g for g in ok if g.endswith("FAIL")], ok
    tl["tour"] = tl["tour"][:3]
    assert any(g.endswith("FAIL") for g in wc.gates_tour(tl))


# ---------------------------------------------------------------- M8: jacket, foley, NPCs
def _j(ms: int, phase: str, jacket: bool, peg: float, scene: str = "livingRoom") -> dict:
    return _s(ms, journey=phase, family="door", presence="onScreen", shot="wide", scene=scene,
              jacket=jacket, journeyJacket=peg)


def _door_run() -> list[dict]:
    run = [_j(0, "pullBack", False, 0.0), _j(100, "open", False, 1.0), _j(200, "grab", False, 1.0),
           _j(300, "grab", True, 0.0), _j(400, "exit", True, 0.0), _j(1900, "exit", True, 0.0),
           _j(2000, "close", True, 0.0), _j(2100, "arriveOpen", True, 0.0, scene="beach"),
           _j(2200, "enter", True, 0.0, scene="beach"), _j(3700, "enter", True, 0.0, scene="beach"),
           _j(3800, "hang", True, 0.0, scene="beach"), _j(3900, "hang", False, 1.0, scene="beach"),
           _j(4000, "arriveClose", False, 1.0, scene="beach"), _j(4100, "vanish", False, 0.0, scene="beach")]
    return run


def _foley_events() -> list[dict]:
    ev = [{"ms": 250, "type": "foley", "kind": "cloth"}, {"ms": 3850, "type": "foley", "kind": "cloth"}]
    ev += [{"ms": 450 + 240 * k, "type": "foley", "kind": "step"} for k in range(6)]
    ev += [{"ms": 2250 + 240 * k, "type": "foley", "kind": "step"} for k in range(6)]
    return ev


def test_jacket_gates_pass_on_a_clean_handoff() -> None:
    lines = wc.jacket_gates(_door_run(), _foley_events())
    assert lines and all(line.endswith("ok") for line in lines), lines


def test_jacket_gates_catch_two_jackets_and_missing_steps() -> None:
    run = _door_run()
    run[3]["journeyJacket"] = 1.0  # the peg still shows while the hand holds it
    ev = [e for e in _foley_events() if not (e["kind"] == "step" and e["ms"] > 2000)]
    lines = wc.jacket_gates(run, ev)
    assert any("one jacket at a time" in line and line.endswith("FAIL") for line in lines)
    assert any("footsteps during enter" in line and line.endswith("FAIL") for line in lines)


def test_jacket_gates_need_grab_before_exit() -> None:
    run = [x for x in _door_run() if x["journey"] != "grab"]
    assert wc.jacket_gates(run, _foley_events())[0].endswith("FAIL")


def test_phase_order_knows_grab_and_hang() -> None:
    assert wc.PHASES.index("grab") == wc.PHASES.index("open") + 1
    assert wc.PHASES.index("hang") == wc.PHASES.index("enter") + 1
    assert wc.phase_order(_door_run())[:3] == ["pullBack", "open", "grab"]


def _n(ms: int, npc: str, x: float = 0.0) -> dict:
    return _s(ms, scene="livingRoom", npc=npc, npcX=x, npcLook=0.0, shotSerial=0, shot="wide", move="ease")


def test_gates_npc() -> None:
    samples = [_n(0, "rest"), _n(1000, "rest"), _n(1100, "react"), _n(3000, "notice"), _n(6000, "notice")]
    samples += [_n(6000 + 100 * k, "move", min(1.0, k * 0.04)) for k in range(1, 27)]
    samples += [_n(9000, "idle", 1.0)]
    tl = {"samples": samples, "frames": [{"i": 0, "ms": 0}], "network_attempts": 0,
          "events": [{"ms": 1000, "type": "poke"}, {"ms": 2900, "type": "send"}]}
    lines = wc.gates_npc(tl)
    assert all(line.endswith(("ok", "info")) for line in lines), lines
    assert wc.npc_states(samples) == ["rest", "react", "notice", "move", "idle"]


def test_foley_offsets_skip_missing_files(tmp_path: Path) -> None:
    (tmp_path / "assets/foley").mkdir(parents=True)
    (tmp_path / "assets/foley/step_0.wav").write_bytes(b"RIFF")
    ev = [{"ms": 500, "type": "foley", "kind": "step", "file": "assets/foley/step_0.wav"},
          {"ms": 600, "type": "foley", "kind": "step", "file": "assets/foley/nope.wav"},
          {"ms": 700, "type": "caption", "text": "x"}]
    out = wc.foley_offsets(ev, 100, tmp_path)
    assert out == [(str(tmp_path / "assets/foley/step_0.wav"), 400)]


# ---------------------------------------------------------------- M9: scenes, drags, gulls, pairs, December
def _m9(ms: int, **kw: object) -> dict:
    base = {"ms": ms, "scene": "livingRoom", "journey": None, "family": None, "presence": "onScreen",
            "shot": "wide", "move": "ease", "shotSerial": 0, "speaking": False, "fileScene": "livingRoom",
            "dragging": False, "drag": {}, "dragRead": 0.0, "npc": "rest", "npcX": 0.0, "npc2": "away",
            "npc2X": 1.0, "moonPhase": 0.52, "festive": 1.0, "moonRead": 0.52, "festiveRead": 1.0,
            "hat": "santaHat", "top": "christmasSweater", "jacket": False, "journeyJacket": 0.0}
    return {**base, **kw}


def test_ruled_family_table() -> None:
    pairs = [(a, b) for a in wc.SCENES for b in wc.SCENES if a != b]
    fams = [wc.ruled_family(a, b) for a, b in pairs]
    assert len(pairs) == 42
    assert {f: fams.count(f) for f in set(fams)} == {"rocket": 6, "portal": 6, "path": 2, "door": 28}
    assert wc.ruled_family("campfire", "beach") == "path" and wc.ruled_family("beach", "deepSpace") == "rocket"


def _drag_tl(hid: str, kind: str, primary: str, during: list[dict], after: list[dict],
             extra_events: list[dict] | None = None, haptic: bool = True) -> dict:
    ev = [{"ms": 1000, "type": "dragStart"}, {"ms": 2000, "type": "dragEnd"}]
    if haptic:
        ev.append({"ms": 1010, "type": "haptic", "kind": "selection"})
    ev += extra_events or []
    ev.sort(key=lambda e: e["ms"])
    return {"samples": [_m9(0)] + during + after, "events": ev,
            "drag": {"id": hid, "kind": kind, "primary": primary}}


def _pull(peak: float = 0.9, action: bool = True, back: float = 0.0) -> dict:
    during = [_m9(1000 + 50 * k, dragging=True, drag={"cord": min(peak, 0.05 * k)}, dragRead=min(peak, 0.05 * k))
              for k in range(21)]
    after = [_m9(2000 + 100 * k, drag={"cord": back if k > 5 else 0.5}, dragRead=0.0) for k in range(1, 30)]
    ev = [{"ms": 1500, "type": "sceneEvent", "name": "lightsOff"}] if action else []
    return _drag_tl("cord", "pull", "cord", during, after, ev)


def test_drag_gates_pull() -> None:
    ok = wc.drag_gates(_pull())
    assert all(g.endswith("ok") for g in ok), ok
    assert any("action" in g and g.endswith("FAIL") for g in wc.drag_gates(_pull(action=False)))
    assert any("pulled" in g and g.endswith("FAIL") for g in wc.drag_gates(_pull(peak=0.4)))
    assert any("springs back" in g and g.endswith("FAIL") for g in wc.drag_gates(_pull(back=0.3)))
    tl = _pull()
    tl["events"] = [e for e in tl["events"] if e["type"] != "haptic"]
    assert any("haptics" in g and g.endswith("FAIL") for g in wc.drag_gates(tl))
    tl = _pull()
    tl["drag"] = {"missing": True, "id": "cord"}
    assert wc.drag_gates(tl)[0].endswith("FAIL")


def test_drag_gates_rope_needs_the_bell() -> None:
    during = [_m9(1000 + 50 * k, dragging=True, drag={"rope": 0.05 * k}, dragRead=0.05 * k) for k in range(21)]
    after = [_m9(2000 + 100 * k, drag={"rope": 0.0}) for k in range(1, 30)]
    ev = [{"ms": 1500, "type": "sceneEvent", "name": "bell"}]
    ok = wc.drag_gates(_drag_tl("rope", "pull", "rope", during, after,
                                ev + [{"ms": 1500, "type": "foley", "kind": "bell"}]))
    assert all(g.endswith("ok") for g in ok), ok
    bad = wc.drag_gates(_drag_tl("rope", "pull", "rope", during, after, ev))
    assert any("bell rang" in g and g.endswith("FAIL") for g in bad)


def test_drag_gates_poke() -> None:
    def tl(stir: float) -> dict:
        during = [_m9(1000 + 50 * k, dragging=True, dragRead=1.0,
                      drag={"poke": 1.0, "pokeX": stir * ((k % 4) - 1.5), "pokeY": stir * ((k % 3) - 1)})
                  for k in range(21)]
        after = [_m9(2000 + 100 * k, drag={"poke": 0.0, "pokeX": 0.0, "pokeY": 0.0}) for k in range(1, 30)]
        return _drag_tl("poke", "poke", "poke", during, after)
    ok = wc.drag_gates(tl(0.4))
    assert all(g.endswith(("ok", "info")) for g in ok), ok
    assert any("stir" in g and g.endswith("FAIL") for g in wc.drag_gates(tl(0.05)))


def test_drag_gates_trail_spin_aim() -> None:
    def trail(n: int) -> dict:
        during = [_m9(1000 + 50 * k, dragging=True, drag={"trailN": min(n, k), "trailFade": 0.0},
                      dragRead=min(n, k)) for k in range(21)]
        return _drag_tl("wipe", "trail", "trailN", during, [_m9(2500, drag={"trailN": n, "trailFade": 0.0})])
    assert all(g.endswith("ok") for g in wc.drag_gates(trail(16)))
    assert any("dots" in g and g.endswith("FAIL") for g in wc.drag_gates(trail(2)))

    def spin(turn: float) -> dict:
        during = [_m9(1000 + 50 * k, dragging=True, drag={"spin": turn * k / 20}, dragRead=turn * k / 20)
                  for k in range(21)]
        after = [_m9(2000 + 100 * k, drag={"spin": turn + min(k, 10) * 0.01 * (turn > 0)}) for k in range(1, 30)]
        return _drag_tl("spin", "spin", "spin", during, after)
    assert all(g.endswith("ok") for g in wc.drag_gates(spin(0.3)))
    assert any("spin moved" in g and g.endswith("FAIL") for g in wc.drag_gates(spin(0.0)))

    def aim(drift: float) -> dict:
        during = [_m9(1000 + 50 * k, dragging=True, drag={"aim": -0.03 * k}, dragRead=-0.03 * k) for k in range(21)]
        after = [_m9(2000 + 100 * k, drag={"aim": -0.6 + drift}) for k in range(1, 30)]
        return _drag_tl("aim", "aim", "aim", during, after)
    assert all(g.endswith("ok") for g in wc.drag_gates(aim(0.0)))
    assert any("holds" in g and g.endswith("FAIL") for g in wc.drag_gates(aim(0.3)))


def _gulls(land: bool = True, react_ms: int = 60) -> dict:
    s = [_m9(t, scene="beach", npc2="away", npc2X=1.0) for t in range(0, 12000, 100)]
    if land:
        s += [_m9(12000 + 100 * k, scene="beach", npc2="move", npc2X=1 - k / 25) for k in range(26)]
        s += [_m9(t, scene="beach", npc2="idle", npc2X=0.0) for t in range(14600, 16000, 100)]
    s += [_m9(16000 + react_ms, scene="beach", npc2="react", npc2X=0.0)]
    s += [_m9(16700 + 100 * k, scene="beach", npc2="move", npc2X=k / 15) for k in range(16)]
    s += [_m9(18400, scene="beach", npc2="away", npc2X=1.0)]
    return {"samples": s, "events": [{"ms": 0, "type": "gullWait"}, {"ms": 16000, "type": "gullPoke"}]}


def test_gull_gates() -> None:
    ok = wc.gull_gates(_gulls())
    assert all(g.endswith("ok") for g in ok), ok
    assert wc.gull_gates(_gulls(land=False))[0].endswith("FAIL")
    assert any("startled" in g and g.endswith("FAIL") for g in wc.gull_gates(_gulls(react_ms=400)))
    assert wc.npc2_states(_gulls()["samples"]) == ["away", "move", "idle", "react", "move", "away"]


def _scene_tl(react_ms: int = 30) -> dict:
    tl = _pull()
    pre = [_m9(t, npc="rest") for t in range(0, 500, 100)] + [_m9(500 + react_ms, npc="react")]
    talk = [_m9(t, speaking=True) for t in range(5200, 6000, 100)]
    tl["samples"] = pre + tl["samples"][1:] + talk
    tl["events"] += [{"ms": 500, "type": "poke", "prop": "cat"}, {"ms": 5200, "type": "start"},
                     {"ms": 5210, "type": "caption", "text": "x"}, {"ms": 6000, "type": "stop"}]
    tl["events"].sort(key=lambda e: e["ms"])
    tl.update({"scene": "livingRoom", "frames": [{"i": 0, "ms": 0}], "network_attempts": 0})
    return tl


def test_gates_scene() -> None:
    ok = wc.gates_scene(_scene_tl())
    assert all(g.endswith(("ok", "info")) for g in ok), ok
    assert any("NPC poked" in g and g.endswith("FAIL") for g in wc.gates_scene(_scene_tl(react_ms=300)))
    tl = _scene_tl()
    tl["samples"][3]["fileScene"] = None
    assert any("file on screen" in g and g.endswith("FAIL") for g in wc.gates_scene(tl))
    tl = _scene_tl()
    tl["network_attempts"] = 1
    assert any("network" in g and g.endswith("FAIL") for g in wc.gates_scene(tl))


def _pair_run(t0: int, a: str, b: str, family: str, drawn_at: str = "arriveOpen") -> list[dict]:
    phases = ["pullBack", "open", "exit", "close", "cut", "arriveOpen", "enter", "arriveClose", "vanish"]
    if family == "door":
        phases = ["pullBack", "open", "grab", "exit", "close", "cut", "arriveOpen", "enter", "hang", "arriveClose",
                  "vanish"]
    out = []
    for k, p in enumerate(phases):
        held = family == "door" and p in ("exit", "close", "cut", "arriveOpen", "enter")
        new = wc.PHASES.index(p) >= wc.PHASES.index("cut")
        drawn = wc.PHASES.index(p) >= wc.PHASES.index(drawn_at)
        out.append(_m9(t0 + 33 * k, journey=p, family=family, scene=b if new else a,
                       fileScene=b if drawn else a, jacket=held,
                       journeyJacket=0.0 if held or p in ("pullBack", "vanish") else 1.0))
    return out


def _pairs_tl(bad: str = "") -> dict:
    s, ev, t = [], [], 0
    order = [(a, b) for a in wc.SCENES for b in wc.SCENES if a != b]  # not a chain: the gates read the events
    for a, b in order:
        fam = wc.ruled_family(a, b)
        if bad == "family" and (a, b) == ("cafe", "rooftop"):
            fam = "path"
        drawn = "exit" if bad == "drawn" and (a, b) == ("beach", "cafe") else "arriveOpen"
        ev.append({"ms": t, "type": "journey", "from": a, "to": b})
        s += _pair_run(t + 1, a, b, fam, drawn)
        s.append(_m9(t + 900, scene=b, fileScene=b))
        t += 1000
    return {"samples": s, "events": ev, "frames": [{"i": 0, "ms": 0}], "network_attempts": 0}


def test_gates_pairs() -> None:
    ok = wc.gates_pairs(_pairs_tl())
    assert all(g.endswith(("ok", "info")) for g in ok), ok
    assert any("family per ruling 5" in g and g.endswith("FAIL") for g in wc.gates_pairs(_pairs_tl("family")))
    assert any("drawn after the cut" in g and g.endswith("FAIL") for g in wc.gates_pairs(_pairs_tl("drawn")))
    tl = _pairs_tl()
    tl["events"] = tl["events"][:-1]
    assert any("every ordered pair" in g and g.endswith("FAIL") for g in wc.gates_pairs(tl))


def _tour7_tl(**over: object) -> dict:
    tour = ["cafe", "rooftop", "mountainHut", "campfire", "beach", "deepSpace", "livingRoom"]
    origin, s, t = "livingRoom", [_m9(0)], 100
    for to in tour:
        run = _pair_run(t, origin, to, wc.ruled_family(origin, to))
        s += [{**x, "presence": "onScreen", "moonRead": 0.52 if x["fileScene"] in wc.MOON_SCENES else None}
              for x in run]
        s.append(_m9(t + 600, scene=to, fileScene=to,
                     moonRead=0.52 if to in wc.MOON_SCENES else None))
        origin, t = to, t + 1000
    s = [{**x, **over} for x in s]
    return {"samples": s, "events": [], "frames": [{"i": 0, "ms": 0}], "network_attempts": 0, "scene": "livingRoom",
            "tour": tour}


def test_gates_tour7() -> None:
    ok = wc.gates_tour7(_tour7_tl())
    assert all(g.endswith(("ok", "info")) for g in ok), ok
    assert any("moon phase" in g and g.endswith("FAIL") for g in wc.gates_tour7(_tour7_tl(moonPhase=0.3)))
    assert any("December outfit" in g and g.endswith("FAIL") for g in wc.gates_tour7(_tour7_tl(hat="noHat")))
    assert any("festive" in g and g.endswith("FAIL") for g in wc.gates_tour7(_tour7_tl(festive=0.0)))
    assert any("moonPhase written" in g and g.endswith("FAIL") for g in wc.gates_tour7(_tour7_tl(moonRead=None)))


def test_blank_frame() -> None:
    import numpy as np
    rng = np.random.default_rng(1)
    scene = rng.integers(0, 255, (100, 60, 3)).astype(np.uint8)
    assert not wc.blank_frame(scene)
    black_stage = scene.copy()
    black_stage[12:72] = 0          # chrome above and below, nothing on the stage
    assert wc.blank_frame(black_stage)
    assert wc.blank_frame(np.full((100, 60, 3), 128, np.uint8))


def test_drag_gates_wipe_mists_back() -> None:
    during = [_m9(1000 + 50 * k, dragging=True, drag={"trailN": min(16, k), "trailFade": 0.0}, dragRead=min(16, k))
              for k in range(21)]

    def tl(end_fade: float) -> dict:
        after = [_m9(22000, drag={"trailN": 0 if end_fade == 1 else 16, "trailFade": end_fade})]
        return _drag_tl("wipe", "trail", "trailN", during, after, [{"ms": 22100, "type": "dragSettled"}])
    assert all(g.endswith("ok") for g in wc.drag_gates(tl(1.0)))
    assert any("misted back" in g and g.endswith("FAIL") for g in wc.drag_gates(tl(0.4)))


# ---------------------------------------------------------------- M10: wardrobe, personas, captions
BLUE, RED = 0xE64F7FCF, 0xE6D65A4E


def _m10(ms: int, **kw: object) -> dict:
    base = {"ms": ms, "scene": "livingRoom", "speaking": False, "shot": "medium", "move": "ease", "shotSerial": 0,
            "lean": 0.0, "vmTopTint": 0, "tintTopWant": 0, "vmHatTint": 0, "tintHatWant": 0, "vmCostume": "none",
            "vmGesture": "none", "captionSeq": 0, "captionOn": False}
    return {**base, **kw}


def _wardrobe_tl(bad: str = "") -> dict:
    s, ev = [], []
    for k, (label, (top_on, hat_on, costume)) in enumerate(wc.WARDROBE_WANT.items()):
        t0 = k * 5000
        ev += [{"ms": t0, "type": "turn", "i": k, "label": label}, {"ms": t0 + 500, "type": "send", "turn": k},
               {"ms": t0 + 1500, "type": "presenceDone"}, {"ms": t0 + 2800, "type": "presenceDone"},
               {"ms": t0 + 4900, "type": "turnEnd", "i": k, "label": label}]
        sig = costume != "none" or (bad == "normal-signature" and label == "back to normal")
        if sig and not (bad == "no-signature" and label == "robocop"):
            ev.append({"ms": t0 + 3000, "type": "gesture", "name": "signature", "costume": costume})
            if not (bad == "no-done" and label == "soubrette"):
                ev.append({"ms": t0 + 4000, "type": "gestureDone", "gestureId": "signature"})
        top = BLUE if top_on else 0
        hat = RED if hat_on else 0
        for t in range(t0, t0 + 5000, 100):
            read_top = BLUE if bad == "tint-under-costume" and costume == "batman" else top
            gesture = "signature" if sig and t0 + 3000 <= t < t0 + 4000 else "none"
            s.append(_m10(t, vmTopTint=read_top, tintTopWant=top, vmHatTint=hat, tintHatWant=hat,
                          vmCostume=costume, vmGesture=gesture))
    ev.sort(key=lambda e: e["ms"])
    return {"wow": "wardrobe", "kind": "wardrobe", "samples": s, "events": ev, "frames": [{"i": 0, "ms": 0}],
            "network_attempts": 0}


def test_gates_wardrobe() -> None:
    ok = wc.gates_wardrobe(_wardrobe_tl())
    assert all(g.endswith(("ok", "info")) for g in ok), [g for g in ok if g.endswith("FAIL")]
    bad = wc.gates_wardrobe(_wardrobe_tl("tint-under-costume"))
    assert any(g.startswith("batman: tints") and g.endswith("FAIL") for g in bad)
    assert any(g.startswith("topTint: a colour") and g.endswith("FAIL") for g in bad)
    assert any(g.startswith("robocop: signature") and g.endswith("FAIL")
               for g in wc.gates_wardrobe(_wardrobe_tl("no-signature")))
    assert any(g.startswith("soubrette: signature") and g.endswith("FAIL")
               for g in wc.gates_wardrobe(_wardrobe_tl("no-done")))
    assert any(g.startswith("back to normal: no signature") and g.endswith("FAIL")
               for g in wc.gates_wardrobe(_wardrobe_tl("normal-signature")))
    tl = _wardrobe_tl()
    tl["network_attempts"] = 1
    assert any("network" in g and g.endswith("FAIL") for g in wc.gates_wardrobe(tl))


def _persona_tl(gestures: dict | None = None, pitch: dict | None = None) -> dict:
    gestures = gestures or {"doomer": ["shrug"], "coach": ["thumbsUp", "clap", "thumbsUp"],
                            "philosopher": ["think", "think"]}
    pitch = pitch or {"doomer": -0.2, "coach": 0.08, "philosopher": -0.08}
    s, ev = [], []
    for k, p in enumerate(["doomer", "coach", "philosopher"]):
        t0 = k * 10000
        ev += [{"ms": t0, "type": "turn", "i": k, "label": p, "persona": p, "profileArmed": True},
               {"ms": t0 + 1500, "type": "send", "turn": k}, {"ms": t0 + 2000, "type": "start"},
               {"ms": t0 + 9000, "type": "turnEnd", "i": k, "label": p}]
        ev += [{"ms": t0 + 2500 + 1000 * j, "type": "gesture", "name": g} for j, g in enumerate(gestures[p])]
        s += [_m10(t, lean=0.6) for t in range(t0, t0 + 1500, 100)]
        s += [_m10(t, speaking=True, vmPitch=pitch[p] + 0.01 * (t % 3), vmLean=0.1, vmRoll=0.0)
              for t in range(t0 + 2000, t0 + 8000, 100)]
    ev.sort(key=lambda e: e["ms"])
    return {"wow": "persona", "kind": "persona", "samples": s, "events": ev, "frames": [{"i": 0, "ms": 0}],
            "network_attempts": 0}


def test_gates_persona() -> None:
    ok = wc.gates_persona(_persona_tl())
    assert all(g.endswith(("ok", "info")) for g in ok), [g for g in ok if g.endswith("FAIL")]
    same = wc.gates_persona(_persona_tl(gestures={p: ["nod"] for p in ("doomer", "coach", "philosopher")}))
    assert any("differ pairwise" in g and g.endswith("FAIL") for g in same)
    flat = wc.gates_persona(_persona_tl(pitch={"doomer": 0.0, "coach": 0.0, "philosopher": 0.0}))
    assert any(g.startswith("mean pitch") and g.endswith("FAIL") for g in flat)
    tl = _persona_tl()
    for x in tl["samples"]:
        x.pop("vmPitch", None)
    assert any("read back from AvatarVM" in g and g.endswith("FAIL") for g in wc.gates_persona(tl))


def _caption_tl(bad: str = "") -> dict:
    s, ev = [], []
    for k, name in enumerate(wc.CAPTION_PASSES):
        t0 = k * 20000
        ev += [{"ms": t0, "type": "turn", "i": k, "label": name}, {"ms": t0 + 1000, "type": "send", "turn": k},
               {"ms": t0 + 2000, "type": "caption", "text": "a"}, {"ms": t0 + 19000, "type": "turnEnd", "i": k}]
        for j, t in enumerate(range(t0 + 2000, t0 + 18000, 100)):
            seq = 4 * k + 1 + j // 40
            within = j % 40
            if name == "textScale":
                bubble = bad == "bubble-at-1.6" and j == 5
                classic = not bubble
            else:
                share = 0.3 if bad == "few-bubbles" and name == "default" else 0.8
                bubble = within < 40 * share
                classic = not bubble
            if bad == "both" and name == "default" and j in (3, 4):
                classic = True
            x = 100 + (within * 2 if name == "default" else 0)
            if bad == "drift" and name == "reduceMotion" and within in (5, 10):
                x += 10 * within
            s.append(_m10(t, speaking=True, captionOn=True, captionSeq=seq, bubble=bubble, classic=classic,
                          bubbleRect=[float(x), 200.0, 180.0, 90.0] if bubble else None,
                          anchor=[400.0, 380.0]))
    ev.sort(key=lambda e: e["ms"])
    return {"wow": "caption", "kind": "caption", "samples": s, "events": ev, "frames": [{"i": 0, "ms": 0}],
            "network_attempts": 0}


def test_gates_caption() -> None:
    ok = wc.gates_caption(_caption_tl())
    assert all(g.endswith(("ok", "info")) for g in ok), [g for g in ok if g.endswith("FAIL")]
    assert any(g.startswith("default: the bubble shows") and g.endswith("FAIL")
               for g in wc.gates_caption(_caption_tl("few-bubbles")))
    assert any(g.startswith("never both") and g.endswith("FAIL") for g in wc.gates_caption(_caption_tl("both")))
    assert any(g.startswith("reduceMotion: the bubble placed") and g.endswith("FAIL")
               for g in wc.gates_caption(_caption_tl("drift")))
    assert any(g.startswith("textScale 1.6") and g.endswith("FAIL")
               for g in wc.gates_caption(_caption_tl("bubble-at-1.6")))


def test_bubble_moves_counts_jumps_per_sentence() -> None:
    xs = [_m10(0, bubble=True, captionSeq=1, bubbleRect=[10.0, 10.0, 5.0, 5.0]),
          _m10(33, bubble=True, captionSeq=1, bubbleRect=[10.5, 10.0, 5.0, 5.0]),   # under 1 dp: no move
          _m10(66, bubble=True, captionSeq=1, bubbleRect=[30.0, 10.0, 5.0, 5.0]),
          _m10(99, bubble=False, captionSeq=1, bubbleRect=None),
          _m10(132, bubble=True, captionSeq=2, bubbleRect=[90.0, 10.0, 5.0, 5.0])]   # new sentence: no move
    assert wc.bubble_moves(xs) == {1: 1, 2: 0}


def test_reel_is_capped_at_twelve_seconds() -> None:
    tl = _wardrobe_tl()
    segs = wc.reel_segments(tl)
    assert len(segs) == 4 and sum(b - a for a, b in segs) <= wc.REEL_MAX_S * 1000
    frames = [{"i": k, "ms": 100 * k} for k in range(400)]
    idx = wc.reel_indices(frames, segs)
    assert len(idx) == 100   # 4 x 2.5 s at 10 fps
    assert len(wc.reel_indices(frames, [(0, 30000)])) == 300
    tl = _persona_tl()
    assert sum(b - a for a, b in wc.reel_segments(tl)) <= wc.REEL_MAX_S * 1000
    tl = _caption_tl()
    (a, b), = wc.reel_segments(tl)
    assert b - a == wc.REEL_MAX_S * 1000


def test_beats_m10_sheets_have_8_to_16_cells() -> None:
    for tl in (_wardrobe_tl(), _persona_tl(), _caption_tl()):
        n = len(wc.beats(tl))
        assert 8 <= n <= 16, (tl["kind"], n)
