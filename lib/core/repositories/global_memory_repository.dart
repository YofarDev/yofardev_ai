import '../models/global_memory.dart';
import '../models/result.dart';

/// Global memory store: facts about the user shared across all chats.
///
/// Stays in core (like `SettingsRepository`): consumed by both chat and
/// settings; settings → chat through the chat barrel would close a feature
/// dependency cycle (chat widgets already read `SettingsCubit`).
abstract class GlobalMemoryRepository {
  Future<Result<GlobalMemory>> getMemory();

  Future<Result<void>> saveMemory(GlobalMemory memory);

  Future<Result<GlobalMemory>> deleteItem(String id);

  Future<Result<void>> clearAll();
}
