"""Art direction for the four environments, using inexpensive vector layers.

The scene generators own the interaction rigs. This pass adds materials,
lighting and secondary ambience without changing the public Rive contract.
All coordinates are artboard-space; gradient coordinates are shape-local.
"""

from __future__ import annotations

from collections.abc import Iterator
import math
import random
from typing import TYPE_CHECKING

from rml import El, ellipse, lin, smooth_path

if TYPE_CHECKING:
    from gen_scenes import Scene

O = (0.0, 0.0)


def walk(elements: list[El]) -> Iterator[El]:
    for element in elements:
        yield element
        yield from walk(element.children)


def named(elements: list[El], name: str) -> El:
    return next(e for e in walk(elements) if e.attrs.get("name") == name)


def before(content: list[El], name: str, *elements: El) -> None:
    index = next(i for i, e in enumerate(content) if e.attrs.get("name") == name)
    content[index:index] = elements


def after(content: list[El], name: str, *elements: El) -> None:
    index = next(i for i, e in enumerate(content) if e.attrs.get("name") == name)
    content[index + 1:index + 1] = elements


def recolor(elements: list[El], palette: dict[str, str]) -> None:
    for e in walk(elements):
        for attr in ("colorValue", "value"):
            value = e.attrs.get(attr)
            if value in palette:
                e.attrs[attr] = palette[value]


def paint(shape: El, fill: El) -> None:
    shape.children = [c for c in shape.children if c.tag != "Fill"] + [fill]


def rectangle(sc: Scene, name: str, x: float, y: float, w: float, h: float, fill: El,
              radius: float = 0, *extra: El) -> El:
    d = sc.d
    path = d("Rectangle", width=w, height=h, cornerRadiusTL=radius, cornerRadiusTR=radius,
             cornerRadiusBL=radius, cornerRadiusBR=radius, name="Path")
    return d("Shape", path, fill, *extra, x=x, y=y, name=name)


def glow(sc: Scene, name: str, x: float, y: float, r: float, color: str, sy: float = 1.0) -> El:
    return sc.E(O, name, x, y, r * 2, r * 2,
                sc.rgrad(r, [(color, 0.0), ("00" + color[2:], 1.0)]), scaleY=sy)


# Phones crop the scene sides (cover) to roughly x 100..980 and the avatar covers the centre
# below y ~760, so props are re-placed as whole groups: outer node = target + scale, inner node
# = -pivot (children keep their absolute coordinates, so their own animations stay valid).
PLACES = {
    "livingRoom": [("TvCorner", "Cat", "Cabinet", (865.0, 1230.0), (865.0, 1230.0), 0.72)],
    "campfire": [("TentPlace", "Tent", "Tent", (840.0, 1100.0), (866.0, 1104.0), 0.62)],
    "beach": [("GullPlace", "Gull", "Post", (980.0, 1170.0), (905.0, 1170.0), 1.0)],
    "deepSpace": [("PlanetPlace", "PlanetHalo", "PlanetGroup", (230.0, 820.0), (300.0, 590.0), 1.0),
                  ("DuckPlace", "DuckLift", "DuckLift", (760.0, 1260.0), (850.0, 1250.0), 1.0)],
}


def place_point(scene_id: str, name: str, x: float, y: float) -> tuple[float, float]:
    for n, _, _, pivot, target, scale in PLACES[scene_id]:
        if n == name:
            return target[0] + scale * (x - pivot[0]), target[1] + scale * (y - pivot[1])
    raise KeyError(name)


def place_groups(sc: Scene, content: list[El]) -> None:
    for name, first, last, pivot, target, scale in PLACES[sc.id]:
        a = next(i for i, e in enumerate(content) if e.attrs.get("name") == first)
        b = next(i for i, e in enumerate(content) if e.attrs.get("name") == last)
        inner = sc.d("Node", *content[a:b + 1], x=-pivot[0], y=-pivot[1], name=name + "Pivot")
        outer = sc.d("Node", inner, x=target[0], y=target[1], scaleX=scale, scaleY=scale, name=name)
        content[a:b + 1] = [outer]


