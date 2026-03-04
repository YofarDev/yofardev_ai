import 'package:fpdart/fpdart.dart';

import '../../../chat/domain/models/chat.dart';
import '../../../../core/models/task_llm_config.dart';

abstract class SettingsRepository {
  Future<Either<Exception, String?>> getLanguage();
  Future<Either<Exception, void>> setLanguage(String language);
  Future<Either<Exception, bool>> getSoundEffects();
  Future<Either<Exception, void>> setSoundEffects(bool enabled);
  Future<Either<Exception, String?>> getUsername();
  Future<Either<Exception, void>> setUsername(String username);
  Future<Either<Exception, String>> getSystemPrompt();
  Future<Either<Exception, void>> setSystemPrompt(String prompt);
  Future<Either<Exception, ChatPersona>> getPersona();
  Future<Either<Exception, void>> setPersona(ChatPersona persona);

  // NEW METHODS:
  /// Get the task-specific LLM configuration
  Future<Either<Exception, TaskLlmConfig>> getTaskLlmConfig();

  /// Save the task-specific LLM configuration
  Future<Either<Exception, void>> setTaskLlmConfig(TaskLlmConfig config);
}
