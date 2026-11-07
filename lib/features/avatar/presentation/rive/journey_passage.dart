import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import '../../domain/models/journey.dart';

/// The avatar's own presence walk (`presence_walkOut` / `presence_walkIn` in
/// `avatar.riv`, `gen_avatar.walk_tracks`): the `Root` node's x over the
/// walk, mirrored so the journey can stage the avatar into its threshold
/// without reading the Rive file. Ten frames of weight shift (a 7 px lean
/// back), then a smoothstep travel to frame 80; the clip lasts 96 frames at
/// 60 fps.
abstract final class PresenceWalk {
  static const double onX = 400;
  static const double offX = 1250;

  /// The feet's y (the artboard's bottom edge).
  static const double ground = 1000;
  static const double _fps = 60;
  static const double _weightFrames = 10;
  static const double _travelEnd = 80;
  static const double _weightShift = 7;

  /// The whole walk clip (96 frames).
  static const Duration length = Duration(milliseconds: 1600);

  /// `Root` x (artboard px) [elapsed] into the walk out ([out]) or in.
  static double rootX(Duration elapsed, {required bool out}) {
    final double from = out ? onX : offX;
    final double to = out ? offX : onX;
    final double f = elapsed.inMicroseconds * _fps / 1e6;
    if (f <= 0) {
      return from;
    }
    if (f < _weightFrames) {
      final double direction = to > from ? 1 : -1;
      return from -
          direction * _weightShift * math.sin(math.pi * f / _weightFrames);
    }
    if (f >= _travelEnd) {
      return to;
    }
    final double t = (f - _weightFrames) / (_travelEnd - _weightFrames);
    return from + (to - from) * _smooth(t);
  }
}

/// How the avatar's colours turn as it goes in.
enum PassageTint {
  /// Untouched.
  none,

  /// Towards the far scene's key light: the avatar turns to light (portal).
  glow,

  /// Towards the scene's ambient, darkened: backlit by the tunnel's far end
  /// (path).
  silhouette,
}

/// Where the avatar is drawn while it goes into (or comes out of) a journey's
/// threshold, in the avatar's artboard space (the journey's, 800 × 1000):
/// every point p of the avatar is drawn at
/// `pivot + offset + R(rotation) · (scaleX, scaleY) · (p − pivot)`, at
/// [opacity], tinted [tintAmount] towards [tint]'s colour, and clipped to the
/// left of [planeX] plus [window] when [planeX] is set.
class AvatarPassage {
  const AvatarPassage({
    this.pivot = Offset.zero,
    this.offset = Offset.zero,
    this.scaleX = 1,
    this.scaleY = 1,
    this.rotation = 0,
    this.opacity = 1,
    this.tint = PassageTint.none,
    this.tintAmount = 0,
    this.planeX,
    this.window,
    this.windowRadius = 0,
  });

  final Offset pivot;
  final Offset offset;
  final double scaleX;
  final double scaleY;

  /// Radians, clockwise on screen (y down), like Rive's.
  final double rotation;
  final double opacity;
  final PassageTint tint;
  final double tintAmount;

  /// The avatar shows only left of this artboard x (and inside [window]).
  final double? planeX;

  /// An opening the avatar shows through right of [planeX] (artboard).
  final Rect? window;
  final double windowRadius;

  static const AvatarPassage none = AvatarPassage();

  /// Whether the avatar is moved, scaled or turned.
  bool get transforms =>
      offset != Offset.zero || scaleX != 1 || scaleY != 1 || rotation != 0;

  bool get clips => planeX != null;

  bool get tints => tint != PassageTint.none && tintAmount > 0;

  /// Nothing to do: the avatar is drawn as it is.
  bool get isNone => !transforms && !clips && !tints && opacity >= 1;

  /// Where artboard point [p] is drawn.
  Offset map(Offset p) {
    final Offset d = p - pivot;
    final double x = d.dx * scaleX;
    final double y = d.dy * scaleY;
    final double c = math.cos(rotation);
    final double s = math.sin(rotation);
    return pivot + offset + Offset(c * x - s * y, s * x + c * y);
  }

  @override
  bool operator ==(Object other) =>
      other is AvatarPassage &&
      other.pivot == pivot &&
      other.offset == offset &&
      other.scaleX == scaleX &&
      other.scaleY == scaleY &&
      other.rotation == rotation &&
      other.opacity == opacity &&
      other.tint == tint &&
      other.tintAmount == tintAmount &&
      other.planeX == planeX &&
      other.window == window &&
      other.windowRadius == windowRadius;

