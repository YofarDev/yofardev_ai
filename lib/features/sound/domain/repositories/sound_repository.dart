import '../../../../core/models/result.dart';

abstract class SoundRepository {
  Future<Result<void>> play(String soundPath);
  Future<Result<void>> stop();
  Future<Result<bool>> get isPlaying;
}
