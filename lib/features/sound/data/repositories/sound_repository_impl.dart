import 'package:fpdart/fpdart.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/models/sound_effects.dart';
import '../datasources/tts_datasource.dart';
import '../../domain/repositories/sound_repository.dart';

class SoundRepositoryImpl implements SoundRepository {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<Either<Exception, void>> play(String soundPath) async {
    try {
      final SoundEffects? soundEffect = SoundEffects.fromString(soundPath);
      if (soundEffect == null) {
        return const Right(null);
      }

      await _player.setAsset(soundEffect.getPath());
      await _player.setVolume(1.0);
      await _player.play();
      return const Right(null);
    } catch (e) {
      return Left(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, void>> stop() async {
    try {
      await _player.stop();
      return const Right(null);
    } catch (e) {
      return Left(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, bool>> get isPlaying async {
    try {
      return Right(_player.playing);
    } catch (e) {
      return Left(Exception(e.toString()));
    }
  }
}
