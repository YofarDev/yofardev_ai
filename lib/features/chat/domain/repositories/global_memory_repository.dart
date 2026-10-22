import '../../../../core/models/global_memory.dart';
import '../../../../core/models/result.dart';

/// Global memory store: facts about the user shared across all chats
abstract class GlobalMemoryRepository {
  Future<Result<GlobalMemory>> getMemory();

  Future<Result<void>> saveMemory(GlobalMemory memory);

  Future<Result<GlobalMemory>> deleteItem(String id);

  Future<Result<void>> clearAll();
}
