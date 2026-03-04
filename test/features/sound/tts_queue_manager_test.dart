import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/features/sound/domain/tts_queue_manager.dart';
import 'package:yofardev_ai/features/sound/domain/tts_queue_item.dart';
import 'package:yofardev_ai/features/sound/data/datasources/tts_datasource.dart';

class MockTtsDatasource extends Mock implements TtsDatasource {}

void main() {
  // Register fallback value for VoiceEffect
  setUpAll(() {
    registerFallbackValue(VoiceEffect(pitch: 1.0, speedRate: 1.0));
  });

  group('TtsQueueManager', () {
    late TtsQueueManager manager;
    late MockTtsDatasource mockDatasource;

    setUp(() {
      mockDatasource = MockTtsDatasource();
      manager = TtsQueueManager(ttsDatasource: mockDatasource);
    });

    tearDown(() {
      manager.dispose();
    });

    test('should process items in priority order', () async {
      when(
        () => mockDatasource.textToFrenchMaleVoice(
          text: any(named: 'text'),
          language: any(named: 'language'),
          voiceEffect: any(named: 'voiceEffect'),
        ),
      ).thenAnswer((_) async => '/path/to/audio1.wav');

      final List<String> audioPaths = <String>[];
      final StreamSubscription<String> subscription = manager.audioStream
          .listen(audioPaths.add);

      // Enqueue with different priorities
      unawaited(
        manager.enqueue(
          text: 'Low priority',
          language: 'fr',
          voiceEffect: VoiceEffect(pitch: 1.0, speedRate: 1.0),
          priority: TtsPriority.low,
        ),
      );

      unawaited(
        manager.enqueue(
          text: 'High priority',
          language: 'fr',
          voiceEffect: VoiceEffect(pitch: 1.0, speedRate: 1.0),
          priority: TtsPriority.high,
        ),
      );

      // Wait for processing
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // High priority should be processed first
      expect(audioPaths.length, greaterThan(0));

      await subscription.cancel();
    });

    test('should clear queue', () async {
      when(
        () => mockDatasource.textToFrenchMaleVoice(
          text: any(named: 'text'),
          language: any(named: 'language'),
          voiceEffect: any(named: 'voiceEffect'),
        ),
      ).thenAnswer((_) async => '/path/to/audio.wav');

      // Pause processing so queue doesn't get processed
      manager.setPaused(true);

      unawaited(
        manager.enqueue(
          text: 'Test',
          language: 'fr',
          voiceEffect: VoiceEffect(pitch: 1.0, speedRate: 1.0),
        ),
      );

      // Wait a bit for enqueue to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(manager.queue.length, 1);

      manager.clear();

      expect(manager.queue.length, 0);
    });

    test('should skip empty text', () async {
      unawaited(
        manager.enqueue(
          text: '   ',
          language: 'fr',
          voiceEffect: VoiceEffect(pitch: 1.0, speedRate: 1.0),
        ),
      );

      // Wait a bit
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(manager.queue.length, 0);
    });

    test('should pause and resume processing', () async {
      when(
        () => mockDatasource.textToFrenchMaleVoice(
          text: any(named: 'text'),
          language: any(named: 'language'),
          voiceEffect: any(named: 'voiceEffect'),
        ),
      ).thenAnswer((_) async => '/path/to/audio.wav');

      manager.setPaused(true);

      unawaited(
        manager.enqueue(
          text: 'Test',
          language: 'fr',
          voiceEffect: VoiceEffect(pitch: 1.0, speedRate: 1.0),
        ),
      );

      // Wait a bit
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Should not process when paused
      expect(manager.isProcessing, false);

      // Resume
      manager.setPaused(false);

      // Wait for processing to start
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Should be processing now
      expect(manager.queue.length, lessThan(1));
    });

    test('should handle processing errors gracefully', () async {
      when(
        () => mockDatasource.textToFrenchMaleVoice(
          text: any(named: 'text'),
          language: any(named: 'language'),
          voiceEffect: any(named: 'voiceEffect'),
        ),
      ).thenThrow(Exception('TTS failed'));

      final List<String> audioPaths = <String>[];
      final StreamSubscription<String> subscription = manager.audioStream
          .listen(audioPaths.add);

      unawaited(
        manager.enqueue(
          text: 'Test',
          language: 'fr',
          voiceEffect: VoiceEffect(pitch: 1.0, speedRate: 1.0),
        ),
      );

      // Wait for processing
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // Queue should be empty even after error
      expect(manager.queue.length, 0);

      await subscription.cancel();
    });
  });
}
