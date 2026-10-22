import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:{{PROJECT_NAME}}/core/models/failure.dart';
import 'package:{{PROJECT_NAME}}/features/{{FEATURE_SNAKE}}/domain/models/{{FEATURE_SNAKE}}.dart';
import 'package:{{PROJECT_NAME}}/features/{{FEATURE_SNAKE}}/domain/repositories/{{FEATURE_SNAKE}}_repository.dart';
import 'package:{{PROJECT_NAME}}/features/{{FEATURE_SNAKE}}/domain/services/{{FEATURE_SNAKE}}_service.dart';

class Mock{{FEATURE_PASCAL}}Repository extends Mock
    implements I{{FEATURE_PASCAL}}Repository {}

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
        (_) async => const Right<Failure, {{FEATURE_PASCAL}}>({{FEATURE_PASCAL}}(id: '1', name: 'Test')),
      );

      final Either<Failure, {{FEATURE_PASCAL}}> result = await service.getData();

      verify(() => mockRepository.getData()).called(1);
      result.fold(
        (_) => fail('Expected Right({{FEATURE_PASCAL}})'),
        ({{FEATURE_PASCAL}} data) => expect(data.id, '1'),
      );
    });

    test('forwards failures untouched', () async {
      when(() => mockRepository.getData()).thenAnswer(
        (_) async => const Left<Failure, {{FEATURE_PASCAL}}>(Failure.networkError()),
      );

      final Either<Failure, {{FEATURE_PASCAL}}> result = await service.getData();

      result.fold(
        (Failure failure) => expect(failure, const Failure.networkError()),
        (_) => fail('Expected Left(Failure.networkError)'),
      );
    });
  });
}
