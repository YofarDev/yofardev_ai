import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import '../../utils/logger.dart';

/// Service for playing audio files
class AudioPlayerService {
  final StreamController<void> _playbackCompleteController =
      StreamController<void>.broadcast();
  AudioPlayer? _player;
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
    player.onPlayerComplete.listen((_) {
      if (_sourceGeneration != _playbackGeneration) {
        return;
      }
      _playbackCompleteController.add(null);
    });
    return player;
  }

  /// Play an audio file from path
  Future<Duration> play(String audioPath) async {
    final int playbackGeneration = ++_playbackGeneration;
    try {
      AppLogger.debug('Playing audio: $audioPath', tag: 'AudioPlayerService');

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

  /// Play an audio asset from the assets folder
  Future<void> playAsset(String assetPath, {double volume = 1.0}) async {
    try {
      AppLogger.debug('Playing asset: $assetPath', tag: 'AudioPlayerService');

      final AudioPlayer player = await _getOrCreatePlayer();
      // Asset playback is fire-and-forget: its completion must not be
      // forwarded as a TTS playback completion.
      _playbackGeneration++;
      _sourceGeneration = -1;

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
    _playbackCompleteController.close();
  }

  /// Stream that emits when playback completes
  Stream<void> get onPlaybackComplete => _playbackCompleteController.stream;
}
