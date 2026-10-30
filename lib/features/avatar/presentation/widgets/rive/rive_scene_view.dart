import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:rive/rive.dart';

import '../../../../../core/models/avatar_scene.dart';
import '../../../../../core/services/audio/foley_service.dart' show DragHaptic;
import '../../../../../core/services/motion/parallax_source.dart';
import '../../../../../core/utils/logger.dart';
import '../../../../../core/design/rive/rive_vm_binding.dart';
import '../../rive/avatar_rive_contract.dart';
import '../../../domain/models/npc_intent.dart';
import '../../rive/scene_fog_writer.dart';
import '../../rive/prop_drag_controller.dart';
import '../../rive/scene_front_follower.dart';
import '../../rive/scene_npc_writer.dart';
import '../../rive/scene_parallax_writer.dart';
import '../../rive/scene_rain_writer.dart';
import '../../rive/scene_sky_writer.dart';
import '../../rive/scene_time_writer.dart';
import '../stage_camera.dart';
import 'latest_load_gate.dart';
import 'scene_drag_surface.dart';

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
/// Fog and the NPC (contract v11): [fog] and [npc]'s intent (or a non-null
/// [npcOverride], the UI lab) are written to `SceneVM` on every scene load
/// and change, like the rain; the fog also goes to the front artboard.
///
/// The sky and the second NPC (contract v12): [moonPhase] and [festive] are
/// written to `SceneVM` like the time of day, and [npc2] (or [npc2Override],
/// the UI lab) is the second NPC slot, the beach's gulls (`npc2*`). A file
/// that does not declare a property ignores the write.
///
/// Drags (contract v12, M9 rulings 7–9): the scene layer (never [middle],
/// never the chrome) carries a pan recognizer for the scene's drag handle,
/// run by [dragController] (or one of its own): it is attached to each
/// loaded file, detached on a scene swap (the drag ends, nothing is written
/// into the new file), released while [dragsEnabled] is false (a journey),
/// and its cues go to [onDragHaptic], [onDragFoley] and [onDragEvent]. A
/// `prop_tapped` that ends a drag is dropped.
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
    this.fog,
    this.npc,
    this.npcOverride,
    this.moonPhase,
    this.festive,
    this.npc2,
    this.npc2Override,
    this.middle,
    this.preload,
    this.onSceneShown,
    this.dragController,
    this.dragsEnabled = true,
    this.onDragHaptic,
    this.onDragFoley,
    this.onDragEvent,
    this.onDragStarted,
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

  /// Weather fog (contract v11), 0..1; null leaves it clear.
  final ValueListenable<double>? fog;

  /// The scene NPC's intent (contract v11); null leaves it at rest.
  final ValueListenable<NpcIntent>? npc;

  /// A hand-set NPC intent written instead of [npc] while non-null.
  final NpcIntent? npcOverride;

  /// The moon's phase (contract v12): 0..1, or -1 for the moon as drawn
  /// before v12; null leaves it so.
  final ValueListenable<double>? moonPhase;

  /// The December dressing (contract v12), 0..1; null leaves it off.
  final ValueListenable<double>? festive;

  /// The second NPC slot's intent (contract v12, the beach's gulls); null
  /// leaves the file's default (away).
  final ValueListenable<NpcIntent>? npc2;

  /// A hand-set second-slot intent written instead of [npc2] while non-null.
  final NpcIntent? npc2Override;

  /// Drawn over the scene and under its front weather: the avatar.
  final Widget? middle;

  /// A scene to decode ahead (a journey's destination, M7 ruling 10): when
  /// [scene] becomes it, the file swaps in the same frame.
  final AvatarScene? preload;

  /// Called once a newly loaded scene's first frame is on screen.
  final ValueChanged<AvatarScene>? onSceneShown;

  /// Runs the scene's drag handle (null: the view makes its own). A given
  /// controller is not disposed by the view: a test drags through it and
  /// reads the file's numbers back ([PropDragController.readNumber]).
  final PropDragController? dragController;

  /// False while a journey runs: no new drag, one in flight is released.
  final bool dragsEnabled;

  /// A drag's haptics, sounds (foley kinds) and scene events.
  final ValueChanged<DragHaptic>? onDragHaptic;
  final ValueChanged<String>? onDragFoley;
  final ValueChanged<SceneEvent>? onDragEvent;

  /// A drag started on the scene's handle (the user is here, even when the
  /// drag fires no scene event).
  final VoidCallback? onDragStarted;

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
  final SceneFogFollower _fog = SceneFogFollower();
  final SceneFogFollower _frontFog = SceneFogFollower();
  final SceneNpcFollower _npc = SceneNpcFollower();
  final SceneSkyFollower _sky = SceneSkyFollower();
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

  /// The scene's drag handle (the widget's, or our own).
  late PropDragController _drags =
      widget.dragController ?? PropDragController();

  /// The decoded [RiveSceneView.preload] file, until a load takes it.
  AvatarScene? _preloadScene;
  File? _preloadFile;
  int _preloadTicket = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenParallax();
    _syncParallaxActive();
    _rain.follow(widget.rain);
    _time.follow(widget.daylight, widget.dusk);
    _fog.follow(widget.fog);
    _frontFog.follow(widget.fog);
    _followNpc();
    _sky.follow(widget.moonPhase, widget.festive);
    _followFrontRain();
    _syncDrags();
    _loadScene(widget.scene);
    _startPreload(widget.preload);
  }

  /// Hands the widget's drag feedback and state to the controller.
  void _syncDrags() {
    _drags
      ..onHaptic = widget.onDragHaptic
      ..onFoley = widget.onDragFoley
      ..onSceneEvent = widget.onDragEvent
      ..onStarted = widget.onDragStarted
      ..parallax = _dragParallax
      ..enabled = widget.dragsEnabled;
  }

  Offset _dragParallax() => widget.parallaxOverride ?? _parallax;

  void _followNpc() => _npc.follow(
    widget.npc,
    override: widget.npcOverride,
    second: widget.npc2,
    secondOverride: widget.npc2Override,
  );

  /// Decodes [scene] ahead of the switch to it; drops a preload nobody took.
  Future<void> _startPreload(AvatarScene? scene) async {
    if (scene == _preloadScene) {
      return;
    }
    final int ticket = ++_preloadTicket;
    _preloadFile?.dispose();
    _preloadFile = null;
    _preloadScene = scene;
    // nothing to decode for the scene on screen or already loading
    if (scene == null || scene == _loadedScene || scene == widget.scene) {
      return;
    }
    try {
      final File? file = await File.asset(
        AvatarRiveContract.sceneAssetPath(scene.name),
        riveFactory: Factory.rive,
      );
      if (!mounted || ticket != _preloadTicket || _preloadScene != scene) {
        file?.dispose();
        return;
      }
      _preloadFile = file;
    } on Object catch (e) {
      // A missing asset throws a FlutterError (an Error, not an Exception).
      AppLogger.error(
        'RiveSceneView failed to preload ${scene.name}.riv',
        tag: 'RiveSceneView',
        error: e,
      );
    }
  }

  /// The preloaded file of [scene], handed over (null when none is ready).
  File? _takePreload(AvatarScene scene) {
    if (_preloadScene != scene) {
      return null;
    }
    final File? file = _preloadFile;
    _preloadFile = null;
    _preloadScene = null;
    _preloadTicket++;
    return file;
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
    _frontFog.load(binding.setNumber);
    apply(() {
      _frontController = controller;
      _frontBinding = binding;
    });
  }

  void _teardownFront() {
    _front.detach();
    _frontFog.unload();
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
    _drags.reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
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
    if (widget.dragController != oldWidget.dragController) {
      if (oldWidget.dragController == null) {
        _drags.dispose();
      } else {
        _drags.release();
      }
      _drags = widget.dragController ?? PropDragController();
      _drags.reduceMotion =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      // A fresh writer assumes the file's defaults: numbers the old
      // controller left mid-drag are not rewritten (no swap in the app).
      _attachDrags();
    }
    _syncDrags();
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
    if (widget.fog != oldWidget.fog) {
      _fog.follow(widget.fog);
      _frontFog.follow(widget.fog);
    }
    if (widget.npc != oldWidget.npc ||
        widget.npcOverride != oldWidget.npcOverride ||
        widget.npc2 != oldWidget.npc2 ||
        widget.npc2Override != oldWidget.npc2Override) {
      _followNpc();
    }
    if (widget.moonPhase != oldWidget.moonPhase ||
        widget.festive != oldWidget.festive) {
      _sky.follow(widget.moonPhase, widget.festive);
    }
    if (widget.parallaxOverride != oldWidget.parallaxOverride ||
        widget.parallax != oldWidget.parallax) {
      _scheduleParallaxWrite();
    }
    if (widget.scene != oldWidget.scene) {
      // A swap ends the drag now: nothing is written into the new file.
      _drags.detach();
      _loadScene(widget.scene, rebuild: false);
      if (widget.preload != oldWidget.preload) {
        _startPreload(widget.preload);
      }
      return;
    }
    if (widget.preload != oldWidget.preload) {
      _startPreload(widget.preload);
    }
    if (widget.sceneEvent.seq != oldWidget.sceneEvent.seq) {
      // the lamp's state, the wave on the sand
      _drags.onSceneEventPlayed(widget.sceneEvent.sceneEvent);
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
    _preloadTicket++;
    _preloadFile?.dispose();
    _preloadFile = null;
    _rain.dispose();
    _time.dispose();
    _fog.dispose();
    _frontFog.dispose();
    _npc.dispose();
    _sky.dispose();
    _frontRainSource?.removeListener(_syncFront);
    unawaited(_parallaxSub?.cancel());
    widget.parallax?.active = false;
    _teardown();
    if (widget.dragController == null) {
      _drags.dispose();
    } else {
      _drags.release();
    }
    super.dispose();
  }

  /// Loads [scene]'s file, or takes its preload: then the swap happens
  /// right now, without `setState` when [rebuild] is false (from
  /// `didUpdateWidget`, whose build follows).
  Future<void> _loadScene(AvatarScene scene, {bool rebuild = true}) async {
    final int ticket = _loads.begin();
    File? preloaded;
    try {
      preloaded = _takePreload(scene);
      final File? file =
          preloaded ??
          await File.asset(
            AvatarRiveContract.sceneAssetPath(scene.name),
            riveFactory: Factory.rive,
          );
      void apply(VoidCallback change) =>
          preloaded != null && !rebuild ? change() : setState(change);
      if (!_loads.isLatest(ticket)) {
        // A newer scene load started meanwhile: this result is stale.
        file?.dispose();
        return;
      }
      if (file == null) {
        if (mounted) {
          setState(() => _error = '${scene.name}.riv could not be decoded');
          _announceShown(scene, loaded: false);
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
      apply(() {
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
        // And the time of day (v10), the fog and the NPC (v11).
        _time.load(binding.setNumber);
        _fog.load(binding.setNumber);
        _npc.load(binding.setEnum, binding.setNumber);
        // And the sky's calendar and the second NPC slot (v12).
        _sky.load(binding.setNumber);
        // And its drag handle (v12).
        _attachDrags();
        _syncParallaxActive();
      });
      // The new file's front, if it has one and it rains.
      _syncFront(rebuild: preloaded == null || rebuild);
      // Tell the stage once the new file's first frame is drawn.
      _announceShown(scene, loaded: true);
    } on Object catch (e) {
      // A missing asset throws a FlutterError (an Error, not an Exception):
      // it is shown like a decode failure, never left to escape.
      // a taken preload that never got installed is ours to drop
      if (preloaded != null && !identical(preloaded, _file)) {
        preloaded.dispose();
      }
      AppLogger.error(
        'RiveSceneView failed to load ${scene.name}.riv',
        tag: 'RiveSceneView',
        error: e,
      );
      if (mounted && _loads.isLatest(ticket)) {
        setState(() => _error = e.toString());
        _announceShown(scene, loaded: false);
      }
    }
  }

  /// Tells the stage the new scene is on screen once its first frame is
  /// drawn. A scene that failed to load ([loaded] false) is announced too, so
  /// a journey's cut does not wait out its timeout for a file that will never
  /// draw.
  void _announceShown(AvatarScene scene, {required bool loaded}) {
    final ValueChanged<AvatarScene>? shown = widget.onSceneShown;
    if (shown == null) {
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      final bool current = loaded
          ? _loadedScene == scene
          : widget.scene == scene && _loadedScene != scene;
      if (mounted && current) {
        shown(scene);
      }
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// Attaches the drag controller to the file on screen, if any.
  void _attachDrags() {
    final RiveVmBinding? binding = _binding;
    final AvatarScene? scene = _loadedScene;
    if (binding == null || scene == null) {
      return;
    }
    _drags.attach(
      scene,
      setNumber: binding.setNumber,
      readNumber: binding.numberValue,
    );
  }

  void _teardown() {
    _drags.detach();
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
    _fog.unload();
    _npc.unload();
    _sky.unload();
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
    if (propId == null) {
      return;
    }
    if (_drags.shouldDropTap()) {
      // the end of a drag (the cord ends on the lamp), not a tap
      AppLogger.debug(
        'RiveSceneView: dropped $propId tap after a drag',
        tag: 'RiveSceneView',
      );
      return;
    }
    widget.onPropTapped?.call(propId);
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
    // The drags hear only the scene layer: the avatar and the chrome above
    // keep the pointers they claim.
    final Widget back = SceneDragSurface(
      controller: _drags,
      child: _back(context, resolution),
    );
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
