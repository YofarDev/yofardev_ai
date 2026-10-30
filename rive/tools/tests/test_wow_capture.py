"""Tests for the wow capture's gates and audio timing (moonshot M6 Task 6, ruling 7)."""

from __future__ import annotations

from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

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
