"""Materials and restrained cloth response for the avatar's existing wardrobe.

The public switches and joint rig stay in gen_avatar. Every suspended piece
has a fixed attachment, an ambient node and an independent gesture node so
layered motion never overwrites its authored position.
"""

from __future__ import annotations

from dataclasses import dataclass
import math
from collections.abc import Iterator

from avatar_kit import E, F, L, R, S, Rig, d, group, hgrad, mirror, rgrad, vgrad
from rml import El, lin, smooth_path


def walk(root: El) -> Iterator[El]:
    yield root
    for child in root.children:
        yield from walk(child)


def named(root: El, name: str) -> El:
    return next(e for e in walk(root) if e.attrs.get("name") == name)


def paint(shape: El, fill: El) -> None:
    shape.children = [c for c in shape.children if c.tag != "Fill"] + [fill]


def front(root: El, *elements: El) -> None:
    root.children[0:0] = elements


@dataclass
class Cloth:
    life: El
    response: El
    strength: float
    phase: float
    amplitude: float


def suspend(parent: El, parts: list[El], pivot: tuple[float, float], name: str,
            strength: float = 1.0, phase: float = 0.0, amplitude: float = 0.012) -> Cloth:
    """Pivot is expressed in the parent node's coordinate space."""
    index = min(parent.children.index(p) for p in parts)
    for part in parts:
        parent.children.remove(part)
        part.attrs["x"] = float(part.attrs.get("x", 0)) - pivot[0]
        part.attrs["y"] = float(part.attrs.get("y", 0)) - pivot[1]
    life = group(name + "Life", *parts)
    response = group(name + "Response", life)
    parent.children.insert(index, d("Node", response, x=pivot[0], y=pivot[1], name=name + "Attachment"))
    return Cloth(life, response, strength, phase, amplitude)