def living_room(sc: Scene, content: list[El]) -> None:
    S, E, F, L, d = sc.S, sc.E, sc.F, sc.L, sc.d
    recolor(content, {
        "FF4E4460": "FF243E43", "FF7A6680": "FF52706B",
        "FF5A4A62": "FF29484B", "FF483A50": "FF1C3338", "FF8A7896": "FF779086",
        "FFA83A4A": "FFB78D5B", "FF6E1E2E": "FF5C4036",
        "FF9A6844": "FF9B7652", "FF5E3A24": "FF45372F",
        "FFB8484A": "FF45645E", "FF8A2E36": "FF294942", "FF5A1E28": "FF193632",
        "FFE8C890": "FFCBAC79", "CCE8C890": "70CBAC79",
        "FF5AA86A": "FF7CA280", "FF2E6A3E": "FF315D53", "FF1A3A22": "FF21483E",
        "FFD88A5A": "FFC39276", "FF9A5232": "FF775446",
        "FF8A5A3A": "FF795B49", "FF5A3622": "FF3D302B",
        "FFE8DCCC": "FFC7BCA3", "FFF2E8DA": "FFE2D6BB",
    })
    content[:] = [e for e in content if not str(e.attrs.get("name", "")).startswith("Stripe")]

    # Restrained architectural mouldings; a very different material from the
    # broad wallpaper stripes, with bright upper edges and recessed shadows.
    panels = []
    for i, x in enumerate((115, 540, 965)):
        panels += [rectangle(sc, f"WallPanel{i}", x, 630, 260, 650, F("00000000"), 2,
                              L("327E9E8E", 2)),
                   rectangle(sc, f"LowerPanel{i}", x, 1090, 260, 130, F("00000000"), 2,
                              L("386A8A7C", 2))]
    panels += [rectangle(sc, "CorniceShadow", 540, 265, 1120, 9, F("28203536")),
               rectangle(sc, "CorniceInlay", 540, 258, 1120, 2, F("60D5B580"))]
    before(content, "Wall", *panels,
           glow(sc, "WallWarmth", 280, 650, 620, "22FAD8A0"),
           glow(sc, "WindowCool", 570, 420, 450, "1832A9BD"))

    # A framed abstract landscape and small shelves give the room a lived-in,
    # designed character while the centre remains clear for the avatar.
    art = [rectangle(sc, "ArtShadow", 909, 534, 170, 224, F("35101E20"), 3),
           rectangle(sc, "ArtFrame", 900, 522, 170, 224, F("FFBBA171"), 3),
           rectangle(sc, "ArtMat", 900, 522, 158, 212, F("FFE1D7BB")),
           rectangle(sc, "ArtCanvas", 900, 522, 130, 180, F("FF9CB7A5"))]
    # Front-first inside the picture frame.
    art = [S(O, "ArtMountain", [(835, 612, "c"), (835, 545), (880, 512), (925, 564), (965, 536), (965, 612, "c")], F("FF416D66")),
           S(O, "ArtHill", [(835, 612, "c"), (835, 584), (880, 565), (932, 574), (965, 564), (965, 612, "c")], F("FF284D4C")),
           E(O, "ArtSun", 923, 474, 36, 36, F("FFE5C796")), *reversed(art)]
    books = [rectangle(sc, f"ShelfBook{i}", 96 + i * 17, 457 - (i % 3) * 5, 13, 60 + (i % 3) * 10,
                       F(c), 1) for i, c in enumerate(("FFB79A72", "FF456862", "FFBD927D", "FFD8C9A8"))]
    shelves = [*books, E(O, "VaseRim", 235, 421, 28, 8, F("FF334E49")),
               S(O, "CeramicVase", [(224, 422), (246, 422), (244, 445), (259, 468), (252, 487),
                                     (215, 487), (210, 468), (226, 445)],
                 sc.vgrad(-36, 36, [("FFD8CDB1", 0), ("FF998C74", 1)])),
               S(O, "VaseSprig", [(234, 423), (232, 390), (247, 364)], L("FF9AAB7A", 2), closed=False),
               E(O, "VaseLeaf", 240, 389, 27, 10, F("FF9AAB7A"), rotation=-0.7),
               rectangle(sc, "FloatingShelf", 176, 496, 226, 12, F("FFA38662"), 2),
               rectangle(sc, "ShelfShadow", 176, 509, 220, 12, F("25203030"), 2)]
    before(content, "Wall", *art, *shelves)

    shadows = [glow(sc, "PlantContact", 145, 1334, 180, "700E2020", 0.14),
               glow(sc, "CabinetContact", 866, 1240, 190, "900D1F20", 0.14),
               glow(sc, "LampContact", 287, 1245, 125, "600D1F20", 0.14),
               S(O, "WindowFloorLight", [(380, 1180), (700, 1180), (1000, 1850), (240, 1850)],
                 sc.vgrad(-340, 340, [("1895C7C4", 0), ("0095C7C4", 1)]))]
    grain = [S(O, f"FloorJoint{i}", [(-60, y), (1140, y)], L("15E0C7A0", 1.2), closed=False)
             for i, y in enumerate((1290, 1460, 1700))]
    before(content, "Floor", *shadows, *grain)
    # Brushed brass inlay, recessed cabinet join, and ceramic pot lip.
    before(content, "Cabinet", rectangle(sc, "CabinetJoin", 867, 1155, 2, 122, F("50251F1A")),
           rectangle(sc, "CabinetLip", 865, 1084, 320, 3, F("50E8C69B")))
    plant = named(content, "Plant")
    plant.children.insert(0, E(O, "PotLip", 140, 1222, 118, 8, F("FFDBB29A")))
    # Cotton hangs in broad folds: side-to-side value changes and fine woven
    # threads keep the cloth distinct from the brass, glass and plaster.
    curtain_tracks = []
    for side in ("L", "R"):
        cloth = named(content, "Curtain" + side)
        paint(cloth, d("Fill", lin(d, -58, 0, 58, 0,
              [("FF85633F", 0), ("FFBE9863", 0.23), ("FFA77E4F", 0.42),
               ("FFC5A16B", 0.66), ("FF87623F", 1)]), name="Fill"))
        path = next(c for c in cloth.children if c.tag == "PointsPath")
        for i, vertex in enumerate(path.children):
            yy = float(vertex.attrs["y"])
            strength = max(0.0, (yy + 305) / 610) ** 2
            xx = float(vertex.attrs["x"])
            curtain_tracks.append(sc.T(vertex, x=[(0, xx), (170, xx + 5 * strength),
                                                  (385, xx - 4 * strength), (600, xx)]))
    sc.ambient("CurtainHems", sc.A("amb_curtain_hems", 600, curtain_tracks, loop=True, seam_hold=True))
    # A sparse grain follows the perspective of individual floor boards.
    # The rug and furniture occlude it naturally through scene draw order.
    wood = []
    rng_wood = random.Random(981)
    for i in range(68):
        yy = rng_wood.uniform(1210, 1910)
        xx = rng_wood.uniform(-40, 1120)
        length = rng_wood.uniform(24, 105)
        skew = (xx - 540) * length / 850
        wood.append(S(O, f"OakGrain{i}", [(xx, yy), (xx + skew * 0.4 - 2, yy + length * 0.45),
                                           (xx + skew, yy + length)],
                      L("0D291D15" if i % 3 else "12EED6AE", 0.8 + (i % 3) * 0.3), closed=False))
    before(content, "Floor", *wood)
    # Animate a zero-offset wrapper at the root of the leaves, not the pot.
    leaves = [e for e in plant.children if str(e.attrs.get("name", "")).startswith(("Leaf", "Vein"))]
    for leaf in leaves:
        leaf.attrs["x"] = float(leaf.attrs["x"]) - 140
        leaf.attrs["y"] = float(leaf.attrs["y"]) - 1230
        plant.children.remove(leaf)
    foliage = sc.node("Foliage", 140, 1230, *leaves)
    plant.children.append(foliage)
    sc.ambient("Foliage", sc.A("amb_foliage", 720, [sc.T(foliage, rotation=[(0, 0.0), (230, 0.045),
                                                                                       (490, -0.035), (720, 0.0)])], loop=True))

    dust, tracks = [], []
    rng = random.Random(89)
    for i in range(9):
        x, y = rng.uniform(190, 400), rng.uniform(650, 1150)
        mote = E(O, f"LamplitDust{i}", x, y, 2.5, 2.5, F("FFE9D7AE"), opacity=0.0)
        dust.append(mote)
        phase = 70 + i * 29
        tracks.append(sc.T(mote, x=[(0, x), (300, x + 15), (600, x)],
                           y=[(0, y), (300, y - 24), (600, y)],
                           opacity=[(0, 0.0), (phase, 0.45), (phase + 100, 0.0), (600, 0.0)]))
    before(content, "LampCone", *dust)
    cone = named(content, "LampCone")
    cone.children = [c for c in cone.children if c.tag not in ("Fill", "Stroke")]
    for i in range(14):
        width = 1.12 - i * 0.045
        cone.children.insert(0, S(O, f"LamplightFalloff{i}",
                                  [(-60 * width, -250), (60 * width, -250),
                                   (170 * width, 250), (-170 * width, 250)],
                                  sc.vgrad(-250, 250, [("06FFE4B3", 0), ("04FFE1A9", 0.45), ("00FFE1A9", 1)])))
    for name, top_width, bottom_width, half_height, tint in (
        ("MoonBeam", 180, 390, 845, "B9D6F2"),
        ("MoonPool", 170, 330, 160, "A9C5F2"),
    ):
        beam = named(content, name)
        beam.children = [c for c in beam.children if c.tag not in ("Fill", "Stroke")]
        for i in range(14):
            width = 1.10 - i * 0.025
            height = half_height * (1.06 - i * 0.012)
            beam.children.insert(0, S(O, name + f"Falloff{i}",
                [(-top_width * width, -height, "c"), (top_width * width, -height, "c"),
                 (bottom_width * width, height, "c"), (-bottom_width * width, height, "c")],
                sc.vgrad(-height, height, [("03" + tint, 0), ("04" + tint, 0.3), ("02" + tint, 0.75), ("00" + tint, 1)])))
    sc.ambient("Dust", sc.A("amb_dust", 600, tracks, loop=True))


