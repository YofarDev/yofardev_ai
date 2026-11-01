import '../../../../core/models/performance/performance.dart';
import '../../domain/models/face_frame.dart';
import 'avatar_rive_contract.dart';

/// Where [AvatarFaceWriter] writes: the avatar's view-model binding.
abstract interface class AvatarVmSink {
  void setNumber(String name, double value);
  void setBool(String name, bool value);

  /// Sets a view-model colour from an ARGB int.
  void setColor(String name, int argb);
  void fireTrigger(String name);
}

/// Writes [FaceFrame]s to `AvatarVM` (contract v7): the 14 `au*` numbers,
/// the 14 per-side `au<Name>L` / `au<Name>R` offsets ([FaceFrame.left] and
/// [FaceFrame.right]), `lipTuck`, `tongueUp`, `roll`, `breath` and `lean` when they
/// move by more than [epsilon], `autoBlink` when it flips, and the `blink`
/// trigger when the blink serial goes up: at most one blink per write, however
/// far it went up, none when it goes down (a source that counts from 0 again)
/// and none for the serial seen on the first write.
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

  /// Takes [serial] as the last blink serial seen, without firing: the next
  /// write fires `blink` only if its serial is above [serial]. Used when
  /// the frames switch source (a lab override and the live performer count
  /// blinks independently).
  void adoptBlinkSerial(int serial) => _blinkSerial = serial;

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
    _sides(AvatarRiveContract.actionUnitLeftProps, face.left, force);
    _sides(AvatarRiveContract.actionUnitRightProps, face.right, force);
    _number(AvatarRiveContract.propLipTuck, face.lipTuck, force);
    _number(AvatarRiveContract.propTongueUp, face.tongueUp, force);
    _number(AvatarRiveContract.propRoll, face.roll, force);
    _number(AvatarRiveContract.propBreath, face.breath, force);
    _number(AvatarRiveContract.propLean, face.lean, force);
    if (force || _autoBlink != face.autoBlink) {
      _sink.setBool(AvatarRiveContract.propAutoBlink, face.autoBlink);
      _autoBlink = face.autoBlink;
    }
    final int? last = _blinkSerial;
    if (last != null && face.blinkSerial > last) {
      _sink.fireTrigger(AvatarRiveContract.propBlinkTrigger);
    }
    _blinkSerial = face.blinkSerial;
  }

  /// Writes one side's offsets to [names] (`ActionUnitSides` field order).
  void _sides(List<String> names, ActionUnitSides s, bool force) {
    _number(names[0], s.browInnerUp, force);
    _number(names[1], s.browOuterUp, force);
    _number(names[2], s.browLower, force);
    _number(names[3], s.lidTighten, force);
    _number(names[4], s.cheekRaise, force);
    _number(names[5], s.lipCornerPull, force);
    _number(names[6], s.lipCornerDepress, force);
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