def refine(body: Rig, head: Rig, tops_front: dict[str, El], tops_back: dict[str, El],
           hats: dict[str, El], arms: list[dict], glasses: dict[str, El], cape: Rig) -> list[Cloth]:
    cloth: list[Cloth] = []
    # Cotton: soft seam highlights and short gathered folds, distinct from the
    # sharper diagonal twill of the trench and wool's broken stitch patterns.
    hoodie = tops_back["pinkHoodie"]
    front(hoodie,
          S(body, "HoodiePocketCurve", [(310, 953), (328, 934), (337, 916)], L("70F9E1E8", 2), closed=False),
          S(body, "HoodiePocketCurveR", mirror([(310, 953), (328, 934), (337, 916)]), L("708F668E", 2), closed=False))
    for cord in tops_front["pinkHoodie"].children[:2]:
        cloth.append(suspend(tops_front["pinkHoodie"], [cord], (float(cord.attrs["x"]), float(cord.attrs["y"])),
                             str(cord.attrs["name"]) + "Inertia", 0.85, len(cloth) * 0.6, 0.004))

    coat = tops_back["longCoat"]
    base = named(coat, "Torso")
    front(coat,
          S(body, "CoatWeltL", [(282, 839), (326, 851)], L("FF88704D", 4), closed=False),
          S(body, "CoatWeltR", mirror([(282, 839), (326, 851)]), L("FF88704D", 4), closed=False),
          S(body, "CoatWeltLight", [(283, 835), (326, 847)], L("80FFF1D1", 1.4), closed=False),
          S(body, "CoatWeltLightR", mirror([(283, 835), (326, 847)]), L("60FFF1D1", 1.4), closed=False),
          S(body, "CoatFacingL", [(307, 648), (349, 700), (388, 754)], L("70FFF0C9", 2), closed=False),
          S(body, "CoatFacingR", mirror([(307, 648), (349, 700), (388, 754)]), L("50685139", 2), closed=False),
          R(body, "BuckleRecess", 400, 962, 54, 32, 3, F("FF6E5739")),
          R(body, "BuckleBrass", 400, 960, 45, 26, 2, F("00000000"), L("FFCEB37F", 4)),
          S(body, "BucklePin", [(400, 948), (400, 972)], L("FFEBCC94", 2), closed=False),
          *[E(body, f"HornButton{i}", x, y, 11, 11,
              rgrad(6, [("FF8C704B", 0), ("FF4E4031", 1)]), L("FF604D35", 1))
            for i, (x, y) in enumerate(((345, 805), (455, 805), (345, 883), (455, 883)))])
    twill = [S(body, f"CoatTwill{i}", [(265 + i * 17, 782), (285 + i * 17, 805)],
               L("15FFF2D4", 1), closed=False, clip=base) for i in range(17)]
    front(coat, *twill)
    for side, x in (("L", -70), ("R", 70)):
        parts = [named(coat, "Lapel" + side), named(coat, "CoatFacing" + side)]
        cloth.append(suspend(coat, parts, (x, -400), "TrenchLapel" + side, 0.55,
                             0.2 if side == "L" else 1.0, 0.003))

    tee = tops_back["tshirt"]
    front(tee,
          S(body, "TeeShoulderSeam", [(263, 693), (287, 681), (318, 669)], L("606D6974", 1.6), closed=False),
          S(body, "TeeSideSeam", [(274, 785), (285, 884), (278, 1000)], L("503B3C47", 1.4), closed=False),
          S(body, "TeePocketSeam", [(456, 739), (509, 739), (505, 791), (482, 802), (459, 791)],
            L("80534F5A", 1.7), closed=False),
          R(body, "TeeWovenLabel", 499, 775, 9, 20, 1, F("FFB46A62")),
          S(body, "TeePocketHighlight", [(460, 735), (505, 735)], L("507F7782", 1.1), closed=False))

    tank = tops_back["underwear"]
    tank_shape = named(tank, "Tank")
    # Fine vertical ribbing follows the vest cut; the skin underneath stays
    # clean, including when a sleeve is absent and the elbow crosses the torso.
    ribs = [S(body, f"TankRib{i}", [(265 + i * 12, 724), (269 + i * 12, 850), (265 + i * 12, 1005)],
              L("407C8F9C", 0.9), closed=False, clip=tank_shape) for i in range(24)]
    front(tank, *ribs,
          S(body, "TankBoundNeck", [(300, 652), (330, 721), (400, 741), (470, 721), (500, 652)],
            L("FFEEF0EF", 6), closed=False),
          S(body, "TankNeckStitch", [(310, 678), (336, 727), (400, 747), (464, 727), (490, 678)],
            L("507E9095", 1.2), closed=False))

    swim = tops_back["swimsuit"]
    swim_shape = named(swim, "SwimTop")
    front(swim,
          S(body, "SwimPanelLeft", [(280, 745), (301, 850), (289, 1010), (249, 1010), (257, 771)],
            hgrad(-30, 30, "FF126273", "FF238F9D"), clip=swim_shape),
          S(body, "SwimPanelRight", mirror([(280, 745), (301, 850), (289, 1010), (249, 1010), (257, 771)]),
            F("FF155F70"), clip=swim_shape),
          S(body, "SwimFlatlock", [(290, 768), (308, 865), (296, 1008)], L("70A7E9DD", 1.4), closed=False),
          S(body, "SwimFlatlockR", mirror([(290, 768), (308, 865), (296, 1008)]), L("508DD3CF", 1.4), closed=False),
          S(body, "SwimWaveMark", [(426, 787), (439, 781), (452, 787), (465, 781)], L("D0D8F4E6", 2), closed=False))
    towels = tops_front["swimsuit"]
    for side in ("L", "R"):
        part = named(towels, "Towel" + side)
        stripe = named(towels, "TowelStripe" + side)
        x = 344 if side == "L" else 456
        extras = [S(body, f"TowelHem{side}{k}", [(x - 18, 878 + k * 5), (x + 17, 878 + k * 5)],
                    L("708BABB0", 1), closed=False) for k in range(3)]
        extras += [S(body, f"TowelFringe{side}{k}", [(x - 17 + k * 7, 899), (x - 18 + k * 7, 910 + k % 2 * 4)],
                     L("FFC8D9D7", 1.7), closed=False) for k in range(6)]
        front(towels, *extras)
        cloth.append(suspend(towels, [*extras, stripe, part], (x - 400, -396), "Towel" + side, 1.3,
                             0 if side == "L" else 0.8, 0.013))

    sweater = tops_back["christmasSweater"]
    sw_shape = named(sweater, "Torso")
    front(sweater,
          *[S(body, f"KnitLoop{i}_{j}", [(x - 3, y - 4), (x, y), (x + 3, y - 4)],
              L("306DB181", 1), closed=False, clip=sw_shape)
            for i, x in enumerate(range(270, 550, 23)) for j, y in enumerate((750, 778, 908, 936, 964))],
          S(body, "SweaterFoldL", [(283, 878), (302, 895), (297, 936)], L("80469A64", 2), closed=False),
          S(body, "SweaterFoldR", mirror([(283, 878), (302, 895), (297, 936)]), L("8020593E", 2), closed=False))

    suit = tops_back["blackSuitAndTie"]
    front(suit,
          S(body, "SuitRollLight", [(318, 655), (349, 699), (382, 754)], L("805E6373", 2), closed=False),
          S(body, "SuitRollShade", mirror([(318, 655), (349, 699), (382, 754)]), L("90171D29", 3), closed=False),
          S(body, "SuitWeltL", [(281, 865), (331, 873)], L("FF171C27", 4), closed=False),
          S(body, "SuitWeltR", mirror([(281, 865), (331, 873)]), L("FF171C27", 4), closed=False),
          S(body, "SuitDartL", [(320, 768), (339, 828), (336, 941)], L("604A4E60", 1.4), closed=False),
          S(body, "SuitDartR", mirror([(320, 768), (339, 828), (336, 941)]), L("603B4050", 1.4), closed=False),
          E(body, "SuitButtonHighlight", 399, 879, 5, 3, F("706D7485")))
    for side, x, roll in (("L", -70, "SuitRollLight"), ("R", 70, "SuitRollShade")):
        cloth.append(suspend(suit, [named(suit, "Lapel" + side), named(suit, roll)], (x, -400),
                             "WoolLapel" + side, 0.35, 0.6 if side == "L" else 1.3, 0.002))
    tie_parts = [named(suit, name) for name in ("TieShine", "Tie")]
    cloth.append(suspend(suit, tie_parts, (0, -359), "SilkTie", 0.8, 0.4, 0.009))

    bat = tops_back["batman"]
    front(bat,
          S(body, "BatChestFacetL", [(303, 696), (365, 680), (390, 711), (356, 728), (312, 716)],
            F("FF454D5B")),
          S(body, "BatChestFacetR", mirror([(303, 696), (365, 680), (390, 711), (356, 728), (312, 716)]),
            F("FF323A48")),
          *[S(body, f"BatAbdominal{k}", [(342, y), (395, y + 5), (399, y + 32), (347, y + 26)],
              hgrad(-30, 30, "FF3B4350", "FF303744"), L("FF252C37", 1.5)) for k, y in enumerate((831, 878, 925))],
          *[S(body, f"BatAbdominalR{k}", mirror([(342, y), (395, y + 5), (399, y + 32), (347, y + 26)]),
              F("FF303846"), L("FF252C37", 1.5)) for k, y in enumerate((831, 878, 925))],
          *[R(body, f"UtilityPouch{k}", x, 992, 42, 27, 4,
              vgrad(-14, 14, "FFE0B45A", "FF947033"), L("FF71542A", 1.5)) for k, x in enumerate((270, 323, 477, 530))],
          R(body, "BatBuckle", 400, 991, 54, 30, 4, F("FFBD9645"), L("FFEAD18A", 2)))
    # Scalloped trailing hem and three reflected folds create a cape, rather
    # than a widening trapezoid. The hem is deformed separately below.
    cape_shape = named(cape.el, "CapeShape")
    replacement = S(cape, "CapeMaterial", [(270, 630), (400, 610), (530, 630), (632, 735), (720, 903),
                     (749, 1030, "c"), (675, 987), (605, 1025, "c"), (535, 988), (465, 1025, "c"),
                     (396, 990), (325, 1025, "c"), (257, 988), (181, 1025, "c"), (105, 987),
                     (52, 1030, "c"), (78, 896), (166, 732)],
                    hgrad(-340, 340, "FF111824", "FF29313F"), L("FF080F19", 2.5))
    cape_shape.children = replacement.children
    cape_shape.attrs.update(x=replacement.attrs["x"], y=replacement.attrs["y"])
    front(cape.el,
          *[S(cape, f"CapeFold{i}", [(x0, 654), (x1, 819), (x2, 1009)],
              L("303E506A" if i % 2 else "60121C2C", 7 if i % 2 else 13), closed=False,
              clip=cape_shape) for i, (x0, x1, x2) in enumerate(((282, 212, 166), (332, 291, 258),
                                                               (468, 505, 544), (518, 590, 660)))])

    robot = tops_back["robocop"]
    # An opaque flexible seal bridges jaw and rings. Hiding the human neck
    # alone would replace the old skin crescent with a transparent gap.
    tops_front["robocop"].add(S(body, "NeckArmorSeal", [(365, 510), (435, 510), (440, 612), (360, 612)],
                                 hgrad(-40, 40, "FF46596F", "FF1C2A40"), L("FF1A283B", 1.5)))
    # Hard, directional reflection steps distinguish brushed armor from cloth.
    for plate_name in ("Plate", "Plate2", "Abs"):
        plate = named(robot, plate_name)
        paint(plate, d("Fill", lin(d, -70, -50, 70, 90,
              [("FFEEF5FA", 0), ("FFBFCED9", 0.28), ("FF65778C", 0.31),
               ("FF9EAFBF", 0.48), ("FF64768B", 0.8), ("FF34475F", 1)]), name="Fill"))
    front(robot,
          *[E(body, f"PlateFastener{i}", x, y, 6, 6, F("FF384B62"), L("FFAABCC7", 1))
            for i, (x, y) in enumerate(((310, 678), (377, 689), (423, 689), (490, 678), (336, 865), (464, 865)))],
          S(body, "ChestGasket", [(399, 672), (399, 807)], L("FF202C3C", 5), closed=False),
          S(body, "ArmorSerial", [(441, 735), (468, 735), (468, 747), (441, 747)], L("FF42566B", 1), closed=False),
          *[S(body, f"SerialBar{i}", [(445 + i * 4, 738), (445 + i * 4, 744)], L("FF42566B", 1), closed=False)
            for i in range(5)])

    maid = tops_back["soubrette"]
    bib = named(maid, "Bib")
    front(maid,
          S(body, "ApronFacing", [(337, 769), (463, 769)], L("FFB9C6CF", 2), closed=False),
          S(body, "ApronPocket", [(354, 873), (446, 873), (443, 932), (400, 945), (357, 932)],
            F("FFF7F5ED"), L("FFBFCAD0", 1.5)),
          S(body, "ApronPocketLip", [(356, 878), (444, 878)], L("90FFFFFF", 2), closed=False),
          *[S(body, f"ApronPleat{i}", [(x, 796), (x - 4, 878), (x - 2, 1005)],
              L("6099A9B7", 1.3), closed=False, clip=bib) for i, x in enumerate((337, 348, 452, 463))])
    apron_parts = [e for e in maid.children if e.attrs.get("name") in ("Bib", "ApronFacing", "ApronPocket", "ApronPocketLip")
                   or str(e.attrs.get("name", "")).startswith("ApronPleat")]
    cloth.append(suspend(maid, apron_parts, (0, -240), "ApronBib", 0.35, 1.4, 0.004))
    # Continuous gathered lace with short scallops, not a necklace of circles.
    neckline = tops_front["soubrette"]
    neckline.children = [e for e in neckline.children if not str(e.attrs.get("name", "")).startswith("Frill")]
    top_edge = [(330 + k * 10, 601 + 19 * math.sin(math.pi * k / 14)) for k in range(15)]
    bottom_edge = [(330 + k * 10, 614 + 20 * math.sin(math.pi * k / 14) + (4 if k % 2 else 0))
                   for k in range(14, -1, -1)]
    neckline.add(S(body, "GatheredNeckLace", [*top_edge, *bottom_edge],
                    vgrad(-18, 18, "FFFFF9E9", "FFCCD4D9"), L("FFAFBEC8", 1.1)))
    front(neckline, *[S(body, f"LaceGather{k}", [(x, y + 3), (x + 2, y + 11)],
                       L("7094A5B2", 1), closed=False) for k, (x, y) in enumerate(top_edge[1:-1])])
    maid_hat = hats["soubrette"]
    maid_hat.children = [e for e in maid_hat.children if not str(e.attrs.get("name", "")).startswith("MaidFrill")]
    crown_top = [(306 + k * 13, 231 - (306 + k * 13 - 400) ** 2 / 2600 - (6 if k % 2 else 0)) for k in range(16)]
    crown_bottom = [(306 + k * 13, 249 - (306 + k * 13 - 400) ** 2 / 2600) for k in range(15, -1, -1)]
    front(maid_hat, S(head, "PleatedLaceHeadband", [*crown_top, *crown_bottom],
                      vgrad(-16, 16, "FFFFF9ED", "FFD1DADF"), L("FFABBAC5", 1.1)),
          *[S(head, f"HeadbandPleat{k}", [(x, y + 4), (x + 1, y + 16)], L("80A8B6C0", 1), closed=False)
            for k, (x, y) in enumerate(crown_top[1:-1])])
    # Small black bow tails respond independently; their attachment stays fixed.
    bow = tops_front["soubrette"]
    for side, pts in (("L", [(390, 635), (378, 669), (389, 664), (396, 672), (400, 637)]),
                      ("R", [(402, 636), (410, 672), (419, 664), (428, 668), (412, 635)])):
        tail = S(body, "BowTail" + side, pts, vgrad(-20, 20, "FF3B3544", "FF151B29"), L("FF101620", 1.2))
        bow.children.append(tail)
        cloth.append(suspend(bow, [tail], (0, -365), "BowTail" + side, 0.9, 0.3 if side == "L" else 1.1, 0.02))

    # A connected nebular volume and restrained filaments avoid the impression
    # of unrelated bright dots pasted onto a dark bodysuit.
    for parent, rig, source_name, clouds in (
            (tops_back["singularity"], body, "Torso",
             ((345, 748, 85, "40387999", 0.82), (378, 811, 115, "403C9DAD", 0.92),
              (433, 857, 75, "406D5C99", 0.78), (465, 933, 68, "30495788", 1.2))),
            (hats["singularity"], head, "Void",
             ((331, 308, 87, "404A689C", 0.86), (371, 337, 60, "404CABA9", 0.9),
              (427, 387, 76, "304D5796", 1.05)))):
        source = named(parent, source_name)
        wisps = [E(rig, f"NebularCloud{k}", x, y, radius * 2, radius * 2,
                   rgrad(radius, [(color, 0), ("20" + color[2:], 0.32), ("00" + color[2:], 1)]),
                   scaleY=sy, clip=source) for k, (x, y, radius, color, sy) in enumerate(clouds)]
        # An obscuring dusty curl gives the clouds a front/back relationship.
        # Head and chest have different paths and concentrations.
        dust_points = ([(285, 310), (323, 294), (354, 314), (367, 350), (403, 372),
                        (447, 367), (405, 383), (362, 361), (344, 327), (317, 314)]
                       if source_name == "Void" else
                       [(306, 756), (349, 774), (366, 808), (398, 821), (430, 813), (455, 833),
                        (477, 880), (451, 850), (430, 836), (395, 841), (354, 823), (335, 790)])
        wisps.insert(0, S(rig, "ObscuringDustLane", dust_points,
                          rgrad(130, [("90080D27", 0), ("00080D27", 1)]), clip=source))
        parent.children[parent.children.index(source):parent.children.index(source)] = wisps

    # Garment-specific sleeve construction, all attached to the existing joint.
    for arm in arms:
        right = arm is arms[1]
        m = mirror if right else lambda p: p
        upper, elbow = arm["arm"], arm["elbow"]
        for oid, up in arm["ups"].items():
            fore = arm["fores"][oid]
            if oid in ("underwear", "swimsuit", "singularity"):
                continue
            if oid == "robocop":
                # Rubber joint gaskets replace drawn fabric wrinkles.
                up.children = [e for e in up.children if e.attrs.get("name") not in ("Fold", "Fold2", "Seam")]
                fore.children = [e for e in fore.children if e.attrs.get("name") != "ElbowFold"]
                # Hard shells end before the hinge. Capsule end caps collide
                # into a flared oval when a foreshortened arm bends sharply.
                for parent, rig, points in ((up, upper, [(204, 756, "c7"), (276, 756, "c7"),
                        (276, 850, "c5"), (264, 875, "c5"), (216, 875, "c5"), (204, 850, "c5")]),
                        (fore, elbow, [(217, 927, "c5"), (263, 927, "c5"), (276, 954, "c5"),
                         (270, 1038, "c5"), (210, 1038, "c5"), (204, 954, "c5")])):
                    shell = named(parent, "Sleeve")
                    replacement = S(rig, "RigidShell", m(points),
                        hgrad(-40, 40, "FFBBCBD7", "FF70869D") if not right else
                        hgrad(-40, 40, "FF70869D", "FFBBCBD7"), L("FF34485F", 2))
                    shell.children = replacement.children
                    shell.attrs.update(x=replacement.attrs["x"], y=replacement.attrs["y"])
                    parent.children = [e for e in parent.children if e.attrs.get("name") != "SleeveLine"]
                # A recessed dark joint explains both rotation and overlap.
                joint = group("RecessedElbowJoint",
                    E(elbow, "HingeInner", 800 - 240 if right else 240, 901, 33, 24, F("FF26384B")),
                    E(elbow, "HingeRim", 800 - 240 if right else 240, 901, 55, 43,
                      hgrad(-28, 28, "FF7892A8", "FFB8CBD8"), L("FF31465C", 1.5)),
                    S(elbow, "FlexGasket", m([(217, 900, "c3"), (263, 900, "c3"), (262, 938, "c3"),
                                             (218, 938, "c3")]), F("FF24364B")))
                fore.children.append(joint)
                front(up,
                      S(upper, "ArmorEdge", m([(197, 704), (220, 687), (256, 688)]), L("C0F6FCFF", 2), closed=False),
                      *[S(upper, f"JointGasket{i}", m([(213, 869 + i * 7), (267, 869 + i * 7)]),
                          L("FF334358", 3), closed=False) for i in range(3)])
                front(fore,
                      S(elbow, "ForePlateRim", m([(218, 939), (212, 980), (218, 1026)]), L("A0D5E4EE", 2), closed=False),
                      S(elbow, "ForePanel", m([(224, 942), (253, 942), (256, 1004), (221, 1004)]),
                        F("FF8599AC"), L("FF42566C", 1.4)))
            elif oid == "longCoat":
                front(up,
                      S(upper, "TrenchSeam", m([(211, 757), (218, 836), (222, 882)]), L("60907852", 1.4), closed=False))
                front(fore,
                      S(elbow, "TrenchCuffTab", m([(204, 1010), (273, 1010), (274, 1030), (204, 1030)]),
                        F("FFBEA983"), L("FF8C7654", 1.3)),
                      E(elbow, "TrenchCuffButton", 800 - 259 if right else 259, 1020, 7, 7, F("FF6D573C")))
            elif oid == "blackSuitAndTie":
                front(fore, *[E(elbow, f"SuitCuffButton{i}", 800 - 260 if right else 260, 1012 + i * 10,
                                5, 5, F("FF151E2A"), L("706F7886", 0.8)) for i in range(3)])
            elif oid == "batman":
                front(fore,
                      S(elbow, "GauntletRim", m([(209, 966), (211, 1018), (220, 1058)]), L("FFA0A9B7", 2), closed=False),
                      S(elbow, "GauntletPlate", m([(218, 976), (252, 973), (260, 1026), (224, 1034)]),
                        hgrad(-22, 22, "FF1C2738", "FF46546A"), L("FF131D2C", 1.3)))
            elif oid == "christmasSweater":
                front(up, *[S(upper, f"KnitStitch{i}", m([(211 + i * 18, 765), (215 + i * 18, 771),
                                                                       (219 + i * 18, 765)]),
                                               L("607BBA91", 1.2), closed=False) for i in range(4)])
                front(fore, *[S(elbow, f"WoolCuff{i}", m([(209 + i * 10, 1040), (209 + i * 10, 1069)]),
                                                L("FFA04249", 1.5), closed=False) for i in range(7)])
            elif oid == "soubrette":
                puff = named(up, "Puff")
                replacement = S(upper, "GatheredPuff", m([(204, 686), (236, 679), (269, 685),
                    (290, 705), (299, 739), (292, 768), (278, 786), (253, 794), (222, 788),
                    (202, 775), (187, 750), (186, 720)]),
                    rgrad(78, [("FF4C4657", 0), ("FF292533", 0.65), ("FF171E2A", 1)], cx=-20, cy=-20),
                    L("FF101722", 2))
                puff.children = replacement.children
                puff.attrs.update(x=replacement.attrs["x"], y=replacement.attrs["y"])
                front(up, *[S(upper, f"PuffGather{i}", m([(211 + i * 16, 704), (217 + i * 16, 732),
                                                                          (214 + i * 16, 763)]),
                                               L("807B7187", 1.5), closed=False) for i in range(4)],
                      S(upper, "PuffGatheredCuff", m([(201, 775), (224, 785), (250, 791), (280, 782)]),
                        L("FFB5BDC8", 3), closed=False))

    # Accessory material accents remain fine enough for the face to lead.
    for hat_id, parent in hats.items():
        if hat_id == "beanie":
            front(parent,
                  S(head, "BeanieFoldLight", [(302, 281), (355, 268), (415, 267)], L("60E3A174", 1.5), closed=False),
                  R(head, "BeanieLabel", 463, 286, 24, 18, 2, F("FFC7AE88"), L("FF6B442E", 1)),
                  S(head, "BeanieLabelMark", [(458, 289), (463, 281), (468, 289)], L("FF674B38", 1.2), closed=False))
        elif hat_id in ("backwardsCap", "redMagaCap"):
            front(parent, *[E(head, f"CapEyelet{i}", x, 218, 5, 4, F("FF7F342C"), L("60ED9B79", 0.7))
                             for i, x in enumerate((334, 469))])
        elif hat_id == "frenchBeret":
            front(parent,
                  S(head, "BeretBoundEdge", [(293, 267), (368, 269), (446, 263), (523, 260)],
                    L("FF41424D", 2), closed=False),
                  S(head, "BeretFold", [(452, 213), (482, 223), (491, 242)], L("70A5A3A7", 1.4), closed=False))
        elif hat_id == "swimCap":
            paint(named(parent, "SwimCap"), rgrad(230, [("FFDDE3E4", 0), ("FFADBFC5", 0.65), ("FF7A929F", 1)], cx=-30, cy=-35))
            named(parent, "CapShine").attrs["opacity"] = 0.25
            front(parent,
                  S(head, "SiliconeSeam", [(304, 293), (331, 239), (390, 198)], L("7094A1B0", 1.6), closed=False),
                  S(head, "CapRim", [(286, 329), (331, 299), (400, 292), (469, 299), (514, 329)],
                    L("706E7D94", 2), closed=False))
    for name in ("glasses", "sunglasses"):
        front(glasses[name], *[E(head, f"Hinge{side}", x, 372, 5, 3, F("FFC8BDAD"))
                              for side, x in (("L", 314), ("R", 486))])
    return cloth
