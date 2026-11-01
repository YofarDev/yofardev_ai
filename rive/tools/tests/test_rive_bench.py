"""Moonshot M11 ruling 15: the CLI bench per scene x tier (`rive_bench.py`) and its gate in rive_gates.py."""

from __future__ import annotations

from pathlib import Path
import sys

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import rive_bench  # noqa: E402
import rive_gates  # noqa: E402

OUT = """[14:37:10.390] rive  bench advance: mean 0.123ms p50 0.120ms p95 0.157ms max 0.194ms
[14:37:10.390] rive  bench render: mean 0.738ms p50 0.731ms p95 1.026ms max 1.185ms
[14:37:10.390] rive  bench memory: 0 -> 0 wasm pages (+0) over 240 frames"""


def _run(render_p95: float) -> dict[str, dict[str, float]]:
    return {"advance": {"mean": 0.1, "p50": 0.1, "p95": 0.2, "max": 0.3},
            "render": {"mean": render_p95 * 0.7, "p50": render_p95 * 0.7, "p95": render_p95, "max": render_p95 * 1.3}}


def test_parses_the_cli_bench_lines() -> None:
    got = rive_bench.parse_bench(OUT)
    assert got["render"] == {"mean": 0.738, "p50": 0.731, "p95": 1.026, "max": 1.185}
    assert got["advance"]["p95"] == 0.157
    with pytest.raises(ValueError):
        rive_bench.parse_bench("rive  built x.riv")


def test_parses_uptime_on_macos_and_linux() -> None:
    assert rive_bench.parse_load("14:35  up  7:02, 3 users, load averages: 3.44 6.80 6.94") == (3.44, 6.8, 6.94)
    assert rive_bench.parse_load(" 14:35:01 up 2 days,  1 user,  load average: 0.52, 0.58, 0.59") == (0.52, 0.58, 0.59)


def test_tiers_rotate_per_repeat() -> None:
    orders = [rive_bench.tier_order(k) for k in range(3)]
    assert orders[0] == ["ultra", "high", "low"]
    assert all(sorted(o) == sorted(rive_bench.TIERS) for o in orders)
    assert len({o[0] for o in orders}) == 3


def test_ratio_compares_the_best_runs_and_gates_follow_ruling_15() -> None:
    # a load spike in repeat 1 slows every tier: the best runs stay put
    b = rive_bench.SceneBench("campfire", {"ultra": [_run(1.0), _run(2.0), _run(1.1)],
                                           "high": [_run(1.0), _run(2.04), _run(1.1)],
                                           "low": [_run(0.6), _run(1.2), _run(0.66)]})
    assert b.ratio("low") == pytest.approx(0.6)
    assert b.ratio("high") == pytest.approx(1.0)
    assert b.median("ultra", "render", "p95") == 1.1
    lines = rive_bench.gate_lines(b)
    assert len(lines) == 2 and all(line.endswith(" ok") for line in lines)
    b.runs["low"] = [_run(0.85), _run(1.7), _run(0.9)]
    b.runs["high"] = [_run(1.05), _run(2.1), _run(1.15)]
    assert all(line.endswith("FAIL") for line in rive_bench.gate_lines(b))
    assert rive_gates.collect(rive_bench.gate_lines(b)) is False
    summary = b.summary()
    assert set(summary) == {*rive_bench.TIERS, "load", "redone"} and summary["low"]["repeats"] == 3


def test_markdown_records_the_load_and_every_tier() -> None:
    b = rive_bench.SceneBench("beach", {t: [_run(1.0)] for t in rive_bench.TIERS})
    md = rive_bench.markdown([b], [], {"rive": "1.8.0", "frames": 240, "repeats": 1, "viewport": "1080x1920 @1x",
                                       "load_before": (3.0, 4.0, 5.0), "load_after": (6.0, 7.0, 8.0)})
    assert "3.00 / 4.00 / 5.00" in md and "6.00 / 7.00 / 8.00" in md
    assert all(f"| beach | {t} |" in md for t in rive_bench.TIERS)


def test_rive_gates_runs_the_bench_for_the_scenes() -> None:
    runs = rive_gates.runs_for(["campfire"], ["beach", "campfire"])
    assert ("rive_bench.py", "campfire", "--gates-only") in runs


