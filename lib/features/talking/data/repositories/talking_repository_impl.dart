import '../../domain/repositories/talking_repository.dart';

/// Implementation of TalkingRepository
///
/// Note: Actual TTS functionality is handled by ChatTtsCubit with TtsQueueService.
/// This repository is kept for API compatibility but performs no operations.
class TalkingRepositoryImpl implements TalkingRepository {
  TalkingRepositoryImpl();

  @override
  Future<void> playWaitingSentence(String sentence) async {
    // No-op: handled by ChatTtsCubit with TtsQueueService
  }

  @override
  Future<void> generateSpeech(String text) async {
    // No-op: handled by ChatTtsCubit with TtsQueueService
  }

  @override
  Future<void> stop() async {
    // No-op: handled by TtsPlaybackService and AudioPlayerService
  }
}
