import 'dart:async';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';

class ProgressiveVolumeControl {
  final double _minVolume;
  final Duration _fadeDuration;
  final int _steps;

  double _currentVolume = 0.5;
  double _targetVolume = 0.5;
  Timer? _timer;

  Function(double)? onVolumeChanged;

  ProgressiveVolumeControl({
    double minVolume = 0.2,
    Duration fadeDuration = const Duration(seconds: 5),
    int steps = 50,
    this.onVolumeChanged,
  })  : _minVolume = minVolume,
        _fadeDuration = fadeDuration,
        _steps = steps {
    _getCurrentVolume();
  }

  Future<void> _getCurrentVolume() async {
    _currentVolume = await FlutterVolumeController.getVolume() ?? 0.6;
    _targetVolume = _currentVolume;
    //  _maxVolume = _currentVolume;
  }

  void startVolumeFade(bool increase, ) async {
    await FlutterVolumeController.updateShowSystemUI(false);
    _timer?.cancel();

    final double startVolume = _currentVolume;
    _targetVolume = increase ? 0.8 : _minVolume;

    int elapsedSteps = 0;
    _timer = Timer.periodic(
      _fadeDuration ~/ _steps,
      (Timer timer) {
        elapsedSteps++;
        final double progress = elapsedSteps / _steps;
        final double newVolume =
            startVolume + ((_targetVolume - startVolume) * progress);

        FlutterVolumeController.setVolume(newVolume);
        _currentVolume = newVolume;
        onVolumeChanged?.call(_currentVolume);

        if (elapsedSteps >= _steps) {
          timer.cancel();
        }
      },
    );
  }

  void cancel() {
    _timer?.cancel();
  }

  double get currentVolume => _currentVolume;
}
