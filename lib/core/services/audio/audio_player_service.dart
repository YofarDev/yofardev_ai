import 'dart:async';

import 'package:just_audio/just_audio.dart';
import '../../utils/logger.dart';

/// Service for playing audio files
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  /// Play an audio file from path
  Future<Duration> play(String audioPath) async {
    try {
      AppLogger.debug('Playing audio: $audioPath', tag: 'AudioPlayerService');

      // Stop any previous playback
      await _player.stop();

      await _player.setFilePath(audioPath);
      _player.play();

      // Return the audio duration for syncing animation
      final Duration duration = _player.duration ?? Duration.zero;
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
      await _player.stop();
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
    _player.dispose();
  }

  /// Stream that emits when playback completes
  Stream<void> get onPlaybackComplete => _player.playerStateStream
      .where(
        (PlayerState state) =>
            state.processingState == ProcessingState.completed,
      )
      .map((_) => const Duration(seconds: 0));
}
