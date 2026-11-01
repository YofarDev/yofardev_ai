"""The CLI bench per scene and quality tier (moonshot M11 ruling 15, contract v14 `tier`).

    uv run rive/tools/rive_bench.py [sceneId ...] [--repeats=N] [--frames=N] [--rain] [--gates-only] [--out=DIR]

For every scene (default: every project in rive/scenes/) x tier (low, high, ultra) runs
`rive rive/scenes/<id> --bench=<frames> --data=tier=<t>` (headless, a fresh build each time) `--repeats`
times (default 5), the tiers interleaved and their order rotated per repeat so the host's load drifts
over all three alike (the tier ratio compares each tier's best p95 over its repeats). A run whose render p95 exceeds `PREEMPTED` x its p50 was preempted by the host
(a loaded Mac: p95 then measures the scheduler, not the scene) and is redone, at most `TRIES` times; before
each scene the bench waits (at most `--max-wait` s, default 180) for the 1-min load to fall to `LOAD_OK` x the
core count, and records the load it ran at. Each stat (advance / render mean, p50, p95, max) is the median over the repeats;
the tier ratio is the best (least disturbed) render p95 of the tier over the best of ultra. `uptime` is recorded before and after. `--rain` benches each tier again at rain 1
(recorded, not gated).

Writes `bench.md` (table) and `bench.json` into `--out` (default `rive/review/m12/perf/`; M11's own
evidence stays in `rive/review/m11/perf/`), unless `--gates-only`, which prints the gate lines only (run
by rive_gates.py, so by scripts/frive.sh). The gate (ruling 15), per scene at
rest: low's render p95 <= LOW_MAX x ultra's, high's <= HIGH_MAX x ultra's (the 2 % is noise), where a high
over 1.02 fails only when every paired repeat is over ultra (the 2 % is below this host's noise: identical
files measure 0.97-1.04; see `gate_lines`). A line with FAIL fails the gates.

M12 ruling 4: a scene whose gate fails is measured once more (after the load wait, `bench_gated`) and a
tier fails only when it fails in both measurements; such a line ends its numbers with `retried` and the
first measurement's ratio (the line shows the re-run's numbers).
"""

from __future__ import annotations

from dataclasses import dataclass, field
import json
import os
from pathlib import Path
import re
import statistics
import subprocess
import sys
import time
from typing import Callable

ROOT = Path(__file__).resolve().parents[2]
SCENES_DIR = ROOT / "rive" / "scenes"
OUT = ROOT / "rive" / "review" / "m12" / "perf"
TIERS = ("ultra", "high", "low")
LOW_MAX = 0.8
HIGH_MAX = 1.02
REPEATS = 5
FRAMES = 1200   # p95 over 1200 frames: paired ratios within ~5 % on a loaded Mac (240: ~10 %)
STATS = ("mean", "p50", "p95", "max")
PREEMPTED = 2.0          # render p95 / p50 above this: the run measured the host's scheduler
TRIES = 4
LOAD_OK = 0.6            # x the core count: the 1-min load a scene waits for
LINE = re.compile(r"bench (advance|render): mean ([\d.]+)ms p50 ([\d.]+)ms p95 ([\d.]+)ms max ([\d.]+)ms")
LOAD = re.compile(r"load averages?: ([\d.]+),? ([\d.]+),? ([\d.]+)")


def parse_bench(text: str) -> dict[str, dict[str, float]]:
    """{"advance": {mean, p50, p95, max}, "render": {...}} (ms) from the CLI's bench lines."""
    out: dict[str, dict[str, float]] = {}
    for m in LINE.finditer(text):
        out[m.group(1)] = dict(zip(STATS, (float(v) for v in m.groups()[1:])))
    if set(out) != {"advance", "render"}:
        raise ValueError(f"no bench lines in rive output:\n{text[-600:]}")
    return out


def parse_load(text: str) -> tuple[float, float, float]:
    """The 1 / 5 / 15 min load averages of an `uptime` line."""
    m = LOAD.search(text)
    if m is None:
        raise ValueError(f"no load averages in {text!r}")
    return float(m.group(1)), float(m.group(2)), float(m.group(3))


