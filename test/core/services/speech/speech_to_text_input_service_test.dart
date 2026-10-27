import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:yofardev_ai/core/services/speech/speech_input_service.dart';
import 'package:yofardev_ai/core/services/speech/speech_to_text_input_service.dart';

class _MockSpeechToText extends Mock implements SpeechToText {}

SpeechRecognitionResult _result(String words, {bool isFinal = false}) =>
    SpeechRecognitionResult.init(<SpeechRecognitionWords>[
      SpeechRecognitionWords(words, null, 0.9),
    ], isFinal ? ResultType.finalResult : ResultType.partial);

void main() {
  group('normaliseSoundLevel', () {
    test('maps the plugin dB range -2..10 onto 0..1', () {
      expect(normaliseSoundLevel(-2), 0);
      expect(normaliseSoundLevel(4), closeTo(0.5, 1e-9));
      expect(normaliseSoundLevel(10), 1);
    });

    test('clamps out-of-range levels', () {
      expect(normaliseSoundLevel(-50), 0);
      expect(normaliseSoundLevel(42), 1);
    });
  });

  group('isSpeechInputSupported', () {
    const Map<String, bool> matrix = <String, bool>{
      'Android': true,
      'iOS': true,
      'Windows': true,
      'Web': false,
      'MacOS': false,
      'Linux': false,
      'Unknown': false,
    };
    for (final MapEntry<String, bool> row in matrix.entries) {
      test('${row.key} -> ${row.value}', () {
        expect(isSpeechInputSupported(row.key), row.value);
      });
    }
  });

  group('SpeechToTextInputService', () {
    late _MockSpeechToText stt;
    late int permissionRequests;
    late bool permissionGranted;
    SpeechResultListener? onResult;
    SpeechSoundLevelChange? onLevel;
    SpeechStatusListener? onStatus;
    SpeechListenOptions? listenOptions;

    SpeechToTextInputService build({String platform = 'Android'}) =>
        SpeechToTextInputService(
          speechToText: stt,
          platform: () => platform,
          requestMicrophonePermission: () async {
            permissionRequests++;
            return permissionGranted;
          },
        );

    setUp(() {
      stt = _MockSpeechToText();
      permissionRequests = 0;
      permissionGranted = true;
      onResult = null;
      onLevel = null;
      onStatus = null;
      listenOptions = null;
      when(
        () => stt.initialize(
          onError: any(named: 'onError'),
          onStatus: any(named: 'onStatus'),
        ),
      ).thenAnswer((Invocation inv) async {
        onStatus = inv.namedArguments[#onStatus] as SpeechStatusListener?;
        return true;
      });
      when(
        () => stt.listen(
          onResult: any(named: 'onResult'),
          onSoundLevelChange: any(named: 'onSoundLevelChange'),
          listenOptions: any(named: 'listenOptions'),
        ),
      ).thenAnswer((Invocation inv) async {
        listenOptions =
            inv.namedArguments[#listenOptions] as SpeechListenOptions?;
        onResult = inv.namedArguments[#onResult] as SpeechResultListener?;
        onLevel =
            inv.namedArguments[#onSoundLevelChange] as SpeechSoundLevelChange?;
      });
      when(() => stt.stop()).thenAnswer((_) async {});
      when(() => stt.cancel()).thenAnswer((_) async {});
    });

    test('unsupported platform: unavailable, no permission prompt', () async {
      final SpeechToTextInputService service = build(platform: 'MacOS');

      expect(service.isSupported, isFalse);
      expect(
        await service.start(localeId: 'en_US'),
        SpeechStartResult.unavailable,
      );
      expect(permissionRequests, 0);
    });

    test('nothing is asked before the first start()', () {
      build();
      expect(permissionRequests, 0);
      verifyNever(
        () => stt.initialize(
          onError: any(named: 'onError'),
          onStatus: any(named: 'onStatus'),
        ),
      );
    });

    test('denied microphone permission: permissionDenied, no init', () async {
      permissionGranted = false;
      final SpeechToTextInputService service = build();

      expect(
        await service.start(localeId: 'en_US'),
        SpeechStartResult.permissionDenied,
      );
      verifyNever(
        () => stt.initialize(
          onError: any(named: 'onError'),
          onStatus: any(named: 'onStatus'),
        ),
      );
    });

    test('plugin that fails to initialise: unavailable', () async {
      when(
        () => stt.initialize(
          onError: any(named: 'onError'),
          onStatus: any(named: 'onStatus'),
        ),
      ).thenAnswer((_) async => false);
      when(() => stt.hasPermission).thenAnswer((_) async => true);

      expect(
        await build().start(localeId: 'en_US'),
        SpeechStartResult.unavailable,
      );
    });

    test('plugin that throws on init: unavailable, never crashes', () async {
      when(
        () => stt.initialize(
          onError: any(named: 'onError'),
          onStatus: any(named: 'onStatus'),
        ),
      ).thenThrow(Exception('no recognizer'));

      expect(
        await build().start(localeId: 'en_US'),
        SpeechStartResult.unavailable,
      );
    });

    test(
      'streams partial words and levels; stop() returns final words',
      () async {
        final SpeechToTextInputService service = build();
        final List<String> partials = <String>[];
        final List<double> levels = <double>[];
        service.partialWords.listen(partials.add);
        service.soundLevel.listen(levels.add);

        expect(
          await service.start(localeId: 'fr_FR'),
          SpeechStartResult.started,
        );
        expect(listenOptions!.localeId, 'fr_FR');
        expect(listenOptions!.partialResults, isTrue);
        onLevel!(4);
        onResult!(_result('bonjour'));

        final Future<String> stopped = service.stop();
        onResult!(_result('bonjour toi', isFinal: true));

        expect(await stopped, 'bonjour toi');
        await Future<void>.delayed(Duration.zero); // deliver stream events
        expect(partials, <String>['bonjour', 'bonjour toi']);
        expect(levels.first, closeTo(0.5, 1e-9));
        verify(() => stt.stop()).called(1);
      },
    );

    test('initialises lazily once and asks permission once', () async {
      final SpeechToTextInputService service = build();

      await service.start(localeId: 'en_US');
      await service.cancel();
      await service.start(localeId: 'en_US');

      expect(permissionRequests, 1);
      verify(
        () => stt.initialize(
          onError: any(named: 'onError'),
          onStatus: any(named: 'onStatus'),
        ),
      ).called(1);
    });

    test('auto-stop: stop() after the plugin reported done still returns '
        'the words', () async {
      final SpeechToTextInputService service = build();
      await service.start(localeId: 'en_US');
      onStatus!(SpeechToText.listeningStatus);
      onResult!(_result('hello', isFinal: true));
      onStatus!(SpeechToText.doneStatus);

      expect(await service.stop(), 'hello');
    });

    test('stop() with nothing heard returns an empty string', () async {
      final SpeechToTextInputService service = build();
      await service.start(localeId: 'en_US');
      onStatus!(SpeechToText.listeningStatus);
      onStatus!(SpeechToText.doneStatus);

      expect(await service.stop(), '');
    });

    test('cancel() drops the words', () async {
      final SpeechToTextInputService service = build();
      await service.start(localeId: 'en_US');
      onResult!(_result('hello'));

      await service.cancel();

      expect(await service.stop(), '');
      verify(() => stt.cancel()).called(1);
    });
  });
}
