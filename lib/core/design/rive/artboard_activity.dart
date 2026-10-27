import 'dart:async';

import 'package:flutter/foundation.dart' show ValueChanged;

/// Decides when a UI-kit artboard's Rive controller advances, so a static
/// artboard costs nothing per frame.
///
/// - **Ambient** artboards (a looping state: the listening ring, the
///   thinking orb, a running tool) run for as long as they are ambient.
/// - Every other artboard runs only to **settle**: each [wake] (a property
///   was written, a trigger fired) runs it, then pauses it once the settle
///   delay has passed without another wake.
/// - A paused app ([appResumed] false) always wins: nothing runs.
///
/// [onActiveChanged] receives every change of [running] (the first call
/// always comes with the first [wake]); it sets the controller's `active`.
/// Pure Dart timers: no Rive type, so the rules are unit-testable.
class ArtboardActivity {
  ArtboardActivity({required this.onActiveChanged});

  final ValueChanged<bool> onActiveChanged;

  bool _ambient = false;
  bool _appResumed = true;
  Timer? _settle;
  bool? _reported;

  /// Whether the controller should advance now.
  bool get running => _appResumed && (_ambient || _settle != null);

  /// Something changed: run now. Ambient artboards keep running; the others
  /// pause [settle] after this wake (a later wake restarts the delay).
  void wake({required bool ambient, required Duration settle}) {
    _ambient = ambient;
    _settle?.cancel();
    _settle = ambient
        ? null
        : Timer(settle, () {
            _settle = null;
            _report();
          });
    _report();
  }

  /// The app's lifecycle: only a resumed app runs artboards.
  set appResumed(bool resumed) {
    _appResumed = resumed;
    _report();
  }

  void _report() {
    final bool now = running;
    if (now != _reported) {
      _reported = now;
      onActiveChanged(now);
    }
  }

  /// Cancels the settle timer; no further [onActiveChanged] call.
  void dispose() {
    _settle?.cancel();
    _settle = null;
  }
}
