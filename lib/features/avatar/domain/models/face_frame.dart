import '../../../../core/models/performance/performance.dart';

/// Everything the face rig of `rive/CONTRACT.md` v5 needs for one frame:
/// the 14 action units (emotion and speech merged), the speech mouth extras,
/// head roll, breath, an additive nod on the head pitch, and blink control.
class FaceFrame {
  const FaceFrame({
    this.au = ActionUnits.neutral,
    this.lipTuck = 0,
    this.tongueUp = 0,
    this.breath = 0,
    this.roll = 0,
    this.nodPitch = 0,
    this.autoBlink = true,
    this.blinkSerial = 0,
  });

  static const FaceFrame rest = FaceFrame();

  final ActionUnits au;

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
    'lipTuck': lipTuck,
    'tongueUp': tongueUp,
    'breath': breath,
    'roll': roll,
    'nodPitch': nodPitch,
    'autoBlink': autoBlink,
    'blinkSerial': blinkSerial,
  };

  @override
  bool operator ==(Object other) =>
      other is FaceFrame &&
      other.au == au &&
      other.lipTuck == lipTuck &&
      other.tongueUp == tongueUp &&
      other.breath == breath &&
      other.roll == roll &&
      other.nodPitch == nodPitch &&
      other.autoBlink == autoBlink &&
      other.blinkSerial == blinkSerial;

  @override
  int get hashCode => Object.hash(
    au,
    lipTuck,
    tongueUp,
    breath,
    roll,
    nodPitch,
    autoBlink,
    blinkSerial,
  );

  @override
  String toString() => 'FaceFrame(${toJson()})';
}
