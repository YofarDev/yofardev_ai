import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/failure.dart';
import 'package:yofardev_ai/core/models/result.dart';
import 'package:yofardev_ai/features/sound/data/repositories/sound_repository_impl.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  late MockAudioPlayer player;
  late SoundRepositoryImpl repo;

  setUpAll(() {
    registerFallbackValue(AssetSource('fallback'));
  });

  setUp(() {
    player = MockAudioPlayer();
    repo = SoundRepositoryImpl(player: player);
    when(() => player.stop()).thenAnswer((_) async {});
    when(() => player.setSource(any())).thenAnswer((_) async {});
    when(() => player.setVolume(any())).thenAnswer((_) async {});
    when(() => player.resume()).thenAnswer((_) async {});
  });

  test('an unknown sound id is ok and never touches the player', () async {
    final Result<void> result = await repo.play('not-a-sound');

    expect(result.isOk, isTrue);
    verifyNever(() => player.setSource(any()));
  });

  test('a known sound id maps the asset path and plays it', () async {
    final List<Source> sources = <Source>[];
    when(() => player.setSource(any())).thenAnswer((Invocation inv) async {
      sources.add(inv.positionalArguments[0] as Source);
    });

    final Result<void> result = await repo.play('whoosh');

    expect(result.isOk, isTrue);
    expect(sources.single, isA<AssetSource>());
    expect((sources.single as AssetSource).path, 'sounds/whoosh.mp3');
    verify(() => player.setVolume(1.0)).called(1);
    verify(() => player.resume()).called(1);
  });

  test('a throwing player maps to a typed failure', () async {
    when(() => player.setSource(any())).thenThrow(StateError('no backend'));

    final Result<void> result = await repo.play('whoosh');

    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      isA<UnknownFailure>(),
    );
  });

  test('stop is forwarded and ok', () async {
    final Result<void> result = await repo.stop();

    expect(result.isOk, isTrue);
    verify(() => player.stop()).called(1);
  });
}
