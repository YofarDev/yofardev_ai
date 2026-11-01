import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The system's reduce-motion setting ("remove animations" on Android,
/// "reduce motion" on iOS and macOS), followed live (M11 ruling 18).
///
/// [value] is the setting now; listeners hear every change. The platform
/// source ([ReduceMotionSource.platform]) re-reads
/// `PlatformDispatcher.accessibilityFeatures.disableAnimations` whenever the
/// binding reports an accessibility change
/// (`WidgetsBindingObserver.didChangeAccessibilityFeatures`), so the
/// services that are not widgets (the parallax source, the idle ladder, the
/// camera and NPC directors, the journeys) follow the switch without a
/// restart. Widgets keep reading `MediaQuery.disableAnimationsOf`, which
/// follows the same flag.
///
/// Tests build it with [ReduceMotionSource.new] and drive [set].
class ReduceMotionSource extends ChangeNotifier
    implements ValueListenable<bool> {
  ReduceMotionSource({bool initial = false}) : _value = initial;

  /// Follows the platform flag of [dispatcher] (the [binding]'s when null)
  /// through [binding] (the app's binding when null). Call [dispose] to
  /// stop.
  factory ReduceMotionSource.platform({
    WidgetsBinding? binding,
    PlatformDispatcher? dispatcher,
  }) {
    final WidgetsBinding widgets =
        binding ?? WidgetsFlutterBinding.ensureInitialized();
    final _PlatformReduceMotionSource source = _PlatformReduceMotionSource(
      dispatcher ?? widgets.platformDispatcher,
    );
    source._attach(widgets);
    return source;
  }

  bool _value;

  /// Whether motion is reduced now.
  @override
  bool get value => _value;

  /// Sets the value (notifies on a change only).
  void set(bool value) {
    if (value == _value) {
      return;
    }
    _value = value;
    notifyListeners();
  }
}

class _PlatformReduceMotionSource extends ReduceMotionSource
    with WidgetsBindingObserver {
  _PlatformReduceMotionSource(this._platform)
    : super(initial: _platform.accessibilityFeatures.disableAnimations);

  final PlatformDispatcher _platform;
  WidgetsBinding? _binding;

  void _attach(WidgetsBinding binding) {
    _binding = binding;
    binding.addObserver(this);
  }

  @override
  void didChangeAccessibilityFeatures() =>
      set(_platform.accessibilityFeatures.disableAnimations);

  @override
  void dispose() {
    _binding?.removeObserver(this);
    _binding = null;
    super.dispose();
  }
}
