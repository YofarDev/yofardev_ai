import '../avatar_gesture.dart';
import '../chat.dart';
import 'avatar_prop.dart';

/// Offsets a persona adds to the avatar's rest pose (moonshot M10 ruling 9),
/// in the contract's units: `lean` −0.15..0.2 (the contract's `lean` is
/// 0..1, so a lean back only shows against the listening lean), `pitch`
/// −0.25..0.1 (+ = chin up) and `roll` −0.1..0.1 (+ = toward the viewer's
/// right shoulder).
class BodyPosture {
  const BodyPosture({this.lean = 0, this.pitch = 0, this.roll = 0});

  /// The rest pose: no offset.
  static const BodyPosture zero = BodyPosture();

  final double lean;
  final double pitch;
  final double roll;

  @override
  bool operator ==(Object other) =>
      other is BodyPosture &&
      other.lean == lean &&
      other.pitch == pitch &&
      other.roll == roll;

  @override
  int get hashCode => Object.hash(lean, pitch, roll);

  @override
  String toString() => 'BodyPosture(lean: $lean, pitch: $pitch, roll: $roll)';
}

/// How a persona idles: the idle ladder's thresholds × [ladderScale] (0.7
/// fidgety .. 1.4 calm), the stage-1 glance period × [glancePeriodScale],
/// and the [prop] the ladder brings out at stages 2 and 3.
class IdleStyle {
  const IdleStyle({
    this.ladderScale = 1,
    this.glancePeriodScale = 1,
    this.prop = AvatarProp.tablet,
  });

  /// Today's idle: the 30 s / 2 min / 10 min ladder, 6–10 s glances, the
  /// tablet.
  static const IdleStyle calmDefault = IdleStyle();

  final double ladderScale;
  final double glancePeriodScale;
  final AvatarProp prop;

  @override
  bool operator ==(Object other) =>
      other is IdleStyle &&
      other.ladderScale == ladderScale &&
      other.glancePeriodScale == glancePeriodScale &&
      other.prop == prop;

  @override
  int get hashCode => Object.hash(ladderScale, glancePeriodScale, prop);

  @override
  String toString() =>
      'IdleStyle(ladderScale: $ladderScale, '
      'glancePeriodScale: $glancePeriodScale, prop: $prop)';
}

/// One entry of a persona's gesture bias: an auto gesture [from] (null: the
/// beat, an emphatic sentence the rules leave bare) becomes one of [to],
/// picked by the sentence's index (`to[index % to.length]`, no RNG).
class GestureSwap {
  const GestureSwap({this.from, required this.to});

  final AvatarGesture? from;
  final List<AvatarGesture> to;