def test_a_preempted_run_is_recognised() -> None:
    run = _run(1.0)
    assert not rive_bench.preempted(run)
    run["render"]["p50"] = 0.4    # p95 2.5 x p50: the host's scheduler, not the scene
    assert rive_bench.preempted(run)


def test_waits_for_the_load_to_fall_but_not_forever() -> None:
    loads = iter([9.0, 8.0, 5.0, 1.0])
    slept: list[float] = []
    got = rive_bench.wait_for_load(120, 10, sleep=slept.append, load=lambda: (next(loads), 0.0, 0.0))
    assert got == 5.0 and slept == [10.0, 10.0]          # 0.6 x 10 cores = 6
    slept.clear()
    got = rive_bench.wait_for_load(20, 10, sleep=slept.append, load=lambda: (30.0, 0.0, 0.0))
    assert got == 30.0 and slept == [10.0, 10.0]


def test_high_over_the_limit_fails_only_when_every_repeat_costs_more() -> None:
    b = rive_bench.SceneBench("cafe", {"ultra": [_run(1.0), _run(1.1), _run(1.0), _run(1.0), _run(1.0)],
                                       "low": [_run(0.6)] * 5,
                                       "high": [_run(1.06), _run(1.08), _run(1.05), _run(1.04), _run(1.03)]})
    high = rive_bench.gate_lines(b)[1]
    assert " ok (noise: 1 of 5" in high and rive_gates.collect([high])
    b.runs["high"] = [_run(1.05), _run(1.2), _run(1.04), _run(1.07), _run(1.05)]
    assert rive_bench.gate_lines(b)[1].endswith("FAIL")
    # low has no such allowance
    b.runs["low"] = [_run(0.85), _run(0.95), _run(0.82), _run(0.9), _run(0.88)]
    assert rive_bench.gate_lines(b)[0].endswith("FAIL")


def _bench(scene: str, low: float, high: float = 1.0) -> rive_bench.SceneBench:
    return rive_bench.SceneBench(scene, {"ultra": [_run(1.0)] * 5, "low": [_run(low)] * 5, "high": [_run(high)] * 5})


def test_a_passing_scene_is_measured_once() -> None:
    calls: list[int] = []
    notes: list[str] = []

    def run() -> rive_bench.SceneBench:
        calls.append(1)
        return _bench("library", 0.7)
    b = rive_bench.bench_gated(run, note=notes.append)
    assert len(calls) == 1 and b.first is None and not notes
    assert all("retried" not in line and line.endswith(" ok") for line in rive_bench.gate_lines(b))


def test_a_failed_scene_is_measured_again_and_passes_on_the_re_run() -> None:
    # M12 ruling 4: library low 0.824 under load, 0.780 re-run alone (M11 ruling 43)
    runs = iter([_bench("library", 0.824), _bench("library", 0.78)])
    notes: list[str] = []
    b = rive_bench.bench_gated(lambda: next(runs), note=notes.append)
    assert b.first is not None and b.ratio("low") == pytest.approx(0.78)
    low, high = rive_bench.gate_lines(b)
    assert "retried: first 0.824 over" in low and low.endswith(" ok")
    assert "retried: first 1.000 within" in high and high.endswith(" ok")
    assert rive_gates.collect([low, high, *notes])     # neither the lines nor the note say FAIL
    assert len(notes) == 1 and "measuring once more" in notes[0]
    assert b.summary()["retried"]["low"]["ratio_p95"] == pytest.approx(0.824)


def test_a_scene_fails_only_when_the_re_run_fails_too() -> None:
    runs = iter([_bench("mountainHut", 0.83), _bench("mountainHut", 0.85)])
    b = rive_bench.bench_gated(lambda: next(runs), note=lambda _: None)
    low = rive_bench.gate_lines(b)[0]
    assert "retried: first 0.830 over" in low and low.endswith("FAIL")
    assert rive_gates.collect([low]) is False
    # a tier that passed the first time is not failed by the re-run
    runs = iter([_bench("cafe", 0.85, 1.0), _bench("cafe", 0.7, 1.2)])
    b = rive_bench.bench_gated(lambda: next(runs), note=lambda _: None)
    low, high = rive_bench.gate_lines(b)
    assert low.endswith(" ok") and "retried: first 1.000 within" in high and "FAIL" not in high
    with pytest.raises(StopIteration):     # never a third measurement
        next(runs)
