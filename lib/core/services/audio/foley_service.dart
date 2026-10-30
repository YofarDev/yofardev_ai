import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../utils/logger.dart';
import 'mix_with_others_context.dart';

/// Plays one short sound at a time (a low-latency pool slot).
abstract interface class FoleyPlayer {
  /// Plays the bundled [asset] (relative to `assets/`) at [volume] (0..1).
  Future<void> play(String asset, double volume);

  Future<void> dispose();
}

/// The two haptics the stage uses (behind an interface so tests use fakes).
abstract interface class HapticsSink {
  void selectionClick();

  void lightImpact();
}

/// [FoleyPlayer] over an `audioplayers` [AudioPlayer] in
/// [PlayerMode.lowLatency] (Android's SoundPool: short sounds, no seek).
class AudioPlayersFoleyPlayer implements FoleyPlayer {
  AudioPlayer? _player;

  @override
  Future<void> play(String asset, double volume) async {
    AudioPlayer? player = _player;
    if (player == null) {
      player = _player = AudioPlayer();
      await player.setAudioContext(mixWithOthersContext());
      await player.setReleaseMode(ReleaseMode.stop);
    }
    await player.stop();
    await player.play(
      AssetSource(asset),
      volume: volume,
      mode: PlayerMode.lowLatency,
    );
  }

  @override
  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}

/// [HapticsSink] over Flutter's [HapticFeedback].
class SystemHaptics implements HapticsSink {
  const SystemHaptics();

  @override
  void selectionClick() => unawaited(HapticFeedback.selectionClick());

  @override
  void lightImpact() => unawaited(HapticFeedback.lightImpact());
}

/// Foley and haptics from the avatar's Rive events (moonshot M8 ruling 10).
///
/// [play] takes a `foley` event's `kind` (`step`, `cloth`, `click`, `paper`)
/// and plays the next of its generated variants ([variants], round robin;
/// `assets/foley/<kind>_<n>.wav`) on the next of [poolSize] players, at
/// [volume] ([stepVolume] for footfalls); a kind repeating within [minGap]
/// is dropped (a looping clip can never spam it); `click` also fires a light
/// impact. [propTap] fires a selection click (scene props, the avatar's head
/// and body).
///
/// Silent, and without haptics, while [enabled] (the sound-effects setting)
/// is off or the app is paused ([setPaused]).
class FoleyService {
  FoleyService({
    required FoleyPlayer Function() createPlayer,
    required HapticsSink haptics,
    required ValueListenable<bool> enabled,
    DateTime Function()? now,
    this.poolSize = 3,
  }) : _createPlayer = createPlayer,
       _haptics = haptics,
       _enabled = enabled,
       _now = now ?? DateTime.now;

  /// Generated variants per kind (see `rive/tools/gen_foley.py`).
  static const Map<String, int> variants = <String, int>{
    'step': 4,
    'cloth': 2,
    'click': 1,
    'paper': 2,
  };

  static const double volume = 0.5;
  static const double stepVolume = 0.35;
  static const Duration minGap = Duration(milliseconds: 90);
  static const String assetDir = 'foley';

  final FoleyPlayer Function() _createPlayer;
  final HapticsSink _haptics;
  final ValueListenable<bool> _enabled;
  final DateTime Function() _now;
  final int poolSize;

  final List<FoleyPlayer> _pool = <FoleyPlayer>[];
  int _nextPlayer = 0;
  final Map<String, int> _nextVariant = <String, int>{};
  final Map<String, DateTime> _lastPlayed = <String, DateTime>{};
  bool _paused = false;

  bool get _audible => _enabled.value && !_paused;

  /// The app went to the background (true) or came back (false).
  void setPaused(bool paused) => _paused = paused;

  /// A `foley` event of [kind].
  void play(String kind) {
    final int? count = variants[kind];
    if (count == null) {
      AppLogger.debug('FoleyService: unknown kind $kind', tag: 'FoleyService');
      return;
    }
    if (!_audible) {
      return;
    }
    final DateTime now = _now();
    final DateTime? last = _lastPlayed[kind];
    if (last != null && now.difference(last) < minGap) {
      return;
    }
    _lastPlayed[kind] = now;
    final int variant = (_nextVariant[kind] ?? 0) % count;
    _nextVariant[kind] = variant + 1;
    final FoleyPlayer player = _player();
    unawaited(
      player
          .play(
            '$assetDir/${kind}_$variant.wav',
            kind == 'step' ? stepVolume : volume,
          )
          .catchError((Object e) {
            AppLogger.warning(
              'FoleyService: $kind failed ($e)',
              tag: 'FoleyService',
            );
          }),
    );
    if (kind == 'click') {
      _haptics.lightImpact();
    }
  }

  /// A tap on a scene prop or the avatar.
  void propTap() {
    if (_audible) {
      _haptics.selectionClick();
    }
  }

  FoleyPlayer _player() {
    if (_pool.length < poolSize) {
      final FoleyPlayer player = _createPlayer();
      _pool.add(player);
      return player;
    }
    final FoleyPlayer player = _pool[_nextPlayer % _pool.length];
    _nextPlayer++;
    return player;
  }

  Future<void> dispose() async {
    for (final FoleyPlayer player in _pool) {
      await player.dispose();
    }
    _pool.clear();
  }
}
