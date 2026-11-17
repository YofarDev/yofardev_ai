import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:{{PROJECT_NAME}}/core/models/failure.dart';
import 'package:{{PROJECT_NAME}}/core/models/result.dart';
import 'package:{{PROJECT_NAME}}/features/{{FEATURE_SNAKE}}/domain/models/{{FEATURE_SNAKE}}.dart';
import '{{CUBIT_TEST_MOCK_IMPORT}}';
import 'package:{{PROJECT_NAME}}/features/{{FEATURE_SNAKE}}/presentation/bloc/{{FEATURE_SNAKE}}_cubit.dart';
import 'package:{{PROJECT_NAME}}/features/{{FEATURE_SNAKE}}/presentation/bloc/{{FEATURE_SNAKE}}_state.dart';

class Mock{{CUBIT_TEST_MOCK_TYPE}} extends Mock implements {{CUBIT_TEST_MOCK_TYPE}} {}

/// State transitions of {{FEATURE_PASCAL}}Cubit. Request ordering and close
/// safety come from `LatestRequestWins` and are tested once in core — add
/// cases here only for logic this cubit owns.
void main() {
  group('{{FEATURE_PASCAL}}Cubit', () {
    // One shared instance: [Failure] has no == override, so identity is what
    // makes the emitted and expected error states equal.
    const NetworkFailure failure = NetworkFailure('offline');
    late {{FEATURE_PASCAL}}Cubit cubit;
    late Mock{{CUBIT_TEST_MOCK_TYPE}} mockSource;

    setUp(() {
      mockSource = Mock{{CUBIT_TEST_MOCK_TYPE}}();
      cubit = {{FEATURE_PASCAL}}Cubit(mockSource);
    });

    tearDown(() {
      cubit.close();
    });

    test('initial state is initial', () {
      expect(cubit.state, const {{FEATURE_PASCAL}}State.initial());
    });

    blocTest<{{FEATURE_PASCAL}}Cubit, {{FEATURE_PASCAL}}State>(
      'emits [loading, loaded] when loadData is successful',
      build: () {
        when(() => mockSource.getData()).thenAnswer(
          (_) async => Result<{{FEATURE_PASCAL}}>.ok(
            const {{FEATURE_PASCAL}}(id: '1', name: 'Test'),
          ),
        );
        return cubit;
      },
      act: ({{FEATURE_PASCAL}}Cubit cubit) => cubit.loadData(),
      expect: () => <{{FEATURE_PASCAL}}State>[
        const {{FEATURE_PASCAL}}State.loading(),
        const {{FEATURE_PASCAL}}State.loaded({{FEATURE_PASCAL}}(id: '1', name: 'Test')),
      ],
    );

    blocTest<{{FEATURE_PASCAL}}Cubit, {{FEATURE_PASCAL}}State>(
      'emits [loading, error] when loadData fails',
      build: () {
        when(() => mockSource.getData()).thenAnswer(
          (_) async => Result<{{FEATURE_PASCAL}}>.err(failure),
        );
        return cubit;
      },
      act: ({{FEATURE_PASCAL}}Cubit cubit) => cubit.loadData(),
      expect: () => <{{FEATURE_PASCAL}}State>[
        const {{FEATURE_PASCAL}}State.loading(),
        {{FEATURE_PASCAL}}State.error(failure: failure),
      ],
    );
  });
}
