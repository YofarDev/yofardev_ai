import '../../../../core/design/rive/ui_kit.dart';
import '../../../../core/models/chat_status.dart';
import '../../../../core/models/talking_phase.dart';

/// The Stage composer's mode (and its orb's look), first match wins:
///
/// 1. [listening] (push-to-talk open) → listening;
/// 2. [error] (the short flash after a failed reply) → error;
/// 3. audio playing ([TalkingPhase.speaking] / [TalkingPhase.waiting]) →
///    speaking;
/// 4. a reply in flight ([TalkingPhase.generating], [ChatStatus.typing] /
///    [ChatStatus.streaming], or the composer's own [submitting]) → thinking;
/// 5. a draft in the field ([hasText]) → typing;
/// 6. otherwise idle.
ComposerOrbState resolveComposerMode({
  required TalkingPhase phase,
  required ChatStatus chatStatus,
  required bool hasText,
  required bool listening,
  required bool submitting,
  required bool error,
}) {
  if (listening) {
    return ComposerOrbState.listening;
  }
  if (error) {
    return ComposerOrbState.error;
  }
  if (phase == TalkingPhase.speaking || phase == TalkingPhase.waiting) {
    return ComposerOrbState.speaking;
  }
  if (phase == TalkingPhase.generating ||
      chatStatus == ChatStatus.typing ||
      chatStatus == ChatStatus.streaming ||
      submitting) {
    return ComposerOrbState.thinking;
  }
  if (hasText) {
    return ComposerOrbState.typing;
  }
  return ComposerOrbState.idle;
}
