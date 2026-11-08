import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/audio/audio_player_service.dart';

import '../../../helpers/fake_audio_players.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioPlayerService.playAsset over speech', () {
    // The avatar's clothes-change whoosh, played while a sentence speaks.
    const String sentence = '/tmp/tts/1794072802474.wav';
    const String whoosh = 'sound_effects/whoosh.wav';
    const String whooshUrl = 'assets/$whoosh';

    late FakeAudioPlayersPlatform platform;
    late AudioPlayerService service;
    late List<void> completions;

    setUp(() {
      platform = FakeAudioPlayersPlatform.install();
      service = AudioPlayerService();
      completions = <void>[];
      service.onPlaybackComplete.listen(completions.add);
    });

    tearDown(() => service.dispose());

    test('leaves the sentence playing', () async {
      await service.play(sentence);

      await service.playAsset(whoosh, volume: 0.3);

      expect(platform.isPlaying(sentence), isTrue);
      expect(platform.isPlaying(whooshUrl), isTrue);
    });

    test('the sentence still reports its end (the TTS queue waits for '
        'it before the next sentence)', () async {
      await service.play(sentence);
      await service.playAsset(whoosh, volume: 0.3);

      await platform.finish(whooshUrl);
      await platform.finish(sentence);

      expect(completions, hasLength(1));
    });

    test('its own end is no sentence completion', () async {
      await service.playAsset(whoosh, volume: 0.3);

      await platform.finish(whooshUrl);

      expect(completions, isEmpty);
    });

    test('its volume never reaches the next sentence', () async {
      await service.playAsset(whoosh, volume: 0.3);

      await service.play(sentence);

      expect(platform.volumeOf(sentence), 1);
    });
  });
}
