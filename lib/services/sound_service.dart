import 'package:just_audio/just_audio.dart';

import '../models/sound_effects.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _player = AudioPlayer();

  Future<void> playSoundEffect(
    SoundEffects soundEffect, {
    double volume = 1.0,
  }) async {
    try {
      await _player.setAsset(soundEffect.getPath());
      await _player.setVolume(volume);
      await _player.play();
    } catch (e) {
      // Silently fail if sound file doesn't exist or can't be played
    }
  }

  Future<void> stop() async {
    await _player.stop();
  }
}
