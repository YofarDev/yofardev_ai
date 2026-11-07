import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/failure.dart';
import 'package:yofardev_ai/core/models/global_memory.dart';
import 'package:yofardev_ai/core/models/result.dart';
import 'package:yofardev_ai/features/chat/data/datasources/global_memory_datasource.dart';
import 'package:yofardev_ai/features/chat/data/repositories/global_memory_repository_impl.dart';

class MockGlobalMemoryLocalDatasource extends Mock
    implements GlobalMemoryLocalDatasource {}

void main() {
  late MockGlobalMemoryLocalDatasource datasource;
  late GlobalMemoryRepositoryImpl repo;

  setUpAll(() {
    registerFallbackValue(GlobalMemory(items: <GlobalMemoryItem>[]));
  });

  setUp(() {
    datasource = MockGlobalMemoryLocalDatasource();
    repo = GlobalMemoryRepositoryImpl(datasource: datasource);
  });

  test('getMemory returns the datasource value', () async {
    final GlobalMemory memory = GlobalMemory(
      items: <GlobalMemoryItem>[
        GlobalMemoryItem(
          id: 'a',
          text: 'likes tea',
          updatedAt: DateTime(2026, 1, 1),
        ),
      ],
    );
    when(() => datasource.getMemory()).thenAnswer((_) async => memory);

    final Result<GlobalMemory> result = await repo.getMemory();

    expect(
      result.when(
        err: (_) => throw StateError('err'),
        ok: (GlobalMemory m) => m,
      ),
      same(memory),
    );
  });

  test('deleteItem removes only the named item and persists the rest',
      () async {
    final GlobalMemoryItem keep = GlobalMemoryItem(
      id: 'keep',
      text: 'keep',
      updatedAt: DateTime(2026, 1, 1),
    );
    final GlobalMemoryItem drop = GlobalMemoryItem(
      id: 'drop',
      text: 'drop',
      updatedAt: DateTime(2026, 1, 2),
    );
    when(() => datasource.getMemory())
        .thenAnswer((_) async => GlobalMemory(
              items: <GlobalMemoryItem>[keep, drop],
            ));
    final List<GlobalMemory> saved = <GlobalMemory>[];
    when(() => datasource.saveMemory(any())).thenAnswer(
      (Invocation inv) async => saved.add(
        inv.positionalArguments[0] as GlobalMemory,
      ),
    );

    final Result<GlobalMemory> result = await repo.deleteItem('drop');

    result.when(
      err: (_) => throw StateError('err'),
      ok: (GlobalMemory m) => expect(m.items, <GlobalMemoryItem>[keep]),
    );
    expect(saved.single.items, <GlobalMemoryItem>[keep]);
  });

  test('a throwing datasource maps to a typed failure', () async {
    when(() => datasource.getMemory())
        .thenThrow(const FormatException('not-json'));

    final Result<GlobalMemory> result = await repo.getMemory();

    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      isA<StorageFailure>(),
    );
  });

  test('clearAll forwards and returns ok', () async {
    when(() => datasource.clear()).thenAnswer((_) async {});

    final Result<void> result = await repo.clearAll();

    expect(result.isOk, isTrue);
    verify(() => datasource.clear()).called(1);
  });
}
