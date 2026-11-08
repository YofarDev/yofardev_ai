"""The tablet is between the sleeves and its two compact, costume-coloured grips."""

from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[3]


def test_tablet_has_two_compact_grips_and_the_sleeves_cannot_cover_the_slab() -> None:
    root = ET.parse(ROOT / "rive/avatar/avatar.rml").getroot()
    parents = {c: p for p in root.iter() for c in p}
    tablet = next(e for e in root.iter() if e.get("name") == "Tablet")
    shoulder = parents[tablet]
    assert list(shoulder).index(tablet) < next(i for i, e in enumerate(shoulder) if e.get("name") == "SwingL")
    front = next(e for e in tablet.iter("Shape") if e.get("name") == "emitScreenGlare")
    grips = [e for e in root.iter() if e.get("name") == "Hand_tabletGrip"]
    assert len(grips) == 2
    for grip in grips:
        assert float(grip.get("scaleY")) == 0.6
        rule = grip.find("DrawRules")
        target = rule.find("DrawTarget")
        assert rule.get("drawTargetId") == target.get("id")
        assert target.get("drawableId") == front.get("id")
        assert target.get("placementValue") == "before"
        solo = parents[grip]
        rest = next(e for e in solo if e.get("name") == "Hand_rest")
        for animation in root.iter("LinearAnimation"):
            keys = [key for obj in animation if obj.get("objectId") == solo.get("id")
                    for key in obj.iter("KeyFrameId")]
            if any(k.get("value") == grip.get("id") for k in keys):
                assert animation.get("name").startswith("prop_tablet_")
            if animation.get("name") == "prop_tablet_away":
                assert keys[-1].get("value") == rest.get("id")


def test_every_costume_colours_the_new_grips_and_resets_to_bare_skin() -> None:
    root = ET.parse(ROOT / "rive/avatar/avatar.rml").getroot()
    for solo in root.iter("Solo"):
        grip = next((e for e in solo if e.get("name") == "Hand_tabletGrip"), None)
        if grip is None:
            continue
        edge = next(e for e in solo if e.get("name") == "Hand_edge")
        # The compact drawing preserves the original geometry and palette; only its group
        # transform changes. Wardrobe keys must cover it in every costume, including none.
        ids = {a.get("id"): b.get("id") for a, b in zip(edge.iter(), grip.iter())}
        for animation in root.iter("LinearAnimation"):
            if not animation.get("name", "").startswith("costume_"):
                continue
            objects = {o.get("objectId"): o for o in animation if o.tag == "KeyedObject"}
            checked = 0
            for original, duplicate in ids.items():
                if original not in objects:
                    continue
                assert duplicate in objects, (animation.get("name"), original)
                def values(obj: ET.Element) -> list:
                    return [(p.get("property"), [(k.tag, k.get("frame"), k.get("value")) for k in p]) for p in obj]
                assert values(objects[original]) == values(objects[duplicate])
                checked += 1
            assert checked > 0


def test_newspaper_is_in_front_of_the_sleeves_with_grips_over_the_page() -> None:
    root = ET.parse(ROOT / "rive/avatar/avatar.rml").getroot()
    parents = {c: p for p in root.iter() for c in p}
    paper = next(e for e in root.iter() if e.get("name") == "Newspaper")
    shoulder = parents[paper]
    assert list(shoulder).index(paper) < next(i for i, e in enumerate(shoulder) if e.get("name") == "SwingL")
    front = next(e for e in paper.iter("Shape") if e.get("name") == "NewsFold")
    grips = [e for e in root.iter() if e.get("name") == "Hand_newspaperGrip"]
    assert len(grips) == 2
    for grip in grips:
        target = grip.find("DrawRules").find("DrawTarget")
        assert target.get("drawableId") == front.get("id")
        solo = parents[grip]
        used = {a.get("name") for a in root.iter("LinearAnimation") for obj in a
                if obj.get("objectId") == solo.get("id")
                for k in obj.iter("KeyFrameId") if k.get("value") == grip.get("id")}
        assert used and all(n.startswith("prop_newspaper_") for n in used)
