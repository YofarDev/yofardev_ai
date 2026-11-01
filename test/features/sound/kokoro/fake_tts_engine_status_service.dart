import 'dart:async';

import 'package:yofardev_ai/features/sound/sound.dart';

/// A [TtsEngineStatusService] a test drives by hand with [emit].
class FakeTtsEngineStatusService implements TtsEngineStatusService {
  FakeTtsEngineStatusService([
    this._current = const TtsEngineStatus.notInstalled(),
  ]);

  final StreamController<TtsEngineStatus> _controller =
      StreamController<TtsEngineStatus>.broadcast();
  TtsEngineStatus _current;
  int installs = 0;

  void emit(TtsEngineStatus status) {
    _current = status;
    _controller.add(status);
  }

  @override
  TtsEngineStatus get current => _current;

  @override
  Stream<TtsEngineStatus> get status => _controller.stream;

  @override
  Future<void> install() async => installs++;
}
