import 'package:audioplayers/audioplayers.dart';

import '../../../../core/models/failure.dart';
import '../../../../core/models/result.dart';
import '../../../../core/models/sound_effects.dart';
import '../../domain/repositories/sound_repository.dart';

class SoundRepositoryImpl implements SoundRepository {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<Result<void>> play(String soundPath) async {
    try {
      final SoundEffects? soundEffect = SoundEffects.fromString(soundPath);
      if (soundEffect == null) {
        return Result<void>.ok(null);
      }

      await _player.stop();
      await _player.setSource(
        AssetSource(soundEffect.getPath().replaceFirst('assets/', '')),
      );
      await _player.setVolume(1.0);
      await _player.resume();
      return Result<void>.ok(null);
    } catch (e) {
      return Result<void>.err(StorageFailure('Failed to play sound', e));
    }
  }

  @override
  Future<Result<void>> stop() async {
    try {
      await _player.stop();
      return Result<void>.ok(null);
    } catch (e) {
      return Result<void>.err(StorageFailure('Failed to stop sound', e));
    }
  }

  @override
  Future<Result<bool>> get isPlaying async {
    try {
      return Result<bool>.ok(_player.state == PlayerState.playing);
    } catch (e) {
      return Result<bool>.err(StorageFailure('Failed to check playing state', e));
    }
  }
}
