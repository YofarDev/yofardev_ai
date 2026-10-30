import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import '../../../../core/models/avatar_scene.dart';

/// How a scene's drag handle answers the finger (contract v12, M9 ruling 8).
enum DragKind {
  /// 1D down the cord, springs back on release; past [PullTuning.fire] it
  /// fires the scene's action once per pull.
  pull,

  /// A stick follows the finger inside a box, eased out on release; a fast
  /// stir fires `flare`.
  poke,

  /// The finger leaves dots (16, oldest recycled).
  trail,

  /// A horizontal drag turns, with inertia; wraps.
  spin,

  /// A horizontal drag swivels, −1..1; it holds.
  aim,
}

/// One `SceneVM` number a handle writes, with its contract default.
typedef DragNumber = ({String name, double value});

/// One row of `rive/CONTRACT.md`'s "Drag handles (v12)" table.
class SceneDragHandle {
  const SceneDragHandle({
    required this.id,
    required this.kind,
    required this.rect,
    required this.plane,
    required this.numbers,
  });

  /// The `dragId` (`cord`, `poke`, `sand`, `spin`, `wipe`, `aim`, `rope`).
  final String id;
  final DragKind kind;

  /// In `Scene` artboard px at parallax 0.
  final Rect rect;

  /// The depth plane (0..5) the handle rides: it moves with that plane's
  /// parallax ([SceneDrags.planeOffset]).
  final int plane;

  /// The numbers it writes with their defaults, in contract order.
  final List<DragNumber> numbers;

  /// The defaults, by name.
  Map<String, double> get defaults => <String, double>{
    for (final DragNumber n in numbers) n.name: n.value,
  };
}

/// The v12 drag handles, one per scene: the Dart mirror of the contract's
/// "Drag handles (v12)" table (an equality test parses `rive/CONTRACT.md`),
/// and the geometry that places them on screen.
abstract final class SceneDrags {
  /// The `Scene` artboard (contract: 1080×1920, drawn with `Fit.cover`).
  static const Size artboard = Size(1080, 1920);

  /// `gen_scenes.PARALLAX_GAINS`: each plane's share of the travel.
  static const List<double> parallaxGains = <double>[
    0.0,
    0.15,
    0.3,
    0.5,
    0.7,
    1.0,
  ];

  /// `gen_scenes.PARALLAX_TRAVEL`: px of x / y travel at gain 1 and
  /// parallax ±1.
  static const Offset parallaxTravel = Offset(40, 24);

  /// How far plane [plane] sits from rest at [parallax] (each axis −1..1),
  /// in artboard px: `gain × 40 × parallaxX`, `gain × 24 × parallaxY`.
  static Offset planeOffset(int plane, Offset parallax) {
    final double gain = parallaxGains[plane.clamp(0, parallaxGains.length - 1)];
    return Offset(
      gain * parallaxTravel.dx * parallax.dx.clamp(-1.0, 1.0),
      gain * parallaxTravel.dy * parallax.dy.clamp(-1.0, 1.0),
    );
  }

  /// The scale `Fit.cover` draws the artboard at in a [box].
  static double coverScale(Size box) =>
      math.max(box.width / artboard.width, box.height / artboard.height);

  /// A [local] point of the scene widget ([box] big, the artboard drawn with
  /// `Fit.cover`, centred) in artboard px.
  static Offset toArtboard(Offset local, Size box) {
    final double scale = coverScale(box);
    final Offset origin = Offset(
      (box.width - artboard.width * scale) / 2,
      (box.height - artboard.height * scale) / 2,
    );
    return (local - origin) / scale;
  }

  /// The inverse of [toArtboard].
  static Offset toLocal(Offset point, Size box) {
    final double scale = coverScale(box);
    final Offset origin = Offset(
      (box.width - artboard.width * scale) / 2,
      (box.height - artboard.height * scale) / 2,
    );
    return origin + point * scale;
  }

