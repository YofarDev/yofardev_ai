import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/failure.dart';
import 'package:yofardev_ai/core/models/result.dart';
import 'package:yofardev_ai/features/avatar/data/datasources/avatar_local_datasource.dart';
import 'package:yofardev_ai/features/avatar/data/repositories/avatar_repository_impl.dart';

class MockAvatarLocalDatasource extends Mock implements AvatarLocalDatasource {}

void main() {
  late MockAvatarLocalDatasource datasource;
  late AvatarRepositoryImpl repo;

  setUp(() {
    datasource = MockAvatarLocalDatasource();
    repo = AvatarRepositoryImpl(datasource: datasource);
  });

  test('a found chat maps through unchanged', () async {
    final Chat chat = Chat(id: 'c1');
    when(
      () => datasource.getChat('c1'),
    ).thenAnswer((_) async => Result<Chat?>.ok(chat));

    final Result<Chat> result = await repo.getChat('c1');

    expect(
      result.when(err: (_) => throw StateError('err'), ok: (Chat c) => c),
      same(chat),
    );
  });

  test('a null chat becomes StorageFailure (not found)', () async {
    when(
      () => datasource.getChat('c1'),
    ).thenAnswer((_) async => Result<Chat?>.ok(null));

    final Result<Chat> result = await repo.getChat('c1');

    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      isA<StorageFailure>(),
    );
  });

  test('a datasource failure passes through untouched', () async {
    const NetworkFailure failure = NetworkFailure('offline');
    when(
      () => datasource.getChat('c1'),
    ).thenAnswer((_) async => Result<Chat?>.err(failure));

    final Result<Chat> result = await repo.getChat('c1');

    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      same(failure),
    );
  });

  test('a throwing datasource maps to a typed failure', () async {
    when(() => datasource.getChat('c1')).thenThrow(TimeoutException('timeout'));

    final Result<Chat> result = await repo.getChat('c1');

    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      isA<NetworkFailure>(),
    );
  });
}
