import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
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

      await _player.setSource(DeviceFileSource(audioPath));
      _player.resume();

      // Return the audio duration for syncing animation
      final Duration duration = await _player.getDuration() ?? Duration.zero;
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
  Stream<void> get onPlaybackComplete => _player.onPlayerComplete;
}
