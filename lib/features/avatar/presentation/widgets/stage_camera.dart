import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/models/performance/shot.dart';
import '../rive/stage_framing.dart';

/// The Rive textures' scale while the camera frames its current shot
/// (moonshot M7 ruling 1), published by [StageCamera].
///
/// The Rive views pass it to `RenderResolution.layout(scale:)`. It changes
/// once per camera command, never per frame of a move, so reading it does not
/// rebuild them while the camera glides.
class StageRenderScale extends InheritedWidget {
  const StageRenderScale({
    super.key,
    required this.scale,
    required super.child,
  });

  final double scale;

  /// The scale above [context]; 1 when there is no [StageCamera].
  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StageRenderScale>()?.scale ??
      1;

  @override
  bool updateShouldNotify(StageRenderScale oldWidget) =>
      scale != oldWidget.scale;
}

/// What a [StageCamera] frames right now, for the chrome drawn over the
/// stage outside the camera (M10 ruling 12: the speech bubble maps the
/// mouth to the screen through it).
///
/// [frame] is computed when read, so it is exact for the frame being
/// built; it notifies whenever the camera moves (a command, each frame of a
/// glide or a creep, a new stage size), never from inside a build. Without
/// a camera attached it is the identity on no stage.
class StageCameraView extends ChangeNotifier {
  _StageCameraState? _camera;
  bool _disposed = false;

  /// The stage box the camera frames (null before its first layout).
  Size? get size => _camera?._size;

  /// The framing on screen now (`p' = zoom * p + translate`).
  StageFrame get frame {
    final _StageCameraState? camera = _camera;
    final Size? size = camera?._size;
    if (camera == null || size == null) {
      return StageFraming.identity;
    }
    return camera._framingAt(size);
  }

  /// The shot the camera was last told to frame.
  Shot get shot => _camera?._command.shot ?? Shot.wide;

  // Attach and detach happen while the tree builds or unmounts: listeners
  // may rebuild, so they hear it once the frame is over.
  void _attach(_StageCameraState camera) {
    _camera = camera;
    _movedAfterFrame();
  }

  void _detach(_StageCameraState camera) {
    if (_camera == camera) {
      _camera = null;
      _movedAfterFrame();
    }
  }

  void _moved() => notifyListeners();

  void _movedAfterFrame() {
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The camera over the stage: transforms [child] (the Rive scene, the avatar
/// and their layers, all locked together) to frame the director's
/// [CameraShot]s. Rive-free; the geometry is [StageFraming].
///
/// A command is applied when [shot] changes: a cut jumps, an ease glides from
/// where the camera is to the shot's framing with an ease-in-out cubic over
/// [CameraShot.duration]. The shot's creep is added on top, linearly, over
/// [CameraShot.creepDuration], continuing from the creep on screen. A ticker
/// runs only while something moves; at rest the camera costs nothing. A
/// change of the stage's size reframes at once.
class StageCamera extends StatefulWidget {
  const StageCamera({
    super.key,
    required this.shot,
    required this.child,
    this.view,
  });

  final ValueListenable<CameraShot> shot;
  final Widget child;

  /// Published with what the camera frames, for the chrome (null: none).
  final StageCameraView? view;

  @override
  State<StageCamera> createState() => _StageCameraState();
}

typedef _Framing = StageFrame;

class _StageCameraState extends State<StageCamera>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);

  /// Bumped to repaint the transform; the child is never rebuilt.
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  late CameraShot _command;
  Size? _size;

  /// The framing the camera left (null: no ease running).
  _Framing? _from;

  /// The creep on screen when the command arrived.
  late double _creepFrom;

  /// Time since the command (while the ticker runs).
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _command = widget.shot.value;
    _creepFrom = _command.creep;
    widget.shot.addListener(_onShot);
    widget.view?._attach(this);
  }

