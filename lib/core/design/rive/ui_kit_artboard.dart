import 'package:flutter/widgets.dart';
import 'package:rive/rive.dart';

import '../../utils/logger.dart';
import 'artboard_activity.dart';
import 'rive_vm_binding.dart';
import 'ui_kit_contract.dart';
import 'ui_kit_file.dart';

/// Base of every UI-kit widget: one artboard of the shared `ui_kit.riv`,
/// driven through its view model.
///
/// Shows [fallback] until the file is loaded, and keeps showing it when the
/// file or the artboard is unavailable (in every build mode: never an error
/// box). Once loaded it creates its own controller (state machine `Main`)
/// and [RiveVmBinding], then calls [apply] right away and on every rebuild of
/// the parent, so property writes (colors included) follow the theme
/// without recreating the controller. The binding skips unchanged values.
///
/// The controller advances only while it has something to animate (see
/// [ArtboardActivity]): an [ambient] artboard runs while it is ambient;
/// any other one runs after a property actually changed, then pauses
/// [settleAfter] later. Rive is paused while the app is not resumed. The
/// controller and binding are disposed with the widget; the shared file is
/// not.
class UiKitArtboard extends StatefulWidget {
  const UiKitArtboard({
    super.key,
    required this.artboard,
    required this.apply,
    required this.fallback,
    this.fit = Fit.contain,
    this.ambient = false,
    this.settleAfter = defaultSettle,
  });

  /// How long a non-ambient artboard keeps running after a change: the
  /// longest kit transition ([AppMotion.max]) plus a margin.
  static const Duration defaultSettle = Duration(milliseconds: 700);

  /// Artboard name from [UiKitContract].
  final String artboard;

  /// Pushes the widget's current values into the view model.
  final void Function(RiveVmBinding binding) apply;

  /// Flutter rendering used while (or instead of) the Rive artboard.
  final Widget fallback;

  final Fit fit;

  /// The artboard is in a looping state and must keep running.
  final bool ambient;

  /// How long a non-ambient artboard runs after a change before it pauses.
  final Duration settleAfter;

  @override
  State<UiKitArtboard> createState() => UiKitArtboardState();
}

/// State of [UiKitArtboard]; [binding] lets a widget send one-shot cues
/// (triggers) outside [UiKitArtboard.apply].
class UiKitArtboardState extends State<UiKitArtboard>
    with WidgetsBindingObserver {
  static const String _tag = 'UiKitArtboard';

  /// Artboards already reported as unusable, so each is logged once.
  static final Set<String> _reported = <String>{};

  RiveWidgetController? _controller;
  RiveVmBinding? _binding;
  ArtboardActivity? _activity;

  /// The bound view model, or null while the fallback is shown.
  RiveVmBinding? get binding => _binding;

  /// Whether the Rive controller advances now (null while the fallback is
  /// shown).
  @visibleForTesting
  bool? get controllerActive => _controller?.active;

  /// Runs the artboard for [settle] (a one-shot cue fired through
  /// [binding], such as the mark's sting), then lets it pause again.
  void wake({Duration? settle}) {
    _activity?.wake(
      ambient: widget.ambient,
      settle: settle ?? widget.settleAfter,
    );
  }

  bool get _appResumed {
    final AppLifecycleState? lifecycle = WidgetsBinding.instance.lifecycleState;
    return lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    final File? file = await UiKitFile.load();
    if (file == null || !mounted) {
      return;
    }
    RiveWidgetController? controller;
    RiveVmBinding? binding;
    try {
      controller = RiveWidgetController(
        file,
        artboardSelector: ArtboardSelector.byName(widget.artboard),
        stateMachineSelector: StateMachineSelector.byName(
          UiKitContract.stateMachine,
        ),
      );
      binding = RiveVmBinding(controller);
      widget.apply(binding);
    } catch (e) {
      // Any failure (missing artboard or `Main`, a malformed view model, an
      // apply error) keeps the fallback: release what was created, log once.
      binding?.dispose();
      controller?.dispose();
      if (_reported.add(widget.artboard)) {
        AppLogger.warning(
          'UI-kit artboard "${widget.artboard}" unavailable, using its '
          'fallback: $e',
          tag: _tag,
        );
      }
      return;
    }
    final RiveWidgetController loaded = controller;
    _activity = ArtboardActivity(
      onActiveChanged: (bool active) => loaded.active = active,
    )..appResumed = _appResumed;
    setState(() {
      _controller = controller;
      _binding = binding;
    });
    // The first values are in: run until they settle.
    wake();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _activity?.appResumed = state == AppLifecycleState.resumed;
  }

  @override
  void didUpdateWidget(UiKitArtboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final RiveVmBinding? binding = _binding;
    if (binding == null) {
      return;
    }
    final int before = binding.writes;
    widget.apply(binding);
    // Parents rebuild often with the same values: only a real change (or
    // a change of ambient) runs the artboard again.
    if (binding.writes != before || widget.ambient != oldWidget.ambient) {
      wake();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activity?.dispose();
    _activity = null;
    _binding?.dispose();
    _controller?.dispose();
    _binding = null;
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final RiveWidgetController? controller = _controller;
    if (controller == null) {
      return widget.fallback;
    }
    return RiveWidget(controller: controller, fit: widget.fit);
  }
}
