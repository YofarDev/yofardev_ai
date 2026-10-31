import '../../../../core/models/avatar_scene.dart';

/// The threshold a scene journey walks through (moonshot M7 ruling 5).
enum JourneyFamily { door, path, portal, rocket }

/// The beats of a scene journey, in order (M7 ruling 9, M8 ruling 6).
enum JourneyPhase {
  /// The camera pulls back to wide.
  pullBack,

  /// The threshold appears and opens; the avatar's gaze leads toward it.
  open,

  /// Door only (M8): the avatar reaches for the jacket on the door's peg and
  /// takes it at [JourneyTiming.grabContact].
  grab,

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

  /// Door only (M8): the avatar hangs the jacket on the new door's peg at
  /// [JourneyTiming.grabContact].
  hang,

  /// The threshold closes behind the avatar.
  arriveClose,

  /// The threshold vanishes.
  vanish,
}

/// A scene journey under way: from where to where, through which threshold,
/// and the current beat. [serial] increments on every phase change, so a view
/// restarts its beat clock even if a phase repeats.
///
/// A [reduced] journey (reduce motion, M11 ruling 18) is a cross-fade cut: no
/// threshold, no walk, no jacket beats. It runs only [JourneyPhase.close]
/// (the stage fades out over [JourneyTiming.reducedFade]), [JourneyPhase.cut]
/// (the scene changes behind the fade) and [JourneyPhase.vanish] (it fades
/// back in); see [fadedOut].
class JourneyState {
  const JourneyState({
    required this.from,
    required this.to,
    required this.family,
    required this.phase,
    required this.serial,
    this.reduced = false,
  });

  final AvatarScene from;
  final AvatarScene to;
  final JourneyFamily family;
  final JourneyPhase phase;
  final int serial;

  /// A cross-fade cut instead of a walk (reduce motion).
  final bool reduced;

  /// Whether a [reduced] journey has the stage faded out now (its `close`
  /// and `cut` beats).
  bool get fadedOut =>
      reduced && (phase == JourneyPhase.close || phase == JourneyPhase.cut);

  /// Whether this journey runs the jacket beats ([JourneyPhase.grab] and
  /// [JourneyPhase.hang]): the door has a peg, the other thresholds do not.
  bool get hasJacket => !reduced && family == JourneyFamily.door;

  /// The scene the avatar is in during [phase]: [from] until the cut, [to]
  /// from the cut on.
  AvatarScene get sceneNow => phase.index >= JourneyPhase.cut.index ? to : from;

  JourneyState next(JourneyPhase phase) => JourneyState(
    from: from,
    to: to,
    family: family,
    phase: phase,
    serial: serial + 1,
    reduced: reduced,
  );

  @override
  bool operator ==(Object other) =>
      other is JourneyState &&
      other.from == from &&
      other.to == to &&
      other.family == family &&
      other.phase == phase &&
      other.serial == serial &&
      other.reduced == reduced;

  @override
  int get hashCode => Object.hash(from, to, family, phase, serial, reduced);

  @override
  String toString() =>
      'JourneyState(${from.name} → ${to.name}, ${family.name}, ${phase.name}, '
      '#$serial${reduced ? ', reduced' : ''})';
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

  /// The door's jacket beats (M8 ruling 6): the `grab` gesture's length, and
  /// its contact, when the jacket changes hands.
  static const Duration grab = Duration(milliseconds: 900);
  static const Duration hang = Duration(milliseconds: 900);
  static const Duration grabContact = Duration(milliseconds: 380);

  /// Reduce motion (M11 ruling 18): each half of the cross-fade cut, the
  /// stage fading out before the cut and back in after it.
  static const Duration reducedFade = Duration(milliseconds: 200);

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
