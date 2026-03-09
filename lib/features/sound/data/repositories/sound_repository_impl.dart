import 'package:audioplayers/audioplayers.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/models/sound_effects.dart';
import '../../domain/repositories/sound_repository.dart';

class SoundRepositoryImpl implements SoundRepository {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<Either<Exception, void>> play(String soundPath) async {
    try {
      final SoundEffects? soundEffect = SoundEffects.fromString(soundPath);
      if (soundEffect == null) {
        return const Right<Exception, void>(null);
      }

      await _player.stop();
      await _player.setSource(
        AssetSource(soundEffect.getPath().replaceFirst('assets/', '')),
      );
      await _player.setVolume(1.0);
      await _player.resume();
      return const Right<Exception, void>(null);
    } catch (e) {
      return Left<Exception, void>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, void>> stop() async {
    try {
      await _player.stop();
      return const Right<Exception, void>(null);
    } catch (e) {
      return Left<Exception, void>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, bool>> get isPlaying async {
    try {
      return Right<Exception, bool>(_player.state == PlayerState.playing);
    } catch (e) {
      return Left<Exception, bool>(Exception(e.toString()));
    }
  }
}
