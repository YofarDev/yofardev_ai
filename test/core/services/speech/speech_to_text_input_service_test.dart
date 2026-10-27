import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
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
    SpeechErrorListener? onError;

    /// Holds the first-use permission dialog open until completed.
    Completer<bool>? permissionDialog;

    SpeechToTextInputService build({String platform = 'Android'}) =>
        SpeechToTextInputService(
          speechToText: stt,
          platform: () => platform,
          requestMicrophonePermission: () async {
            permissionRequests++;
            final Completer<bool>? dialog = permissionDialog;
            return dialog == null ? permissionGranted : dialog.future;
          },
        );

    void verifyNeverListened() => verifyNever(
      () => stt.listen(
        onResult: any(named: 'onResult'),
        onSoundLevelChange: any(named: 'onSoundLevelChange'),
        listenOptions: any(named: 'listenOptions'),
      ),
    );

    setUp(() {
      stt = _MockSpeechToText();
      permissionRequests = 0;
      permissionGranted = true;
      onResult = null;
      onLevel = null;
      onStatus = null;
      listenOptions = null;
      onError = null;
      permissionDialog = null;
      when(
        () => stt.initialize(
          onError: any(named: 'onError'),
          onStatus: any(named: 'onStatus'),
        ),
      ).thenAnswer((Invocation inv) async {
        onStatus = inv.namedArguments[#onStatus] as SpeechStatusListener?;
        onError = inv.namedArguments[#onError] as SpeechErrorListener?;
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

    test('a permanent recognizer error ends the session with the words '
        'heard so far', () async {
      final SpeechToTextInputService service = build();
      await service.start(localeId: 'en_US');
      onResult!(_result('hello wor'));

      onError!(SpeechRecognitionError('error_network', true));

      expect(await service.stop(), 'hello wor');
      // Ended by the error: the next start opens a fresh session.
      expect(await service.start(localeId: 'en_US'), SpeechStartResult.started);
    });

    test('a transient recognizer error keeps the session open', () async {
      final SpeechToTextInputService service = build();
      await service.start(localeId: 'en_US');
      onResult!(_result('hello'));

      onError!(SpeechRecognitionError('error_speech_timeout', false));
      final Future<String> stopped = service.stop();
      onResult!(_result('hello there', isFinal: true));

      expect(await stopped, 'hello there');
    });

    group('sessionEnded', () {
      Future<int> countEnds(
        SpeechToTextInputService service,
        Future<void> Function() act,
      ) async {
        int ends = 0;
        final StreamSubscription<void> sub = service.sessionEnded.listen(
          (_) => ends++,
        );
        await act();
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();
        return ends;
      }

      test('fires when the recognizer reports done on its own', () async {
        final SpeechToTextInputService service = build();
        await service.start(localeId: 'en_US');
        onStatus!(SpeechToText.listeningStatus);
        onResult!(_result('hello'));

        final int ends = await countEnds(service, () async {
          onStatus!(SpeechToText.doneStatus);
        });

        expect(ends, 1);
        expect(await service.stop(), 'hello');
      });

      test('fires on a final result and on a permanent error', () async {
        final SpeechToTextInputService service = build();
        await service.start(localeId: 'en_US');
        expect(
          await countEnds(service, () async {
            onResult!(_result('hi', isFinal: true));
          }),
          1,
        );
        await service.stop();

        await service.start(localeId: 'en_US');
        expect(
          await countEnds(service, () async {
            onError!(SpeechRecognitionError('error_network', true));
          }),
          1,
        );
      });

      test('fires after notListening when done never comes', () {
        fakeAsync((FakeAsync async) {
          final SpeechToTextInputService service = build();
          int ends = 0;
          service.sessionEnded.listen((_) => ends++);
          service.start(localeId: 'en_US');
          async.flushMicrotasks();
          onStatus!(SpeechToText.listeningStatus);
          onStatus!(SpeechToText.notListeningStatus);

          async.elapse(
            SpeechToTextInputService.finalResultTimeout -
                const Duration(milliseconds: 1),
          );
          expect(ends, 0, reason: 'done may still bring the final words');
          async.elapse(const Duration(milliseconds: 2));
          expect(ends, 1);
        });
      });

      test('never fires for stop() or cancel()', () async {
        final SpeechToTextInputService service = build();
        await service.start(localeId: 'en_US');
        onStatus!(SpeechToText.listeningStatus);
        expect(
          await countEnds(service, () async {
            final Future<String> stopped = service.stop();
            // The plugin answers a stop with its final result, then done.
            onResult!(_result('hello', isFinal: true));
            onStatus!(SpeechToText.doneStatus);
            await stopped;
          }),
          0,
        );

        await service.start(localeId: 'en_US');
        onStatus!(SpeechToText.listeningStatus);
        expect(await countEnds(service, service.cancel), 0);
      });
    });

    group('races', () {
      test('overlapping start() calls listen only once', () async {
        permissionDialog = Completer<bool>();
        final SpeechToTextInputService service = build();

        final Future<SpeechStartResult> first = service.start(
          localeId: 'en_US',
        );
        final Future<SpeechStartResult> second = service.start(
          localeId: 'en_US',
        );
        permissionDialog!.complete(true);

        expect(await first, SpeechStartResult.started);
        expect(await second, SpeechStartResult.started);
        expect(permissionRequests, 1);
        verify(
          () => stt.listen(
            onResult: any(named: 'onResult'),
            onSoundLevelChange: any(named: 'onSoundLevelChange'),
            listenOptions: any(named: 'listenOptions'),
          ),
        ).called(1);
      });

      test('stop() during the first-use permission dialog keeps the mic '
          'closed', () async {
        permissionDialog = Completer<bool>();
        final SpeechToTextInputService service = build();

        final Future<SpeechStartResult> starting = service.start(
          localeId: 'en_US',
        );
        expect(await service.stop(), '');
        permissionDialog!.complete(true);

        expect(await starting, SpeechStartResult.cancelled);
        verifyNeverListened();

        // The granted permission is kept: the next start needs no dialog.
        permissionDialog = null;
        expect(
          await service.start(localeId: 'en_US'),
          SpeechStartResult.started,
        );
        expect(permissionRequests, 1);
      });

      test('start() after a stop superseded a pending start opens a fresh '
          'session', () async {
        permissionDialog = Completer<bool>();
        final SpeechToTextInputService service = build();

        final Future<SpeechStartResult> first = service.start(
          localeId: 'en_US',
        );
        expect(await service.stop(), '');
        final Future<SpeechStartResult> second = service.start(
          localeId: 'en_US',
        );
        permissionDialog!.complete(true);

        expect(await first, SpeechStartResult.cancelled);
        expect(await second, SpeechStartResult.started);
        verify(
          () => stt.listen(
            onResult: any(named: 'onResult'),
            onSoundLevelChange: any(named: 'onSoundLevelChange'),
            listenOptions: any(named: 'listenOptions'),
          ),
        ).called(1);
      });

      test('a restart stopped again before the stale start settles keeps the '
          'mic closed', () async {
        permissionDialog = Completer<bool>();
        final SpeechToTextInputService service = build();

        final Future<SpeechStartResult> first = service.start(
          localeId: 'en_US',
        );
        await service.stop();
        final Future<SpeechStartResult> second = service.start(
          localeId: 'en_US',
        );
        await service.stop();
        permissionDialog!.complete(true);

        expect(await first, SpeechStartResult.cancelled);
        expect(await second, SpeechStartResult.cancelled);
        verifyNeverListened();
      });

      test('cancel() during initialize keeps the mic closed', () async {
        final Completer<bool> init = Completer<bool>();
        when(
          () => stt.initialize(
            onError: any(named: 'onError'),
            onStatus: any(named: 'onStatus'),
          ),
        ).thenAnswer((_) => init.future);
        final SpeechToTextInputService service = build();

        final Future<SpeechStartResult> starting = service.start(
          localeId: 'en_US',
        );
        await Future<void>.delayed(Duration.zero); // reach initialize
        await service.cancel();
        init.complete(true);

        expect(await starting, SpeechStartResult.cancelled);
        verifyNeverListened();
        verifyNever(() => stt.cancel()); // no session to cancel
      });

      test('dispose() aborts a pending start and closes the streams', () async {
        permissionDialog = Completer<bool>();
        final SpeechToTextInputService service = build();
        bool levelsDone = false;
        bool wordsDone = false;
        service.soundLevel.listen(null, onDone: () => levelsDone = true);
        service.partialWords.listen(null, onDone: () => wordsDone = true);

        final Future<SpeechStartResult> starting = service.start(
          localeId: 'en_US',
        );
        await service.dispose();
        permissionDialog!.complete(true);

        expect(await starting, SpeechStartResult.cancelled);
        verifyNeverListened();
        expect(levelsDone, isTrue);
        expect(wordsDone, isTrue);
        expect(
          await service.start(localeId: 'en_US'),
          SpeechStartResult.unavailable,
        );
      });

      test('dispose() cancels a live session', () async {
        final SpeechToTextInputService service = build();
        await service.start(localeId: 'en_US');

        await service.dispose();

        verify(() => stt.cancel()).called(1);
      });
    });
  });
}
