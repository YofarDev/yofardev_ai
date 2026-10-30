import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:rive/rive.dart';

import '../../../../../core/models/avatar_scene.dart';
import '../../../../../core/services/motion/parallax_source.dart';
import '../../../../../core/utils/logger.dart';
import '../../../../../core/design/rive/rive_vm_binding.dart';
import '../../rive/avatar_rive_contract.dart';
import '../../rive/scene_front_follower.dart';
import '../../rive/scene_parallax_writer.dart';
import '../../rive/scene_rain_writer.dart';
import '../../rive/scene_time_writer.dart';
import '../stage_camera.dart';
import 'latest_load_gate.dart';

/// Rive rendering of the scene currently on screen.
///
/// Loads the scene's `.riv` file lazily — only while its scene is active —
/// and disposes the previous file when the scene switches. One-shot scene
/// events fire from the `sceneEvent` seq in [sceneEvent]; `prop_tapped`
/// Rive events are forwarded to [onPropTapped].
///
/// Parallax (contract v7): [parallax]'s offset is written to `SceneVM`
/// `parallaxX` / `parallaxY` at most once per frame, and only when an axis
/// moved by more than 0.001. A non-null [parallaxOverride] (the UI lab) is
/// written instead of the source. The source runs (accelerometer
/// subscribed) only while the loaded scene is a diorama and the app is
/// resumed.
///
/// Rain (contract v8): [rain]'s value is written to `SceneVM` `rain` once
/// when a scene file loads (so a scene switch while it rains rains in the new
/// file) and on every change.
///
/// Time of day (contract v10): [daylight] and [dusk] are written to `SceneVM`
/// on every scene load and change, like the rain.
///
/// Front (contract v9): a file with a `SceneFront` artboard gets it drawn
/// above [middle] (the avatar) while it rains, with the same fit, never
/// hit-tested; [middle] sits between the two at a fixed index, so a scene
/// switch never remounts it.
class RiveSceneView extends StatefulWidget {
  const RiveSceneView({
    super.key,
    required this.scene,
    required this.sceneEvent,
    this.onPropTapped,
    this.parallax,
    this.parallaxOverride,
    this.rain,
    this.daylight,
    this.dusk,
    this.middle,
  });

  final AvatarScene scene;

  /// The latest scene-event cue (event + seq) from the avatar state.
  final ({SceneEvent sceneEvent, int seq}) sceneEvent;

  final ValueChanged<String>? onPropTapped;

  /// The device tilt or pointer offset; null leaves the scene centred.
  final ParallaxSource? parallax;

  /// A hand-set offset written instead of [parallax] while non-null.
  final Offset? parallaxOverride;

  /// The steady rain intensity, 0..1; null leaves it dry.
  final ValueListenable<double>? rain;

  /// The time of day (contract v10), 0..1 each; null leaves it night.
  final ValueListenable<double>? daylight;
  final ValueListenable<double>? dusk;

  /// Drawn over the scene and under its front weather: the avatar.
  final Widget? middle;

  @override
  State<RiveSceneView> createState() => _RiveSceneViewState();
}

