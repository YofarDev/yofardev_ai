"""Compact tablet-only grip drawings and their occlusion, installed after wardrobe dedupe.

The sleeve stays behind the slab; the curled hand silhouette stays in front. Cloning the
existing edge artwork and its wardrobe paint keys preserves every costume's hand colour,
without changing the edge pose used by clapping, the newspaper and costume gestures.
"""

from __future__ import annotations

from copy import deepcopy

from avatar_tablet import GRIP_ID_START, walk
from rml import Doc, El


def _clone(source: El, doc: Doc, references: dict[str, str] | None = None) -> tuple[El, dict[str, str]]:
    result = deepcopy(source)
    mapping = {old.ref(): doc(old.tag).ref() for old in walk(source)}
    refs = {**(references or {}), **mapping}
    for old, new in zip(walk(source), walk(result)):
        new.id = mapping[old.ref()]
        new.attrs = {k: refs.get(v, v) if isinstance(v, str) else v for k, v in new.attrs.items()}
    return result, mapping


def install(artboard: El, prop: El, *, kind: str = "tablet", anchor: str = "emitScreenGlare",
            start: int = GRIP_ID_START, scale_y: float | None = 0.60) -> None:
    """Put `prop` above the sleeves and draw copies of the `edge` hand above it.

    kind: animation prefix (`prop_<kind>_*`) whose edge-hand keys switch to the copies.
    anchor: the prop's front-most drawable; the copies' draw target sits before it.
    """
    doc = Doc(start=start)
    parents = {id(child): parent for parent in walk(artboard) for child in parent.children}
    # Reorder only: keep the breath/lean transforms shared with the carrying arm.
    shoulder = parents[id(prop)]
    shoulder.children.remove(prop)
    shoulder.children.insert(0, prop)
    front = next(e for e in walk(prop) if e.attrs.get("name") == anchor)
    animations = [e for e in artboard.children if e.tag == "LinearAnimation"]
    edges = [e for e in walk(artboard) if e.attrs.get("name") == "Hand_edge"]
    assert len(edges) == 2, "Install prop grips after the shared hand skins have been deduped"
    for edge in edges:
        grip, mapping = _clone(edge, doc)
        grip.attrs.update(name=f"Hand_{kind}Grip")
        if scale_y is not None:
            grip.attrs.update(scaleY=scale_y)
        target = doc("DrawTarget", drawableId=front.ref(), placementValue="before", name=f"Over{kind.title()}")
        grip.add(doc("DrawRules", target, drawTargetId=target.ref(), name=f"{kind.title()}GripDepth"))
        parents[id(edge)].add(grip)
        for animation in animations:
            # The new drawing follows the same costume paints as the original hand, including
            # costume_none's reset. Original tracks and ids remain untouched.
            for obj in list(animation.children):
                if obj.attrs.get("objectId") in mapping:
                    duplicate, _ = _clone(obj, doc, mapping)
                    animation.add(duplicate)
            if str(animation.attrs.get("name", "")).startswith(f"prop_{kind}_"):
                for key in walk(animation):
                    if key.tag == "KeyFrameId" and key.attrs.get("value") == edge.ref():
                        key.attrs["value"] = grip.ref()