  @override
  int get hashCode => Object.hash(
    pivot,
    offset,
    scaleX,
    scaleY,
    rotation,
    opacity,
    tint,
    tintAmount,
    planeX,
    window,
    windowRadius,
  );

  @override
  String toString() =>
      'AvatarPassage(pivot $pivot, offset $offset, scale ($scaleX, $scaleY), '
      'rotation $rotation, opacity $opacity, ${tint.name} $tintAmount, '
      'plane $planeX, window $window)';
}

/// The avatar goes INTO each threshold (v17 staging): a pure function of the
/// family, the passage's progress `u` (0: on stage, 1: inside) and the
/// avatar's walk position x (`Root` x, [PresenceWalk]). The progress runs on
/// the beat's own clock over most of the walk ([exitWindow] /
/// [enterWindow]), not on the walk's position: the walk crosses the
/// threshold in a few hundred ms, the passage takes about a second. The
/// avatar keeps its own walk until it reaches the threshold's point (its
/// position is `min(x, point)`), then the passage carries it, scaled about
/// its own feet (or body) so its legs keep stepping. The walk in replays the
/// passage backwards, so the avatar comes out the way it went in. The
/// geometry mirrors `gen_journeys.py` (a Python test keeps them equal).
///
/// - **portal**: the rift draws the avatar off its feet to [portalPull]
///   inside the ring, spiralling with the vortex (anticlockwise), stretching,
///   shrinking to a point and turning to the far scene's light.
/// - **path**: the avatar walks down the tunnel to its far end
///   ([pathFar]), shrinking with the depth and darkening into a silhouette
///   against the light there, until the dark takes it.
/// - **rocket**: the avatar shrinks as it walks up, hops onto the hatch's
///   sill ([rocketSill]) and walks on into the lit cabin, clipped by the
///   hatch's opening, fading into its depth.
/// - **book**: the avatar folds flat into the gutter like a paper figure,
///   clipped right of the spine (the book draws over it).
abstract final class JourneyPassage {
  /// `gen_journeys` PORTAL_X / PORTAL_Y: the rift's core.
  static const Offset portalCore = Offset(795, 520);

  /// Where the rift draws the avatar's body to: inside the mouth, left of
  /// and above the core, so a portrait phone (artboard x 640–800) and the
  /// wide shot (which crops the floor) both see it go.
  static const Offset portalPull = Offset(742, 420);

  /// The anticlockwise turn at the core (the vortex's sense).
  static const double portalTurn = -1.6 * math.pi;

  /// The tunnel's far end on the ground (`gen_journeys` PATH_X − 10, the
  /// trail's far edge GROUND_Y − 120 + 2).
  static const Offset pathFar = Offset(850, 882);
  static const double pathFarScale = 0.26;
  static const double pathSilhouette = 0.85;

  /// `gen_journeys` RocketHatchHole in artboard space (ROCKET_X 834, its
  /// rounded corners 30).
  static const Rect rocketHatch = Rect.fromLTRB(644, 666.5, 794, 827.5);
  static const double rocketHatchRadius = 30;
  static const double rocketScale = 0.16;
  static const double rocketHop = 140;

  /// Where the avatar's feet land on the sill, and how far on it walks into
  /// the cabin (past the opening's far edge, where the hull hides it).
  static const Offset rocketSill = Offset(690, 827.5);
  static const double rocketCabinWalk = 100;

  /// `gen_journeys` THRESHOLD_X: the book's spine.
  static const double bookSpine = 640;

  /// The body's centre above the feet (the avatar's artboard).
  static const double bodyHeight = 440;

  /// The passage's span in the walk out, ms into the beat: it starts as the
  /// weight shift ends and lands before the walk's 1600 ms clip does.
  static (int, int) exitWindow(JourneyFamily family) => switch (family) {
    JourneyFamily.portal => (300, 1500),
    JourneyFamily.path => (300, 1550),
    JourneyFamily.rocket => (250, 1450),
    JourneyFamily.book => (250, 1000),
  };

  /// The passage's span (backwards) in the walk in.
  static (int, int) enterWindow(JourneyFamily family) => switch (family) {
    JourneyFamily.portal => (100, 1300),
    JourneyFamily.path => (80, 1300),
    JourneyFamily.rocket => (100, 1300),
    JourneyFamily.book => (400, 1300),
  };

