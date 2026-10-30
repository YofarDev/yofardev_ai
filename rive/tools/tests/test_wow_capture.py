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
