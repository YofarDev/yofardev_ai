"""Moonshot M10 Task 2a (ruling 3): the wardrobe dedupe of avatar.riv.

Copies of a wardrobe piece that differ only in paint (sleeves of the same kind, the hand skins) are
merged into ONE drawing per Solo switch: the first member of a merge class survives with its ids, the
other members' matching elements are dropped, and each member's values are keyed (frame 0, hold) in the
clips that pick it. Elements that only some members draw (a sweater's knit band, a glove's seams) move
into the survivor with their own ids and an opacity key per member (0 where that member does not draw
them).

What may differ between two matched elements (anything else raises: the geometry, the skin weights and
the transforms must be identical):

- `SolidColor.colorValue`, `GradientStop.colorValue` (KeyFrameColor),
- `opacity` of a Shape / Node, `Stroke.thickness` (KeyFrameDouble),
- id references that point inside the merged copies (mapped through the match).

History-free by construction: every clip that keys a member keys EVERY varying property of the class,
so the last clip applied (the later state-machine layer) fully determines what is drawn. Keyed objects
of other clips that target a dropped element must be duplicates of the survivor's own keys in the same
clip (the hand-pose keys every gesture writes per skin): they are dropped; anything else raises. The
generator mints this pass's elements (key objects, properties, frames) from the doc it is given
(gen_avatar: `avatar_kit.M10_ID_START`).
"""

from __future__ import annotations

import re
from collections import Counter
from collections.abc import Iterator
from dataclasses import dataclass, field

from rml import Doc, El

ID = re.compile(r"\d+:\d+")
COLOR_PROPS = {("SolidColor", "colorValue"), ("GradientStop", "colorValue")}
DOUBLE_PROPS = {("Shape", "opacity"), ("Node", "opacity"), ("Solo", "opacity"), ("Stroke", "thickness")}
DEFAULTS = {"opacity": 1.0, "thickness": 1.0}
OPACITY_TAGS = {"Shape", "Node", "Solo"}


def walk(e: El) -> Iterator[El]:
    yield e
    for c in e.children:
        yield from walk(c)


@dataclass
class Merge:
    """One merge class: `members` (label -> group, the survivor first) are children of `solo`; each
    label's values are keyed in `key_clips[label]`; the survivor is renamed `name`."""
    solo: El
    members: dict[str, El]
    name: str
    key_clips: dict[str, list[El]]
    # filled by dedupe()
    keyed: dict[tuple[str, str], dict[str, object]] = field(default_factory=dict)  # (el id, prop) -> label -> value
    dropped: set[str] = field(default_factory=set)
    moved: list[str] = field(default_factory=list)


class _Union:
    def __init__(self, survivor: El, label: str) -> None:
        self.survivor = survivor
        self.show: dict[int, set[str]] = {id(e): {label} for e in walk(survivor)}
        self.values: dict[tuple[int, str], dict[str, object]] = {}
        self.els: dict[int, El] = {id(e): e for e in walk(survivor)}
        self.corr: dict[str, El] = {}           # dropped element id -> survivor element
        self.pairs: list[tuple[El, El, str]] = []
        self.moved: list[El] = []
        self.parent: dict[int, El] = {}
        for e in walk(survivor):
            for c in e.children:
                self.parent[id(c)] = e
        for e in walk(survivor):
            self._record(e, e, label)

    def _record(self, s: El, o: El, label: str) -> None:
        for tag_prop in COLOR_PROPS | DOUBLE_PROPS:
            if s.tag == tag_prop[0]:
                prop = tag_prop[1]
                self.values.setdefault((id(s), prop), {})[label] = o.attrs.get(prop, DEFAULTS.get(prop))

    @staticmethod
    def _keys(children: list[El]) -> list[tuple[str, object, int]]:
        seen: Counter = Counter()
        out = []
        for c in children:
            k = (c.tag, c.attrs.get("name"))
            out.append((*k, seen[k]))
            seen[k] += 1
        return out

    def merge(self, s: El, o: El, label: str) -> None:
        assert s.tag == o.tag, (s.tag, o.tag, s.attrs.get("name"))
        self.corr[o.ref()] = s
        self.show[id(s)].add(label)
        self.pairs.append((s, o, label))
        self._record(s, o, label)
        s_keys = dict(zip(self._keys(s.children), s.children))
        pending: list[El] = []
        last = -1
        for key, oc in zip(self._keys(o.children), list(o.children)):
            sc = s_keys.get(key)
            if sc is None:
                pending.append(oc)
                continue
            at = s.children.index(sc)
            assert at > last, f"{label}: {key} is out of order in {s.attrs.get('name')}"
            if pending:
                self._move(s, o, pending, at, label)
                at += len(pending)
                pending = []
            last = at
            self.merge(sc, oc, label)
        if pending:
            self._move(s, o, pending, len(s.children), label)

    def _move(self, s: El, o: El, extras: list[El], at: int, label: str) -> None:
        """Extras of `o` (drawn only by `label`) move into `s` at `at` (in front of the next match)."""
        for x in extras:
            assert x.tag in OPACITY_TAGS, f"{label}: a {x.tag} only some members draw cannot be hidden"
            o.children.remove(x)
        s.children[at:at] = extras
        for x in extras:
            self.parent[id(x)] = s
            for e in walk(x):
                self.els[id(e)] = e
                self.show[id(e)] = {label}
                for c in e.children:
                    self.parent[id(c)] = e
                self._record(e, e, label)
            self.moved.append(x)

    def check_attrs(self) -> None:
        for s, o, label in self.pairs:
            for k in set(s.attrs) | set(o.attrs):
                if (s.tag, k) in COLOR_PROPS | DOUBLE_PROPS or (s is self.survivor and k == "name"):
                    continue
                vs, vo = s.attrs.get(k), o.attrs.get(k)
                if vs == vo:
                    continue
                if isinstance(vo, str) and ID.fullmatch(vo) and vo in self.corr and self.corr[vo].ref() == vs:
                    continue
                raise ValueError(f"{label}: {o.tag} {o.attrs.get('name')!r}.{k} = {vo!r}, the survivor has {vs!r}")


