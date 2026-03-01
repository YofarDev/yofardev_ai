import 'package:fpdart/fpdart.dart';

abstract class SoundRepository {
  Future<Either<Exception, void>> play(String soundPath);
  Future<Either<Exception, void>> stop();
  Future<Either<Exception, bool>> get isPlaying;
}
