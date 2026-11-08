import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import '../../utils/logger.dart';

/// Service for playing audio files
class AudioPlayerService {
  final StreamController<void> _playbackCompleteController =
      StreamController<void>.broadcast();
  AudioPlayer? _player;

  /// Idle second player holding the preloaded next sentence's source.
  AudioPlayer? _nextPlayer;
  String? _preloadedPath;

  /// Plays [playAsset]'s one-shot sounds, apart from the sentence players: a
  /// sound effect over speech must not replace the sentence, swallow the
  /// completion the TTS queue waits for, or leave its volume behind.
  AudioPlayer? _assetPlayer;
  StreamSubscription<void>? _completionSubscription;
  int _playbackGeneration = 0;

  /// Generation of the source currently loaded into [_player]. Completion
  /// events are only forwarded when it matches [_playbackGeneration], so a
  /// stop()/dispose() invalidates pending completions.
  int _sourceGeneration = -1;

  /// Returns the persistent [AudioPlayer], creating it (and its completion
  /// subscription) on first use. Reused across plays so consecutive sentences
  /// don't pay player setup.
  Future<AudioPlayer> _getOrCreatePlayer() async {
    final AudioPlayer? existing = _player;
    if (existing != null) {
      return existing;
    }

    final AudioPlayer player = AudioPlayer();
    _player = player;
    await player.setReleaseMode(ReleaseMode.stop);
    _listenForCompletion(player);
    return player;
  }

  /// (Re)binds the completion listener to [player]. The subscription is
  /// stored so a player swap in [play] can cancel and rebind it to the
  /// now-active player.
  void _listenForCompletion(AudioPlayer player) {
    _completionSubscription?.cancel();
    _completionSubscription = player.onPlayerComplete.listen((_) {
      if (_sourceGeneration != _playbackGeneration) {
        return;
      }
      _playbackCompleteController.add(null);
    });
  }

  /// Loads [audioPath] into a second idle player so the next [play] skips
  /// the setSource round trip. Safe to call repeatedly; ignored on error.
  Future<void> preload(String audioPath) async {
    if (_preloadedPath == audioPath) {
      return;
    }
    // Snapshot the generation: if stop() invalidates the preload while
    // setSource is in flight, the resolved source must not be recorded.
    final int generation = _playbackGeneration;
    try {
      final AudioPlayer player = (_nextPlayer ??= AudioPlayer());
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setSource(DeviceFileSource(audioPath));
      if (generation != _playbackGeneration) {
        return;
      }
      _preloadedPath = audioPath;
    } catch (e) {
      AppLogger.error(
        'Failed to preload audio',
        tag: 'AudioPlayerService',
        error: e,
      );
      _preloadedPath = null;
    }
  }

  /// Play an audio file from path
  Future<Duration> play(String audioPath) async {
    final int playbackGeneration = ++_playbackGeneration;
    try {
      AppLogger.debug('Playing audio: $audioPath', tag: 'AudioPlayerService');

      // If the requested source is already loaded in the idle second player,
      // swap it in: the setSource round trip already happened during preload.
      if (_preloadedPath == audioPath && _nextPlayer != null) {
        final AudioPlayer ready = _nextPlayer!;
        final AudioPlayer? demoted = _player;
        await demoted?.stop();
        _player = ready;
        _nextPlayer = null;
        _preloadedPath = null;
        // The swapped-in player is now the active one: its generation must
        // match the just-captured playbackGeneration so its completion is
        // forwarded, and the completion subscription must listen on it.
        _sourceGeneration = playbackGeneration;
        _listenForCompletion(ready);
        // The demoted player has no subscription left (cancelled inside
        // _listenForCompletion before this point) and no field referencing
        // it; dispose it or its native resources leak per sentence swap.
        if (demoted != null) {
          unawaited(demoted.dispose());
        }
        await ready.resume();
        final Duration duration = await ready.getDuration() ?? Duration.zero;
        AppLogger.debug(
          'Audio duration: ${duration.inMilliseconds}ms',
          tag: 'AudioPlayerService',
        );
        return duration;
      }

      final AudioPlayer player = await _getOrCreatePlayer();
      _sourceGeneration = playbackGeneration;

      await player.setSource(DeviceFileSource(audioPath));
      await player.resume();

      // Return the audio duration for syncing animation
      final Duration duration = await player.getDuration() ?? Duration.zero;
      AppLogger.debug(
        'Audio duration: ${duration.inMilliseconds}ms',
        tag: 'AudioPlayerService',
      );
      return duration;
    } catch (e) {
      AppLogger.error(
        'Failed to play audio',
        tag: 'AudioPlayerService',
        error: e,
      );
      rethrow;
    }
  }

  /// Play an audio asset from the assets folder, fire-and-forget, on its own
  /// player: a sentence playing meanwhile plays on and still completes, and
  /// [stop] (a speech interruption) leaves the asset alone.
  Future<void> playAsset(String assetPath, {double volume = 1.0}) async {
    try {
      AppLogger.debug('Playing asset: $assetPath', tag: 'AudioPlayerService');

      final AudioPlayer player = _assetPlayer ??= AudioPlayer();
      await player.setSource(AssetSource(assetPath));
      await player.setVolume(volume);
      await player.resume();
    } catch (e) {
      AppLogger.error(
        'Failed to play asset',
        tag: 'AudioPlayerService',
        error: e,
      );
    }
  }

  /// Stop current playback
  Future<void> stop() async {
    try {
      _playbackGeneration++;
      final AudioPlayer? player = _player;
      if (player != null) {
        await player.stop();
      }
      final AudioPlayer? nextPlayer = _nextPlayer;
      if (nextPlayer != null) {
        await nextPlayer.stop();
      }
      _preloadedPath = null;
    } catch (e) {
      AppLogger.error(
        'Failed to stop audio',
        tag: 'AudioPlayerService',
        error: e,
      );
    }
  }

  /// Dispose resources
  void dispose() {
    _playbackGeneration++;
    final AudioPlayer? player = _player;
    _player = null;
    if (player != null) {
      unawaited(player.dispose());
    }
    final AudioPlayer? nextPlayer = _nextPlayer;
    _nextPlayer = null;
    if (nextPlayer != null) {
      unawaited(nextPlayer.dispose());
    }
    final AudioPlayer? assetPlayer = _assetPlayer;
    _assetPlayer = null;
    if (assetPlayer != null) {
      unawaited(assetPlayer.dispose());
    }
    unawaited(_completionSubscription?.cancel());
    _completionSubscription = null;
    _preloadedPath = null;
    _playbackCompleteController.close();
  }

  /// Current position of the active player, null when no player is active
  /// (or the position cannot be read). Consumed by the playback clock.
  Future<Duration?> currentPosition() async {
    final AudioPlayer? player = _player;
    if (player == null) {
      return null;
    }
    try {
      return await player.getCurrentPosition();
    } catch (e) {
      AppLogger.error(
        'Failed to read playback position',
        tag: 'AudioPlayerService',
        error: e,
      );
      return null;
    }
  }

  /// Stream that emits when playback completes
  Stream<void> get onPlaybackComplete => _playbackCompleteController.stream;
}
