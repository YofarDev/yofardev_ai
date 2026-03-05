import 'dart:async';

import 'package:just_audio/just_audio.dart';
import '../../utils/logger.dart';

/// Service for playing audio files
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  
  /// Play an audio file from path
  Future<void> play(String audioPath) async {
    try {
      AppLogger.debug('Playing audio: $audioPath', tag: 'AudioPlayerService');
      await _player.setFilePath(audioPath);
      await _player.play();
    } catch (e) {
      AppLogger.error('Failed to play audio', tag: 'AudioPlayerService', error: e);
      rethrow;
    }
  }
  
  /// Stop current playback
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      AppLogger.error('Failed to stop audio', tag: 'AudioPlayerService', error: e);
    }
  }
  
  /// Dispose resources
  void dispose() {
    _player.dispose();
  }
  
  /// Stream that emits when playback completes
  Stream<void> get onPlaybackComplete => _player.playerStateStream
      .where((PlayerState state) => state.processingState == ProcessingState.completed)
      .map((_) => const Duration(seconds: 0));
}
