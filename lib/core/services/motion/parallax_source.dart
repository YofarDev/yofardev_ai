import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:sensors_plus/sensors_plus.dart' show AccelerometerEvent;

import '../../utils/logger.dart';
import '../power/power_saver_source.dart';

/// The parallax offset of the diorama scenes, each axis in -1..1.
///
/// On phones it is the accelerometer's gravity tilt: low-passed, relative to
/// a rest pose that slowly re-centres (the way the user holds the device),
/// scaled so a [tiltRange] tilt reaches 1 and clamped. Without an
/// accelerometer (desktop, web, or after its stream failed) the offset is
/// the pointer position over the stage, reported through [pointer]. It reads
/// 0 under reduce motion and battery saver.
///
/// Sign: tilting the device's right edge down gives +x; tilting its top away
/// from the viewer (the screen facing more upward) gives +y.
///
/// Nothing here throws: a sensor error is logged once, the accelerometer is
/// dropped and the pointer (or 0) takes over.
class ParallaxSource {
  ParallaxSource({
    Stream<AccelerometerEvent>? accel,
    required bool Function() reduceMotion,
    required PowerSaverSource power,
  }) : _reduceMotion = reduceMotion,
       _power = power,
       _hasAccel = accel != null {
    if (accel != null) {
      _accelSub = accel.listen(
        _onAccel,
        onError: _onAccelError,
        onDone: () => _dropAccel('accelerometer stream ended'),
      );
    }
    _powerSub = power.changes.listen(
      (bool on) {
        _powerSaver = on;
        _update();
      },
      onError: (Object error) {
        AppLogger.warning(
          'ParallaxSource: power saver stream error ($error)',
          tag: _tag,
        );
      },
    );
    unawaited(_readPower());
  }

  static const String _tag = 'ParallaxSource';

  /// Gravity fraction (of g) that moves the offset by 1 (about 17 degrees).
  static const double tiltRange = 0.3;

  /// Time constant of the tilt low-pass, in seconds.
  static const double smoothingSeconds = 0.12;

  /// Time constant of the rest pose re-centring, in seconds.
  static const double recentreSeconds = 6;

  /// Smallest change worth emitting.
  static const double epsilon = 0.001;

  final bool Function() _reduceMotion;
  final PowerSaverSource _power;
  final bool _hasAccel;

  final StreamController<Offset> _controller =
      StreamController<Offset>.broadcast();
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<bool>? _powerSub;

  bool _accelDropped = false;
  bool _powerSaver = false;
  bool _disposed = false;

  Offset _pointer = Offset.zero;
  Offset _tilt = Offset.zero;
  Offset _emitted = Offset.zero;

  // Low-passed gravity direction (x, z as fractions of g) and its rest pose.
  double? _gx;
  double? _gz;
  double _restX = 0;
  double _restZ = 0;
  DateTime? _lastSample;

  /// The offset now, -1..1 per axis.
  Offset get value => _emitted;

  /// Emits the offset whenever it changes by more than [epsilon] on an axis.
  Stream<Offset> get values => _controller.stream;

  /// Whether the accelerometer drives the offset (false: the pointer does).
  bool get usesAccelerometer => _hasAccel && !_accelDropped;

  /// Reports the pointer position over the stage, normalised to -1..1 per
  /// axis (0 at the centre, +x right, +y up). Ignored while the
  /// accelerometer drives the offset.
  void pointer(Offset normalized) {
    _pointer = Offset(_clamp(normalized.dx), _clamp(normalized.dy));
    if (!usesAccelerometer) {
      _update();
    }
  }

  Future<void> _readPower() async {
    try {
      final bool on = await _power.isOn;
      if (_disposed) {
        return;
      }
      _powerSaver = on;
      _update();
    } catch (e) {
      AppLogger.warning(
        'ParallaxSource: power saver unavailable ($e)',
        tag: _tag,
      );
    }
  }

  void _onAccel(AccelerometerEvent event) {
    if (_disposed) {
      return;
    }
    final double magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    if (!magnitude.isFinite || magnitude < 1e-3) {
      return;
    }
    final double x = event.x / magnitude;
    final double z = event.z / magnitude;
    final DateTime at = event.timestamp;
    final DateTime? last = _lastSample;
    final double dt = last == null
        ? 0
        : math.min(
            0.5,
            math.max(0.0, at.difference(last).inMicroseconds / 1e6),
          );
    _lastSample = at;
    final double? gx = _gx;
    final double? gz = _gz;
    if (gx == null || gz == null) {
      _gx = _restX = x;
      _gz = _restZ = z;
    } else {
      final double a = 1 - math.exp(-dt / smoothingSeconds);
      final double r = 1 - math.exp(-dt / recentreSeconds);
      _gx = gx + (x - gx) * a;
      _gz = gz + (z - gz) * a;
      _restX += (_gx! - _restX) * r;
      _restZ += (_gz! - _restZ) * r;
    }
    _tilt = Offset(
      _clamp(-(_gx! - _restX) / tiltRange),
      _clamp((_gz! - _restZ) / tiltRange),
    );
    _update();
  }

  void _onAccelError(Object error, [StackTrace? stackTrace]) {
    _dropAccel('accelerometer error ($error)');
  }

  void _dropAccel(String reason) {
    if (_accelDropped || _disposed) {
      return;
    }
    _accelDropped = true;
    AppLogger.warning(
      'ParallaxSource: $reason; falling back to the pointer',
      tag: _tag,
    );
    _tilt = Offset.zero;
    unawaited(_accelSub?.cancel());
    _accelSub = null;
    _update();
  }

  void _update() {
    if (_disposed) {
      return;
    }
    final Offset next = _reduceMotion() || _powerSaver
        ? Offset.zero
        : (usesAccelerometer ? _tilt : _pointer);
    if ((next.dx - _emitted.dx).abs() <= epsilon &&
        (next.dy - _emitted.dy).abs() <= epsilon &&
        !(next == Offset.zero && _emitted != Offset.zero)) {
      return;
    }
    _emitted = next;
    _controller.add(next);
  }

  static double _clamp(double v) =>
      v.isNaN ? 0 : math.min(1.0, math.max(-1.0, v));

  Future<void> dispose() async {
    _disposed = true;
    await _accelSub?.cancel();
    await _powerSub?.cancel();
    await _controller.close();
  }
}
