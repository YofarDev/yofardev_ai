import 'dart:ui' show Offset;

import 'scene_parallax_writer.dart';
import 'scene_rain_writer.dart';

/// The scene view's logic for the contract v9 `SceneFront` artboard (the
/// weather drawn above the avatar), free of Rive so it can be tested.
///
/// The front exists only while the loaded file has one and it rains
/// ([shouldShow]): dry, it draws nothing, so it costs nothing. [attach] runs
/// when its controller is created and writes the current rain and parallax
/// into that fresh binding; [rain] and [parallax] follow later changes;
/// [detach] drops the binding.
class SceneFrontFollower {
  SceneRainWriter? _rain;
  SceneParallaxWriter? _parallax;

  /// Whether the front artboard should be live.
  static bool shouldShow({required bool hasFront, required double rain}) =>
      hasFront && rain > SceneRainWriter.epsilon;

  /// Whether a front binding is attached.
  bool get attached => _rain != null;

  /// A front controller was created: writes [rain] and [parallax] to it.
  void attach(
    void Function(String name, double value) setNumber, {
    required double rain,
    required Offset parallax,
  }) {
    _rain = SceneRainWriter(setNumber)..write(rain, force: true);
    _parallax = SceneParallaxWriter(setNumber)..write(parallax, force: true);
  }

  /// The rain changed.
  void rain(double value) => _rain?.write(value);

  /// The parallax offset changed.
  void parallax(Offset value) => _parallax?.write(value);

  /// The front controller is gone.
  void detach() {
    _rain = null;
    _parallax = null;
  }
}
