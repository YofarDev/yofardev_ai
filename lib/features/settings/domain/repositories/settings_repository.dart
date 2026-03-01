import 'package:fpdart/fpdart.dart';

abstract class SettingsRepository {
  Future<Either<Exception, String?>> getLanguage();
  Future<Either<Exception, void>> setLanguage(String language);
  Future<Either<Exception, bool>> getSoundEffects();
  Future<Either<Exception, void>> setSoundEffects(bool enabled);
  Future<Either<Exception, String?>> getUsername();
  Future<Either<Exception, void>> setUsername(String username);
  Future<Either<Exception, String>> getSystemPrompt();
  Future<Either<Exception, void>> setSystemPrompt(String prompt);
}