def uptime() -> tuple[float, float, float]:
    return parse_load(subprocess.run(["uptime"], capture_output=True, text=True, check=True).stdout)


def preempted(run: dict[str, dict[str, float]]) -> bool:
    """True when the host preempted the run (its render p95 is over PREEMPTED x its p50)."""
    return run["render"]["p95"] > PREEMPTED * run["render"]["p50"]


def wait_for_load(max_wait: float, cores: int, sleep: Callable[[float], None] = time.sleep,
                  load: Callable[[], tuple[float, float, float]] | None = None) -> float:
    """Waits (polling every 10 s, at most `max_wait` s) until the 1-min load is <= LOAD_OK x `cores`;
    returns the 1-min load it ends at."""
    load = load or uptime
    waited = 0.0
    now = load()[0]
    while now > LOAD_OK * cores and waited < max_wait:
        sleep(10.0)
        waited += 10.0
        now = load()[0]
    return now


def tier_order(repeat: int) -> list[str]:
    """The tiers of one repeat, rotated by one per repeat (load drift lands on each tier alike)."""
    k = repeat % len(TIERS)
    return [*TIERS[k:], *TIERS[:k]]


@dataclass
class SceneBench:
    """One scene's runs: `runs[tier]` = one parse_bench dict per repeat (the same repeat index pairs)."""

    scene: str
    runs: dict[str, list[dict[str, dict[str, float]]]] = field(default_factory=dict)
    load: float = 0.0        # the 1-min load when the scene started
    redone: int = 0          # preempted runs redone
    first: SceneBench | None = None   # M12 ruling 4: the failed first measurement this one re-ran

    def median(self, tier: str, what: str, stat: str) -> float:
        return statistics.median(r[what][stat] for r in self.runs[tier])

    def ratio(self, tier: str) -> float:
        """Best render p95 of `tier` over its repeats / best render p95 of ultra. The host's interference
        (other processes, the GPU shared with a browser) only ever adds time, and it compresses a ratio
        toward 1 (measured: library low 0.76 on a quiet host, 0.84 beside a busy GPU), so the gate compares
        each tier's least disturbed run."""
        return min(r["render"]["p95"] for r in self.runs[tier]) / min(r["render"]["p95"] for r in self.runs["ultra"])

    def summary(self) -> dict[str, object]:
        retried = {} if self.first is None else {"retried": {"load": self.first.load, **{
            t: {"ratio_p95": round(self.first.ratio(t), 4)} for t in TIERS}}}
        return {"load": self.load, "redone": self.redone, **retried,
                **{t: {"render": {s: round(self.median(t, "render", s), 4) for s in STATS},
                       "advance": {s: round(self.median(t, "advance", s), 4) for s in STATS},
                       "ratio_p95": round(self.ratio(t), 4), "repeats": len(self.runs[t])} for t in TIERS}}


def paired(b: SceneBench, tier: str) -> list[float]:
    """The per-repeat render p95 ratios of `tier` to ultra (paired by repeat)."""
    return [t["render"]["p95"] / u["render"]["p95"] for t, u in zip(b.runs[tier], b.runs["ultra"])]


GATED = (("low", LOW_MAX), ("high", HIGH_MAX))


def verdict(b: SceneBench, tier: str, limit: float) -> str:
    """One tier's ruling-15 verdict: "ok", "ok (noise: ...)" or "FAIL". low: the best p95 ratio <= LOW_MAX.
    high: the ratio <= HIGH_MAX, or, above it, not every repeat over 1 (no measurable cost: at rest high
    draws all but a few twinkle copies of ultra, so its ratio is the host's noise, measured 0.97-1.04 for
    identical files; a high that really cost more than ultra would come out over 1 in every paired repeat)."""
    r = b.ratio(tier)
    pr = paired(b, tier)
    if r <= limit:
        return "ok"
    if tier == "high" and not all(x > 1.0 for x in pr):
        return f"ok (noise: {sum(x <= 1.0 for x in pr)} of {len(pr)} repeats at or under ultra)"
    return "FAIL"


