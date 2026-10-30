import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../models/avatar_scene.dart';
import '../../utils/logger.dart';
import 'mix_with_others_context.dart';

/// One looping bed (behind an interface so tests use fakes).
abstract interface class BedPlayer {
  /// Starts looping the bundled [asset] (relative to `assets/`) at [volume].
  Future<void> start(String asset, double volume);

  Future<void> setVolume(double volume);

  Future<void> stop();

  Future<void> dispose();
}

/// [BedPlayer] over an `audioplayers` [AudioPlayer] in loop mode.
class AudioPlayersBedPlayer implements BedPlayer {
  AudioPlayer? _player;

  @override
  Future<void> start(String asset, double volume) async {
    AudioPlayer? player = _player;
    if (player == null) {
      player = _player = AudioPlayer();
      await player.setAudioContext(mixWithOthersContext());
      await player.setReleaseMode(ReleaseMode.loop);
    }
    await player.play(AssetSource(asset), volume: volume);
  }

  @override
  Future<void> setVolume(double volume) async => _player?.setVolume(volume);

  @override
  Future<void> stop() async => _player?.stop();

  @override
  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}

/// The two ambient beds (moonshot M8 ruling 12), driven by the scene state:
///
/// - **crackle** (campfire, and mountainHut's stove at [hutCrackleScale] of
///   the campfire's level): [crackleVolume] × (0.6 + 0.4 × the campfire's
///   flicker); a `flare` ([onFlare]) swells it to [flareVolume] for
///   [flareLength];
/// - **rain**: the world's rain × [rainVolumeOutdoors] in campfire and
///   beach, × [rainVolumeIndoors] in livingRoom (behind the window),
///   × [rainVolumeRooftop] on the rooftop, × [rainVolumeBehindGlass] in the
///   cafe (behind its glass), 0 in deepSpace and mountainHut (it snows there).
///
/// Every volume eases linearly over [ease] (a scene change, at a journey's
/// cut, cross-fades the two); both duck to [duck] while the avatar speaks. A
/// bed starts when its volume rises above 0 and stops once it eased back to
/// 0. Pausing the app or turning the sound-effects setting off ([enabled])
/// stops both at once; reduce motion does not mute them.
class AmbientBedService {
  AmbientBedService({
    required BedPlayer Function() createPlayer,
    required ValueListenable<bool> enabled,
    required double Function(AvatarScene scene) flickerOf,
    DateTime Function()? now,
    ValueListenable<double>? rain,
    Stream<bool>? speaking,
    Stream<void>? flares,
    AvatarScene scene = AvatarScene.defaultScene,
  }) : _createPlayer = createPlayer,
       _enabled = enabled,
       _flickerOf = flickerOf,
       _now = now ?? DateTime.now,
       _rainSource = rain,
       _scene = scene {
    _crackle = _Bed('foley/bed_crackle.wav');
    _rain = _Bed('foley/bed_rain.wav');
    enabled.addListener(_update);
    rain?.addListener(_update);
    if (speaking != null) {
      _subscriptions.add(speaking.listen(setSpeaking));
    }
    if (flares != null) {
      _subscriptions.add(flares.listen((_) => onFlare()));
    }
    _update();
  }

  static const double crackleVolume = 0.18;
  static const double flareVolume = 0.35;
  static const Duration flareLength = Duration(seconds: 2);
  static const double rainVolumeOutdoors = 0.25;
  static const double rainVolumeIndoors = 0.12;
  static const double rainVolumeBehindGlass = 0.12;
  static const double rainVolumeRooftop = 0.25;

  /// The stove in mountainHut crackles at this fraction of the campfire's
  /// level (M9 ruling 3).
  static const double hutCrackleScale = 0.6;
  static const double duck = 0.5;
  static const Duration ease = Duration(milliseconds: 800);

  /// How often a volume ramp is stepped.
  static const Duration step = Duration(milliseconds: 50);

  final BedPlayer Function() _createPlayer;
  final ValueListenable<bool> _enabled;
  final double Function(AvatarScene scene) _flickerOf;
  final DateTime Function() _now;
  final ValueListenable<double>? _rainSource;
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  late final _Bed _crackle;
  late final _Bed _rain;
  AvatarScene _scene;
  bool _speaking = false;
  bool _paused = false;
  DateTime? _flareUntil;
  Timer? _timer;
  bool _disposed = false;

  /// The crackle bed's current volume (for tests and the capture log).
  double get crackleVolumeNow => _crackle.volumeAt(_now());

  /// The rain bed's current volume.
  double get rainVolumeNow => _rain.volumeAt(_now());

  /// Whether each bed's player is running.
  bool get cracklePlaying => _crackle.playing;
  bool get rainPlaying => _rain.playing;

  /// The scene on screen (a journey changes it at its cut).
  void setScene(AvatarScene scene) {
    if (scene == _scene) {
      return;
    }
    _scene = scene;
    _flareUntil = null;
    _update();
  }

  /// The avatar speaks: the beds duck.
  void setSpeaking(bool speaking) {
    if (speaking == _speaking) {
      return;
    }
    _speaking = speaking;
    _update();
  }

  /// A `flare` scene event (campfire, mountainHut): the crackle swells for a
  /// moment.
  void onFlare() {
    if (_crackleScale(_scene) == 0) {
      return;
    }
    _flareUntil = _now().add(flareLength);
    _update();
  }

