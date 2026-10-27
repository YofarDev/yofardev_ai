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
///    [ChatStatus.streaming], or the composer's own [submitting]) →
///    thinking (the composer may hold speaking over it between two
///    sentences, see [holdsSpeaking]);
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

/// Whether the speaking look is held over [raw], the mode resolved without
/// any hold, given the [previous] raw mode and whether it was [held].
///
/// Within one reply the avatar goes quiet between two sentences while the
/// reply is still in flight, which resolves to thinking: once the orb
/// showed speaking, that gap keeps speaking (the Stop control stays put).
/// The hold starts when speaking turns into thinking, lasts while the mode
/// stays thinking, and ends on anything else (idle once the reply ended,
/// listening, an error) or when the caller's hold window runs out (it then
/// passes `held: false` with [previous] already thinking).
bool holdsSpeaking({
  required ComposerOrbState? previous,
  required ComposerOrbState raw,
  required bool held,
}) =>
    raw == ComposerOrbState.thinking &&
    (held || previous == ComposerOrbState.speaking);
