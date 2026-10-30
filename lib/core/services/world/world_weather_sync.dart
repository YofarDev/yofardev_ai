import 'dart:async';

import '../../models/weather_report.dart';
import '../../utils/logger.dart';
import '../power/power_saver_source.dart';
import 'world_state_service.dart';

/// Keeps the world's weather in step with the user's own location while the
/// app is active: one refresh at [start], then every [interval].
///
/// It is deliberately timid. A refresh only happens when ALL hold: an
/// OpenWeather key is configured, the location permission is ALREADY granted
/// (it never asks) and battery saver is off. Anything else is a silent no-op,
/// and the weather then only follows the weather tool.
///
/// Everything platform-facing is injected, so tests need no network or plugin.
class WorldWeatherSync {
  WorldWeatherSync({
    required WorldStateService world,
    required PowerSaverSource power,
    required Future<String?> Function() readApiKey,
    required Future<bool> Function() hasLocationPermission,
    required Future<WeatherReport?> Function(String apiKey) fetchOwnLocation,
    this.interval = const Duration(minutes: 30),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _world = world,
       _power = power,
       _readApiKey = readApiKey,
       _hasLocationPermission = hasLocationPermission,
       _fetchOwnLocation = fetchOwnLocation;

  final Duration interval;

  final DateTime Function() _now;
  final WorldStateService _world;
  final PowerSaverSource _power;
  final Future<String?> Function() _readApiKey;
  final Future<bool> Function() _hasLocationPermission;
  final Future<WeatherReport?> Function(String apiKey) _fetchOwnLocation;

  Timer? _timer;
  bool _active = false;
  bool _refreshing = false;
  DateTime? _lastFetchAt;

  /// Refreshes now (unless the last fetch is less than [interval] old: a
  /// quick background / foreground round trip costs no call), then every
  /// [interval]. Safe to call again.
  void start() {
    _timer?.cancel();
    _active = true;
    final DateTime? last = _lastFetchAt;
    if (last == null || _now().difference(last) >= interval) {
      unawaited(refresh());
    }
    _timer = Timer.periodic(interval, (Timer _) => unawaited(refresh()));
  }

  /// Stops refreshing (the app is paused); [start] resumes.
  void pause() {
    _active = false;
    _timer?.cancel();
    _timer = null;
  }

  /// One guarded refresh; a no-op unless key, permission and battery allow.
  Future<void> refresh() async {
    if (!_active || _refreshing) {
      return;
    }
    _refreshing = true;
    try {
      final String? key = await _readApiKey();
      if (key == null || key.isEmpty || !_active) {
        return;
      }
      if (await _power.isOn || !_active) {
        return;
      }
      if (!await _hasLocationPermission() || !_active) {
        return;
      }
      _lastFetchAt = _now();
      final WeatherReport? report = await _fetchOwnLocation(key);
      if (report != null && _active) {
        _world.applyWeather(report);
      }
    } catch (e) {
      AppLogger.warning(
        'WorldWeatherSync: refresh failed ($e)',
        tag: 'WorldWeatherSync',
      );
    } finally {
      _refreshing = false;
    }
  }

  void dispose() => pause();
}