def _key_obj(doc: Doc, target: El, props: dict[str, object]) -> El:
    kps = []
    for prop, v in props.items():
        tag = "KeyFrameColor" if isinstance(v, str) else "KeyFrameDouble"
        kps.append(doc("KeyedProperty", doc(tag, frame=0, value=v if isinstance(v, str) else float(v),
                                            interpolationType="hold"), property=prop))
    return doc("KeyedObject", *kps, objectId=target.ref())


def _canon(obj: El, corr: dict[str, El]) -> list:
    """A keyed object's content with ids mapped onto the survivor's (for duplicate detection)."""
    def val(v: object) -> object:
        return corr[v].ref() if isinstance(v, str) and v in corr else v
    return [(p.attrs.get("property"), [(k.tag, {a: val(b) for a, b in k.attrs.items()}) for k in p.children])
            for p in obj.children]


def dedupe(doc: Doc, root: El, merges: list[Merge]) -> None:
    clips = [a for a in walk(root) if a.tag == "LinearAnimation"]
    for m in merges:
        labels = list(m.members)
        survivor = m.members[labels[0]]
        u = _Union(survivor, labels[0])
        for label in labels[1:]:
            u.merge(survivor, m.members[label], label)
        u.check_attrs()
        member_ids = {g.ref(): label for label, g in m.members.items()}

        # every property that varies between members (or an element some members do not draw)
        varying: dict[tuple[int, str], dict[str, object]] = {}
        for (eid, prop), vals in u.values.items():
            el = u.els[eid]
            shown = u.show[eid]
            parent = u.parent.get(eid)
            hidden_some = parent is not None and el is not survivor and shown != u.show[id(parent)]
            if prop == "opacity" and hidden_some:
                varying[(eid, prop)] = {lb: (vals.get(lb, 1.0) if lb in shown else 0.0) for lb in labels}
                continue
            distinct = {vals[lb] for lb in shown if lb in vals}
            if len(distinct) > 1:
                fallback = vals[next(lb for lb in labels if lb in vals)]
                varying[(eid, prop)] = {lb: vals.get(lb, fallback) for lb in labels}
        # an extra drawn only by others still needs its opacity property keyed (default 1 = drawn)
        for x in u.moved:
            varying.setdefault((id(x), "opacity"), {lb: (x.attrs.get("opacity", 1.0) if lb in u.show[id(x)] else 0.0)
                                                    for lb in labels})
        # static values: the survivor's member (the default outfit where the survivor is the default)
        for (eid, prop), per in varying.items():
            u.els[eid].attrs[prop] = per[labels[0]]
            m.keyed[(u.els[eid].ref(), prop)] = per

        # the switch keys: retarget to the survivor; add every varying value to the member's key clips
        for clip in clips:
            for obj in [c for c in clip.children if c.tag == "KeyedObject" and c.attrs["objectId"] == m.solo.ref()]:
                for prop in obj.children:
                    for kf in prop.children:
                        if prop.attrs.get("property") == "activeComponentId" and kf.attrs["value"] in member_ids:
                            kf.attrs["value"] = survivor.ref()
        for label in labels:
            for clip in m.key_clips.get(label, []):
                per_el: dict[int, dict[str, object]] = {}
                for (eid, prop), per in varying.items():
                    per_el.setdefault(eid, {})[prop] = per[label]
                taken = {c.attrs["objectId"] for c in clip.children if c.tag == "KeyedObject"}
                for eid, props in per_el.items():
                    assert u.els[eid].ref() not in taken, (clip.attrs["name"], u.els[eid].attrs.get("name"))
                    clip.add(_key_obj(doc, u.els[eid], props))
        missing = [lb for lb in labels if not m.key_clips.get(lb)] if varying else []
        assert not missing, f"{m.name}: no key clip for {missing}"

        # drop the other members
        for label in labels[1:]:
            g = m.members[label]
            m.dropped |= {e.ref() for e in walk(g)}
            m.solo.children.remove(g)
        if m.solo.attrs.get("activeComponentId") in member_ids:
            m.solo.attrs["activeComponentId"] = survivor.ref()
        m.moved = [x.ref() for x in u.moved]
        survivor.attrs["name"] = m.name

        # keyed objects elsewhere that target a dropped element: duplicates of the survivor's keys only
        for clip in clips:
            objs = {c.attrs["objectId"]: c for c in clip.children if c.tag == "KeyedObject"}
            for obj in [c for c in clip.children if c.tag == "KeyedObject" and c.attrs["objectId"] in m.dropped]:
                twin = objs.get(u.corr[obj.attrs["objectId"]].ref())
                if twin is None or _canon(twin, u.corr) != _canon(obj, u.corr):
                    raise ValueError(f"{clip.attrs['name']} keys the dropped {obj.attrs['objectId']} differently")
                clip.children.remove(obj)

    dropped = set().union(*(m.dropped for m in merges))
    for e in walk(root):
        for k, v in e.attrs.items():
            if isinstance(v, str) and v in dropped:
                raise ValueError(f"{e.tag} {e.attrs.get('name')!r}.{k} still references dropped {v}")
