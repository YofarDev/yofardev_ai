import 'dart:async';

import 'package:flutter_volume_controller/flutter_volume_controller.dart';

import 'extensions.dart';

class ProgressiveVolumeControl {
  final double _minVolume = 0.4;
  Timer? _timer;
  bool _init = false;
  bool _programmaticallyChangingVolume = false;
  late double _initialVolume;

  ProgressiveVolumeControl() {
    _getCurrentVolume();
    _setListener();
  }

  Future<void> _getCurrentVolume() async {
    await FlutterVolumeController.updateShowSystemUI(false);
    _initialVolume = await FlutterVolumeController.getVolume() ?? 0.8;
  }

  void _setListener() {
    FlutterVolumeController.addListener(
      (double value) {
        if (!_init) {
          _init = true;
          return;
        }
        if (_programmaticallyChangingVolume) {
          return;
        }
        "Volume changed to $value".printBlueLog();
        _initialVolume = value;
      },
    );
  }

  void startVolumeFade(bool increase) async {
    cancel();
    _programmaticallyChangingVolume = true;
    final double targetVolume = increase ? _initialVolume : _minVolume;
    double currentVolume =
        await FlutterVolumeController.getVolume() ?? _initialVolume;
    if (beyondTargetVolume(
      increase: increase,
      currentVolume: currentVolume,
      targetVolume: targetVolume,
    )) {
      return;
    }
    "Fading volume ${increase ? 'up' : 'down'} to $targetVolume".printCyanLog();
    const double increment = 0.03;
    final int vector = increase ? 1 : -1;
    _timer = Timer.periodic(
      const Duration(milliseconds: 100),
      (Timer timer) async {
        if (beyondTargetVolume(
          increase: increase,
          currentVolume: currentVolume,
          targetVolume: targetVolume,
        )) {
          cancel();
          "Fading done".toYellowLog();
          return;
        }

        currentVolume += vector * increment;
        await FlutterVolumeController.setVolume(currentVolume);
      },
    );
  }

  void cancel() {
    _timer?.cancel();
    _programmaticallyChangingVolume = false;
  }

  bool beyondTargetVolume({
    required bool increase,
    required double currentVolume,
    required double targetVolume,
  }) =>
      (increase && currentVolume >= targetVolume) ||
      (!increase && currentVolume <= targetVolume);
}
