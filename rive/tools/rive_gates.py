"""The objective Rive gates, run by scripts/frive.sh (M6 ruling 10).

uv run --with pillow --with numpy rive/tools/rive_gates.py [--props] [sceneId ...]

Runs `review_diorama.py --gates-only` for each named scene (every scene in rive/scenes/ when none
is named; about 2 min each), then, with `--props`, `motion_review.py --gates-only` (the tablet and
newspaper prop gates, about 23 min: M6 execution ruling 28), streaming every line. A line holding the word FAIL fails the run: exit 1. An unknown scene id exits 2.
"""

from __future__ import annotations

from pathlib import Path
import re
import subprocess
import sys

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parents[1]
FAIL = re.compile(r"\bFAIL\b")
PROGRESS = re.compile(r"^(?:\w+: )?Captured \d+/\d+ frames")


def collect(lines: list[str]) -> bool:
    """True when no line holds the whole word FAIL (case-sensitive)."""
    return not any(FAIL.search(line) for line in lines)


def known_scenes() -> list[str]:
    return sorted(d.name for d in (ROOT / "rive" / "scenes").iterdir() if d.is_dir())


def parse_scenes(argv: list[str], known: list[str]) -> list[str]:
    """The scenes to check: `argv` in order, or all of `known` when empty; exit 2 on an unknown id."""
    unknown = [a for a in argv if a not in known]
    if unknown:
        print(f"unknown scene {', '.join(unknown)} (known: {', '.join(known)})", file=sys.stderr)
        raise SystemExit(2)
    return list(argv) if argv else list(known)


def _stream(script: str, *args: str) -> tuple[list[str], int]:
    """Run a sub-script with the same uv invocation, echoing its lines as they arrive."""
    cmd = ["uv", "run", "--with", "pillow", "--with", "numpy", str(TOOLS / script), *args]
    proc = subprocess.Popen(cmd, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    assert proc.stdout is not None
    lines: list[str] = []
    for raw in proc.stdout:
        line = raw.rstrip("\n")
        print(line, flush=True)
        if line.strip() and not PROGRESS.match(line):
            lines.append(line)
    return lines, proc.wait()


def runs_for(argv: list[str], known: list[str]) -> list[tuple[str, ...]]:
    """(script, *args) to run: the scene gates, and the prop gates only with `--props`."""
    scenes = parse_scenes([a for a in argv if a != "--props"], known)
    runs = [("review_diorama.py", scene, "--gates-only") for scene in scenes]
    if "--props" in argv:
        runs.append(("motion_review.py", "--gates-only"))
    return runs


def main(argv: list[str]) -> int:
    runs = runs_for(argv, known_scenes())
    lines: list[str] = []
    crashed = 0
    for script, *args in runs:
        got, code = _stream(script, *args)
        lines += got
        if code != 0 and collect(got):  # a non-zero exit with no FAIL line: a crash, not a verdict
            crashed += 1
            print(f"! {script} {' '.join(args)} exited {code} without a verdict", flush=True)
    failures = sum(1 for line in lines if FAIL.search(line)) + crashed
    if failures:
        print(f"✗ gates: {failures} FAIL")
        return 1
    print(f"✓ gates: {len(lines)} lines ok")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
