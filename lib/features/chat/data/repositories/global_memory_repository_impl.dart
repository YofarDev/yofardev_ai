import '../../../../core/models/failure.dart';
import '../../../../core/models/global_memory.dart';
import '../../../../core/models/result.dart';
import '../../../../core/repositories/global_memory_repository.dart';
import '../datasources/global_memory_datasource.dart';

class GlobalMemoryRepositoryImpl implements GlobalMemoryRepository {
  final GlobalMemoryLocalDatasource _datasource;

  GlobalMemoryRepositoryImpl({
    required GlobalMemoryLocalDatasource datasource,
  }) : _datasource = datasource;

  @override
  Future<Result<GlobalMemory>> getMemory() async {
    try {
      return Result<GlobalMemory>.ok(await _datasource.getMemory());
    } catch (e) {
      return Result<GlobalMemory>.err(StorageFailure(e.toString(), e));
    }
  }

  @override
  Future<Result<void>> saveMemory(GlobalMemory memory) async {
    try {
      await _datasource.saveMemory(memory);
      return Result<void>.ok(null);
    } catch (e) {
      return Result<void>.err(StorageFailure(e.toString(), e));
    }
  }

  @override
  Future<Result<GlobalMemory>> deleteItem(String id) async {
    try {
      final GlobalMemory memory = await _datasource.getMemory();
      final GlobalMemory updated = memory.copyWith(
        items: memory.items
            .where((GlobalMemoryItem item) => item.id != id)
            .toList(),
      );
      await _datasource.saveMemory(updated);
      return Result<GlobalMemory>.ok(updated);
    } catch (e) {
      return Result<GlobalMemory>.err(StorageFailure(e.toString(), e));
    }
  }

  @override
  Future<Result<void>> clearAll() async {
    try {
      await _datasource.clear();
      return Result<void>.ok(null);
    } catch (e) {
      return Result<void>.err(StorageFailure(e.toString(), e));
    }
  }
}
