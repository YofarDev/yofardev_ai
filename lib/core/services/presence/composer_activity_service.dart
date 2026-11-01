import 'dart:async';

/// What the message composer reports about the user typing.
///
/// The composer sends a report per edit and must send `typing: false` (or
/// call [ComposerActivityService.clear]) when typing pauses, on submit and on
/// blur: the avatar only leans in and watches the caret while [typing].
class ComposerActivity {
  const ComposerActivity({
    this.typing = false,
    this.caretFraction = 0.5,
    this.lastChar,
    this.edited = true,
  });

  /// Nothing typed: the state after [ComposerActivityService.clear].
  static const ComposerActivity idle = ComposerActivity();

  /// True while the user is actively typing.
  final bool typing;

  /// Where the caret sits across the text field, 0..1.
  final double caretFraction;

  /// The character just typed, or null when the report is not a keystroke.
  final String? lastChar;

  /// False when the text did not change (a caret move, or a tap reported
  /// through [ComposerActivityService.touch]): the avatar counts it as
  /// presence and may follow the caret with its eyes, but does not nod.
  final bool edited;

  @override
  bool operator ==(Object other) =>
      other is ComposerActivity &&
      other.typing == typing &&
      other.caretFraction == caretFraction &&
      other.lastChar == lastChar &&
      other.edited == edited;

  @override
  int get hashCode => Object.hash(typing, caretFraction, lastChar, edited);

  @override
  String toString() =>
      'ComposerActivity(typing: $typing, caret: $caretFraction, '
      'lastChar: $lastChar, edited: $edited)';
}

/// Carries the composer's typing reports to the avatar (core service so the
/// home composer and the avatar feature never import each other).
class ComposerActivityService {
  ComposerActivityService();

  final StreamController<ComposerActivity> _controller =
      StreamController<ComposerActivity>.broadcast();
  ComposerActivity _current = ComposerActivity.idle;

  /// The latest report.
  ComposerActivity get current => _current;

  /// Every report, as it comes (broadcast).
  Stream<ComposerActivity> get activity => _controller.stream;

  /// Publishes [activity] as the composer's state.
  void report(ComposerActivity activity) {
    _current = activity;
    if (!_controller.isClosed) {
      _controller.add(activity);
    }
  }

  /// The user touched the composer or a control around it (an orb tap, the
  /// mic starting or ending, attach, a chip): presence without an edit.
  /// Keeps the typing state and caret as they are.
  void touch() => report(
    ComposerActivity(
      typing: _current.typing,
      caretFraction: _current.caretFraction,
      edited: false,
    ),
  );

  /// The composer submitted or lost focus: nobody is typing any more.
  void clear() => report(ComposerActivity.idle);

  Future<void> dispose() => _controller.close();
}
