import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../rive/prop_drag_controller.dart';

/// The scene layer's pan recognizer (M9 ruling 7): wraps the scene only
/// (never the avatar above it, never the Stage chrome), so it hears only
/// pointers nobody above claimed. It joins the gesture arena only for a
/// pointer that goes down on the [controller]'s handle; anywhere else it
/// stays out, and taps (Rive's own listeners get the raw pointers anyway)
/// are untouched.
class SceneDragSurface extends StatelessWidget {
  const SceneDragSurface({
    super.key,
    required this.controller,
    required this.child,
  });

  final PropDragController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Size box() => context.size ?? Size.zero;
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        HandlePanGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<HandlePanGestureRecognizer>(
              () => HandlePanGestureRecognizer(
                canStart: (Offset local) => controller.canStart(local, box()),
                debugOwner: this,
              ),
              (HandlePanGestureRecognizer recognizer) {
                recognizer.canStart = (Offset local) {
                  return controller.canStart(local, box());
                };
                recognizer.dragStartBehavior = DragStartBehavior.down;
                recognizer.onStart = (DragStartDetails details) {
                  controller.start(details.localPosition, box());
                };
                recognizer.onUpdate = (DragUpdateDetails details) {
                  controller.update(details.localPosition, box());
                };
                recognizer.onEnd = (DragEndDetails _) {
                  controller.end();
                };
                recognizer.onCancel = controller.end;
              },
            ),
      },
      child: child,
    );
  }
}

/// A [PanGestureRecognizer] that only tracks pointers [canStart] accepts
/// (their pointer-down position, local to the detector), and accepts after
/// [acceptDistance] instead of the pan slop.
class HandlePanGestureRecognizer extends PanGestureRecognizer {
  HandlePanGestureRecognizer({required this.canStart, super.debugOwner});

  /// Logical px the finger moves before the drag starts. The pan slop (36 px
  /// on touch) would arrive as one jump with the accept (the cord at ~0.8 in
  /// one frame, the poke's tip ~0.75 off, a "stir" out of nothing). 3 px
  /// (~7 artboard px on a phone: cord 0.07, tip 0.06) still lets a still
  /// finger's jitter be a tap, and the recognizer only competes for pointers
  /// that land on the handle, so nothing else loses its gestures.
  static const double acceptDistance = 3;

  bool Function(Offset local) canStart;

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) => globalDistanceMoved.abs() > acceptDistance;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      super.isPointerAllowed(event) && canStart(event.localPosition);
}