  @override
  bool operator ==(Object other) {
    if (other is! GestureSwap ||
        other.from != from ||
        other.to.length != to.length) {
      return false;
    }
    for (int i = 0; i < to.length; i++) {
      if (other.to[i] != to[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(from, Object.hashAll(to));

  @override
  String toString() => 'GestureSwap(from: $from, to: $to)';
}

/// A persona's body language (moonshot M10 ruling 9): pure const data the
/// performance layer applies through the director, the face performer and
/// the idle ladder. [normal] is the identity: today's behaviour exactly.
///
/// - [gestureRate] (0.5–1.6): auto gestures fire with weight
///   `min(rate, 1)` (a running credit, deterministic) and the director's
///   cooldown is `gestureCooldown / rate`;
/// - [gestureBias]: ordered swaps of auto gestures (never the LLM's);
/// - [posture]: rest-pose offsets, eased in over 600 ms;
/// - [motionScale] (0.6–1.4): the amplitude of the prosody nods, tilts and
///   brow beats and the intensity of the face's accents (clamped as before);
/// - [idle]: the idle ladder's pace, the glances' period and the idle prop.
///
/// Keyed gesture clips keep their amplitude (ruling 9): it lives in the
/// procedural channels and in the choice of gesture.
class BodyLanguageProfile {
  const BodyLanguageProfile({
    this.gestureRate = 1,
    this.gestureBias = const <GestureSwap>[],
    this.posture = BodyPosture.zero,
    this.motionScale = 1,
    this.idle = IdleStyle.calmDefault,
  });

  /// The identity profile.
  static const BodyLanguageProfile normal = BodyLanguageProfile();

  final double gestureRate;
  final List<GestureSwap> gestureBias;
  final BodyPosture posture;
  final double motionScale;
  final IdleStyle idle;

  /// The profile of [persona] (the table below).
  static BodyLanguageProfile of(ChatPersona persona) =>
      _profiles[persona] ?? normal;

  /// True when this profile changes nothing.
  bool get isIdentity => this == normal;

  /// The auto gesture [gesture] becomes for the sentence at [index]: the
  /// first swap from it, else itself.
  AvatarGesture swapFor(AvatarGesture gesture, int index) {
    for (final GestureSwap swap in gestureBias) {
      if (swap.from == gesture) {
        return swap.to[index % swap.to.length];
      }
    }
    return gesture;
  }

  /// The beat gesture for the emphatic sentence at [index], or null when
  /// this persona has none (normal: none).
  AvatarGesture? beatFor(int index) {
    for (final GestureSwap swap in gestureBias) {
      if (swap.from == null) {
        return swap.to[index % swap.to.length];
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    if (other is! BodyLanguageProfile ||
        other.gestureRate != gestureRate ||
        other.posture != posture ||
        other.motionScale != motionScale ||
        other.idle != idle ||
        other.gestureBias.length != gestureBias.length) {
      return false;
    }
    for (int i = 0; i < gestureBias.length; i++) {
      if (other.gestureBias[i] != gestureBias[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    gestureRate,
    Object.hashAll(gestureBias),
    posture,
    motionScale,
    idle,
  );

  @override
  String toString() =>
      'BodyLanguageProfile(gestureRate: $gestureRate, gestureBias: '
      '$gestureBias, posture: $posture, motionScale: $motionScale, '
      'idle: $idle)';
}

/// One profile per persona. Ranges (ruling 9): rate 0.5–1.6, lean
/// −0.15–0.2, pitch −0.25–0.1, roll −0.1–0.1, motion 0.6–1.4, ladder and
/// glance scales 0.7–1.4.
const Map<ChatPersona, BodyLanguageProfile> _profiles =
    <ChatPersona, BodyLanguageProfile>{
      // Why: the composed helper — a touch forward and a little more measured
      // than normal; no gesture swaps.
      ChatPersona.assistant: BodyLanguageProfile(
        gestureRate: 0.9,
        posture: BodyPosture(lean: 0.05),
        motionScale: 0.9,
      ),
      // Why: today's avatar, unchanged (the identity).
      ChatPersona.normal: BodyLanguageProfile.normal,
      // Why: the slump — head down, leaning back, little energy; agreement
      // and emphasis both come out as a resigned shrug; drifts off sooner and
      // glances slowly.
      ChatPersona.doomer: BodyLanguageProfile(
        gestureRate: 0.6,
        gestureBias: <GestureSwap>[
          GestureSwap(to: <AvatarGesture>[AvatarGesture.shrug]),
          GestureSwap(
            from: AvatarGesture.nod,
            to: <AvatarGesture>[AvatarGesture.shrug],
          ),
        ],
        posture: BodyPosture(lean: -0.12, pitch: -0.2, roll: -0.05),
        motionScale: 0.7,
        idle: IdleStyle(ladderScale: 0.8, glancePeriodScale: 1.4),
      ),
      // Why: upright and restrained, chin a little up; emphasis is a firm nod;
      // a calm idle behind the newspaper.
      ChatPersona.conservative: BodyLanguageProfile(
        gestureRate: 0.7,
        gestureBias: <GestureSwap>[
          GestureSwap(to: <AvatarGesture>[AvatarGesture.nod]),
        ],
        posture: BodyPosture(pitch: 0.05),
        motionScale: 0.8,
        idle: IdleStyle(
          ladderScale: 1.2,
          glancePeriodScale: 1.2,
          prop: AvatarProp.newspaper,
        ),
      ),
      // Why: the ponderer — head a little down and tilted, emphasis and
      // agreement turn into a think; the calmest idle, with the newspaper.
      ChatPersona.philosopher: BodyLanguageProfile(
        gestureRate: 0.8,
        gestureBias: <GestureSwap>[
          GestureSwap(to: <AvatarGesture>[AvatarGesture.think]),
          GestureSwap(
            from: AvatarGesture.nod,
            to: <AvatarGesture>[AvatarGesture.think],
          ),
        ],
        posture: BodyPosture(lean: 0.05, pitch: -0.08, roll: 0.06),
        motionScale: 0.85,
        idle: IdleStyle(
          ladderScale: 1.4,
          glancePeriodScale: 1.3,
          prop: AvatarProp.newspaper,
        ),
      ),
      // Why: the eager enthusiast — leans in, counts things off and thumbs
      // up on emphasis, livelier head, fidgets at idle.
      ChatPersona.geek: BodyLanguageProfile(
        gestureRate: 1.3,
        gestureBias: <GestureSwap>[
          GestureSwap(
            to: <AvatarGesture>[AvatarGesture.count, AvatarGesture.thumbsUp],
          ),
        ],
        posture: BodyPosture(lean: 0.12, roll: -0.04),
        motionScale: 1.2,
        idle: IdleStyle(ladderScale: 0.75, glancePeriodScale: 0.8),
      ),
      // Why: the most energetic — leans in with the chin up, thumbs up and
      // claps on emphasis, a yes is a thumbs up, the biggest motion, restless
      // at idle.
      ChatPersona.coach: BodyLanguageProfile(
        gestureRate: 1.6,
        gestureBias: <GestureSwap>[
          GestureSwap(
            to: <AvatarGesture>[AvatarGesture.thumbsUp, AvatarGesture.clap],
          ),
          GestureSwap(
            from: AvatarGesture.nod,
            to: <AvatarGesture>[AvatarGesture.thumbsUp],
          ),
        ],
        posture: BodyPosture(lean: 0.2, pitch: 0.08),
        motionScale: 1.4,
        idle: IdleStyle(ladderScale: 0.7, glancePeriodScale: 0.7),
      ),
      // Why: the attentive listener — leans in with an empathic tilt, meets
      // emphasis with an encouraging nod, calm and soft in motion.
      ChatPersona.psychologist: BodyLanguageProfile(
        gestureRate: 0.8,
        gestureBias: <GestureSwap>[
          GestureSwap(to: <AvatarGesture>[AvatarGesture.nod]),
        ],
        posture: BodyPosture(lean: 0.15, pitch: -0.03, roll: 0.08),
        motionScale: 0.75,
        idle: IdleStyle(ladderScale: 1.3, glancePeriodScale: 1.2),
      ),
    };