class _RiveSceneViewState extends State<RiveSceneView>
    with WidgetsBindingObserver {
  File? _file;
  RiveWidgetController? _controller;
  RiveVmBinding? _binding;
  SceneParallaxWriter? _parallaxWriter;
  final SceneRainFollower _rain = SceneRainFollower();
  final SceneTimeFollower _time = SceneTimeFollower();
  final SceneFrontFollower _front = SceneFrontFollower();
  ValueListenable<double>? _frontRainSource;
  bool _hasFront = false;
  RiveWidgetController? _frontController;
  RiveVmBinding? _frontBinding;
  StreamSubscription<Offset>? _parallaxSub;
  Offset _parallax = Offset.zero;
  bool _parallaxFrameScheduled = false;
  AvatarScene? _loadedScene;
  bool _resumed =
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  String? _error;

  /// Home switches scene while the first load may still be in flight (the
  /// default scene, then the chat's): only the newest load may publish.
  final LatestLoadGate _loads = LatestLoadGate();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenParallax();
    _syncParallaxActive();
    _rain.follow(widget.rain);
    _time.follow(widget.daylight, widget.dusk);
    _followFrontRain();
    _loadScene(widget.scene);
  }

  /// Listens to [RiveSceneView.rain] for the front artboard.
  void _followFrontRain() {
    _frontRainSource?.removeListener(_syncFront);
    _frontRainSource = widget.rain;
    _frontRainSource?.addListener(_syncFront);
  }

  /// Creates the front controller when it starts raining on a file with a
  /// front, drops it when the rain stops, and writes the rain in between.
  /// [rebuild] false applies it without `setState` (from `didUpdateWidget`,
  /// whose build follows anyway).
  void _syncFront({bool rebuild = true}) {
    if (rebuild &&
        SchedulerBinding.instance.schedulerPhase ==
            SchedulerPhase.persistentCallbacks) {
      // Notified mid-frame (build or layout): rebuild after it.
      SchedulerBinding.instance.addPostFrameCallback((Duration _) {
        if (mounted) {
          _syncFront();
        }
      });
      return;
    }
    void apply(VoidCallback change) => rebuild ? setState(change) : change();
    final double rain = widget.rain?.value ?? 0;
    final File? file = _file;
    // Only the file of the scene on screen (not one a switch is replacing).
    final bool show =
        file != null &&
        _loadedScene == widget.scene &&
        SceneFrontFollower.shouldShow(hasFront: _hasFront, rain: rain);
    if (!show) {
      if (_frontController != null) {
        apply(_teardownFront);
      }
      return;
    }
    if (_frontController != null) {
      _front.rain(rain);
      return;
    }
    final RiveWidgetController controller = RiveWidgetController(
      file,
      artboardSelector: ArtboardSelector.byName(
        AvatarRiveContract.sceneFrontArtboard,
      ),
      stateMachineSelector: StateMachineSelector.byName(
        AvatarRiveContract.sceneStateMachine,
      ),
    );
    controller.active = _resumed;
    final RiveVmBinding binding = RiveVmBinding(controller);
    _front.attach(
      binding.setNumber,
      rain: rain,
      parallax: widget.parallaxOverride ?? _parallax,
    );
    apply(() {
      _frontController = controller;
      _frontBinding = binding;
    });
  }

  void _teardownFront() {
    _front.detach();
    _frontBinding?.dispose();
    _frontController?.dispose();
    _frontBinding = null;
    _frontController = null;
  }

  void _listenParallax() {
    unawaited(_parallaxSub?.cancel());
    final ParallaxSource? source = widget.parallax;
    _parallax = source?.value ?? Offset.zero;
    _parallaxSub = source?.values.listen((Offset value) {
      _parallax = value;
      _scheduleParallaxWrite();
    });
  }

  /// Writes the offset in the next frame, however many updates arrive first.
  void _scheduleParallaxWrite() {
    if (_parallaxFrameScheduled || _parallaxWriter == null) {
      return;
    }
    _parallaxFrameScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((Duration _) {
      _parallaxFrameScheduled = false;
      final Offset offset = widget.parallaxOverride ?? _parallax;
      _parallaxWriter?.write(offset);
      _front.parallax(offset);
    });
  }

  /// The sensors run only for a loaded diorama while the app is resumed.
  void _syncParallaxActive() {
    widget.parallax?.active = _resumed && (_loadedScene?.isDiorama ?? false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce motion is read through a callback: re-push it on a change.
    MediaQuery.maybeDisableAnimationsOf(context);
    widget.parallax?.refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _syncParallaxActive();
    // Pause Rive while the app is in the background.
    final RiveWidgetController? controller = _controller;
    if (controller != null) {
      controller.active = state == AppLifecycleState.resumed;
    }
    _frontController?.active = state == AppLifecycleState.resumed;
  }

  @override
  void didUpdateWidget(RiveSceneView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.parallax != oldWidget.parallax) {
      oldWidget.parallax?.active = false;
      _listenParallax();
      _syncParallaxActive();
    }
    if (widget.rain != oldWidget.rain) {
      _rain.follow(widget.rain);
      _followFrontRain();
      _syncFront(rebuild: false);
    }
    if (widget.daylight != oldWidget.daylight ||
        widget.dusk != oldWidget.dusk) {
      _time.follow(widget.daylight, widget.dusk);
    }
    if (widget.parallaxOverride != oldWidget.parallaxOverride ||
        widget.parallax != oldWidget.parallax) {
      _scheduleParallaxWrite();
    }
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
    _rain.dispose();
    _time.dispose();
    _frontRainSource?.removeListener(_syncFront);
    unawaited(_parallaxSub?.cancel());
    widget.parallax?.active = false;
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
      // Contract v9: does this file carry the front weather?
      final Artboard? front = file.artboard(
        AvatarRiveContract.sceneFrontArtboard,
      );
      final bool hasFront = front != null;
      front?.dispose();
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
        _hasFront = hasFront;
        // A fresh binding has no parallax yet.
        _parallaxWriter = SceneParallaxWriter(binding.setNumber)
          ..write(widget.parallaxOverride ?? _parallax, force: true);
        // Nor has it the rain: a scene switch writes it to the new file.
        _rain.load(binding.setNumber);
        // And the time of day (v10).
        _time.load(binding.setNumber);
        _syncParallaxActive();
      });
      // The new file's front, if it has one and it rains.
      _syncFront();
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
    // The front shares the file: it goes first.
    _teardownFront();
    _hasFront = false;
    final RiveWidgetController? controller = _controller;
    _binding?.dispose();
    controller?.stateMachine.removeEventListener(_onRiveEvent);
    controller?.dispose();
    _file?.dispose();
    _controller = null;
    _binding = null;
    _parallaxWriter = null;
    _rain.unload();
    _time.unload();
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
    final Widget? middle = widget.middle;
    final RiveWidgetController? front = _frontController;
    final bool loaded = _controller != null && _loadedScene == widget.scene;
    // The camera's texture scale: changes once per shot, not per frame.
    final RenderResolution resolution = RenderResolution.layout(
      scale: StageRenderScale.of(context),
    );
    final Widget back = _back(context, resolution);
    // A file with a front always sits in the Stack, so the front coming and
    // going never remounts the back.
    if (middle == null && !_hasFront) {
      return back;
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        back,
        // index 1 whatever the back shows: the avatar is never remounted
        ?middle,
        if (front != null && loaded)
          IgnorePointer(
            child: RiveWidget(
              controller: front,
              fit: Fit.cover,
              renderResolution: resolution,
            ),
          ),
      ],
    );
  }

  Widget _back(BuildContext context, RenderResolution resolution) {
    final RiveWidgetController? controller = _controller;
    if (controller != null && _loadedScene == widget.scene) {
      return RiveWidget(
        controller: controller,
        fit: Fit.cover,
        renderResolution: resolution,
      );
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
