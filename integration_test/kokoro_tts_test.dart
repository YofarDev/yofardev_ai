// Kokoro on the real engine (sherpa-onnx), end to end on a desktop or
// device: install (a one-time ~132 MB download from GitHub releases when
// the model is not on disk yet), load, synthesize French and English, and
// feed each WAV to the lip-sync analysis the playback uses.
//
//   flutter test integration_test/kokoro_tts_test.dart -d macos
//
// Not in fverify.sh (native engine, network on first run).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yofardev_ai/core/models/performance/speech_timeline.dart';
import 'package:yofardev_ai/core/models/voice_effect.dart';
import 'package:yofardev_ai/core/services/audio/audio_amplitude_service.dart';
import 'package:yofardev_ai/core/services/audio/wav_pcm.dart';
import 'package:yofardev_ai/core/utils/logger.dart';
import 'package:yofardev_ai/features/sound/data/datasources/kokoro_tts_datasource.dart';
import 'package:yofardev_ai/features/sound/data/kokoro/kokoro_engine.dart';
import 'package:yofardev_ai/features/sound/data/kokoro/kokoro_engine_factory.dart';
import 'package:yofardev_ai/features/sound/data/kokoro/kokoro_model_store.dart';
import 'package:yofardev_ai/features/sound/data/kokoro/kokoro_tts_service.dart';
import 'package:yofardev_ai/features/sound/data/kokoro/model_archive_extractor.dart';
import 'package:yofardev_ai/features/sound/domain/tts_engine_status.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kokoro speaks French and English into lip-sync-ready WAVs', (
    WidgetTester tester,
  ) async {
    final KokoroEngine engine = createKokoroEngine();
    final KokoroTtsService service = KokoroTtsService(
      store: KokoroModelStore(
        client: http.Client(),
        extractor: const ArchivePackageExtractor(),
        supportDirectoryProvider: getApplicationSupportDirectory,
      ),
      engine: engine,
    );

    await tester.runAsync(() async {
      final Stopwatch install = Stopwatch()..start();
      await service.install();
      AppLogger.info(
        'Kokoro install + load: ${install.elapsedMilliseconds} ms',
        tag: 'KokoroTtsTest',
      );
      expect(service.current, const TtsEngineStatus.ready());

      final KokoroTtsDatasource datasource = KokoroTtsDatasource(
        engine: engine,
      );
      final AudioAmplitudeService analysis = AudioAmplitudeService();
      const Map<String, String> sentences = <String, String>{
        'fr': 'Bonjour ! Je suis ravie de te parler aujourd’hui.',
        'en': 'Hello! It is lovely to talk with you today.',
      };
      for (final MapEntry<String, String> sentence in sentences.entries) {
        final Stopwatch synth = Stopwatch()..start();
        final String path = await datasource.synthesize(
          text: sentence.value,
          language: sentence.key,
          voiceEffect: const VoiceEffect(pitch: 1, speedRate: 1),
        );
        final int elapsed = synth.elapsedMilliseconds;

        final WavPcm pcm = WavPcm.decode(
          Uint8List.fromList(await File(path).readAsBytes()),
        );
        expect(pcm.sampleRate, 24000);
        expect(pcm.duration, greaterThan(const Duration(milliseconds: 1500)));
        expect(pcm.duration, lessThan(const Duration(seconds: 8)));

        final List<int> amplitudes = await analysis.extractAmplitudes(path);
        expect(amplitudes.length, greaterThan(40));
        expect(
          amplitudes.reduce((int a, int b) => a > b ? a : b),
          greaterThan(20),
        );

        final SpeechTimeline? timeline = await analysis.analyzeSpeech(
          path,
          text: sentence.value,
          language: sentence.key,
        );
        expect(timeline, isNotNull);
        expect(timeline!.visemes, isNotEmpty);

        AppLogger.info(
          '${sentence.key}: ${pcm.duration.inMilliseconds} ms of audio in '
          '$elapsed ms, ${amplitudes.length} amplitude frames, '
          '${timeline.visemes.length} viseme spans → $path',
          tag: 'KokoroTtsTest',
        );
        // Kept for a listen; the app's sweeper removes stale WAVs.
      }
    });
    await service.dispose();
  });

  // Supertonic, the fallback voice, runs on flutter_onnxruntime: on Android
  // its ONNX Runtime is forced to the one sherpa-onnx bundles (1.24.3, see
  // android/app/build.gradle). This loads one of Supertonic's own models
  // (3.7 MB from Hugging Face) through flutter_onnxruntime in the same
  // process as sherpa-onnx: the JNI link and the session must work.
  // Android only: on macOS / iOS the ORT 1.28 wrapper binds to sherpa's
  // 1.24 library and segfaults, which is why the app has no Supertonic
  // fallback there (service_locator.dart).
  testWidgets('flutter_onnxruntime (Supertonic) loads next to sherpa-onnx', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      final Directory dir = await getTemporaryDirectory();
      final File model = File('${dir.path}/duration_predictor.onnx');
      if (!model.existsSync()) {
        final http.Response response = await http.get(
          Uri.parse(
            'https://huggingface.co/Supertone/supertonic-3/resolve/main/'
            'onnx/duration_predictor.onnx',
          ),
        );
        expect(response.statusCode, 200);
        await model.writeAsBytes(response.bodyBytes);
      }
      final OrtSession session = await OnnxRuntime().createSession(model.path);
      expect(session.inputNames, isNotEmpty);
      expect(session.outputNames, isNotEmpty);
      AppLogger.info(
        'flutter_onnxruntime session: ${session.inputNames} → '
        '${session.outputNames}',
        tag: 'KokoroTtsTest',
      );
      await session.close();
    });
  }, skip: !Platform.isAndroid);
}
