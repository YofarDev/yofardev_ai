import 'dart:async';

import 'package:battery_plus/battery_plus.dart';

import '../../utils/logger.dart';

/// Whether the device is in a battery saver mode (the idle life and the
/// parallax stand still while it is on).
abstract interface class PowerSaverSource {
  /// The current state; false when it cannot be known.
  Future<bool> get isOn;

  /// Emits whenever the state changes.
  Stream<bool> get changes;
}

/// [PowerSaverSource] backed by `battery_plus`'s battery save mode.
///
/// Polls every [pollInterval] while [changes] has a listener (no platform
/// event channel: desktop and web have none). An unsupported platform or any
/// error reads as false and is logged once per change of outcome.
class BatteryPowerSaverSource implements PowerSaverSource {
  BatteryPowerSaverSource({
    Future<bool> Function()? read,
    this.pollInterval = const Duration(seconds: 60),
  }) : _read = read ?? _readBattery {
    _controller = StreamController<bool>.broadcast(
      onListen: _startPolling,
      onCancel: _stopPolling,
    );
  }

  final Future<bool> Function() _read;
  final Duration pollInterval;

  late final StreamController<bool> _controller;
  Timer? _timer;

  /// The value [changes] last emitted (false before any).
  bool _last = false;
  bool _failed = false;
  bool _disposed = false;

  static Future<bool> _readBattery() => Battery().isInBatterySaveMode;

  /// A one-off read: it never touches what [changes] last emitted, so a
  /// read between two polls cannot swallow a transition.
  @override
  Future<bool> get isOn => _safeRead();

  @override
  Stream<bool> get changes => _controller.stream;

  Future<bool> _safeRead() async {
    try {
      final bool value = await _read();
      _failed = false;
      return value;
    } catch (e, st) {
      if (!_failed) {
        AppLogger.warning(
          'BatteryPowerSaverSource: battery saver unavailable ($e)',
          tag: 'BatteryPowerSaverSource',
        );
        AppLogger.debug('$st', tag: 'BatteryPowerSaverSource');
      }
      _failed = true;
      return false;
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(pollInterval, (Timer _) => unawaited(_poll()));
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    final bool value = await _safeRead();
    if (_disposed || value == _last) {
      return;
    }
    _last = value;
    _controller.add(value);
  }

  /// Stops polling and closes [changes].
  Future<void> dispose() async {
    _disposed = true;
    _stopPolling();
    await _controller.close();
  }
}
