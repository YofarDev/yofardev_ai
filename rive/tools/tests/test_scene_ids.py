"""Every committed scene's RML mints each id once (M12 review: the M12 module ids come from several
`Doc(start=880000)` minters, `scene_npc.own_m12`, `scene_library.own_m12` and mountainHut's own; a scene
that drew from two of them would reuse ids silently)."""

from __future__ import annotations

from collections import Counter
from pathlib import Path
import xml.etree.ElementTree as ET

import pytest

SCENES = Path(__file__).resolve().parents[2] / "scenes"


@pytest.mark.parametrize("rml", sorted(SCENES.glob("*/*.rml")), ids=lambda p: p.parent.name)
def test_committed_scene_ids_are_unique(rml: Path) -> None:
    ids = Counter(e.get("id") for e in ET.parse(rml).iter() if e.get("id"))
    assert [i for i, n in ids.items() if n > 1] == []
