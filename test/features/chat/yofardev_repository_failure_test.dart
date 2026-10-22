import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/failure.dart';
import 'package:yofardev_ai/core/models/result.dart';
import 'package:yofardev_ai/features/chat/data/datasources/chat_local_datasource.dart';
import 'package:yofardev_ai/features/chat/data/repositories/yofardev_repository_impl.dart';

class MockChatLocalDatasource extends Mock implements ChatLocalDatasource {}

void main() {
  late MockChatLocalDatasource datasource;
  late YofardevRepositoryImpl repo;

  setUp(() {
    datasource = MockChatLocalDatasource();
    repo = YofardevRepositoryImpl(chatDatasource: datasource);
  });

  test('a timeout maps to NetworkFailure via the boundary mapper', () async {
    when(
      () => datasource.getChatsList(),
    ).thenThrow(TimeoutException('timeout', const Duration(seconds: 5)));

    final Result<List<Chat>> result = await repo.getChatsList();

    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      isA<NetworkFailure>(),
    );
  });

  test(
    'a malformed payload maps to a typed Failure instead of escaping',
    () async {
      when(
        () => datasource.getChatsList(),
      ).thenThrow(const FormatException('not-json'));

      final Result<List<Chat>> result = await repo.getChatsList();

      expect(result.getOrNull, isNull);
      expect(
        result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
        isA<Failure>(),
      );
    },
  );
}
