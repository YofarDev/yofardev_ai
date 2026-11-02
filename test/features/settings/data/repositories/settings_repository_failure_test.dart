import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/failure.dart';
import 'package:yofardev_ai/core/models/result.dart';
import 'package:yofardev_ai/core/models/task_llm_config.dart';
import 'package:yofardev_ai/core/services/settings_local_datasource.dart';
import 'package:yofardev_ai/features/settings/data/repositories/settings_repository_impl.dart';

class MockSettingsLocalDatasource extends Mock
    implements SettingsLocalDatasource {}

void main() {
  late MockSettingsLocalDatasource datasource;
  late SettingsRepositoryImpl repo;

  setUp(() {
    datasource = MockSettingsLocalDatasource();
    repo = SettingsRepositoryImpl(datasource: datasource);
    registerFallbackValue(const TaskLlmConfig());
  });

  test(
    'getLanguage: a timeout maps to NetworkFailure via the mapper',
    () async {
      when(
        () => datasource.getLanguage(),
      ).thenThrow(TimeoutException('timeout', const Duration(seconds: 5)));

      final Result<String?> result = await repo.getLanguage();

      expect(
        result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
        isA<NetworkFailure>(),
      );
    },
  );

  test('getLanguage: a malformed payload maps to StorageFailure', () async {
    when(
      () => datasource.getLanguage(),
    ).thenThrow(const FormatException('not-json'));

    final Result<String?> result = await repo.getLanguage();

    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      isA<StorageFailure>(),
    );
  });

  test('setLanguage: a timeout maps to NetworkFailure', () async {
    when(
      () => datasource.setLanguage(any()),
    ).thenThrow(TimeoutException('timeout', const Duration(seconds: 5)));

    final Result<void> result = await repo.setLanguage('fr');

    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      isA<NetworkFailure>(),
    );
  });

  test('setLanguage: a malformed payload maps to StorageFailure', () async {
    when(
      () => datasource.setLanguage(any()),
    ).thenThrow(const FormatException('not-json'));

    final Result<void> result = await repo.setLanguage('fr');

    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      isA<StorageFailure>(),
    );
  });

  test('getSoundEffects: a timeout maps to NetworkFailure', () async {
    when(
      () => datasource.getSoundEffects(),
    ).thenThrow(TimeoutException('timeout', const Duration(seconds: 5)));

    final Result<bool> result = await repo.getSoundEffects();

    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      isA<NetworkFailure>(),
    );
  });

  test('getSoundEffects: a malformed payload maps to StorageFailure', () async {
    when(
      () => datasource.getSoundEffects(),
    ).thenThrow(const FormatException('not-json'));

    final Result<bool> result = await repo.getSoundEffects();

    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      isA<StorageFailure>(),
    );
  });

  test(
    'getTaskLlmConfig: a timeout maps to NetworkFailure instead of escaping',
    () async {
      when(
        () => datasource.getTaskLlmConfig(),
      ).thenThrow(TimeoutException('timeout', const Duration(seconds: 5)));

      final Result<TaskLlmConfig> result = await repo.getTaskLlmConfig();

      expect(
        result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
        isA<NetworkFailure>(),
      );
    },
  );

  test(
    'getTaskLlmConfig: a malformed payload maps to StorageFailure',
    () async {
      when(
        () => datasource.getTaskLlmConfig(),
      ).thenThrow(const FormatException('not-json'));

      final Result<TaskLlmConfig> result = await repo.getTaskLlmConfig();

      expect(
        result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
        isA<StorageFailure>(),
      );
    },
  );

  test('setTaskLlmConfig: a timeout maps to NetworkFailure', () async {
    when(
      () => datasource.setTaskLlmConfig(any()),
    ).thenThrow(TimeoutException('timeout', const Duration(seconds: 5)));

    final Result<void> result = await repo.setTaskLlmConfig(
      const TaskLlmConfig(),
    );

    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      isA<NetworkFailure>(),
    );
  });

  test(
    'setTaskLlmConfig: a malformed payload maps to StorageFailure',
    () async {
      when(
        () => datasource.setTaskLlmConfig(any()),
      ).thenThrow(const FormatException('not-json'));

      final Result<void> result = await repo.setTaskLlmConfig(
        const TaskLlmConfig(),
      );

      expect(
        result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
        isA<StorageFailure>(),
      );
    },
  );

  test(
    'getPersona maps a stored persona name to the model on success',
    () async {
      when(
        () => datasource.getPersona(),
      ).thenAnswer((_) async => ChatPersona.geek);

      final Result<ChatPersona> result = await repo.getPersona();

      expect(result.getOrNull, ChatPersona.geek);
    },
  );

  test('getPersona: a timeout maps to NetworkFailure', () async {
    when(
      () => datasource.getPersona(),
    ).thenThrow(TimeoutException('timeout', const Duration(seconds: 5)));

    final Result<ChatPersona> result = await repo.getPersona();

    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      isA<NetworkFailure>(),
    );
  });

  test('json round trip: setTaskLlmConfig encodes the model for storage', () {
    const TaskLlmConfig config = TaskLlmConfig(
      assistantLlmId: 'a',
      titleGenerationLlmId: 't',
    );

    final Map<String, dynamic> decoded =
        jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>;

    expect(TaskLlmConfig.fromJson(decoded), config);
  });
}
