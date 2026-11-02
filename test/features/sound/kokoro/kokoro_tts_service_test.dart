import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/failure.dart';
import 'package:yofardev_ai/features/sound/data/kokoro/kokoro_model_store.dart';
import 'package:yofardev_ai/features/sound/data/kokoro/kokoro_tts_service.dart';
import 'package:yofardev_ai/features/sound/domain/tts_engine_status.dart';

import 'kokoro_test_fakes.dart';

void main() {
  late Directory support;

  setUp(() {
    support = Directory.systemTemp.createTempSync('kokoro_service_test');
  });

  tearDown(() => support.deleteSync(recursive: true));

  KokoroTtsService service({
    FakeModelServer? server,
    FakeExtractor? extractor,
    FakeKokoroEngine? engine,
    FakeVoiceBlender? blender,
  }) => KokoroTtsService(
    store: KokoroModelStore(
      client: (server ?? FakeModelServer()).client(),
      extractor: extractor ?? FakeExtractor(),
      supportDirectoryProvider: () async => support,
      modelId: testModelId,
      downloadUrl: 'https://example.test/model.tar.bz2',
      requiredPaths: testRequiredPaths,
    ),
    engine: engine ?? FakeKokoroEngine(),
    voiceBlender: blender ?? FakeVoiceBlender(),
  );

  test('starts not installed, ends ready after download and load', () async {
    final FakeKokoroEngine engine = FakeKokoroEngine();
    final KokoroTtsService subject = service(engine: engine);
    final List<TtsEngineStatus> seen = <TtsEngineStatus>[];
    subject.status.listen(seen.add);
    expect(subject.current, const TtsEngineStatus.notInstalled());

    await subject.install();
    await Future<void>.delayed(Duration.zero);

    expect(subject.current, const TtsEngineStatus.ready());
    expect(engine.isLoaded, isTrue);
    expect(seen.first, const TtsEngineStatus.downloading(null));
    expect(seen, contains(const TtsEngineStatus.extracting()));
    expect(seen.sublist(seen.length - 2), const <TtsEngineStatus>[
      TtsEngineStatus.loading(),
      TtsEngineStatus.ready(),
    ]);
  });

  test('a download failure is failed(NetworkFailure), never thrown', () async {
    final KokoroTtsService subject = service(
      server: FakeModelServer(status: 404),
    );

    await subject.install();

    final TtsEngineStatus status = subject.current;
    expect(status, isA<TtsEngineFailed>());
    expect((status as TtsEngineFailed).failure, isA<NetworkFailure>());
  });

  test('an incomplete archive is failed(StorageFailure)', () async {
    final KokoroTtsService subject = service(
      extractor: FakeExtractor(files: <String>['voices.bin']),
    );

    await subject.install();

    expect((subject.current as TtsEngineFailed).failure, isA<StorageFailure>());
  });

  test('an engine load failure is failed(TtsFailure)', () async {
    final KokoroTtsService subject = service(
      engine: FakeKokoroEngine(loadError: StateError('bad model')),
    );

    await subject.install();

    expect((subject.current as TtsEngineFailed).failure, isA<TtsFailure>());
  });

  test('the voices are blended before the engine loads', () async {
    final FakeVoiceBlender blender = FakeVoiceBlender();
    final FakeKokoroEngine engine = FakeKokoroEngine();
    final KokoroTtsService subject = service(blender: blender, engine: engine);

    await subject.install();

    expect(blender.applied, hasLength(1));
    expect(blender.applied.single.root, engine.loadedPaths!.root);
  });

  test(
    'a blend failure is failed(TtsFailure) and the engine stays unloaded',
    () async {
      final FakeKokoroEngine engine = FakeKokoroEngine();
      final KokoroTtsService subject = service(
        blender: FakeVoiceBlender(
          error: const FileSystemException('bad voices'),
        ),
        engine: engine,
      );

      await subject.install();

      expect((subject.current as TtsEngineFailed).failure, isA<TtsFailure>());
      expect(engine.isLoaded, isFalse);
    },
  );

  test('retry after a failure installs', () async {
    final FakeModelServer server = FakeModelServer(status: 503);
    final KokoroTtsService subject = service(server: server);
    await subject.install();
    expect(subject.current, isA<TtsEngineFailed>());

    server.status = 200;
    await subject.install();

    expect(subject.current, const TtsEngineStatus.ready());
    expect(server.requests, 2);
  });

  test('install is single-flight and a no-op once ready', () async {
    final FakeModelServer server = FakeModelServer();
    final FakeKokoroEngine engine = FakeKokoroEngine();
    final KokoroTtsService subject = service(server: server, engine: engine);

    await Future.wait(<Future<void>>[subject.install(), subject.install()]);
    await subject.install();

    expect(server.requests, 1);
    expect(engine.loads, 1);
  });
}