def campfire(sc: Scene, content: list[El]) -> None:
    S, E, F, L, d = sc.S, sc.E, sc.F, sc.L, sc.d
    recolor(content, {"FF0B1026": "FF161E30", "FF1A1B45": "FF202F40", "FF3D2A5C": "FF3E4459",
                      "FF6B3A5A": "FF80606A", "FF2A2550": "FF284552", "FF1E1A3C": "FF193943",
                      "FF1A1630": "FF183139", "FF120F22": "FF0A2229", "FF2A2338": "FF253A3A",
                      "FF1C1726": "FF101E25", "FF0E0B16": "FF07171D", "FF2E2638": "FF314042",
                      "FF241E2E": "FF1B2B31", "FF241C30": "FF152D32", "FF1F1D48": "FF17313F"})
    # Alpine depth: hard mountain facets behind organic conifer silhouettes.
    mountains = [S(O, "AlpineRidge", [(-70, 1100, "c"), (-70, 838, "c"), (100, 736, "c"), (220, 796, "c"),
                                      (390, 610, "c"), (590, 814, "c"), (728, 708, "c"), (900, 850, "c"),
                                      (1130, 720, "c"), (1130, 1100, "c")],
                   sc.vgrad(-240, 240, [("FF35515D", 0), ("FF203C49", 1)])),
                 S(O, "PeakSnow", [(310, 698, "c"), (390, 610, "c"), (484, 706, "c"), (417, 685, "c"),
                                    (390, 663, "c"), (367, 689, "c")], F("FF6F8185")),
                 S(O, "MountainShadow", [(390, 610, "c"), (590, 814, "c"), (520, 874, "c"), (420, 764, "c")],
                   F("FF233D49"))]
    before(content, "FarHills", *reversed(mountains))
    before(content, "MidHills", glow(sc, "ValleyMist", 560, 946, 740, "284B8D95", 0.10))
    # Replace the evenly stacked zigzags with tapered, irregular branches.
    rng = random.Random(82)
    for tree in [e for e in content if str(e.attrs.get("name", "")).startswith(("Pine", "FarPine"))]:
        path = next(c for c in tree.children if c.tag == "PointsPath")
        xs = [float(v.attrs["x"]) for v in path.children]
        ys = [float(v.attrs["y"]) for v in path.children]
        x = float(tree.attrs["x"])
        base = float(tree.attrs["y"]) + max(ys)
        height = max(ys) - min(ys)
        color = "FF0A2229" if str(tree.attrs["name"]).startswith("Pine") else "FF193943"
        pts = [(x, base - height, "c")]
        for side in (1, -1):
            tiers = range(1, 9) if side == 1 else range(8, 0, -1)
            for k in tiers:
                t = k / 9
                yy = base - height + height * t
                width = height * 0.27 * t * rng.uniform(0.85, 1.12)
                branch = [(x + side * width * 0.46, yy - height * 0.055, "c"),
                          (x + side * width, yy + height * 0.018, "c"),
                          (x + side * width * 0.4, yy + height * 0.008, "c")]
                pts.extend(branch if side == 1 else reversed(branch))
            if side == 1:
                pts += [(x + height * 0.035, base, "c"), (x - height * 0.035, base, "c")]
        replacement = S(O, "PineArt", pts, F(color), tension=0.45)
        tree.children = replacement.children
        tree.attrs.update(x=replacement.attrs["x"], y=replacement.attrs["y"])

    ribbons = []
    for i in range(3):
        yy = 290 + i * 52
        ribbon = S(O, f"Aurora{i}", [(-80, yy), (180, yy + 115), (410, yy + 48), (670, yy + 155), (1150, yy + 80),
                                     (1150, yy + 200), (670, yy + 225), (410, yy + 108), (180, yy + 155), (-80, yy + 60)],
                   sc.vgrad(-130, 130, [("003E9C98", 0), ("183E9C98", 0.55), ("003E9C98", 1)]))
        ribbons.append(ribbon)
    before(content, "Sky", *ribbons)
    sc.ambient("Aurora", sc.A("amb_aurora", 960,
               [sc.T(r, x=[(0, float(r.attrs["x"])), (480, float(r.attrs["x"]) + (20 if i % 2 else -20)),
                            (960, float(r.attrs["x"]))], opacity=[(0, 0.65), (480, 1.0), (960, 0.65)])
                for i, r in enumerate(ribbons)], loop=True))
    # Stitched canvas and a warm tent entrance; details remain attached to the
    # original prop and do not compete with the avatar silhouette.
    tent = named(content, "Tent")
    tent.children[0:0] = [S(O, "TentSeam", [(840, 854), (670, 1094)], L("60D7C9A1", 1.5), closed=False),
                          S(O, "TentHem", [(665, 1098), (850, 1107), (1031, 1097)], L("50C9B996", 2), closed=False),
                          S(O, "TentGuy", [(974, 1026), (1070, 1123)], L("809D9A7E", 1.6), closed=False),
                          glow(sc, "TentLantern", 810, 1080, 45, "50EDB868", 0.45)]
    # A few taut folds terminate at the pegs; restrained fabric detail does
    # not compete with the fire's moving edge.
    tent.children[0:0] = [S(O, f"CanvasFold{i}", pts, L(col, width), closed=False)
                          for i, (pts, col, width) in enumerate((
                              ([(838, 880), (821, 997), (833, 1088)], "30515B4C", 2),
                              ([(678, 1093), (744, 1048), (792, 976)], "40CAB58A", 1.5),
                              ([(1024, 1094), (945, 1040), (873, 940)], "203B4D56", 2),
                          ))]
    # Wing coverts and facial discs give the owl a soft, feathered structure.
    owl = named(content, "Owl")
    owl_details = []
    for side in (-1, 1):
        owl_details += [S((884, 704), f"OwlWing{side}",
                          [(884 + side * 29, 696), (884 + side * 37, 713),
                           (884 + side * 27, 746), (884 + side * 19, 737),
                           (884 + side * 23, 710)],
                          sc.vgrad(-25, 25, [("FF806345", 0), ("FF453B2C", 1)])),
                        S((884, 704), f"OwlFaceRim{side}",
                          [(884 + side * 4, 674), (884 + side * 22, 675),
                           (884 + side * 29, 688), (884 + side * 17, 701)],
                          L("50E5C591", 1.2), closed=False)]
        for i in range(3):
            xx, yy = side * (25 + i), 12 + i * 7
            owl_details.append(S(O, f"WingCovert{side}_{i}", [(xx - 2, yy - 4), (xx, yy), (xx + 3, yy - 3)],
                                 L("508E7856", 1.2), closed=False))
    for i, (xx, yy) in enumerate(((-8, 12), (7, 14), (-6, 23), (5, 25), (0, 33))):
        owl_details.append(S(O, f"ChestFeather{i}", [(xx - 2, yy), (xx, yy + 3), (xx + 2, yy)],
                             L("605F4730", 1.1), closed=False))
    owl.children[0:0] = owl_details
    hoot = next(a for a in sc.anims if a.attrs["name"] == "ev_owlHoot")
    beak = named(owl.children, "Beak")
    for obj in hoot.children:
        if obj.attrs.get("objectId") == beak.ref():
            for prop in obj.children:
                if prop.attrs.get("property") == "scaleY":
                    for key in prop.children:
                        key.attrs["value"] = 1.0
    opening = E(O, "HootMouth", 0, 3, 9, 12, F("FF302218"), opacity=0.0, scaleY=0.05)
    jaw = S(O, "HootLowerBeak", [(-4, 0), (4, 0), (0, 5)], F("FFD8A040"), origin=O)
    jaw.attrs["y"] = 5.0
    owl.children[0:0] = [jaw, opening]
    hoot.add(sc.T(opening, opacity=[(0, 0.0), (10, 0.0), (14, 1.0), (25, 1.0), (31, 0.0),
                                    (55, 0.0), (59, 1.0), (70, 1.0), (79, 0.0), (150, 0.0)],
                  scaleY=[(0, 0.05), (10, 0.05), (16, 1.0), (23, 0.9), (31, 0.05),
                          (55, 0.05), (62, 0.9), (70, 0.8), (79, 0.05), (150, 0.05)]),
             sc.T(jaw, y=[(0, 5.0), (10, 5.0), (16, 11.0), (31, 5.0),
                          (55, 5.0), (62, 10.0), (79, 5.0), (150, 5.0)]))
    for i, xx in enumerate((-15, 15)):
        lid = S(O, f"HootLid{i}", [(xx - 13, -26), (xx, -29), (xx + 13, -26),
                                   (xx + 12, -16), (xx, -13), (xx - 12, -16)],
                F("FF8C6C47"), origin=(xx, -29), scaleY=0.0)
        owl.children.insert(0, lid)
        hoot.add(sc.T(lid, scaleY=[(0, 0.0), (8, 0.0), (15, 0.9), (24, 0.7), (33, 0.0),
                                   (53, 0.0), (61, 0.8), (73, 0.6), (83, 0.0), (150, 0.0)]))
    for side in (-1, 1):
        wing = named(owl.children, f"OwlWing{side}")
        hoot.add(sc.T(wing, rotation=[(0, 0.0), (8, side * 0.07), (19, -side * 0.10),
                                      (36, 0.0), (53, side * 0.06), (64, -side * 0.08), (84, 0.0), (150, 0.0)]))
        tuft = S(O, f"OwlTuft{side}", [(side * 24, -29), (side * 35, -42, "c"),
                                       (side * 31, -24)], F("FF806345"), origin=(side * 24, -29))
        owl.children.insert(0, tuft)
        hoot.add(sc.T(tuft, rotation=[(0, 0.0), (16, -side * 0.16), (24, side * 0.12),
                                      (37, -side * 0.04), (45, 0.0), (65, -side * 0.12),
                                      (75, side * 0.08), (90, 0.0), (150, 0.0)]))
    before(content, "Branch", *[S(O, f"OwlGrip{i}", [(875 + i * 9, 750), (872 + i * 9, 756), (876 + i * 9, 758)],
                                  L("FFB89B6B", 2), closed=False) for i in range(3)])
    # The rain has a local consequence at the coals as well as its screen
    # layers: staggered steam rises, expands and disappears over the fire bed.
    rain = next(a for a in sc.anims if a.attrs["name"] == "ev_Rain")
    steam = []
    for i in range(4):
        x, y = 135 + i * 39, 1122 - i % 2 * 7
        puff = glow(sc, f"WetCoalSteam{i}", x, y, 27, "60C5CDC3", 0.5)
        puff.attrs["opacity"] = 0.0
        steam.append(puff)
        keys_x, keys_y, keys_op, keys_scale = [(0, x)], [(0, y)], [(0, 0.0)], [(0, 0.5)]
        for start in (70 + i * 19, 230 + i * 23):
            keys_x += [(start, x), (start + 85, x + 17 - i * 3)]
            keys_y += [(start, y), (start + 85, y - 83 - i * 8)]
            keys_op += [(start, 0.0), (start + 18, 0.42), (start + 85, 0.0)]
            keys_scale += [(start, 0.5), (start + 85, 1.7)]
        rain.add(sc.T(puff, x=keys_x + [(480, x)], y=keys_y + [(480, y)],
                      opacity=keys_op + [(480, 0.0)], scaleX=keys_scale + [(480, 0.5)],
                      scaleY=[(f, v * 0.7) for f, v in keys_scale] + [(480, 0.35)]))
    before(content, "FireFlare", *steam)
    for e in walk(content):
        if str(e.attrs.get("name", "")).startswith("Grass"):
            e.attrs["opacity"] = 0.55
    # Fireflies take curved paths and fade at rest rather than flashing in sync.
    flies, tracks = [], []
    for i, (x, y) in enumerate(((640, 1050), (740, 1170), (150, 990), (930, 1190), (490, 1260))):
        fly = sc.node(f"Firefly{i}", x, y, E(O, "FireflyCore", 0, 0, 3, 3, F("FFFFE4A1")),
                      glow(sc, "FireflyGlow", 0, 0, 13, "55FAD88D"), opacity=0.0)
        flies.append(fly)
        t = 90 + i * 55
        tracks.append(sc.T(fly, x=[(0, x), (t, x + 25), (t + 140, x - 12), (720, x)],
                           y=[(0, y), (t, y - 32), (t + 140, y - 15), (720, y)],
                           opacity=[(0, 0.0), (t, 0.9), (t + 100, 0.2), (t + 220, 0.0), (720, 0.0)]))
    before(content, "Tent", *flies)
    sc.ambient("Fireflies", sc.A("amb_fireflies", 720, tracks, loop=True))
    # Amber rims, a charcoal bed and reflected heat tie the campfire to the
    # ground. The flame has soft asymmetric tips, rather than rigid triangles.
    before(content, "FireFlare", glow(sc, "CoalBed", 196, 1148, 125, "A0F09535", 0.20))
    # A worn trail follows the terrain. Rounded shoulders, broken edges and
    # low value contrast keep it from reading as a projected spotlight.
    # Many nested geometry components are also named Path; this is the
    # top-level ground silhouette, not the first nested path in the document.
    trail = next(e for e in content if e.attrs.get("name") == "Path")
    replacement = S(O, "Trail", [(325, 1940, "c"), (390, 1740), (462, 1535), (474, 1420),
                                (492, 1310), (518, 1240), (545, 1194), (558, 1190),
                                (568, 1244), (550, 1370), (554, 1480), (628, 1710),
                                (744, 1940, "c")],
                    sc.vgrad(-380, 380, [("FF263B39", 0), ("FF243736", 0.45), ("FF1C3030", 1)]))
    trail.children = replacement.children
    trail.attrs.update(x=replacement.attrs["x"], y=replacement.attrs["y"])
    pebbles = []
    for i, (x, y, size) in enumerate(((490, 1320, 7), (570, 1500, 11), (403, 1685, 14),
                                      (648, 1800, 17), (426, 1720, 7), (543, 1264, 4))):
        pebbles.append(E(O, f"TrailStone{i}", x, y, size * 1.8, size * 0.65,
                         sc.vgrad(-size, size, [("FF42504A", 0), ("FF1B3030", 1)])))
    before(content, "Path", *pebbles)
    for e in walk(content):
        if str(e.attrs.get("name", "")).startswith("Stone") and e.tag == "Shape":
            paint(e, sc.rgrad(36, [("FFAA9887", 0), ("FF62636B", 0.5), ("FF343E48", 1)], cx=-8, cy=-14))
    for i, name in enumerate(("LogA", "LogB", "LogC")):
        log = named(content, name)
        log.children[0:0] = [S(O, "BarkRidge", [(-60, -9), (-18, -12), (48, -9)], L("60895238", 1.3), closed=False),
                            S(O, "LogHeat", [(-45, -17), (20, -18), (65, -14)], L("70E8AA5B", 2), closed=False)]


