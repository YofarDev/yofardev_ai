import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/avatar_mood.dart';
import 'package:yofardev_ai/core/models/chat_entry.dart';

ChatEntry entryWithBody(String body) => ChatEntry(
  id: 'entry-1',
  entryType: EntryType.yofardev,
  body: body,
  timestamp: DateTime(2026, 10, 22),
);

void main() {
  group('reply JSON mood parsing', () {
    test('a valid mood is parsed from the reply JSON', () {
      final AvatarConfig config = entryWithBody(
        '{"message":"hi","mood":"happy"}',
      ).getAvatarConfig();
      expect(config.mood, AvatarMood.happy);
    });

    test('an invalid mood falls back to neutral', () {
      final AvatarConfig config = entryWithBody(
        '{"message":"hi","mood":"ecstatic"}',
      ).getAvatarConfig();
      expect(config.mood, AvatarMood.neutral);
    });

    test('a non-string mood falls back to neutral', () {
      final AvatarConfig config = entryWithBody(
        '{"message":"hi","mood":42}',
      ).getAvatarConfig();
      expect(config.mood, AvatarMood.neutral);
    });

    test('an absent mood leaves the field null (no change)', () {
      final AvatarConfig config = entryWithBody(
        '{"message":"hi"}',
      ).getAvatarConfig();
      expect(config.mood, isNull);
    });

    test('the JSON converter applies the same validation', () {
      expect(const MoodConverter().fromJson('sad'), AvatarMood.sad);
      expect(const MoodConverter().fromJson('nope'), AvatarMood.neutral);
      expect(const MoodConverter().fromJson(null), isNull);
      expect(const MoodConverter().toJson(AvatarMood.angry), 'angry');
      expect(const MoodConverter().toJson(null), isNull);
    });

    test('mood survives a full JSON round trip', () {
      const AvatarConfig config = AvatarConfig(mood: AvatarMood.thinking);
      final AvatarConfig decoded = AvatarConfig.fromJson(config.toJson());
      expect(decoded.mood, AvatarMood.thinking);
    });
  });
}
