import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/scheduler.dart';

import '../../../../core/models/avatar_scene.dart';
import '../../../../core/services/audio/foley_service.dart' show DragHaptic;
import '../../domain/models/scene_drag.dart';
import '../../domain/services/prop_drag_physics.dart';
import 'scene_drag_writer.dart';

/// Schedules [callback] for the next frame.
typedef DragFrameScheduler = void Function(VoidCallback callback);

/// The scene's drag handle on screen (contract v12, M9 rulings 7–9).
///
/// `RiveSceneView` attaches it to each loaded scene file ([attach]: the
/// scene and its `SceneVM` number sink) and detaches it when the file goes
/// ([detach]: a scene swap ends the drag, nothing more is written). Its pan
/// recognizer (`SceneDragSurface`, on the scene layer only) asks [canStart]
/// at pointer-down, then feeds [start] / [update] / [end] with positions
/// local to the scene widget: the camera's `Transform` is an ancestor, so
/// they are already untransformed.
///
/// A local position maps to artboard px with `Fit.cover`, centred
/// ([SceneDrags.toArtboard]), minus the handle plane's [parallax] offset, and
/// is hit-tested against the handle's rect. [PropDragPhysics] (pure) moves
/// the numbers; one [SceneDragWriter] writes them once per frame, only while
/// a finger moves or something animates: at rest nothing is written.
///
/// Cues go out as [onHaptic] (start and steps: selection; a pull's
/// threshold and a flare: impact), [onFoley] (`click` at a pull's threshold,
/// `bell` for the hut's rope) and [onSceneEvent] (the cord's `lightsOff` /
/// `lightsOn` alternately, the rope's `bell`, the poke's `flare`).
/// [onSceneEvent] echoes of the scene's own events keep the lamp's state and
/// wash the beach's trail on a `bigWave`.
///
/// Rive still gets the raw pointers: [shouldDropTap] tells the view to drop
/// a `prop_tapped` that ends a drag (moved past the touch slop) or arrives
/// within [tapGrace] of one.
class PropDragController {
  PropDragController({
    Duration Function()? now,
    DragFrameScheduler? scheduleFrame,
  }) : _now = now ?? _stopwatchClock(),
       _scheduleFrame = scheduleFrame ?? _nextFrame;

  /// A `prop_tapped` this soon after a drag ends is part of it.
  static const Duration tapGrace = Duration(milliseconds: 250);

  final Duration Function() _now;
  final DragFrameScheduler _scheduleFrame;

  /// A drag's haptics (null: none).
  ValueChanged<DragHaptic>? onHaptic;

  /// A drag's sounds, by foley kind (null: silent).
  ValueChanged<String>? onFoley;

  /// A drag started on the handle: the user is here (null: nobody listens).
  VoidCallback? onStarted;

  /// A drag's scene actions (null: none).
  ValueChanged<SceneEvent>? onSceneEvent;

  /// The scene's parallax offset now (each axis −1..1).
  Offset Function() parallax = _noParallax;

  AvatarScene? _scene;
  PropDragPhysics? _physics;
  SceneDragWriter? _writer;
  double? Function(String name)? _read;

  bool _enabled = true;
  bool _reduceMotion = false;
  bool _lightsOff = false;

  Offset? _downLocal;
  bool _moved = false;
  bool _lastDragMoved = false;
  Duration? _endedAt;

  bool _frameScheduled = false;

  /// Bumped by [detach]: a frame scheduled for a former scene does nothing.
  int _generation = 0;

  /// The scene attached now (null: none).
  AvatarScene? get scene => _scene;

  /// The attached scene's handle (null: none, or no scene).
  SceneDragHandle? get handle => _physics?.handle;

  /// Whether a finger holds the handle.
  bool get dragging => _physics?.dragging ?? false;

  /// Whether something still moves without the finger.
  bool get animating => _physics?.animating ?? false;

  /// The handle's numbers as the physics holds them (empty without one).
  Map<String, double> get values =>
      _physics?.values ?? const <String, double>{};

  /// The attached file's number [name] read back from the view model (null
  /// without a reader or the property): for the real-runtime tests.
  double? readNumber(String name) => _read?.call(name);

  /// Whether new drags may start (false during a journey: a drag in flight
  /// is released, its spring settles).
  bool get enabled => _enabled;
  set enabled(bool value) {
    if (value == _enabled) {
      return;
    }
    _enabled = value;
    if (!value) {
      end();
    }
  }

  /// Reduce motion: springs settle at once, no inertia (haptics unchanged).
  bool get reduceMotion => _reduceMotion;
  set reduceMotion(bool value) {
    _reduceMotion = value;
    _physics?.reduceMotion = value;
  }

  /// A scene file loaded: [scene]'s handle (if any) is live, written through
  /// [setNumber]; [readNumber] reads the file's numbers back.
  void attach(
    AvatarScene scene, {
    required void Function(String name, double value) setNumber,
    double? Function(String name)? readNumber,
  }) {
    detach();
    _scene = scene;
    _read = readNumber;
    _lightsOff = false;
    final SceneDragHandle? handle = SceneDrags.of(scene);
    if (handle == null) {
      return;
    }
    _physics = PropDragPhysics(handle, reduceMotion: _reduceMotion);
    _writer = SceneDragWriter(setNumber, defaults: handle.defaults);
  }

  /// The scene file goes (a swap, a teardown): the drag ends where it is,
  /// springs and inertia stop, and nothing more is written.
  void detach() {
    _physics?.halt();
    _physics = null;
    _writer = null;
    _read = null;
    _scene = null;
    _downLocal = null;
    _moved = false;
    _lastDragMoved = false;
    _endedAt = null;
    // A frame scheduled for the former file does nothing (the generation
    // check), and must not keep the next file's first frame from scheduling.
    _frameScheduled = false;
    _generation++;
  }

