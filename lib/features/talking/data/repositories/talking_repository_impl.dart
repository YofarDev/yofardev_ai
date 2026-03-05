import '../../../../core/services/audio/tts_service.dart';
import '../../domain/repositories/talking_repository.dart';

/// Implementation of TalkingRepository that wraps TtsService
class TalkingRepositoryImpl implements TalkingRepository {
  TalkingRepositoryImpl(this._ttsService);

  final TtsService _ttsService;

  @override
  Future<void> playWaitingSentence(String sentence) async {
    await _ttsService.playWaitingSentence(sentence);
  }

  @override
  Future<void> generateSpeech(String text) async {
    await _ttsService.speak(text);
  }

  @override
  Future<void> stop() async {
    await _ttsService.stop();
  }
}
