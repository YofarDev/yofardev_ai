"""The storybook jacket (moonshot M8 Task 3, plan ruling 5; contract v11 `jacket`).

One drawing, used by both files so the handoff at the `grab` contact shows one jacket:
- `gen_avatar.py`: under the viewer's-right `Hand`, at its grip point, kept upright (a world rotation /
  scale lock) while `AvatarVM.jacket` is true;
- `gen_journeys.py`: on the door family's peg at the hook point (628, 560), opacity `JourneyVM.jacket`.

A short ochre coat folded over a hook: the collar loop, a front and a back panel, one sleeve (4 shapes).
Coordinates are relative to the hang point (the hook / the closed hand), y down. Everything stays left of
x - 8, so with the hang point at the hook (x 628) no part reaches the door jamb (x 624, drawn by the journey in
front of the avatar) nor the journey threshold (x 640, where the app clips the avatar): both copies always
show whole. Colours are fitted into every scene's
colour script (as gen_journeys.fit does), so both files lint clean wherever the jacket shows.
"""

from __future__ import annotations

from art_bible import SCENES, fit_colour
from rml import Doc, El, lin, smooth_path

HOOK = (628.0, 560.0)         # contract v11 hook point
RIGHT_LIMIT = -8.0            # no point right of hang x + this: the jamb's outer edge is x 624 (stroke 2.5)
INK = "FF2A1E24"
OCHRE = "FFC9923E"
OCHRE_SH = "FF9C6A2A"
OCHRE_HI = "FFDDB060"
LINING = "FF7A4A2C"


def fit_all(c: str) -> str:
    """A colour inside every scene's colour script (the journey file shows in all four)."""
    out = c.upper()
    for _ in range(4):
        before = out
        for sid in SCENES:
            out = fit_colour(out, sid)
        if out == before:
            break
    return out


# shape -> points (relative to the hang point; first listed = front), then shifted SHIFT px left: the collar
# loop hangs off the peg's knob end, and the whole coat stays left of the door jamb's outer edge (x 624), which
# the journey file draws in front of the avatar, so neither copy is ever partly covered by the jamb
SHIFT = -18.0
_PARTS: dict[str, list[tuple]] = {
    "JacketCollar": [(-40.0, 6.0), (-30.0, -6.0), (-6.0, -9.0), (7.0, -3.0), (9.0, 8.0, "c"), (-2.0, 20.0),
                     (-24.0, 22.0), (-42.0, 18.0, "c")],
    "JacketSleeve": [(-56.0, 26.0), (-40.0, 30.0), (-42.0, 108.0), (-36.0, 146.0, "c3"), (-58.0, 150.0, "c3"),
                     (-62.0, 110.0), (-64.0, 50.0)],
    "JacketFront": [(-48.0, 14.0), (6.0, 14.0), (8.0, 100.0), (4.0, 182.0, "c4"), (-50.0, 188.0, "c4"),
                    (-56.0, 100.0)],
    "JacketBack": [(-88.0, 16.0), (-30.0, 12.0), (-28.0, 120.0), (-34.0, 200.0, "c5"), (-92.0, 196.0, "c5"),
                   (-96.0, 110.0)],
}


PARTS: dict[str, list[tuple]] = {k: [(p[0] + SHIFT, *p[1:]) for p in v] for k, v in _PARTS.items()}


def _shape(d: Doc, name: str, pts: list, *paints: El) -> El:
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    ox, oy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    loc = [((p[0] - ox, p[1] - oy) + tuple(p[2:])) for p in pts]
    return d("Shape", smooth_path(d, loc), *paints, x=float(ox), y=float(oy), name=name)


def jacket(d: Doc, name: str = "Jacket", **kw: object) -> El:
    """The jacket drawing as one node whose origin is the hang point (extra attrs, e.g. opacity, on it)."""
    def fill(c: str) -> El:
        return d("Fill", d("SolidColor", colorValue=fit_all(c)), name="Fill")

    def vfill(y0: float, y1: float, c0: str, c1: str) -> El:
        return d("Fill", lin(d, 0, y0, 0, y1, [(fit_all(c0), 0.0), (fit_all(c1), 1.0)]), name="Fill")

    def line(w: float, c: str = INK) -> El:
        return d("Stroke", d("SolidColor", colorValue=fit_all(c)), thickness=float(w), cap="round", join="round",
                 name="Line")

    shapes = [
        _shape(d, "JacketCollar", PARTS["JacketCollar"], vfill(-15, 15, OCHRE_HI, OCHRE), line(2.6)),
        _shape(d, "JacketSleeve", PARTS["JacketSleeve"], vfill(-62, 62, OCHRE, OCHRE_SH), line(2.6)),
        _shape(d, "JacketFront", PARTS["JacketFront"], vfill(-87, 87, OCHRE, OCHRE_SH), line(3.0)),
        _shape(d, "JacketBack", PARTS["JacketBack"], vfill(-94, 94, LINING, OCHRE_SH), line(3.0)),
    ]
    return d("Node", *shapes, x=0.0, y=0.0, name=name, **kw)


def extent() -> tuple[float, float, float, float]:
    """(x0, x1, y0, y1) of the drawing's points, relative to the hang point."""
    pts = [p for ps in PARTS.values() for p in ps]
    return min(p[0] for p in pts), max(p[0] for p in pts), min(p[1] for p in pts), max(p[1] for p in pts)
