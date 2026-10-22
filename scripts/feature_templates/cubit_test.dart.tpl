import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:{{PROJECT_NAME}}/core/models/failure.dart';
import 'package:{{PROJECT_NAME}}/features/{{FEATURE_SNAKE}}/domain/models/{{FEATURE_SNAKE}}.dart';
import '{{CUBIT_TEST_MOCK_IMPORT}}';
import 'package:{{PROJECT_NAME}}/features/{{FEATURE_SNAKE}}/presentation/bloc/{{FEATURE_SNAKE}}_cubit.dart';
import 'package:{{PROJECT_NAME}}/features/{{FEATURE_SNAKE}}/presentation/bloc/{{FEATURE_SNAKE}}_state.dart';

class Mock{{CUBIT_TEST_MOCK_TYPE}} extends Mock implements {{CUBIT_TEST_MOCK_TYPE}} {}

/// Tests for the {{FEATURE_PASCAL}}Cubit, including the deliberate async
/// lifecycle semantics: latest-request-wins reads, no emission after close,
/// and stale failures that cannot overwrite newer successes.
void main() {
  group('{{FEATURE_PASCAL}}Cubit', () {
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
          (_) async => const Right<Failure, {{FEATURE_PASCAL}}>({{FEATURE_PASCAL}}(id: '1', name: 'Test')),
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
          (_) async => const Left<Failure, {{FEATURE_PASCAL}}>(Failure.networkError()),
        );
        return cubit;
      },
      act: ({{FEATURE_PASCAL}}Cubit cubit) => cubit.loadData(),
      expect: () => <{{FEATURE_PASCAL}}State>[
        const {{FEATURE_PASCAL}}State.loading(),
        const {{FEATURE_PASCAL}}State.error(failure: Failure.networkError()),
      ],
    );

    test('a success completing after close does not emit or throw', () async {
      final Completer<Either<Failure, {{FEATURE_PASCAL}}>> completer =
          Completer<Either<Failure, {{FEATURE_PASCAL}}>>();
      when(() => mockSource.getData()).thenAnswer((_) => completer.future);

      final List<{{FEATURE_PASCAL}}State> emissions = <{{FEATURE_PASCAL}}State>[];
      final StreamSubscription<{{FEATURE_PASCAL}}State> subscription =
          cubit.stream.listen(emissions.add);

      final Future<void> load = cubit.loadData();
      await cubit.close();
      completer.complete(
        const Right<Failure, {{FEATURE_PASCAL}}>({{FEATURE_PASCAL}}(id: '1', name: 'Late')),
      );

      // Does not throw (emit on a closed cubit would).
      await load;
      // Flush the microtask queue so the broadcast state stream delivers
      // queued emissions before the subscription is cancelled.
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      expect(emissions, <{{FEATURE_PASCAL}}State>[const {{FEATURE_PASCAL}}State.loading()]);
    });

    test('a failure completing after close does not emit or throw', () async {
      final Completer<Either<Failure, {{FEATURE_PASCAL}}>> completer =
          Completer<Either<Failure, {{FEATURE_PASCAL}}>>();
      when(() => mockSource.getData()).thenAnswer((_) => completer.future);

      final List<{{FEATURE_PASCAL}}State> emissions = <{{FEATURE_PASCAL}}State>[];
      final StreamSubscription<{{FEATURE_PASCAL}}State> subscription =
          cubit.stream.listen(emissions.add);

      final Future<void> load = cubit.loadData();
      await cubit.close();
      completer.complete(
        const Left<Failure, {{FEATURE_PASCAL}}>(Failure.unauthorized()),
      );

      await load;
      // Flush the microtask queue so the broadcast state stream delivers
      // queued emissions before the subscription is cancelled.
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      expect(emissions, <{{FEATURE_PASCAL}}State>[const {{FEATURE_PASCAL}}State.loading()]);
    });

    test('two reads completed in reverse order retain the newer result', () async {
      final Completer<Either<Failure, {{FEATURE_PASCAL}}>> first =
          Completer<Either<Failure, {{FEATURE_PASCAL}}>>();
      final Completer<Either<Failure, {{FEATURE_PASCAL}}>> second =
          Completer<Either<Failure, {{FEATURE_PASCAL}}>>();
      int call = 0;
      when(() => mockSource.getData()).thenAnswer((_) {
        call++;
        return call == 1 ? first.future : second.future;
      });

      final List<{{FEATURE_PASCAL}}State> emissions = <{{FEATURE_PASCAL}}State>[];
      final StreamSubscription<{{FEATURE_PASCAL}}State> subscription =
          cubit.stream.listen(emissions.add);

      final Future<void> firstLoad = cubit.loadData();
      final Future<void> secondLoad = cubit.loadData();

      // The newer request completes first; then the stale older one resolves.
      second.complete(
        const Right<Failure, {{FEATURE_PASCAL}}>({{FEATURE_PASCAL}}(id: '2', name: 'Newer')),
      );
      await secondLoad;
      first.complete(
        const Right<Failure, {{FEATURE_PASCAL}}>({{FEATURE_PASCAL}}(id: '1', name: 'Older')),
      );
      await firstLoad;

      // Flush the microtask queue so the broadcast state stream delivers
      // queued emissions before the subscription is cancelled.
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      expect(emissions.last, const {{FEATURE_PASCAL}}State.loaded({{FEATURE_PASCAL}}(id: '2', name: 'Newer')));
    });

    test('a stale failure cannot overwrite a newer success', () async {
      final Completer<Either<Failure, {{FEATURE_PASCAL}}>> first =
          Completer<Either<Failure, {{FEATURE_PASCAL}}>>();
      final Completer<Either<Failure, {{FEATURE_PASCAL}}>> second =
          Completer<Either<Failure, {{FEATURE_PASCAL}}>>();
      int call = 0;
      when(() => mockSource.getData()).thenAnswer((_) {
        call++;
        return call == 1 ? first.future : second.future;
      });

      final List<{{FEATURE_PASCAL}}State> emissions = <{{FEATURE_PASCAL}}State>[];
      final StreamSubscription<{{FEATURE_PASCAL}}State> subscription =
          cubit.stream.listen(emissions.add);

      final Future<void> firstLoad = cubit.loadData();
      final Future<void> secondLoad = cubit.loadData();

      second.complete(
        const Right<Failure, {{FEATURE_PASCAL}}>({{FEATURE_PASCAL}}(id: '2', name: 'Newer')),
      );
      await secondLoad;
      first.complete(
        const Left<Failure, {{FEATURE_PASCAL}}>(Failure.networkError()),
      );
      await firstLoad;

      // Flush the microtask queue so the broadcast state stream delivers
      // queued emissions before the subscription is cancelled.
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      expect(
        emissions.last,
        isNot(const {{FEATURE_PASCAL}}State.error(failure: Failure.networkError())),
      );
      expect(emissions.last, const {{FEATURE_PASCAL}}State.loaded({{FEATURE_PASCAL}}(id: '2', name: 'Newer')));
    });

    test('a failed current request is followed by a successful retry', () async {
      final Completer<Either<Failure, {{FEATURE_PASCAL}}>> first =
          Completer<Either<Failure, {{FEATURE_PASCAL}}>>();
      when(() => mockSource.getData()).thenAnswer((_) => first.future);

      final List<{{FEATURE_PASCAL}}State> emissions = <{{FEATURE_PASCAL}}State>[];
      final StreamSubscription<{{FEATURE_PASCAL}}State> subscription =
          cubit.stream.listen(emissions.add);

      final Future<void> failedLoad = cubit.loadData();
      first.complete(
        const Left<Failure, {{FEATURE_PASCAL}}>(Failure.networkError()),
      );
      await failedLoad;

      when(() => mockSource.getData()).thenAnswer(
        (_) async => const Right<Failure, {{FEATURE_PASCAL}}>({{FEATURE_PASCAL}}(id: '2', name: 'Retry')),
      );
      await cubit.loadData();

      // Flush the microtask queue so the broadcast state stream delivers
      // queued emissions before the subscription is cancelled.
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      expect(emissions, <{{FEATURE_PASCAL}}State>[
        const {{FEATURE_PASCAL}}State.loading(),
        const {{FEATURE_PASCAL}}State.error(failure: Failure.networkError()),
        const {{FEATURE_PASCAL}}State.loading(),
        const {{FEATURE_PASCAL}}State.loaded({{FEATURE_PASCAL}}(id: '2', name: 'Retry')),
      ]);
    });
  });
}
