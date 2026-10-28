import '../../../../core/models/performance/performance.dart';
import '../../domain/models/face_frame.dart';
import 'avatar_rive_contract.dart';

/// Where [AvatarFaceWriter] writes: the avatar's view-model binding.
abstract interface class AvatarVmSink {
  void setNumber(String name, double value);
  void setBool(String name, bool value);
  void fireTrigger(String name);
}

/// Writes [FaceFrame]s to `AvatarVM` (contract v5): the 14 `au*` numbers,
/// `lipTuck`, `tongueUp`, `roll` and `breath` when they move by more than
/// [epsilon], `autoBlink` when it flips, and the `blink` trigger once per new
/// blink serial (never for the serial seen on the first write).
class AvatarFaceWriter {
  AvatarFaceWriter(this._sink);

  final AvatarVmSink _sink;

  /// Smallest change worth writing.
  static const double epsilon = 0.001;

  final Map<String, double> _written = <String, double>{};
  bool? _autoBlink;
  int? _blinkSerial;

  /// Forgets what was written (a fresh binding has none of it).
  void reset() {
    _written.clear();
    _autoBlink = null;
    _blinkSerial = null;
  }

  /// Writes [face]; [force] writes every number and flag.
  void write(FaceFrame face, {bool force = false}) {
    final ActionUnits a = face.au;
    _number(AvatarRiveContract.propAuBrowInnerUp, a.browInnerUp, force);
    _number(AvatarRiveContract.propAuBrowOuterUp, a.browOuterUp, force);
    _number(AvatarRiveContract.propAuBrowLower, a.browLower, force);
    _number(AvatarRiveContract.propAuLidTighten, a.lidTighten, force);
    _number(AvatarRiveContract.propAuUpperLidRaise, a.upperLidRaise, force);
    _number(AvatarRiveContract.propAuCheekRaise, a.cheekRaise, force);
    _number(AvatarRiveContract.propAuNoseWrinkle, a.noseWrinkle, force);
    _number(AvatarRiveContract.propAuLipCornerPull, a.lipCornerPull, force);
    _number(
      AvatarRiveContract.propAuLipCornerDepress,
      a.lipCornerDepress,
      force,
    );
    _number(AvatarRiveContract.propAuLipStretch, a.lipStretch, force);
    _number(AvatarRiveContract.propAuLipPucker, a.lipPucker, force);
    _number(AvatarRiveContract.propAuLipPress, a.lipPress, force);
    _number(AvatarRiveContract.propAuJawDrop, a.jawDrop, force);
    _number(AvatarRiveContract.propAuDimpler, a.dimpler, force);
    _number(AvatarRiveContract.propLipTuck, face.lipTuck, force);
    _number(AvatarRiveContract.propTongueUp, face.tongueUp, force);
    _number(AvatarRiveContract.propRoll, face.roll, force);
    _number(AvatarRiveContract.propBreath, face.breath, force);
    if (force || _autoBlink != face.autoBlink) {
      _sink.setBool(AvatarRiveContract.propAutoBlink, face.autoBlink);
      _autoBlink = face.autoBlink;
    }
    final int? last = _blinkSerial;
    if (last != null && face.blinkSerial != last) {
      _sink.fireTrigger(AvatarRiveContract.propBlinkTrigger);
    }
    _blinkSerial = face.blinkSerial;
  }

  void _number(String name, double value, bool force) {
    final double? last = _written[name];
    if (!force && last != null && (value - last).abs() <= epsilon) {
      return;
    }
    _sink.setNumber(name, value);
    _written[name] = value;
  }
}