  /// The app went to the background (true): both beds stop at once.
  void setPaused(bool paused) {
    if (paused == _paused) {
      return;
    }
    _paused = paused;
    _update();
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    _enabled.removeListener(_update);
    _rainSource?.removeListener(_update);
    for (final StreamSubscription<dynamic> s in _subscriptions) {
      await s.cancel();
    }
    await _crackle.player?.dispose();
    await _rain.player?.dispose();
  }

  // — internals —

  bool get _silent => !_enabled.value || _paused;

  static double _crackleScale(AvatarScene scene) => switch (scene) {
    AvatarScene.campfire => 1,
    AvatarScene.mountainHut => hutCrackleScale,
    AvatarScene.livingRoom ||
    AvatarScene.beach ||
    AvatarScene.deepSpace ||
    AvatarScene.cafe ||
    AvatarScene.rooftop => 0,
  };

  double _crackleTarget(DateTime now) {
    final double scale = _crackleScale(_scene);
    if (scale == 0) {
      return 0;
    }
    final DateTime? until = _flareUntil;
    final double base = until != null && now.isBefore(until)
        ? flareVolume
        // the campfire's level, whichever fire is burning (the hut's stove
        // is that, scaled)
        : crackleVolume *
              (0.6 + 0.4 * _flickerOf(AvatarScene.campfire).clamp(0.0, 1.0));
    return base * scale * (_speaking ? duck : 1);
  }

  double _rainTarget() {
    final double rain = (_rainSource?.value ?? 0).clamp(0.0, 1.0);
    final double scale = switch (_scene) {
      AvatarScene.campfire || AvatarScene.beach => rainVolumeOutdoors,
      AvatarScene.livingRoom => rainVolumeIndoors,
      AvatarScene.cafe => rainVolumeBehindGlass,
      AvatarScene.rooftop => rainVolumeRooftop,
      AvatarScene.deepSpace || AvatarScene.mountainHut => 0,
    };
    return rain * scale * (_speaking ? duck : 1);
  }

  void _update() {
    if (_disposed) {
      return;
    }
    final DateTime now = _now();
    if (_silent) {
      _timer?.cancel();
      _timer = null;
      _crackle.silence();
      _rain.silence();
      return;
    }
    _crackle.aim(_crackleTarget(now), now);
    _rain.aim(_rainTarget(), now);
    _apply(now);
  }

  /// Writes the current volumes, starts and stops the players, and steps
  /// again while a ramp runs (or when the flare ends).
  void _apply(DateTime now) {
    for (final _Bed bed in <_Bed>[_crackle, _rain]) {
      bed.apply(now, _createPlayer);
    }
    _timer?.cancel();
    _timer = null;
    if (_crackle.ramping(now) || _rain.ramping(now)) {
      _timer = Timer(step, () => _apply(_now()));
      return;
    }
    final DateTime? until = _flareUntil;
    if (until == null) {
      return;
    }
    if (!until.isAfter(now)) {
      // the swell ended while a ramp ran: ease back now
      _flareUntil = null;
      _update();
      return;
    }
    _timer = Timer(until.difference(now), () {
      _flareUntil = null;
      _update();
    });
  }
}

/// One bed's player and its linear volume ramp.
class _Bed {
  _Bed(this.asset);

  final String asset;
  BedPlayer? player;
  bool playing = false;
  double _from = 0;
  double _to = 0;
  DateTime? _start;
  double? _written;

  double volumeAt(DateTime now) {
    final DateTime? start = _start;
    if (start == null) {
      return _to;
    }
    final double t =
        now.difference(start).inMicroseconds /
        AmbientBedService.ease.inMicroseconds;
    if (t >= 1) {
      return _to;
    }
    return _from + (_to - _from) * t.clamp(0.0, 1.0);
  }

  bool ramping(DateTime now) {
    final DateTime? start = _start;
    return start != null && now.difference(start) < AmbientBedService.ease;
  }

  /// Eases toward [target] from where the volume is now.
  void aim(double target, DateTime now) {
    if ((target - _to).abs() < 1e-9) {
      return;
    }
    _from = volumeAt(now);
    _to = target;
    _start = now;
  }

  void apply(DateTime now, BedPlayer Function() create) {
    final double volume = volumeAt(now);
    if (!ramping(now)) {
      _start = null;
    }
    if (volume > 0 && !playing) {
      playing = true;
      _written = volume;
      _run((player ??= create()).start(asset, volume));
      return;
    }
    if (volume <= 0 && playing && !ramping(now)) {
      playing = false;
      _written = null;
      _run(player?.stop());
      return;
    }
    if (playing && (_written == null || (volume - _written!).abs() > 1e-4)) {
      _written = volume;
      _run(player?.setVolume(volume));
    }
  }

  /// Stops at once (pause, setting off); the next start eases in from 0.
  void silence() {
    _from = 0;
    _to = 0;
    _start = null;
    if (playing) {
      playing = false;
      _written = null;
      _run(player?.stop());
    }
  }

  static void _run(Future<void>? future) {
    if (future == null) {
      return;
    }
    unawaited(
      future.catchError((Object e) {
        AppLogger.warning(
          'AmbientBedService: player failed ($e)',
          tag: 'AmbientBedService',
        );
      }),
    );
  }
}