  /// The progress [elapsed] into the walk out ([out]) or in.
  static double progress(
    JourneyFamily family,
    Duration elapsed, {
    required bool out,
  }) {
    final double ms = elapsed.inMicroseconds / 1000;
    final (int a, int b) = out ? exitWindow(family) : enterWindow(family);
    final double t = _window(ms, a.toDouble(), b.toDouble());
    return out ? t : 1 - t;
  }

  /// The avatar's passage at progress [u] with its `Root` at [x] (the ground
  /// is y 1000).
  static AvatarPassage of(JourneyFamily family, double u, double x) {
    if (u <= 0 && family != JourneyFamily.book) {
      return AvatarPassage.none;
    }
    return switch (family) {
      JourneyFamily.portal => _portal(u, x),
      JourneyFamily.path => _path(u, x),
      JourneyFamily.rocket => _rocket(u, x),
      JourneyFamily.book => _book(u),
    };
  }

  static AvatarPassage _portal(double u, double x) {
    final Offset body = Offset(x, PresenceWalk.ground - bodyHeight);
    final Offset from = Offset(math.min(x, portalPull.dx), body.dy);
    final Offset to = Offset.lerp(
      from,
      portalPull,
      _smooth(_window(u, 0, 0.55)),
    )!;
    // never quite 0: a singular transform could drop the (faded) avatar's
    // paint, and the Rive avatar advances only while painted
    final double s = math.max(0.001, 1 - math.pow(u, 1.6).toDouble());
    final double stretch = math.sin(math.pi * u);
    return AvatarPassage(
      pivot: body,
      offset: to - body,
      scaleX: s * (1 - 0.3 * stretch),
      scaleY: s * (1 + 0.2 * stretch),
      rotation: portalTurn * math.pow(u, 2.2).toDouble(),
      opacity: 1 - _smooth(_window(u, 0.82, 1)),
      tint: PassageTint.glow,
      tintAmount: 0.85 * _smooth(_window(u, 0.15, 0.85)),
    );
  }

  static AvatarPassage _path(double u, double x) {
    final double e = _smooth(u);
    final Offset feet = Offset(x, PresenceWalk.ground);
    final Offset to = Offset.lerp(
      Offset(math.min(x, pathFar.dx), PresenceWalk.ground),
      pathFar,
      e,
    )!;
    final double s = _lerp(1, pathFarScale, e);
    return AvatarPassage(
      pivot: feet,
      offset: to - feet,
      scaleX: s,
      scaleY: s,
      opacity: 1 - _smooth(_window(u, 0.8, 1)),
      tint: PassageTint.silhouette,
      tintAmount: pathSilhouette * _smooth(_window(u, 0.1, 0.7)),
    );
  }

  /// The rocket's landing on the sill: the hop's share of the progress.
  static const double _hopFrom = 0.45;
  static const double _landed = 0.8;

  static AvatarPassage _rocket(double u, double x) {
    final Offset feet = Offset(x, PresenceWalk.ground);
    final double s = _lerp(1, rocketScale, _smooth(_window(u, 0, 0.6)));
    final double hop = _window(u, _hopFrom, _landed);
    final double cabin = _smooth(_window(u, _landed, 1));
    final Offset to = Offset(
      _lerp(
            math.min(x, rocketSill.dx),
            rocketSill.dx,
            _smooth(_window(u, 0, 0.75)),
          ) +
          rocketCabinWalk * cabin,
      _lerp(PresenceWalk.ground, rocketSill.dy, _smooth(hop)) -
          rocketHop * math.sin(math.pi * hop),
    );
    final bool aboard = u >= _landed;
    return AvatarPassage(
      pivot: feet,
      offset: to - feet,
      scaleX: s,
      scaleY: s,
      opacity: 1 - _smooth(_window(u, 0.88, 1)),
      // once on the sill the hull hides all but the hatch's opening
      planeX: aboard ? rocketHatch.left : null,
      window: aboard ? rocketHatch : null,
      windowRadius: aboard ? rocketHatchRadius : 0,
    );
  }

  static AvatarPassage _book(double u) {
    final double e = _smooth(u);
    return AvatarPassage(
      pivot: const Offset(bookSpine, PresenceWalk.ground),
      scaleX: 1 - e,
      scaleY: 1 - 0.06 * e,
      opacity: e >= 0.98 ? 0 : 1,
      planeX: bookSpine,
    );
  }
}

double _window(double x, double a, double b) =>
    ((x - a) / (b - a)).clamp(0.0, 1.0);

double _smooth(double t) => t * t * (3 - 2 * t);

double _lerp(double a, double b, double t) => a + (b - a) * t;
