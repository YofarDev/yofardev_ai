import 'package:flutter/foundation.dart';

/// The sound-effects setting as a live value (default on), so the foley and
/// the ambient beds hear it change without reading preferences on every
/// sound. Loaded once at startup and set whenever the setting is saved
/// (wired in the service locator).
class SoundEffectsSetting {
  SoundEffectsSetting({bool initial = true})
    : _enabled = ValueNotifier<bool>(initial);

  final ValueNotifier<bool> _enabled;

  /// Whether sound effects (foley, beds, their haptics) may play.
  ValueListenable<bool> get enabled => _enabled;

  void set(bool value) => _enabled.value = value;

  void dispose() => _enabled.dispose();
}
