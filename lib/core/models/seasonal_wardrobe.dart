import 'avatar_config.dart';

/// The avatar's December outfit (moonshot M9 ruling 13).
///
/// From 1 to 31 December a chat whose stored outfit is the default (hat
/// `noHat`, top `pinkHoodie`, costume `none`) is *shown* in `santaHat` and
/// `christmasSweater`. Never saved: the stored [Avatar] is untouched, so
/// anything the user or the LLM chose (any other hat, top or a costume) wins,
/// and on 1 January the avatar is back in its stored outfit.
Avatar shownWardrobe(Avatar stored, DateTime local) {
  if (local.month != DateTime.december) {
    return stored;
  }
  final bool usesDefaults =
      stored.hat == AvatarHat.noHat &&
      stored.top == AvatarTop.pinkHoodie &&
      stored.costume == AvatarCostume.none;
  if (!usesDefaults) {
    return stored;
  }
  return stored.copyWith(
    hat: AvatarHat.santaHat,
    top: AvatarTop.christmasSweater,
  );
}

/// The line the system prompt gets in December, so the LLM knows what the
/// user sees (and can mention it); empty outside December.
String decemberWardrobePromptNote(DateTime local) {
  if (local.month != DateTime.december) {
    return '';
  }
  return 'It is December: while the avatar keeps its default outfit (hat '
      'noHat, top pinkHoodie, costume none), the user sees it in its '
      'December outfit, a santaHat and a christmasSweater. Any hat, top or '
      'costume you choose replaces it.';
}
