/// Abstract interface for SoundService to allow for dependency injection
abstract class ISoundService {
  /// Play a sound effect by name
  Future<void> playSound(String soundName);
}
