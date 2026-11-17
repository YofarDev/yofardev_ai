import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:{{PROJECT_NAME}}/core/models/failure.dart';
import 'package:{{PROJECT_NAME}}/core/models/result.dart';
import 'package:{{PROJECT_NAME}}/features/{{FEATURE_SNAKE}}/domain/models/{{FEATURE_SNAKE}}.dart';
import 'package:{{PROJECT_NAME}}/features/{{FEATURE_SNAKE}}/domain/repositories/{{FEATURE_SNAKE}}_repository.dart';
import 'package:{{PROJECT_NAME}}/features/{{FEATURE_SNAKE}}/domain/services/{{FEATURE_SNAKE}}_service.dart';

class Mock{{FEATURE_PASCAL}}Repository extends Mock
    implements {{FEATURE_PASCAL}}Repository {}

/// PLACEHOLDER service tests: they only pin the current forwarding behavior.
/// When the service gains actual rules/coordination, replace them with tests
/// of that logic; if the service is removed instead, delete this file with it.
void main() {
  group('{{FEATURE_PASCAL}}Service', () {
    late {{FEATURE_PASCAL}}Service service;
    late Mock{{FEATURE_PASCAL}}Repository mockRepository;

    setUp(() {
      mockRepository = Mock{{FEATURE_PASCAL}}Repository();
      service = {{FEATURE_PASCAL}}Service(mockRepository);
    });

    test('returns the repository result on success', () async {
      when(() => mockRepository.getData()).thenAnswer(
        (_) async => Result<{{FEATURE_PASCAL}}>.ok(
          const {{FEATURE_PASCAL}}(id: '1', name: 'Test'),
        ),
      );

      final Result<{{FEATURE_PASCAL}}> result = await service.getData();

      verify(() => mockRepository.getData()).called(1);
      result.when(
        err: (Failure failure) => fail('Expected Result.ok, got $failure'),
        ok: ({{FEATURE_PASCAL}} data) => expect(data.id, '1'),
      );
    });

    test('forwards failures untouched', () async {
      when(() => mockRepository.getData()).thenAnswer(
        (_) async => Result<{{FEATURE_PASCAL}}>.err(NetworkFailure('offline')),
      );

      final Result<{{FEATURE_PASCAL}}> result = await service.getData();

      result.when(
        ok: ({{FEATURE_PASCAL}} _) => fail('Expected a NetworkFailure'),
        err: (Failure failure) => expect(failure, isA<NetworkFailure>()),
      );
    });
  });
}
