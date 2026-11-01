import '../../../../core/models/performance/light_rig.dart';
import 'avatar_face_writer.dart';
import 'avatar_rive_contract.dart';

/// Writes a scene's [LightRig] to `AvatarVM` (contract v7): `lightKey`,
/// `lightRim`, `lightAmbient` (colours) and the six light numbers.
///
/// The rig is static data per scene, so it is written on load and when the
/// scene (hence the rig) changes, never per frame: a [write] of the rig
/// already written does nothing. The flicker loops inside the Rive file;
/// `lightFlicker` only says how strongly. The fog is scene-only and is not
/// written. The app never reads light back from a file.
class AvatarLightWriter {
  AvatarLightWriter(this._sink);

  final AvatarVmSink _sink;
  LightRig? _written;

  /// Forgets what was written (a fresh binding has none of it).
  void reset() => _written = null;

  /// Writes [rig] unless it is the rig written last.
  void write(LightRig rig) {
    if (_written == rig) {
      return;
    }
    _written = rig;
    _sink.setColor(AvatarRiveContract.propLightKey, rig.keyColor);
    _sink.setNumber(AvatarRiveContract.propLightKeyIntensity, rig.keyIntensity);
    _sink.setNumber(AvatarRiveContract.propLightKeyX, rig.keyX);
    _sink.setNumber(AvatarRiveContract.propLightKeyY, rig.keyY);
    _sink.setColor(AvatarRiveContract.propLightRim, rig.rimColor);
    _sink.setNumber(AvatarRiveContract.propLightRimIntensity, rig.rimIntensity);
    _sink.setColor(AvatarRiveContract.propLightAmbient, rig.ambientColor);
    _sink.setNumber(
      AvatarRiveContract.propLightAmbientAmount,
      rig.ambientAmount,
    );
    _sink.setNumber(AvatarRiveContract.propLightFlicker, rig.flicker);
  }
}
