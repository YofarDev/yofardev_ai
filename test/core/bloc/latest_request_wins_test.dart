import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/bloc/latest_request_wins.dart';

/// Minimal cubit using the mixin. The result type is generic, so these tests
/// cover successes and failures alike (an `Either` is just another `T`).
class _ProbeCubit extends Cubit<String> with LatestRequestWins<String> {
  _ProbeCubit() : super('initial');

  Future<void> load(Future<String> Function() request) => runLatest<String>(
    request,
    onStart: () => emit('loading'),
    onResult: emit,
  );
}

void main() {
  late _ProbeCubit cubit;
  late List<String> emissions;
  late StreamSubscription<String> subscription;

  setUp(() {
    cubit = _ProbeCubit();
    emissions = <String>[];
    subscription = cubit.stream.listen(emissions.add);
  });

  tearDown(() async {
    await subscription.cancel();
    await cubit.close();
  });

  // Lets the broadcast state stream deliver queued emissions.
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  test('delivers the result of a single request', () async {
    await cubit.load(() async => 'a');
    await flush();

    expect(emissions, <String>['loading', 'a']);
  });

  test('responses completed in reverse order keep the newest', () async {
    final Completer<String> older = Completer<String>();
    final Completer<String> newer = Completer<String>();

    final Future<void> first = cubit.load(() => older.future);
    final Future<void> second = cubit.load(() => newer.future);
    newer.complete('newer');
    await second;
    older.complete('older');
    await first;
    await flush();

    // One 'loading': a Cubit never re-emits a state equal to the current one.
    expect(emissions, <String>['loading', 'newer']);
  });

  test('a result completing after close is dropped without throwing', () async {
    final Completer<String> pending = Completer<String>();

    final Future<void> load = cubit.load(() => pending.future);
    await cubit.close();
    pending.complete('late');
    await load;
    await flush();

    expect(emissions, <String>['loading']);
  });

  test('a request started after close does nothing', () async {
    await cubit.close();
    bool requested = false;

    await cubit.load(() async {
      requested = true;
      return 'never';
    });

    expect(requested, isFalse);
    expect(emissions, isEmpty);
  });
}
