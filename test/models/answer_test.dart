import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/models/answer.dart';

void main() {
  group('Answer', () {
    const AvatarConfig defaultAvatarConfig = AvatarConfig();

    test('should create instance with default values', () {
      const Answer answer = Answer();
      expect(answer.chatId, '');
      expect(answer.answerText, '');
      expect(answer.audioPath, '');
      expect(answer.amplitudes, <dynamic>[]);
      expect(answer.avatarConfig, defaultAvatarConfig);
    });

    test('should create instance with provided values', () {
      final AvatarConfig avatarConfig = AvatarConfig(
        background: AvatarBackgrounds.beach,
        hat: AvatarHat.beanie,
      );
      final Answer answer = Answer(
        chatId: 'chat123',
        answerText: 'Hello',
        audioPath: '/path/to/audio.mp3',
        amplitudes: <int>[100, 200, 300],
        avatarConfig: avatarConfig,
      );
      expect(answer.chatId, 'chat123');
      expect(answer.answerText, 'Hello');
      expect(answer.audioPath, '/path/to/audio.mp3');
      expect(answer.amplitudes, <int>[100, 200, 300]);
      expect(answer.avatarConfig, avatarConfig);
    });

    test('should support equality', () {
      const Answer answer1 = Answer(chatId: 'test');
      const Answer answer2 = Answer(chatId: 'test');
      const Answer answer3 = Answer(chatId: 'different');

      expect(answer1, equals(answer2));
      expect(answer1, isNot(equals(answer3)));
    });

    test('should copy with new values', () {
      const Answer original = Answer(
        chatId: 'chat1',
        answerText: 'Hello',
      );

      final Answer copied = original.copyWith(
        chatId: 'chat2',
        answerText: 'Goodbye',
      );

      expect(copied.chatId, 'chat2');
      expect(copied.answerText, 'Goodbye');
      // Other fields should remain the same
      expect(copied.audioPath, original.audioPath);
      expect(copied.amplitudes, original.amplitudes);
    });

    test('should copy with partial values', () {
      const Answer original = Answer(
        chatId: 'chat1',
        answerText: 'Hello',
      );

      final Answer copied = original.copyWith(answerText: 'Hi');

      expect(copied.chatId, original.chatId);
      expect(copied.answerText, 'Hi');
      expect(copied.audioPath, original.audioPath);
    });

    test('should replace avatarConfig with new value in copyWith', () {
      final Answer original = Answer(
        chatId: 'chat1',
        avatarConfig: AvatarConfig(background: AvatarBackgrounds.forest),
      );

      final Answer withNewConfig = original.copyWith(
        avatarConfig: AvatarConfig(background: AvatarBackgrounds.beach),
      );

      expect(withNewConfig.avatarConfig.background, AvatarBackgrounds.beach);
      // Other fields should remain the same
      expect(withNewConfig.chatId, original.chatId);
    });
  });
}
