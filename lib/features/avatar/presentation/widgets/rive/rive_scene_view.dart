import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

import '../../../../../core/models/avatar_scene.dart';
import '../../../../../core/utils/logger.dart';
import '../../../../../core/design/rive/rive_vm_binding.dart';
import '../../rive/avatar_rive_contract.dart';
import 'latest_load_gate.dart';

/// Rive rendering of the scene currently on screen.
///
/// Loads the scene's `.riv` file lazily — only while its scene is active —
/// and disposes the previous file when the scene switches. One-shot scene
/// events fire from the `sceneEvent` seq in [sceneEvent]; `prop_tapped`
/// Rive events are forwarded to [onPropTapped].
class RiveSceneView extends StatefulWidget {
  const RiveSceneView({
    super.key,
    required this.scene,
    required this.sceneEvent,
    this.onPropTapped,
  });

  final AvatarScene scene;

  /// The latest scene-event cue (event + seq) from the avatar state.
  final ({SceneEvent sceneEvent, int seq}) sceneEvent;

  final ValueChanged<String>? onPropTapped;

  @override
  State<RiveSceneView> createState() => _RiveSceneViewState();
}

class _RiveSceneViewState extends State<RiveSceneView>
    with WidgetsBindingObserver {
  File? _file;
  RiveWidgetController? _controller;
  RiveVmBinding? _binding;
  AvatarScene? _loadedScene;
  String? _error;

  /// Home switches scene while the first load may still be in flight (the
  /// default scene, then the chat's): only the newest load may publish.
  final LatestLoadGate _loads = LatestLoadGate();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadScene(widget.scene);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause Rive while the app is in the background.
    final RiveWidgetController? controller = _controller;
    if (controller != null) {
      controller.active = state == AppLifecycleState.resumed;
    }
  }

  @override
  void didUpdateWidget(RiveSceneView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scene != oldWidget.scene) {
      _loadScene(widget.scene);
      return;
    }
    final RiveVmBinding? binding = _binding;
    if (binding == null) {
      return;
    }
    if (widget.sceneEvent.seq != oldWidget.sceneEvent.seq) {
      final List<String> allowed =
          AvatarRiveContract.sceneEvents[widget.scene.name]!;
      binding.setEnum(
        AvatarRiveContract.scenePropEventId,
        allowed,
        widget.sceneEvent.sceneEvent.name,
      );
      binding.fireTrigger(AvatarRiveContract.scenePropEventTrigger);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loads.cancelAll();
    _teardown();
    super.dispose();
  }

  Future<void> _loadScene(AvatarScene scene) async {
    final int ticket = _loads.begin();
    try {
      final File? file = await File.asset(
        AvatarRiveContract.sceneAssetPath(scene.name),
        riveFactory: Factory.rive,
      );
      if (!_loads.isLatest(ticket)) {
        // A newer scene load started meanwhile: this result is stale.
        file?.dispose();
        return;
      }
      if (file == null) {
        if (mounted) {
          setState(() => _error = '${scene.name}.riv could not be decoded');
        }
        return;
      }
      final RiveWidgetController controller = RiveWidgetController(
        file,
        artboardSelector: ArtboardSelector.byName(
          AvatarRiveContract.sceneArtboard,
        ),
        stateMachineSelector: StateMachineSelector.byName(
          AvatarRiveContract.sceneStateMachine,
        ),
      );
      final RiveVmBinding binding = RiveVmBinding(controller);
      controller.stateMachine.addEventListener(_onRiveEvent);
      if (!mounted) {
        binding.dispose();
        controller.dispose();
        file.dispose();
        return;
      }
      setState(() {
        // Dispose the previously loaded scene only once the new file is
        // ready, so switching never flashes empty.
        _teardown();
        _file = file;
        _controller = controller;
        _binding = binding;
        _loadedScene = scene;
      });
    } on Exception catch (e) {
      AppLogger.error(
        'RiveSceneView failed to load ${scene.name}.riv',
        tag: 'RiveSceneView',
        error: e,
      );
      if (mounted && _loads.isLatest(ticket)) {
        setState(() => _error = e.toString());
      }
    }
  }

  void _teardown() {
    final RiveWidgetController? controller = _controller;
    _binding?.dispose();
    controller?.stateMachine.removeEventListener(_onRiveEvent);
    controller?.dispose();
    _file?.dispose();
    _controller = null;
    _binding = null;
    _file = null;
    _loadedScene = null;
  }

  void _onRiveEvent(Event event) {
    if (event.name != AvatarRiveContract.eventPropTapped) {
      return;
    }
    final String? propId = event
        .stringProperty(AvatarRiveContract.sceneEventPropIdProperty)
        ?.value;
    if (propId != null) {
      widget.onPropTapped?.call(propId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final RiveWidgetController? controller = _controller;
    if (controller != null && _loadedScene == widget.scene) {
      return RiveWidget(controller: controller, fit: Fit.cover);
    }
    if (_error != null && !kReleaseMode) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Center(child: Text('${widget.scene.name}: $_error')),
      );
    }
    return const SizedBox.expand();
  }
}
