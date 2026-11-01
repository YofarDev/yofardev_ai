/// Gestures the avatar plays. Names mirror `rive/CONTRACT.md`
/// (`AvatarVM.gestureId`); v11 appends `thumbsUp`, `count` and `grab` (the
/// journey's jacket reach), v13 `signature` (the worn costume's signature
/// move, played by the app when a costume is put on).
enum AvatarGesture {
  wave,
  laugh,
  facepalm,
  shrug,
  nod,
  headshake,
  clap,
  think,
  thumbsUp,
  count,
  grab,
  signature;

  /// The inline gesture cues the LLM is offered and may fire mid-reply:
  /// every gesture but [signature] (M10 ruling 6: the app plays it when a
  /// costume goes on; without a costume it is a no-op the LLM would only
  /// waste a cue on).
  static List<AvatarGesture> get llmCues => values
      .where((AvatarGesture g) => g != AvatarGesture.signature)
      .toList(growable: false);
}