def beach(sc: Scene, content: list[El]) -> None:
    S, E, F, L, d = sc.S, sc.E, sc.F, sc.L, sc.d
    recolor(content, {"FF4AA0E0": "FF438EAB", "FF9AD0F0": "FFADD3CF", "FFFFE4C8": "FFF4DEC0",
                      "FF2A7AB8": "FF297D8D", "FF3AA8C8": "FF5BB9B1", "FFE04848": "FFC86C53",
                      "FFF6DCA8": "FFF0D9AC", "FFE0B87A": "FFC9AA7D", "FFD6B07A": "FFBFA67E",
                      "FF3AB0C8": "FF6C9E98", "FF2A8AA8": "FF416D6A", "FFF4F0E8": "FFF5E8CB"})
    # Long, sculpted clouds replace the overlapping circles.
    for i in range(3):
        cloud = named(content, f"Cloud{i}")
        size = (1.0, 0.8, 0.6)[i]
        cloud.children = [S(O, "CloudSilhouette", [(x * size, y * size) for x, y in
                           [(-130, 24), (-107, 6), (-67, 5), (-49, -22), (-13, -35), (17, -13),
                            (59, -17), (86, 5), (123, 11), (139, 24), (71, 32), (-44, 33)]],
                           sc.vgrad(-35 * size, 35 * size, [("F2FFF8E6", 0), ("30E9F4E8", 1)]))]
    islands = [S(O, "DistantHeadland", [(-80, 985, "c"), (-80, 913), (30, 909), (100, 936), (195, 949),
                                       (300, 983), (300, 987, "c")], F("FF759E9D")),
               S(O, "DistantIslet", [(775, 984), (840, 969), (887, 963), (946, 974), (1040, 984)], F("FF8BAFA7"))]
    before(content, "Sea", *islands)
    sea_details = []
    rng = random.Random(31)
    for i in range(32):
        y = 996 + i * 4.9
        width = 18 + (y - 990) * 0.42
        x = 780 + math.sin(i * 1.7) * 32
        sea_details.append(S(O, f"SunReflection{i}", [(x - width, y), (x, y - 1.2), (x + width, y)],
                             L("65F9E5BA" if i % 3 else "30F9E5BA", 1.6 + i * 0.035), closed=False))
    for i in range(14):
        y = rng.uniform(996, 1145)
        x = rng.uniform(0, 1000)
        sea_details.append(S(O, f"WaterRiffle{i}", [(x, y), (x + 30, y - 2), (x + 80, y)], L("24DBF0D8", 1), closed=False))
    before(content, "Sea", *sea_details)
    # The shore has stretched, irregular foam rather than two identical sine
    # waves. Fine lace travels with its original wave transform.
    for i in range(2):
        wave = named(content, f"Wave{i}")
        for path in wave.children:
            if path.tag == "PointsPath":
                for vertex in path.children:
                    vertex.attrs["y"] = float(vertex.attrs["y"]) * 0.52
    before(content, "Foam", *[E(O, f"FoamLace{i}", i * 61 + 14, 1200 + math.sin(i * 2.3) * 6,
                                   19 + (i % 3) * 7, 2, F("80FFF8E4")) for i in range(18)])
    # Linen stripes and fringe on the towel, very fine compared with the old
    # black contour; a glancing highlight across the canopy ribs.
    towel = named(content, "Towel")
    weave = [S(O, f"TowelWeave{i}", [(113 + i * 17, 1302), (121 + i * 17, 1386)],
               L("60F7E9C8", 2), closed=False) for i in range(12)]
    for line in weave:
        line.children.insert(0, d("ClippingShape", sourceId=towel.ref(), name="Clip"))
    before(content, "Towel", *weave,
           *[S(O, f"TowelFringe{i}", [(108 + i * 13, 1388), (109 + i * 13, 1398)], L("A0E7D6B5", 1.3),
                closed=False) for i in range(17)])
    # Grounding is part of the prop rig, so the shadow follows every sidestep.
    crab = named(content, "Crab")
    crab.children.append(glow(sc, "CrabContact", 0, 31, 68, "553F4D38", 0.14))
    crab.children.insert(0, S(O, "ShellGlint", [(-24, -14), (-9, -20), (6, -18)],
                               L("80FFE6B0", 2), closed=False))
    # Cloth has curved lit ribs and shaded edges, rather than uniformly bright
    # triangles. The whole canopy flexes about its crown, independently of pole.
    umbrella = named(content, "Umbrella")
    canopy = named(content, "Canopy")
    paint(canopy, sc.vgrad(-80, 80, [("FFFFF0D2", 0), ("FFE7D2AE", 0.65), ("FFBCA47D", 1)]))
    canopy_parts = [e for e in umbrella.children if str(e.attrs.get("name", "")).startswith(("UStripe", "Canopy"))]
    for panel in canopy_parts:
        if str(panel.attrs.get("name", "")).startswith("UStripe"):
            paint(panel, sc.vgrad(-90, 90, [("FFD48C6B", 0), ("FFC36D53", 0.6), ("FF9E5745", 1)]))
    crown = (220.0, 990.0)
    ribs = [S(crown, f"CanopyRib{i}", [(220, 991), (220 + dx * 0.48, 1034), (220 + dx, 1113)],
              L("50FFF5D4", 1.4), closed=False) for i, dx in enumerate((-168, -84, 74, 163))]
    for part in canopy_parts:
        umbrella.children.remove(part)
        part.attrs["x"] = float(part.attrs["x"]) - crown[0]
        part.attrs["y"] = float(part.attrs["y"]) - crown[1]
    canopy_motion = sc.node("CanopyBreeze", *crown, *ribs, *canopy_parts)
    umbrella.children.insert(0, canopy_motion)
    sc.ambient("CanopyBreeze", sc.A("amb_canopy", 600, [
        sc.T(canopy_motion, rotation=[(0, 0.0), (160, -0.012), (342, 0.009), (490, -0.004), (600, 0.0)],
             scaleY=[(0, 1.0), (180, 0.984), (360, 1.006), (600, 1.0)])], loop=True, seam_hold=True))
    # The passing breaker sends a restrained gust through the canopy, with
    # its hem arriving after the initial pressure instead of moving the pole.
    canopy_motion.attrs.update(x=0.0, y=0.0)
    gust = sc.node("CanopyWaveGust", *crown, canopy_motion)
    umbrella.children[umbrella.children.index(canopy_motion)] = gust
    wave_event = next(a for a in sc.anims if a.attrs["name"] == "ev_bigWave")
    wave_event.add(sc.T(gust, rotation=[(0, 0.0), (68, 0.0), (88, -0.025), (113, 0.012),
                                       (144, -0.004), (178, 0.0), (360, 0.0)],
                       scaleY=[(0, 1.0), (73, 1.0), (96, 0.975), (120, 1.012), (151, 0.997),
                               (178, 1.0), (360, 1.0)]))
    wash = named(content, "Wash")
    for i, (xx, yy, length) in enumerate(((-420, 71, 66), (-270, 82, 37), (-80, 68, 85),
                                        (160, 83, 42), (340, 70, 73))):
        lace = S(O, f"DrainingFoam{i}", [(xx - length / 2, yy), (xx, yy + 3), (xx + length / 2, yy - 1)],
                 L("A8F8FFF5", 1.7), closed=False, opacity=0.0)
        wash.children.insert(0, lace)
        x, y = float(lace.attrs["x"]), float(lace.attrs["y"])
        start = 116 + i * 4
        wave_event.add(sc.T(lace,
            opacity=[(0, 0.0), (start, 0.0), (start + 13, 0.7), (180 + i * 7, 0.0), (360, 0.0)],
            x=[(0, x), (start, x), (210, x + (13 if i % 2 else -11)), (360, x)],
            y=[(0, y), (start, y), (210, y + 14 + i * 2), (360, y)]))
    # Foreground dunes and fine beach grass make a coherent depth stack.
    # the dune runs 40 px below the frame (M5: Plane5 travels 24 px up); the gradient keeps its span
    dunes = [S(O, "NearDune", [(-60, 1960, "c"), (-60, 1690), (130, 1710), (335, 1850), (680, 1870),
                               (1130, 1780), (1130, 1960, "c")],
               sc.vgrad(-115, 85, [("FFE5CAA0", 0), ("FFB59873", 1)]))]
    for i in range(18):
        x = 15 + i * 15
        y = 1765 + i * 5
        dunes.insert(0, S(O, f"DuneGrass{i}", [(x, y + 45), (x - 5, y + 12), (x - 18 + (i % 3) * 12, y - 12)],
                          L("80A08E61", 1.5), closed=False))
    tint_at = next(i for i, e in enumerate(content) if e.attrs.get("name") == "SunsetTint")
    content[tint_at + 1:tint_at + 1] = dunes      # behind the sunset tint, so the dune warms too
    # A palm silhouette at the edge frames the sky; fronds pivot separately for
    # low amplitude, delayed breeze. Everything remains outside the focal area.
    # the palm now stands inside the frame (trunk visible) instead of fronds hanging from nowhere
    crown_x, crown_y = 150.0, 440.0
    trunk_pts = [(30, 1240), (82, 900), (128, 620), (138, 440), (166, 450), (156, 640), (114, 915), (78, 1250)]
    trunk = S(O, "PalmTrunk", trunk_pts, sc.vgrad(-400, 400, [("FF8C7357", 0), ("FF5B4A3B", 1)]))
    rings = [S(O, f"TrunkRing{i}", [(xl - 2, y + 6), ((xl + xr) / 2, y), (xr + 2, y + 6)], L("70392C22", 3),
               closed=False) for i, (xl, xr, y) in enumerate([(36 + k * 3.4, 80 + k * 3.0, 1200 - k * 52)
                                                             for k in range(15)])]
    for r_ in rings:
        r_.children.insert(0, d("ClippingShape", sourceId=trunk.ref(), name="Clip"))
    fronds, tracks = [], []
    for i, (angle, length) in enumerate(((-2.7, 260), (-1.9, 270), (-1.1, 310), (-0.3, 325), (0.35, 340), (0.95, 300))):
        vx, vy = math.cos(angle), math.sin(angle)
        nx, ny = -vy, vx
        midrib = [(0, 0), (vx * length * 0.5, vy * length * 0.5 + 15), (vx * length, vy * length + 58)]
        blades = []
        for k in range(1, 14):
            t = k / 14
            xx, yy = vx * length * t, vy * length * t + 58 * t * t
            width = 44 * math.sin(math.pi * t) + 8
            for side in (-1, 1):
                blades.append(S(O, f"Pinna{k}_{side}", [(xx, yy),
                    (xx + side * nx * width * 0.55 + vx * 10, yy + side * ny * width * 0.55 + vy * 10),
                    (xx + side * nx * width + vx * 25, yy + side * ny * width + vy * 25 + 8, "c"),
                    (xx + vx * 15, yy + vy * 15)], F("FF315F56" if (k + i) % 2 else "FF416E60")))
        leaf = sc.node(f"PalmFrond{i}", crown_x, crown_y,
                       S(O, "FrondRib", midrib, L("FF426B59", 2), closed=False), *blades)
        fronds.append(leaf)
        tracks.append(sc.T(leaf, rotation=[(0, 0.0), (150 + i * 23, 0.06 + i * 0.006), (330 + i * 17, -0.035 - i * 0.004),
                                           (480 + i * 9, 0.02), (600, 0.0)]))
    # behind the umbrella: the trunk crosses the canopy's rim tip on the left (content is
    # front-most first, so the palm goes after it)
    after(content, "Umbrella", *fronds, *rings, trunk)
    sc.ambient("PalmBreeze", sc.A("amb_palm", 600, tracks, loop=True))


