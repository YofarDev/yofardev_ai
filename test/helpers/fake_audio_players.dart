import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';

/// audioplayers' native side, in memory, for tests of code that plays audio
/// through real [AudioPlayer]s: each player's source, playing state and
/// volume are tracked, every source is prepared at once, and [finish] ends
/// the audio a player is actually playing, as the platform would.
///
///     final FakeAudioPlayersPlatform platform =
///         FakeAudioPlayersPlatform.install();
///     // ... code under test plays '/tmp/a.wav' ...
///     expect(platform.isPlaying('/tmp/a.wav'), isTrue);
///     await platform.finish('/tmp/a.wav'); // its onPlayerComplete fires
class FakeAudioPlayersPlatform {
  FakeAudioPlayersPlatform._();

  /// Routes every [AudioPlayer] created from now on (and the global scope)
  /// to a fresh fake. Asset sources resolve without file IO: an
  /// `AssetSource('x.wav')` plays from the URL `assets/x.wav`.
  static FakeAudioPlayersPlatform install() {
    final FakeAudioPlayersPlatform fake = FakeAudioPlayersPlatform._();
    AudioplayersPlatformInterface.instance = _FakeAudioplayers(fake);
    GlobalAudioplayersPlatformInterface.instance = _FakeGlobalAudioplayers();
    AudioCache.instance = _NoIoAudioCache();
    return fake;
  }

  final Map<String, _FakePlayer> _players = <String, _FakePlayer>{};

  /// Whether a live player is playing the source at [url].
  bool isPlaying(String url) =>
      _players.values.any((_FakePlayer p) => p.url == url && p.playing);

  /// The volume last set on the player holding [url] (1 when never set);
  /// null when no live player holds it.
  double? volumeOf(String url) {
    for (final _FakePlayer p in _players.values) {
      if (p.url == url) {
        return p.volume;
      }
    }
    return null;
  }

  /// Ends the audio at [url] on the player playing it: its complete event
  /// fires. Nothing happens when no player is playing [url] (it was
  /// stopped, or another source replaced it).
  Future<void> finish(String url) async {
    for (final _FakePlayer p in _players.values) {
      if (p.url == url && p.playing) {
        p.playing = false;
        p.events.add(const AudioEvent(eventType: AudioEventType.complete));
      }
    }
    // Let the player and its listeners see the event.
    await Future<void>.delayed(Duration.zero);
  }

  _FakePlayer _player(String playerId) =>
      _players.putIfAbsent(playerId, _FakePlayer.new);
}

class _FakePlayer {
  final StreamController<AudioEvent> events =
      StreamController<AudioEvent>.broadcast();
  String? url;
  bool playing = false;
  double volume = 1;
}

class _FakeAudioplayers extends AudioplayersPlatformInterface {
  _FakeAudioplayers(this._fake);

  final FakeAudioPlayersPlatform _fake;

  @override
  Future<void> create(String playerId) async => _fake._player(playerId);

  @override
  Future<void> dispose(String playerId) async {
    final _FakePlayer? player = _fake._players.remove(playerId);
    await player?.events.close();
  }

  @override
  Stream<AudioEvent> getEventStream(String playerId) =>
      _fake._player(playerId).events.stream;

  @override
  Future<void> setSourceUrl(
    String playerId,
    String url, {
    bool? isLocal,
    String? mimeType,
  }) async {
    final _FakePlayer player = _fake._player(playerId);
    player
      ..url = url
      ..playing = false
      ..events.add(
        const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
      );
  }

  @override
  Future<void> resume(String playerId) async =>
      _fake._player(playerId).playing = true;

  @override
  Future<void> pause(String playerId) async =>
      _fake._player(playerId).playing = false;

  @override
  Future<void> stop(String playerId) async =>
      _fake._player(playerId).playing = false;

  @override
  Future<void> release(String playerId) async {
    final _FakePlayer player = _fake._player(playerId);
    player
      ..playing = false
      ..url = null;
  }

  @override
  Future<void> setVolume(String playerId, double volume) async =>
      _fake._player(playerId).volume = volume;

  @override
  Future<int?> getDuration(String playerId) async => 1000;

  @override
  Future<int?> getCurrentPosition(String playerId) async => 0;

  @override
  Future<void> seek(String playerId, Duration position) async {}

  @override
  Future<void> setBalance(String playerId, double balance) async {}

  @override
  Future<void> setReleaseMode(String playerId, ReleaseMode releaseMode) async {}

  @override
  Future<void> setPlaybackRate(String playerId, double playbackRate) async {}

  @override
  Future<void> setSourceBytes(
    String playerId,
    Uint8List bytes, {
    String? mimeType,
  }) async {}

  @override
  Future<void> setAudioContext(
    String playerId,
    AudioContext audioContext,
  ) async {}

  @override
  Future<void> setPlayerMode(String playerId, PlayerMode playerMode) async {}

  @override
  Future<void> emitLog(String playerId, String message) async {}

  @override
  Future<void> emitError(String playerId, String code, String message) async {}
}

class _FakeGlobalAudioplayers implements GlobalAudioplayersPlatformInterface {
  final StreamController<GlobalAudioEvent> _events =
      StreamController<GlobalAudioEvent>.broadcast();

  @override
  Future<void> init() async {}

  @override
  Future<void> setGlobalAudioContext(AudioContext ctx) async {}

  @override
  Future<void> emitGlobalLog(String message) async {}

  @override
  Future<void> emitGlobalError(String code, String message) async {}

  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() => _events.stream;
}

/// Resolves an asset to its bundle path without copying it to a temp file
/// (no path_provider in tests).
class _NoIoAudioCache extends AudioCache {
  @override
  Future<String> loadPath(String fileName) async => '$prefix$fileName';
}
