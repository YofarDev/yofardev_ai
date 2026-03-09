import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import '../../utils/logger.dart';

/// Service for playing audio files
class AudioPlayerService {
  final StreamController<void> _playbackCompleteController =
      StreamController<void>.broadcast();
  AudioPlayer? _player;
  StreamSubscription<void>? _completionSubscription;
  int _playbackGeneration = 0;

  /// Play an audio file from path
  Future<Duration> play(String audioPath) async {
    final int playbackGeneration = ++_playbackGeneration;
    try {
      AppLogger.debug('Playing audio: $audioPath', tag: 'AudioPlayerService');

      await _disposeCurrentPlayer();

      final AudioPlayer player = AudioPlayer();
      _player = player;
      await player.setReleaseMode(ReleaseMode.stop);
      _completionSubscription = player.onPlayerComplete.listen((_) {
        if (playbackGeneration != _playbackGeneration) {
          return;
        }

        _playbackCompleteController.add(null);
        unawaited(
          _disposeCompletedPlayer(playbackGeneration, stopPlayback: false),
        );
      });

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

  /// Stop current playback
  Future<void> stop() async {
    try {
      _playbackGeneration++;
      await _disposeCurrentPlayer();
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
    unawaited(_disposeCurrentPlayer());
    _playbackCompleteController.close();
  }

  /// Stream that emits when playback completes
  Stream<void> get onPlaybackComplete => _playbackCompleteController.stream;

  Future<void> _disposeCompletedPlayer(
    int playbackGeneration, {
    required bool stopPlayback,
  }) async {
    if (playbackGeneration != _playbackGeneration) {
      return;
    }

    await _disposeCurrentPlayer(stopPlayback: stopPlayback);
  }

  Future<void> _disposeCurrentPlayer({bool stopPlayback = true}) async {
    final StreamSubscription<void>? completionSubscription =
        _completionSubscription;
    _completionSubscription = null;
    await completionSubscription?.cancel();

    final AudioPlayer? player = _player;
    _player = null;
    if (player == null) {
      return;
    }

    if (stopPlayback) {
      try {
        await player.stop();
      } catch (_) {}
    }

    await player.dispose();
  }
}