def deep_space(sc: Scene, content: list[El]) -> None:
    S, E, F, L, d = sc.S, sc.E, sc.F, sc.L, sc.d
    recolor(content, {"66B03AD0": "443B7095", "5530B0C8": "4432A8A7", "44E04A8A": "408A678E",
                      "FFF0A070": "FFE8BD94", "FFC0587A": "FF9C6B8A", "FF3A1A4A": "FF242C51",
                      "AAE0C8A0": "80B9B3A0", "DDF0D8B0": "BBDCD4B4"})
    # A directional dust lane with clustered pinpricks has structure that a
    # handful of circular gradients lacks. No blur/filter/raster assets.
    dust, stars, tracks = [], [], []
    rng = random.Random(107)
    for i in range(7):
        x, y = 40 + i * 172, 350 + i * 125
        haze = glow(sc, f"InterstellarDust{i}", x, y, 270, ("183B718A", "20548586", "206B638D")[i % 3], 0.28)
        haze.attrs["rotation"] = 0.64
        dust.append(haze)
    for i in range(130):
        t = rng.uniform(0, 1)
        x = -80 + t * 1240 + rng.gauss(0, 42)
        y = 260 + t * 930 + rng.gauss(0, 95)
        size = rng.choice((1.2, 1.6, 2.0, 2.5))
        stars.append(E(O, f"DustStar{i}", x, y, size, size, F("FFD1E5DF"), opacity=rng.uniform(0.12, 0.6)))
    before(content, "Void", *stars, *dust)
    # A layered ring system and atmospheric limb make the hero planet read as
    # an illuminated volume; fine cloud bands are clipped to the sphere.
    planet_g = named(content, "PlanetGroup")
    planet = named(content, "Planet")
    ring_front = named(content, "RingFront")
    ring_back = named(content, "RingBack")
    ring_back.children = [ellipse(d, 520, 120), L("80B9B3A0", 5)]
    arc = [(260 * math.cos(t * math.pi / 24), 60 * math.sin(t * math.pi / 24)) for t in range(25)]
    ring_front.children = [smooth_path(d, arc, closed=False), L("BBDCD4B4", 5)]
    rings = []
    for i, scale in enumerate((0.88, 0.94, 1.04, 1.10)):
        ring = S(O, f"RingFilament{i}", [(x * scale, y * scale) for x, y in arc],
                 L(("60E4D9C1", "30D8D3D5", "80C1B9A4", "30E5DCC4")[i], 1.5 if i % 2 else 3),
                 closed=False, origin=O, rotation=-0.25)
        ring.attrs.update(x=230.0, y=820.0)
        rear = E(O, f"RingRearFilament{i}", 230, 820, 520 * scale, 120 * scale, L("40C8C4AE", 1.4), rotation=-0.25)
        planet_g.children.append(rear)
        rings.append(ring)
    planet_g.children[0:0] = rings
    for e in planet_g.children:
        if str(e.attrs.get("name", "")).startswith("Band"):
            e.attrs["opacity"] = 0.2
    limb = E(O, "AtmosphericLimb", 230, 820, 304, 304, L("506ABED0", 2))
    planet_g.children.insert(planet_g.children.index(planet), limb)
    cloud_bands = []
    for i in range(14):
        yy = 698 + i * 17
        half = math.sqrt(max(0, 148**2 - (yy - 820)**2))
        band = S(O, f"PlanetWeather{i}", [(230 - half, yy), (200, yy + 4), (265, yy + 1), (230 + half, yy - 3)],
                 L("25F4DEBA" if i % 3 else "283B325E", 2 + i % 3), closed=False)
        band.children.insert(0, d("ClippingShape", sourceId=planet.ref(), name="Clip"))
        cloud_bands.append(band)
    planet_g.children[planet_g.children.index(planet):planet_g.children.index(planet)] = cloud_bands
    # Put a dark terminator at the edge, with a transparent edge toward light.
    terminator = E(O, "PlanetTerminator", 230, 820, 300, 300,
                   d("Fill", lin(d, -100, -80, 150, 100, [("00202D51", 0), ("00202D51", 0.35), ("B0101934", 1)]), name="Fill"))
    planet_g.children.insert(planet_g.children.index(planet), terminator)
    before(content, "PlanetGroup", glow(sc, "PlanetHalo", 215, 800, 215, "142D99B9"))
    # Brushed metal, glass highlights, animated propulsion and the tractor beam.
    ufo = named(content, "Ufo")
    ufo.children[0:0] = [S((860, 900), "DomeReflection", [(825, 879), (835, 859), (852, 850)],
                           L("A0E4FFF4", 2), closed=False),
                          E((860, 900), "HullInlay", 860, 906, 195, 30, L("80D6EDF1", 1)),
                          glow(sc, "ThrusterBloom", 0, 28, 52, "505EE8CE", 0.3)]
    # Nested translucent volumes soften the cone laterally as well as down
    # its length. The existing Beam node still owns its opacity animation.
    # Stagger alpha/ranges across layers: identical low-alpha gradients
    # quantize together into visible horizontal stripes in the runtime.
    beam = named(content, "Beam")
    beam.children = [c for c in beam.children if c.tag not in ("Fill", "Stroke")]
    for i in range(12):
        width = 1.24 - i * 0.065
        alpha = 7 + i
        volume = S(O, f"BeamFalloff{i}", [(-40 * width, -140), (40 * width, -140),
                                          (110 * width, 140), (-110 * width, 140)],
                   sc.vgrad(-140 - i * 2.3, 140 + i * 4.7,
                            [(f"{alpha:02X}9CEED7", 0), (f"{round(alpha * .75):02X}88D5CB", .18 + i * .011),
                             (f"{round(alpha * .16):02X}79BDC7", .72 + i * .008), ("0079BDC7", 1)]))
        beam.children.insert(0, volume)
    ship_beam = named(content, "ShipBeam")
    ship_beam.children = [c for c in ship_beam.children if c.tag not in ("Fill", "Stroke")]
    for i in range(16):
        width = 1.26 - i * 0.053
        alpha = 11 + i * 1.3
        volume = S(O, f"MothershipFalloff{i}",
                   [(-46 * width, -235, "c"), (46 * width, -235, "c"),
                    (165 * width, 355, "c"), (-165 * width, 355, "c")],
                   # every layer is clear before the shape's bottom (295): a layer still lit there
                   # cut the beam off with a hard edge (M5 Task 6 self-check)
                   sc.vgrad(-295 - i * 2.1, 295 - i * 5.3,
                            [(f"{round(alpha):02X}C5F9E5", 0),
                             (f"{round(alpha * .66):02X}B8EAD9", .21 + i * .012),
                             (f"{round(alpha * .23):02X}98D6CF", .61 + i * .009),
                             ("0098D6CF", 1)]), blendModeValue=14)
        ship_beam.children.insert(0, volume)
    # Tiny engine particles move on their own layer and never overwrite the
    # UFO bob or an event animation.
    particles = []
    for i in range(6):
        p = E((860, 900), f"TractorParticle{i}", 830 + i * 12, 950 + i * 30, 2, 4, F("80B9F6DD"), opacity=0.0)
        particles.append(p)
        yy = float(p.attrs["y"])
        tracks.append(sc.T(p, y=[(0, yy), (180, yy - 28), (360, yy)],
                           opacity=[(0, 0.0), (50 + i * 30, 0.7), (150 + i * 30, 0.0), (360, 0.0)]))
    ufo.children[0:0] = particles
    sc.ambient("TractorDust", sc.A("amb_tractor_dust", 360, tracks, loop=True))
    duck = named(content, "Duck")
    for name, radius in (("DHead", 40), ("DBody", 80)):
        paint(named(content, name), sc.rgrad(radius, [("FFFFEC83", 0), ("FFF5C84A", 0.6), ("FFD3952C", 1)], cx=-15, cy=-14))
    duck.children.insert(0, E((760, 1260), "DuckGlint", 768, 1196, 17, 7, F("70FFF5C1"), rotation=-0.5))


def refine_scene(sc: Scene, content: list[El]) -> None:
    # Fine contours for small props; hero silhouettes and value structure do
    # the work of separating planes. Keep transparent hit areas untouched.
    for e in walk(content):
        if e.tag == "Stroke":
            e.attrs["thickness"] = float(e.attrs["thickness"]) * 0.72
    {"livingRoom": living_room, "campfire": campfire, "beach": beach, "deepSpace": deep_space}[sc.id](sc, content)
    place_groups(sc, content)
