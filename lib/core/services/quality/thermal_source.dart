import 'dart:async';

import 'package:flutter/services.dart';

import '../../utils/logger.dart';

/// The device's thermal state, normalized across platforms (moonshot M11
/// ruling 12).
///
/// Android `PowerManager` thermal status: none → [nominal], light →
/// [light], moderate → [moderate], severe → [severe], critical, emergency
/// and shutdown → [critical]. Apple `ProcessInfo.ThermalState`: nominal →
/// [nominal], fair → [light], serious → [moderate], critical → [critical].
enum ThermalLevel {
  nominal,
  light,
  moderate,
  severe,
  critical;

  /// The level named [value] (as the native side sends it); anything else
  /// (null, an unknown name) is [nominal].
  static ThermalLevel parse(Object? value) {
    if (value is String) {
      for (final ThermalLevel level in ThermalLevel.values) {
        if (level.name == value) {
          return level;
        }
      }
    }
    return ThermalLevel.nominal;
  }
}

/// Where the thermal state comes from; abstracted so the tier service can be
/// tested with a fake.
abstract interface class ThermalSource {
  /// The state now; [ThermalLevel.nominal] when it cannot be known.
  Future<ThermalLevel> get current;

  /// Emits every change of the state (never an error).
  Stream<ThermalLevel> get changes;
}

/// A [ThermalSource] that is always nominal (the web, desktops without the
/// channel, tests).
class NominalThermalSource implements ThermalSource {
  const NominalThermalSource();

  @override
  Future<ThermalLevel> get current async => ThermalLevel.nominal;

  @override
  Stream<ThermalLevel> get changes => const Stream<ThermalLevel>.empty();
}

/// [ThermalSource] over the app's own platform channels: the
/// [eventChannelName] event channel streams the level's name on every change
/// (the native side sends the current one first), and the [methodChannelName]
/// method channel answers `current`. Android (API 29+), iOS and macOS
/// implement them (`MainActivity.kt`, `AppDelegate.swift`,
/// `MainFlutterWindow.swift`); a missing plugin or any error reads as
/// nominal and is logged once.
class MethodChannelThermalSource implements ThermalSource {
  MethodChannelThermalSource({EventChannel? events, MethodChannel? query})
    : _events = events ?? const EventChannel(eventChannelName),
      _query = query ?? const MethodChannel(methodChannelName);

  static const String eventChannelName = 'yofardev/thermal';
  static const String methodChannelName = 'yofardev/thermal_state';
  static const String currentMethod = 'current';

  static const String _tag = 'ThermalSource';

  final EventChannel _events;
  final MethodChannel _query;
  bool _reported = false;
  Stream<ThermalLevel>? _changes;

  @override
  Future<ThermalLevel> get current async =>
      (await _read()) ?? ThermalLevel.nominal;

  /// The level now; null when there is no plugin (or it failed).
  Future<ThermalLevel?> _read() async {
    try {
      final String? name = await _query.invokeMethod<String>(currentMethod);
      return ThermalLevel.parse(name);
    } on MissingPluginException {
      _reportOnce('no thermal plugin on this platform: nominal');
      return null;
    } on PlatformException catch (e) {
      _reportOnce('thermal state unavailable (${e.message}): nominal');
      return null;
    }
  }

  /// The event channel is listened to only once the method channel answered:
  /// listening without a plugin would report an error.
  @override
  Stream<ThermalLevel> get changes =>
      _changes ??= _availableChanges().asBroadcastStream();

  Stream<ThermalLevel> _availableChanges() async* {
    if (await _read() == null) {
      return;
    }
    yield* _events.receiveBroadcastStream().map(ThermalLevel.parse).handleError(
      (Object error) {
        _reportOnce('thermal stream error ($error)');
      },
    ).distinct();
  }

  void _reportOnce(String message) {
    if (_reported) {
      return;
    }
    _reported = true;
    AppLogger.warning('MethodChannelThermalSource: $message', tag: _tag);
  }
}