def failed(b: SceneBench) -> bool:
    """True when a gated tier of this measurement fails."""
    return any(verdict(b, tier, limit) == "FAIL" for tier, limit in GATED)


def gate_lines(b: SceneBench) -> list[str]:
    """The ruling-15 verdicts of one scene (`verdict`). A re-run (M12 ruling 4: `b.first` holds the failed
    first measurement) fails a tier only when the first measurement failed it too; its line says `retried`
    and gives the first ratio (`over` the limit or within it)."""
    out = []
    for tier, limit in GATED:
        v = verdict(b, tier, limit)
        retry = ""
        if b.first is not None:
            fv = verdict(b.first, tier, limit)
            retry = f", retried: first {b.first.ratio(tier):.3f} {'over' if fv == 'FAIL' else 'within'}"
            if v == "FAIL" and fv != "FAIL":
                v = "ok (the first measurement passed)"
        out.append(f"bench {b.scene}: {tier} render p95 {b.median(tier, 'render', 'p95'):.3f} ms = {b.ratio(tier):.3f} x "
                   f"ultra {b.median('ultra', 'render', 'p95'):.3f} ms (<= {limit}; load {b.load:.1f}, {b.redone} redone"
                   f"{retry}) {v}")
    return out


def bench_gated(run: Callable[[], SceneBench], note: Callable[[str], None] = print) -> SceneBench:
    """M12 ruling 4: `run()` (one scene's measurement, its load wait included); when a gate fails, `run()`
    once more and return the re-run with the failed first one in `first` (a busy host squeezes the tier
    ratios toward 1: a scene fails only when the re-run fails too)."""
    b = run()
    if not failed(b):
        return b
    note(f"bench {b.scene}: over the line ({', '.join(f'{t} {b.ratio(t):.3f}' for t, _ in GATED)}); "
         "measuring once more after the load wait")
    again = run()
    again.first = b
    return again


def bench_once(scene: str, tier: str, frames: int, rain: bool = False) -> dict[str, dict[str, float]]:
    args = ["rive", str(SCENES_DIR / scene), f"--bench={frames}", f"--data=tier={tier}"]
    if rain:
        args.append("--data=rain=1")
    r = subprocess.run(args, capture_output=True, text=True)
    if r.returncode:
        raise SystemExit(f"rive bench failed for {scene} {tier}: {r.stderr[-600:]}")
    return parse_bench(r.stdout + r.stderr)


def bench_scene(scene: str, repeats: int, frames: int, rain: bool = False, load: float = 0.0) -> SceneBench:
    b = SceneBench(scene, {t: [] for t in TIERS}, load=load)
    for k in range(repeats):
        for t in tier_order(k):
            run = bench_once(scene, t, frames, rain)
            for _ in range(TRIES - 1):
                if not preempted(run):
                    break
                b.redone += 1
                run = bench_once(scene, t, frames, rain)
            b.runs[t].append(run)
    return b


