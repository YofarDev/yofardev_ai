"""Motion-synthesis solvers (moonshot M4 ruling 15): an intent becomes keys.

`action` turns one beat (from `a` to `b`, starting at `start`, lasting `frames`) into keys
that follow the art bible's motion rules: an anticipation away from the target over the first
18 % of the beat, an ease-out main move that overshoots by 12 % of the travel, and a damped
settle back onto the target within 220 ms. `stagger` turns a part order (head leads) into
frame offsets of 40 ms per step. Only new keys use them (the tablet in M4); existing gestures
are not re-synthesised.

Keys are `(frame, value, interpolation)` where the interpolation names the curve of the
segment that STARTS at that key: `hold`, `linear`, or one of the cubic eases in `EASES`
(`easeIn`, `easeOut`, `easeInOut`). `to_track_keys` maps them onto `rml.track` keys.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Callable, Sequence

from art_bible import MOTION, MotionRules

# Cubic-bezier control points (x1, y1, x2, y2) per named ease. All y in 0..1, so a segment
# never leaves the range between its two keys: the extremes are the keys themselves.
EASES: dict[str, tuple[float, float, float, float]] = {
    "easeIn": (0.32, 0.0, 0.67, 0.0),
    "easeOut": (0.33, 1.0, 0.68, 1.0),
    "easeInOut": (0.65, 0.0, 0.35, 1.0),
}

SETTLE_SWING: float = 0.25  # the settle's counter-swing, as a share of the overshoot

Key = tuple[int, float, str]


@dataclass(frozen=True)
class Beat:
    """One move: from `a` to `b`, starting at frame `start`, the main action lasting `frames`."""

    start: int
    frames: int
    a: float
    b: float


def action(beat: Beat, rules: MotionRules = MOTION, fps: int = 60) -> list[Key]:
    """Keys for one beat: anticipation, overshooting main move, damped settle, hold.

    The anticipation moves `rules.anticipation` x travel away from `b` over the first
    `rules.anticipation` share of the frames; the main move lands `rules.overshoot` x travel
    past `b` at `start + frames`; the settle swings back through a small counter-swing and
    rests exactly on `b` `rules.settle_ms` later, where a hold key ends the beat.
    """
    s, n, a, b = beat.start, beat.frames, float(beat.a), float(beat.b)
    travel: float = b - a
    if travel == 0 or n <= 1:
        return [(s, a, "hold"), (s + max(n, 0), b, "hold")]
    # The anticipation must land before the main key (n >= 2 leaves room for one frame).
    wind: int = min(max(1, round(n * rules.anticipation)), n - 1)
    settle: int = max(1, round(rules.settle_ms * fps / 1000))
    over: float = rules.overshoot * travel
    keys: list[Key] = [
        (s, a, "easeInOut"),
        (s + wind, a - rules.anticipation * travel, "easeOut"),
        (s + n, b + over, "easeInOut"),
    ]
    if settle >= 4:
        swing: int = max(2, round(settle * 0.55))
        keys.append((s + n + swing, b - SETTLE_SWING * over, "easeInOut"))
    keys.append((s + n + settle, b, "hold"))
    return keys


def stagger(parts: Sequence[str], rules: MotionRules = MOTION, fps: int = 60) -> dict[str, int]:
    """Frame offset per part: `rules.part_offset_ms` per step in the given order (the first part
    leads at 0), rounded from the cumulative time so the error never accumulates."""
    step: float = rules.part_offset_ms * fps / 1000
    return {p: round(i * step) for i, p in enumerate(parts)}


def shifted(keys: Sequence[Key], frames: int) -> list[Key]:
    """The same keys `frames` later (a staggered part)."""
    return [(f + frames, v, m) for f, v, m in keys]


def sample(keys: Sequence[Key], frame: float) -> float:
    """The value of `keys` at `frame` (cubic eases evaluated as Rive does: x is time)."""
    if frame <= keys[0][0]:
        return keys[0][1]
    for (f0, v0, m), (f1, v1, _) in zip(keys, keys[1:]):
        if frame <= f1:
            t: float = (frame - f0) / (f1 - f0)
            if m == "hold":
                return v0 if frame < f1 else v1
            if m in EASES:
                t = _bezier_y(EASES[m], t)
            return v0 + (v1 - v0) * t
    return keys[-1][1]


def to_track_keys(keys: Sequence[Key], ease: Callable[[str], object]) -> list[tuple]:
    """Map synthesised keys onto `rml.track` keys: `ease(name)` returns the shared
    `CubicEaseInterpolator` element for a named ease (one per name per artboard)."""
    out: list[tuple] = []
    for f, v, m in keys:
        out.append((f, v, ease(m)) if m in EASES else (f, v, m))
    return out


def _bezier_y(cp: tuple[float, float, float, float], x: float) -> float:
    x1, y1, x2, y2 = cp

    def bez(p1: float, p2: float, t: float) -> float:
        return 3 * (1 - t) ** 2 * t * p1 + 3 * (1 - t) * t * t * p2 + t ** 3

    lo, hi = 0.0, 1.0
    for _ in range(40):  # bisection on x(t) = x (monotonic for x1, x2 in 0..1)
        mid = (lo + hi) / 2
        if bez(x1, x2, mid) < x:
            lo = mid
        else:
            hi = mid
    return bez(y1, y2, (lo + hi) / 2)
