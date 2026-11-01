import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yofardev_ai/features/sound/data/kokoro/kokoro_model_paths.dart';
import 'package:yofardev_ai/features/sound/data/kokoro/kokoro_model_spec.dart';
import 'package:yofardev_ai/features/sound/data/kokoro/kokoro_model_store.dart';
import 'package:yofardev_ai/features/sound/domain/tts_engine_status.dart';

import 'kokoro_test_fakes.dart';

void main() {
  late Directory support;
  late List<TtsEngineStatus> statuses;

  KokoroModelStore store(FakeModelServer server, FakeExtractor extractor) =>
      KokoroModelStore(
        client: server.client(),
        extractor: extractor,
        supportDirectoryProvider: () async => support,
        modelId: testModelId,
        downloadUrl: 'https://example.test/model.tar.bz2',
        requiredPaths: testRequiredPaths,
      );

  String tts(String name) => p.join(support.path, 'tts', name);

  setUp(() {
    support = Directory.systemTemp.createTempSync('kokoro_store_test');
    statuses = <TtsEngineStatus>[];
  });

  tearDown(() => support.deleteSync(recursive: true));

  test('installs: downloads with progress, extracts, marks ready', () async {
    final FakeModelServer server = FakeModelServer();
    final KokoroModelStore subject = store(server, FakeExtractor());

    final KokoroModelPaths paths = await subject.install(
      onStatus: statuses.add,
    );

    expect(paths.root, tts(testModelId));
    expect(File(p.join(paths.root, 'model.onnx')).existsSync(), isTrue);
    expect(File(p.join(paths.root, '.ready')).existsSync(), isTrue);
    expect(await subject.isInstalled(), isTrue);
    expect(statuses.first, const TtsEngineStatus.downloading(null));
    expect(statuses.last, const TtsEngineStatus.extracting());
    final List<double> progress = statuses
        .whereType<TtsEngineDownloading>()
        .map((TtsEngineDownloading s) => s.progress)
        .whereType<double>()
        .toList();
    expect(progress, isNotEmpty);
    expect(progress.last, 1.0);
    for (int i = 1; i < progress.length; i++) {
      expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
    }
    // No archive or staging folder left behind.
    expect(Directory(p.join(support.path, 'tts')).listSync().length, 1);
  });

  test('an installed model is not downloaded again', () async {
    final FakeModelServer server = FakeModelServer();
    await store(server, FakeExtractor()).install(onStatus: statuses.add);

    final KokoroModelStore again = store(server, FakeExtractor());
    await again.install(onStatus: statuses.add);

    expect(server.requests, 1);
  });

  test('HTTP error throws ModelDownloadException, nothing left', () async {
    final KokoroModelStore subject = store(
      FakeModelServer(status: 500),
      FakeExtractor(),
    );

    await expectLater(
      subject.install(onStatus: statuses.add),
      throwsA(isA<ModelDownloadException>()),
    );
    expect(Directory(p.join(support.path, 'tts')).listSync(), isEmpty);
    expect(await subject.isInstalled(), isFalse);
  });

  test('a short body throws ModelDownloadException', () async {
    final KokoroModelStore subject = store(
      FakeModelServer(declaredLength: 5000),
      FakeExtractor(),
    );

    await expectLater(
      subject.install(onStatus: statuses.add),
      throwsA(isA<ModelDownloadException>()),
    );
    expect(Directory(p.join(support.path, 'tts')).listSync(), isEmpty);
  });

  test('an extraction error wipes the staging folder', () async {
    final KokoroModelStore subject = store(
      FakeModelServer(),
      FakeExtractor(error: const FormatException('bad bz2')),
    );

    await expectLater(
      subject.install(onStatus: statuses.add),
      throwsA(isA<FormatException>()),
    );
    expect(Directory(p.join(support.path, 'tts')).listSync(), isEmpty);
  });

  test('a missing required file throws ModelLayoutException', () async {
    final KokoroModelStore subject = store(
      FakeModelServer(),
      FakeExtractor(files: <String>['model.onnx']),
    );

    await expectLater(
      subject.install(onStatus: statuses.add),
      throwsA(isA<ModelLayoutException>()),
    );
    expect(await subject.isInstalled(), isFalse);
    expect(Directory(p.join(support.path, 'tts')).listSync(), isEmpty);
  });

  test('concurrent installs share one download', () async {
    final Completer<void> gate = Completer<void>();
    final FakeModelServer server = FakeModelServer(gate: gate);
    final FakeExtractor extractor = FakeExtractor();
    final KokoroModelStore subject = store(server, extractor);

    final Future<KokoroModelPaths> first = subject.install(
      onStatus: statuses.add,
    );
    final Future<KokoroModelPaths> second = subject.install(
      onStatus: statuses.add,
    );
    gate.complete();
    await Future.wait(<Future<KokoroModelPaths>>[first, second]);

    expect(server.requests, 1);
    expect(extractor.calls, 1);
  });

  test('leftovers of a killed run and older models are removed', () async {
    Directory(tts('kokoro-old')).createSync(recursive: true);
    File(tts('$testModelId.tar.bz2.part'))
      ..createSync(recursive: true)
      ..writeAsStringSync('half');
    Directory(tts('$testModelId.tmp')).createSync(recursive: true);

    await store(
      FakeModelServer(),
      FakeExtractor(),
    ).install(onStatus: statuses.add);

    final List<String> left = Directory(
      p.join(support.path, 'tts'),
    ).listSync().map((FileSystemEntity e) => p.basename(e.path)).toList();
    expect(left, <String>[testModelId]);
  });

  test('the shipped spec names the GitHub release and sherpa layout', () {
    expect(KokoroModelSpec.downloadUrl, startsWith('https://github.com/'));
    expect(
      KokoroModelSpec.downloadUrl,
      endsWith('${KokoroModelSpec.modelId}.tar.bz2'),
    );
    expect(KokoroModelSpec.requiredPaths, contains('espeak-ng-data'));
    const KokoroModelPaths paths = KokoroModelPaths('/m');
    expect(paths.lexicon, '/m/lexicon-us-en.txt');
  });
}
