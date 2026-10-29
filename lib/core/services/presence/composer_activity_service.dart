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
  });

  /// Nothing typed: the state after [ComposerActivityService.clear].
  static const ComposerActivity idle = ComposerActivity();

  /// True while the user is actively typing.
  final bool typing;

  /// Where the caret sits across the text field, 0..1.
  final double caretFraction;

  /// The character just typed, or null when the report is not a keystroke.
  final String? lastChar;

  @override
  bool operator ==(Object other) =>
      other is ComposerActivity &&
      other.typing == typing &&
      other.caretFraction == caretFraction &&
      other.lastChar == lastChar;

  @override
  int get hashCode => Object.hash(typing, caretFraction, lastChar);

  @override
  String toString() =>
      'ComposerActivity(typing: $typing, caret: $caretFraction, '
      'lastChar: $lastChar)';
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

  /// The composer submitted or lost focus: nobody is typing any more.
  void clear() => report(ComposerActivity.idle);

  Future<void> dispose() => _controller.close();
}