  @override
  void didUpdateWidget(StageCamera oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shot != oldWidget.shot) {
      oldWidget.shot.removeListener(_onShot);
      widget.shot.addListener(_onShot);
      _onShot();
    }
    if (widget.view != oldWidget.view) {
      oldWidget.view?._detach(this);
      widget.view?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.shot.removeListener(_onShot);
    widget.view?._detach(this);
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  bool get _easing =>
      _from != null && _command.move == CameraMove.ease && _hasEase;

  bool get _hasEase => _command.duration > Duration.zero;

  double _creepAt(Duration elapsed) {
    final Duration length = _command.creepDuration;
    if (length <= Duration.zero) {
      return _command.creep;
    }
    final double t = math.min(
      1,
      elapsed.inMicroseconds / length.inMicroseconds,
    );
    return lerpDouble(_creepFrom, _command.creep, t)!;
  }

  _Framing _framingAt(Size size) {
    final _Framing target = StageFraming.of(
      _command.shot,
      size,
      creep: _creepAt(_elapsed),
    );
    final _Framing? from = _from;
    if (from == null || !_easing) {
      return target;
    }
    final double t = Curves.easeInOutCubic.transform(
      math.min(1, _elapsed.inMicroseconds / _command.duration.inMicroseconds),
    );
    return (
      zoom: lerpDouble(from.zoom, target.zoom, t)!,
      translate: Offset.lerp(from.translate, target.translate, t)!,
    );
  }

  /// Stops moving and rests on the command's final framing.
  void _settle() {
    _ticker.stop();
    _from = null;
    _creepFrom = _command.creep;
    _elapsed = Duration.zero;
  }

  void _onShot() {
    final CameraShot next = widget.shot.value;
    if (next == _command) {
      return;
    }
    final Size? size = _size;
    final _Framing? current = size == null ? null : _framingAt(size);
    final double creepNow = _creepAt(_elapsed);
    final bool cut = next.move == CameraMove.cut || current == null;
    _ticker.stop();
    _command = next;
    _elapsed = Duration.zero;
    // An ease with no length (a creep step) only moves the creep; a cut
    // starts the creep over.
    _from = cut || next.duration <= Duration.zero ? null : current;
    _creepFrom = cut ? 0 : creepNow;
    final bool creeping =
        next.creepDuration > Duration.zero && _creepFrom != next.creep;
    if (_from != null || creeping) {
      _ticker.start();
    } else {
      _settle();
    }
    // A new command may change the render scale: rebuild once.
    setState(() {});
    _frame.value++;
    widget.view?._moved();
  }

  void _onTick(Duration elapsed) {
    _elapsed = elapsed;
    final bool easeDone = !_easing || elapsed >= _command.duration;
    final bool creepDone =
        _command.creepDuration <= Duration.zero ||
        _creepFrom == _command.creep ||
        elapsed >= _command.creepDuration;
    if (easeDone && creepDone) {
      _settle();
    }
    _frame.value++;
    widget.view?._moved();
  }

  @override
  Widget build(BuildContext context) {
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return widget.child;
        }
        final Size size = constraints.biggest;
        if (_size != size) {
          if (_size != null) {
            // The framing depends on the aspect: reframe instantly.
            _settle();
          }
          // Inside a build: the view hears it after the frame.
          widget.view?._movedAfterFrame();
        }
        _size = size;
        final double renderScale = cameraRenderScale(
          StageFraming.of(_command.shot, size).zoom,
          dpr,
        );
        return StageRenderScale(
          scale: renderScale,
          child: ClipRect(
            child: ValueListenableBuilder<int>(
              valueListenable: _frame,
              child: widget.child,
              builder: (BuildContext context, int _, Widget? child) {
                final _Framing f = _framingAt(size);
                final Matrix4 matrix = Matrix4.diagonal3Values(
                  f.zoom,
                  f.zoom,
                  1,
                )..setTranslationRaw(f.translate.dx, f.translate.dy, 0);
                return Transform(transform: matrix, child: child);
              },
            ),
          ),
        );
      },
    );
  }
}
