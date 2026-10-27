import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/design/rive/ui_kit.dart';
import 'package:yofardev_ai/core/models/chat_status.dart';
import 'package:yofardev_ai/core/models/talking_phase.dart';
import 'package:yofardev_ai/features/home/widgets/stage/composer_mode.dart';

ComposerOrbState _mode({
  TalkingPhase phase = TalkingPhase.idle,
  ChatStatus chatStatus = ChatStatus.success,
  bool hasText = false,
  bool listening = false,
  bool submitting = false,
  bool error = false,
}) => resolveComposerMode(
  phase: phase,
  chatStatus: chatStatus,
  hasText: hasText,
  listening: listening,
  submitting: submitting,
  error: error,
);

void main() {
  group('resolveComposerMode', () {
    test('nothing going on: idle', () {
      expect(_mode(), ComposerOrbState.idle);
      expect(_mode(chatStatus: ChatStatus.loaded), ComposerOrbState.idle);
      expect(_mode(chatStatus: ChatStatus.initial), ComposerOrbState.idle);
      expect(_mode(chatStatus: ChatStatus.interrupted), ComposerOrbState.idle);
      expect(_mode(phase: TalkingPhase.error), ComposerOrbState.idle);
    });

    test('a draft: typing', () {
      expect(_mode(hasText: true), ComposerOrbState.typing);
    });

    test('a request in flight: thinking, over a draft', () {
      expect(_mode(phase: TalkingPhase.generating), ComposerOrbState.thinking);
      expect(_mode(chatStatus: ChatStatus.typing), ComposerOrbState.thinking);
      expect(
        _mode(chatStatus: ChatStatus.streaming),
        ComposerOrbState.thinking,
      );
      expect(_mode(submitting: true), ComposerOrbState.thinking);
      expect(_mode(submitting: true, hasText: true), ComposerOrbState.thinking);
    });

    test('audio playing: speaking, over thinking', () {
      expect(_mode(phase: TalkingPhase.speaking), ComposerOrbState.speaking);
      expect(_mode(phase: TalkingPhase.waiting), ComposerOrbState.speaking);
      expect(
        _mode(
          phase: TalkingPhase.speaking,
          chatStatus: ChatStatus.streaming,
          submitting: true,
          hasText: true,
        ),
        ComposerOrbState.speaking,
      );
    });

    test('error flash: over speaking and thinking', () {
      expect(_mode(error: true), ComposerOrbState.error);
      expect(
        _mode(
          error: true,
          phase: TalkingPhase.speaking,
          chatStatus: ChatStatus.streaming,
          submitting: true,
          hasText: true,
        ),
        ComposerOrbState.error,
      );
    });

    test('listening wins over everything', () {
      expect(_mode(listening: true), ComposerOrbState.listening);
      expect(
        _mode(
          listening: true,
          error: true,
          phase: TalkingPhase.speaking,
          chatStatus: ChatStatus.streaming,
          submitting: true,
          hasText: true,
        ),
        ComposerOrbState.listening,
      );
    });
  });
}