  /// [local] (in a scene widget [box] big) in the handle's rest frame.
  Offset _toHandle(SceneDragHandle handle, Offset local, Size box) =>
      SceneDrags.toArtboard(local, box) -
      SceneDrags.planeOffset(handle.plane, parallax());

  /// Whether a pointer down at [local] lands on the handle.
  bool canStart(Offset local, Size box) {
    final SceneDragHandle? handle = this.handle;
    if (!_enabled || handle == null || box.isEmpty) {
      return false;
    }
    return SceneDrags.hits(
      handle,
      SceneDrags.toArtboard(local, box),
      parallax(),
    );
  }

  /// A pan accepted at [local] (its pointer-down position): starts the drag
  /// when it lands on the handle. Returns whether it did.
  bool start(Offset local, Size box) {
    final PropDragPhysics? physics = _physics;
    if (physics == null || !canStart(local, box)) {
      return false;
    }
    _downLocal = local;
    _moved = false;
    physics.start(_toHandle(physics.handle, local, box), _now());
    _afterInput(physics);
    onStarted?.call();
    return true;
  }

  /// The finger moved to [local].
  void update(Offset local, Size box) {
    final PropDragPhysics? physics = _physics;
    if (physics == null || !physics.dragging) {
      return;
    }
    final Offset? down = _downLocal;
    if (down != null && (local - down).distance > kTouchSlop) {
      _moved = true;
    }
    physics.move(_toHandle(physics.handle, local, box), _now());
    _afterInput(physics);
  }

  /// The finger left, or the pan was cancelled.
  void end() {
    final PropDragPhysics? physics = _physics;
    if (physics == null || !physics.dragging) {
      return;
    }
    final Duration now = _now();
    physics.end(now);
    _endedAt = now;
    _lastDragMoved = _moved;
    _downLocal = null;
    _moved = false;
    _afterInput(physics);
  }

  /// A `prop_tapped` arrived: whether it belongs to a drag (drop it).
  bool shouldDropTap() {
    if (dragging && _moved) {
      return true;
    }
    final Duration? ended = _endedAt;
    return ended != null && _lastDragMoved && _now() - ended <= tapGrace;
  }

  /// One of the scene's events played (whoever fired it).
  void onSceneEventPlayed(SceneEvent event) {
    final PropDragPhysics? physics = _physics;
    switch (event) {
      case SceneEvent.lightsOff:
        _lightsOff = true;
      case SceneEvent.lightsOn:
        _lightsOff = false;
      case SceneEvent.bigWave:
        if (physics != null && physics.handle.kind == DragKind.trail) {
          physics.wash(_now());
          _schedule();
        }
      default:
        break;
    }
  }

  /// Where the handle's centre is now in a scene widget [box] big (null
  /// without a handle): what a test drags.
  Offset? handleCentre(Size box) {
    final SceneDragHandle? handle = this.handle;
    if (handle == null) {
      return null;
    }
    return SceneDrags.toLocal(
      handle.rect.center + SceneDrags.planeOffset(handle.plane, parallax()),
      box,
    );
  }

  /// Advances the physics and writes what changed: once per frame while a
  /// finger moves or something animates (scheduled by the controller).
  @visibleForTesting
  void frame() {
    _frameScheduled = false;
    final PropDragPhysics? physics = _physics;
    final SceneDragWriter? writer = _writer;
    if (physics == null || writer == null) {
      return;
    }
    physics.tick(_now());
    _emit(physics.takeCues());
    final bool moving = physics.animating;
    writer.write(physics.values, animating: moving);
    if (moving) {
      _schedule();
    }
  }

  /// The view lets go of the controller (it disposes, or a new controller
  /// replaces this one): detached, its feedback and parallax dropped, so it
  /// holds nothing of a dead view.
  void release() {
    detach();
    onHaptic = null;
    onFoley = null;
    onSceneEvent = null;
    onStarted = null;
    parallax = _noParallax;
  }

  void dispose() => release();

  void _afterInput(PropDragPhysics physics) {
    _emit(physics.takeCues());
    _schedule();
  }

  void _schedule() {
    if (_frameScheduled || _physics == null) {
      return;
    }
    _frameScheduled = true;
    final int generation = _generation;
    _scheduleFrame(() {
      if (generation != _generation) {
        return;
      }
      frame();
    });
  }

  void _emit(List<DragCue> cues) {
    for (final DragCue cue in cues) {
      switch (cue) {
        case DragCue.start:
        case DragCue.tick:
          onHaptic?.call(DragHaptic.selection);
        case DragCue.pullFired:
          onHaptic?.call(DragHaptic.impact);
          onFoley?.call('click');
          _pullAction();
        case DragCue.flare:
          onHaptic?.call(DragHaptic.impact);
          onSceneEvent?.call(SceneEvent.flare);
      }
    }
  }

  /// A pull past its threshold: the scene's action.
  void _pullAction() {
    switch (_scene) {
      case AvatarScene.livingRoom:
        onSceneEvent?.call(
          _lightsOff ? SceneEvent.lightsOn : SceneEvent.lightsOff,
        );
      case AvatarScene.mountainHut:
        onFoley?.call('bell');
        onSceneEvent?.call(SceneEvent.bell);
      default:
        break;
    }
  }

  static Offset _noParallax() => Offset.zero;

  static Duration Function() _stopwatchClock() {
    final Stopwatch stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  static void _nextFrame(VoidCallback callback) {
    SchedulerBinding.instance.scheduleFrameCallback((Duration _) => callback());
  }
}
