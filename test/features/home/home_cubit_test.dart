import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/services/app_lifecycle_service.dart';
import 'package:yofardev_ai/features/home/domain/repositories/home_repository.dart';
import 'package:yofardev_ai/features/home/presentation/bloc/home_cubit.dart';
import 'package:yofardev_ai/features/home/presentation/bloc/home_state.dart';

class MockHomeRepository extends Mock implements HomeRepository {}

void main() {
  late MockHomeRepository repository;
  late AppLifecycleService lifecycle;
  late HomeCubit cubit;

  setUp(() {
    repository = MockHomeRepository();
    lifecycle = AppLifecycleService();
    cubit = HomeCubit(repository, lifecycle);
    // initialize() is pure (it only emits isInitialized); the repository is
    // touched by startVolumeFade/playTts and by dispose() on close.
    when(() => repository.startVolumeFade(any())).thenAnswer((_) async {});
    when(
      () => repository.playTts(
        any(),
        removeFile: any(named: 'removeFile'),
        soundEffectsEnabled: any(named: 'soundEffectsEnabled'),
        onComplete: any(named: 'onComplete'),
      ),
    ).thenAnswer((_) async {});
    when(() => repository.stopTts()).thenAnswer((_) async {});
  });

  tearDown(() async => cubit.close());

  test('initialize flips isInitialized', () async {
    await cubit.initialize();
    expect(cubit.state.isInitialized, isTrue);
  });

  test('a repository failure does not crash the cubit', () async {
    // Re-stub ONE repository call with a failure (throwing) result.
    when(() => repository.startVolumeFade(any())).thenThrow(StateError('disk'));

    await expectLater(cubit.startVolumeFade(true), throwsA(isA<StateError>()));
    // The optimistic isFading emission already happened before the repo call.
    expect(cubit.state.isFading, isTrue);
    expect(cubit.state, isA<HomeState>());

    // The cubit stays usable afterwards.
    await cubit.initialize();
    expect(cubit.state.isInitialized, isTrue);
  });
}
