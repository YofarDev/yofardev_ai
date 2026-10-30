import '../../../../core/models/avatar_scene.dart';

/// The threshold a scene journey walks through (moonshot M7 ruling 5).
enum JourneyFamily { door, path, portal, rocket }

/// The beats of a scene journey, in order (M7 ruling 9).
enum JourneyPhase {
  /// The camera pulls back to wide.
  pullBack,

  /// The threshold appears and opens; the avatar's gaze leads toward it.
  open,

  /// The avatar walks out through it (until `presence_done(outOfScreen)`).
  exit,

  /// The threshold closes (the rocket then lifts off).
  close,

  /// The scene switches behind the closed threshold (the preloaded file).
  cut,

  /// The same threshold opens in the new scene (the rocket lands first).
  arriveOpen,

  /// The avatar walks in out of it (until `presence_done(onScreen)`).
  enter,

  /// The threshold closes behind the avatar.
  arriveClose,

  /// The threshold vanishes.
  vanish,
}

/// A scene journey under way: from where to where, through which threshold,
/// and the current beat. [serial] increments on every phase change, so a view
/// restarts its beat clock even if a phase repeats.
class JourneyState {
  const JourneyState({
    required this.from,
    required this.to,
    required this.family,
    required this.phase,
    required this.serial,
  });

  final AvatarScene from;
  final AvatarScene to;
  final JourneyFamily family;
  final JourneyPhase phase;
  final int serial;

  /// The scene the avatar is in during [phase]: [from] until the cut, [to]
  /// from the cut on.
  AvatarScene get sceneNow => phase.index >= JourneyPhase.cut.index ? to : from;

  JourneyState next(JourneyPhase phase) => JourneyState(
    from: from,
    to: to,
    family: family,
    phase: phase,
    serial: serial + 1,
  );

  @override
  bool operator ==(Object other) =>
      other is JourneyState &&
      other.from == from &&
      other.to == to &&
      other.family == family &&
      other.phase == phase &&
      other.serial == serial;

  @override
  int get hashCode => Object.hash(from, to, family, phase, serial);

  @override
  String toString() =>
      'JourneyState(${from.name} → ${to.name}, ${family.name}, ${phase.name}, #$serial)';
}

/// How long the timed beats last (M7 ruling 9). The walks and the cut wait
/// for the Rive file and the scene view, each bounded by [waitTimeout].
abstract final class JourneyTiming {
  static const Duration pullBack = Duration(milliseconds: 600);
  static const Duration appear = Duration(milliseconds: 300);
  static const Duration open = Duration(milliseconds: 450);
  static const Duration close = Duration(milliseconds: 350);

  /// The rocket's lift-off after its hatch closes, and its landing.
  static const Duration lift = Duration(milliseconds: 700);
  static const Duration arriveHold = Duration(milliseconds: 150);
  static const Duration arriveOpen = Duration(milliseconds: 350);
  static const Duration vanish = Duration(milliseconds: 300);

  /// Longest wait for a walk's `presence_done` or for the new scene on screen.
  static const Duration waitTimeout = Duration(seconds: 3);

  /// The `close` beat of [family] (the rocket also lifts off in it).
  static Duration closeOf(JourneyFamily family) =>
      family == JourneyFamily.rocket ? close + lift : close;

  /// The `arriveOpen` beat of [family] (the rocket lands first).
  static Duration arriveOpenOf(JourneyFamily family) =>
      family == JourneyFamily.rocket
      ? lift + arriveOpen
      : arriveHold + arriveOpen;
}