def table(benches: list[SceneBench], title: str) -> list[str]:
    rows = [f"### {title}", "",
            "| scene | tier | render mean | render p50 | render p95 | p95 / ultra | advance mean | advance p95 | load | redone |",
            "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for b in benches:
        for t in TIERS:
            rows.append(f"| {b.scene} | {t} | {b.median(t, 'render', 'mean'):.3f} | {b.median(t, 'render', 'p50'):.3f} | "
                        f"{b.median(t, 'render', 'p95'):.3f} | {b.ratio(t):.3f} | {b.median(t, 'advance', 'mean'):.3f} | "
                        f"{b.median(t, 'advance', 'p95'):.3f} | {b.load:.1f} | {b.redone} |")
    return rows + [""]


def markdown(rest: list[SceneBench], rain: list[SceneBench], meta: dict[str, object]) -> str:
    lb, la = meta["load_before"], meta["load_after"]
    lines = ["# CLI bench per scene and tier (M11 ruling 15)", "",
             f"`rive <scene> --bench={meta['frames']} --data=tier=<t>` (rive {meta['rive']}, headless, "
             f"{meta['viewport']}), {meta['repeats']} repeats per scene x tier, tiers interleaved; each value is "
             "the median over the repeats, `p95 / ultra` the best p95 of the tier over the best of ultra (interference "
             "only adds time). Times in ms. "
             "The host is a shared, often loaded Mac: compare tiers within a scene, not across runs. "
             f"A run with render p95 > {PREEMPTED} x its p50 was preempted and is redone (`redone`); each scene "
             f"waits for the 1-min load to fall to {LOAD_OK} x the cores first (`load`: where it started).", "",
             f"Host load (1 / 5 / 15 min) before: {lb[0]:.2f} / {lb[1]:.2f} / {lb[2]:.2f}; "
             f"after: {la[0]:.2f} / {la[1]:.2f} / {la[2]:.2f}.", "",
             f"Gate (every scene, at rest): low p95 <= {LOW_MAX} x ultra, high p95 <= {HIGH_MAX} x ultra (above "
             "it, a FAIL only when every paired repeat is over ultra: identical files measure 0.97-1.04 here). A scene "
             "whose gate fails is measured once more after the load wait and fails only if the re-run fails too "
             "(M12 ruling 4: the table shows the re-run, its gate line says `retried`).", ""]
    lines += table(rest, "At rest (rain 0)")
    if rain:
        lines += table(rain, "Rain 1 (recorded, not gated; the app never creates SceneFront at low)")
    lines += ["### Gates", "", *(f"- {g}" for b in rest for g in gate_lines(b)), ""]
    return "\n".join(lines)


def rive_version() -> str:
    return subprocess.run(["rive", "--version"], capture_output=True, text=True).stdout.strip().removeprefix("rive ")


def main(argv: list[str]) -> int:
    opts = {a.split("=", 1)[0]: (a.split("=", 1)[1] if "=" in a else "1") for a in argv if a.startswith("--")}
    scenes = [a for a in argv if not a.startswith("--")]
    known = sorted(p.name for p in SCENES_DIR.iterdir() if p.is_dir())
    unknown = [s for s in scenes if s not in known]
    if unknown:
        print(f"unknown scene {', '.join(unknown)} (known: {', '.join(known)})", file=sys.stderr)
        return 2
    scenes = scenes or known
    repeats, frames = int(opts.get("--repeats", REPEATS)), int(opts.get("--frames", FRAMES))
    gates_only = "--gates-only" in opts
    max_wait = float(opts.get("--max-wait", 180))
    cores = os.cpu_count() or 8
    load_before = uptime()
    rest: list[SceneBench] = []
    rain: list[SceneBench] = []
    out = Path(opts["--out"]) if "--out" in opts else OUT
    for s in scenes:
        rest.append(bench_gated(lambda s=s: bench_scene(s, repeats, frames, load=wait_for_load(max_wait, cores)),
                                note=lambda m: print(m, flush=True)))
        for line in gate_lines(rest[-1]):
            print(line, flush=True)
        if "--rain" in opts and not gates_only:
            rain.append(bench_scene(s, repeats, frames, rain=True, load=wait_for_load(max_wait, cores)))
    load_after = uptime()
    print(f"bench load before {load_before} after {load_after}", flush=True)
    if gates_only:
        return 0
    meta = {"rive": rive_version(), "frames": frames, "repeats": repeats, "viewport": "1080x1920 @1x", "cores": cores,
            "load_before": load_before, "load_after": load_after, "low_max": LOW_MAX, "high_max": HIGH_MAX}
    out.mkdir(parents=True, exist_ok=True)
    (out / "bench.json").write_text(json.dumps({
        "meta": meta, "rest": {b.scene: b.summary() for b in rest},
        "rain": {b.scene: b.summary() for b in rain},
        "runs": {"rest": {b.scene: b.runs for b in rest}, "rain": {b.scene: b.runs for b in rain}}}, indent=1) + "\n")
    (out / "bench.md").write_text(markdown(rest, rain, meta))
    print(f"wrote {out / 'bench.md'} and bench.json")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
