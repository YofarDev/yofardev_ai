import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/audio/tts_service.dart';

void main() {
  late TtsService ttsService;

  setUp(() {
    ttsService = TtsService();
  });

  tearDown(() {
    ttsService.dispose();
  });

  test('can distinguish waiting sentences from TTS', () async {
    await ttsService.playWaitingSentence('Waiting...');
    expect(ttsService.currentType, equals(TtsType.waiting));

    await ttsService.speak('Response');
    expect(ttsService.currentType, equals(TtsType.response));
  });

  test('isPlayingWaiting returns true when playing waiting sentence', () async {
    await ttsService.playWaitingSentence('Waiting...');
    expect(ttsService.isPlayingWaiting, isTrue);
    expect(ttsService.isPlayingResponse, isFalse);
  });

  test('isPlayingResponse returns true when speaking', () async {
    await ttsService.speak('Response');
    expect(ttsService.isPlayingResponse, isTrue);
    expect(ttsService.isPlayingWaiting, isFalse);
  });

  test('stop clears current type', () async {
    await ttsService.speak('Test');
    expect(ttsService.currentType, isNotNull);

    await ttsService.stop();
    expect(ttsService.currentType, isNull);
  });

  test('speak stops previous waiting sentence', () async {
    await ttsService.playWaitingSentence('Waiting...');
    expect(ttsService.currentType, equals(TtsType.waiting));

    await ttsService.speak('Response');
    expect(ttsService.currentType, equals(TtsType.response));
  });

  test('playWaitingSentence stops previous speak', () async {
    await ttsService.speak('Response');
    expect(ttsService.currentType, equals(TtsType.response));

    await ttsService.playWaitingSentence('Waiting...');
    expect(ttsService.currentType, equals(TtsType.waiting));
  });
}
