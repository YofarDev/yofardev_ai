import 'package:just_audio/just_audio.dart';

import '../../models/sound_effects.dart';
import '../sound_service_interface.dart';

class SoundService implements ISoundService {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> playSound(String soundName) async {
    final SoundEffects? soundEffect = SoundEffects.fromString(soundName);
    if (soundEffect == null) {
      return;
    }

    try {
      await _player.setAsset(soundEffect.getPath());
      await _player.setVolume(1.0);
      await _player.play();
    } catch (e) {
      // Silently fail if sound file doesn't exist or can't be played
    }
  }

  Future<void> stop() async {
    await _player.stop();
  }
}
