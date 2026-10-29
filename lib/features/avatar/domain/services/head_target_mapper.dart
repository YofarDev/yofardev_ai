import '../../../../core/models/performance/avatar_prop.dart';
import '../../../../core/models/performance/gaze_target.dart';
import '../models/head_pose.dart';

/// Pitch used while looking at a tablet / tool (down).
const double kToolPitch = -0.5;

/// Widening of the glance angle while a tool runs: the director's 0.6 becomes
/// a 0.84 three-quarter turn toward the tablet.
const double kToolGlanceGain = 1.4;

/// Pitch used while glancing away to think (up).
const double kThinkingPitch = 0.2;

/// Pitch used while watching the text caret.
const double kCaretPitch = -0.8;

/// Yaw while the tablet is out: held at chest height toward the viewer's
/// right, a 3/4 turn that keeps the lit face visible.
const double kTabletYaw = 0.6;

/// How far the head turns across the field's width while watching the caret.
const double kCaretYawSpan = 0.4;

/// Maps a gaze target to the head target the rig should hold.
///
/// - `user` → (0, 0).
/// - `away(angle)` → yaw = angle (normalized −1..1) while thinking, looking
///   up. While a tool runs it turns further (yaw = angle x 1.4, clamped to
///   ±1: 0.6 becomes 0.84), looks down at the tablet and reads (eye
///   saccades).
/// - `caret(x)` → a small turn following the caret across the field
///   ((x − 0.5) × 0.4), looking down at the composer.
/// - A held tablet overrides the gaze: (0.6, −0.5), reading.
/// - `point(x, y)` with normalized 0..1 screen coordinates.
HeadTarget headTargetFor(
  GazeTarget gaze, {
  String? activeTool,
  AvatarProp prop = AvatarProp.none,
}) {
  if (prop == AvatarProp.tablet) {
    return const HeadTarget(kTabletYaw, kToolPitch, reading: true);
  }
  return switch (gaze) {
    GazeUser() => HeadTarget.zero,
    GazeAway(:final double angle) when activeTool != null => HeadTarget(
      (angle * kToolGlanceGain).clamp(-1.0, 1.0),
      kToolPitch,
      reading: true,
    ),
    GazeAway(:final double angle) => HeadTarget(
      angle.clamp(-1.0, 1.0),
      kThinkingPitch,
    ),
    GazeCaret(:final double x) => HeadTarget(
      (x.clamp(0.0, 1.0) - 0.5) * kCaretYawSpan,
      kCaretPitch,
    ),
    GazePoint(:final double x, :final double y) => HeadTarget(
      ((x.clamp(0.0, 1.0) - 0.5) * 1.2).clamp(-1.0, 1.0),
      ((0.5 - y.clamp(0.0, 1.0)) * 0.6).clamp(-1.0, 1.0),
    ),
  };
}
