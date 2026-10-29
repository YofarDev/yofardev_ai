import '../../../../core/models/performance/performance.dart';

/// Everything the face rig of `rive/CONTRACT.md` v6 (plus the listening
/// [lean] the v7 rig takes) needs for one frame:
/// the 14 action units (emotion and speech merged), their per-side offsets
/// ([left] and [right], the viewer's), the speech mouth extras, head roll,
/// breath, an additive nod on the head pitch, blink control, and the gaze
/// cues the head solver acts on ([gazeLock], [saccadeSerial]).
class FaceFrame {
  const FaceFrame({
    this.au = ActionUnits.neutral,
    this.left = ActionUnitSides.zero,
    this.right = ActionUnitSides.zero,
    this.lipTuck = 0,
    this.tongueUp = 0,
    this.breath = 0,
    this.roll = 0,
    this.nodPitch = 0,
    this.autoBlink = true,
    this.blinkSerial = 0,
    this.gazeLock = false,
    this.saccadeSerial = 0,
    this.lean = 0,
  });

  static const FaceFrame rest = FaceFrame();

  final ActionUnits au;

  /// −1..1 offsets added to [au] on the viewer's left side (`au<Name>L`).
  final ActionUnitSides left;

  /// −1..1 offsets added to [au] on the viewer's right side (`au<Name>R`).
  final ActionUnitSides right;

  /// 0..1: the lower lip tucks under the upper teeth (f, v).
  final double lipTuck;

  /// 0..1: the tongue tip rises to the upper teeth (th, l, d, n).
  final double tongueUp;

  /// 0..1: inhale before a sentence.
  final double breath;

  /// −1..1: head tilt (+ toward the viewer's right shoulder).
  final double roll;

  /// Added to the head `pitch` (−1..1 units; negative nods down).
  final double nodPitch;

  /// False while the performer places blinks itself (speech).
  final bool autoBlink;

  /// Increments once per blink the performer asks for.
  final int blinkSerial;

  /// The eyes stay on the camera (no micro-saccade): a question's end.
  final bool gazeLock;

  /// Increments once per gaze saccade the performer asks for (after a full
  /// stop).
  final int saccadeSerial;

  /// 0..1: the torso and head tip toward the viewer while the user types
  /// (0 at rest).
  final double lean;

  Map<String, Object> toJson() => <String, Object>{
    'au': <String, double>{
      'browInnerUp': au.browInnerUp,
      'browOuterUp': au.browOuterUp,
      'browLower': au.browLower,
      'lidTighten': au.lidTighten,
      'upperLidRaise': au.upperLidRaise,
      'cheekRaise': au.cheekRaise,
      'noseWrinkle': au.noseWrinkle,
      'lipCornerPull': au.lipCornerPull,
      'lipCornerDepress': au.lipCornerDepress,
      'lipStretch': au.lipStretch,
      'lipPucker': au.lipPucker,
      'lipPress': au.lipPress,
      'jawDrop': au.jawDrop,
      'dimpler': au.dimpler,
    },
    'left': _sidesJson(left),
    'right': _sidesJson(right),
    'lipTuck': lipTuck,
    'tongueUp': tongueUp,
    'breath': breath,
    'roll': roll,
    'nodPitch': nodPitch,
    'autoBlink': autoBlink,
    'blinkSerial': blinkSerial,
    'gazeLock': gazeLock,
    'saccadeSerial': saccadeSerial,
    'lean': lean,
  };

  @override
  bool operator ==(Object other) =>
      other is FaceFrame &&
      other.au == au &&
      other.left == left &&
      other.right == right &&
      other.lipTuck == lipTuck &&
      other.tongueUp == tongueUp &&
      other.breath == breath &&
      other.roll == roll &&
      other.nodPitch == nodPitch &&
      other.autoBlink == autoBlink &&
      other.blinkSerial == blinkSerial &&
      other.gazeLock == gazeLock &&
      other.saccadeSerial == saccadeSerial &&
      other.lean == lean;

  @override
  int get hashCode => Object.hash(
    au,
    left,
    right,
    lipTuck,
    tongueUp,
    breath,
    roll,
    nodPitch,
    autoBlink,
    blinkSerial,
    gazeLock,
    saccadeSerial,
    lean,
  );

  @override
  String toString() => 'FaceFrame(${toJson()})';
}

Map<String, double> _sidesJson(ActionUnitSides s) => <String, double>{
  'browInnerUp': s.browInnerUp,
  'browOuterUp': s.browOuterUp,
  'browLower': s.browLower,
  'lidTighten': s.lidTighten,
  'cheekRaise': s.cheekRaise,
  'lipCornerPull': s.lipCornerPull,
  'lipCornerDepress': s.lipCornerDepress,
};