  /// The trail numbers (beach and cafe): `trailN`, `trailX0..15`,
  /// `trailY0..15`, `trailFade` (default 1: nothing drawn).
  static const int trailDots = 16;
  static const List<DragNumber> _trail = <DragNumber>[
    (name: 'trailN', value: 0),
    (name: 'trailX0', value: 0),
    (name: 'trailX1', value: 0),
    (name: 'trailX2', value: 0),
    (name: 'trailX3', value: 0),
    (name: 'trailX4', value: 0),
    (name: 'trailX5', value: 0),
    (name: 'trailX6', value: 0),
    (name: 'trailX7', value: 0),
    (name: 'trailX8', value: 0),
    (name: 'trailX9', value: 0),
    (name: 'trailX10', value: 0),
    (name: 'trailX11', value: 0),
    (name: 'trailX12', value: 0),
    (name: 'trailX13', value: 0),
    (name: 'trailX14', value: 0),
    (name: 'trailX15', value: 0),
    (name: 'trailY0', value: 0),
    (name: 'trailY1', value: 0),
    (name: 'trailY2', value: 0),
    (name: 'trailY3', value: 0),
    (name: 'trailY4', value: 0),
    (name: 'trailY5', value: 0),
    (name: 'trailY6', value: 0),
    (name: 'trailY7', value: 0),
    (name: 'trailY8', value: 0),
    (name: 'trailY9', value: 0),
    (name: 'trailY10', value: 0),
    (name: 'trailY11', value: 0),
    (name: 'trailY12', value: 0),
    (name: 'trailY13', value: 0),
    (name: 'trailY14', value: 0),
    (name: 'trailY15', value: 0),
    (name: 'trailFade', value: 1),
  ];

  /// The handle table, one per scene (CONTRACT.md "Drag handles (v12)").
  static const Map<AvatarScene, SceneDragHandle> handles =
      <AvatarScene, SceneDragHandle>{
        AvatarScene.livingRoom: SceneDragHandle(
          id: 'cord',
          kind: DragKind.pull,
          rect: Rect.fromLTRB(270, 770, 370, 940),
          plane: 4,
          numbers: <DragNumber>[(name: 'cord', value: 0)],
        ),
        AvatarScene.campfire: SceneDragHandle(
          id: 'poke',
          kind: DragKind.poke,
          rect: Rect.fromLTRB(0, 1040, 330, 1340),
          plane: 4,
          numbers: <DragNumber>[
            (name: 'poke', value: 0),
            (name: 'pokeX', value: 0),
            (name: 'pokeY', value: 0),
          ],
        ),
        AvatarScene.beach: SceneDragHandle(
          id: 'sand',
          kind: DragKind.trail,
          rect: Rect.fromLTRB(830, 1230, 980, 1700),
          plane: 4,
          numbers: _trail,
        ),
        AvatarScene.deepSpace: SceneDragHandle(
          id: 'spin',
          kind: DragKind.spin,
          rect: Rect.fromLTRB(150, 440, 450, 740),
          plane: 2,
          numbers: <DragNumber>[(name: 'spin', value: 0)],
        ),
        AvatarScene.cafe: SceneDragHandle(
          id: 'wipe',
          kind: DragKind.trail,
          rect: Rect.fromLTRB(330, 260, 750, 760),
          plane: 2,
          numbers: _trail,
        ),
        AvatarScene.rooftop: SceneDragHandle(
          id: 'aim',
          kind: DragKind.aim,
          rect: Rect.fromLTRB(710, 1011, 978, 1317),
          plane: 4,
          numbers: <DragNumber>[(name: 'aim', value: 0)],
        ),
        AvatarScene.mountainHut: SceneDragHandle(
          id: 'rope',
          kind: DragKind.pull,
          rect: Rect.fromLTRB(172, 470, 252, 980),
          plane: 3,
          numbers: <DragNumber>[(name: 'rope', value: 0)],
        ),
      };

  /// [scene]'s handle (null for a scene without one).
  static SceneDragHandle? of(AvatarScene scene) => handles[scene];

  /// Whether the artboard point [point] lands on [handle] while the scene's
  /// parallax is [parallax] (the handle rides its plane's offset).
  static bool hits(SceneDragHandle handle, Offset point, Offset parallax) =>
      handle.rect.contains(point - planeOffset(handle.plane, parallax));
}
