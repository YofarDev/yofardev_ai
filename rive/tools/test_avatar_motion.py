"""Rig regression checks: python3 -m unittest discover -s rive/tools -p 'test_*.py'."""

import math
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

from avatar_kit import L1, L2, SHOULDER, ik


class ArmReachTest(unittest.TestCase):
    def test_extended_rest_has_no_artificial_bend(self) -> None:
        for side, x in ((-1, 240), (1, 560)):
            self.assertEqual(ik(side, (x, 1070), 90), (0.0, 0.0, 0.0))

    def test_unreachable_targets_extend_towards_target(self) -> None:
        for target in ((240, 1084), (100, 1150), (700, 400)):
            up, elbow, hand = ik(-1, target, 90)
            self.assertAlmostEqual(elbow, 0, places=6)
            expected = math.atan2(target[1] - SHOULDER[1], target[0] - SHOULDER[0])
            self.assertAlmostEqual(math.sin(up + math.pi / 2), math.sin(expected))
            self.assertAlmostEqual(math.cos(up + math.pi / 2), math.cos(expected))
            self.assertAlmostEqual(math.sin(up + elbow + hand), 0)

    def test_forward_kinematics_reaches_contact_poses(self) -> None:
        # Wave, facepalm, chin touch and clap contacts with foreshortening.
        for target, fs in (((198, 604), 0.75), ((342, 476), 0.55),
                           ((370, 598), 0.7), ((387, 812), 0.76)):
            up, elbow, _ = ik(-1, target, -90, fs=fs)
            x = SHOULDER[0] - L1 * fs * math.sin(up) - L2 * math.sin(up + elbow)
            y = SHOULDER[1] + L1 * fs * math.cos(up) + L2 * math.cos(up + elbow)
            self.assertAlmostEqual(x, target[0], places=6)
            self.assertAlmostEqual(y, target[1], places=6)

    def test_mirrored_targets_produce_mirrored_joints(self) -> None:
        left = ik(-1, (348, 466), -76, fs=0.55)
        right = ik(1, (452, 466), 256, fs=0.55)
        for a, b in zip(left, right):
            self.assertAlmostEqual(a, -b)


class AnimationChannelTest(unittest.TestCase):
    def test_each_timeline_owns_each_property_only_once(self) -> None:
        source = Path(__file__).resolve().parents[1] / "avatar/avatar.rml"
        for animation in ET.parse(source).findall("Artboard/LinearAnimation"):
            seen = set()
            for obj in animation.findall("KeyedObject"):
                for prop in obj.findall("KeyedProperty"):
                    channel = (obj.get("objectId"), prop.get("property"))
                    self.assertNotIn(channel, seen, animation.get("name"))
                    seen.add(channel)
                    frames = [int(key.get("frame")) for key in prop]
                    self.assertEqual(frames, sorted(set(frames)), animation.get("name"))


if __name__ == "__main__":
    unittest.main()
