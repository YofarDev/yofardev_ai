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

/// Maps a gaze target to the head target the rig should hold.
///
/// - `user` → (0, 0).
/// - `away(angle)` → yaw = angle (normalized −1..1) while thinking, looking
///   up. While a tool runs it turns further (yaw = angle x 1.4, clamped to
///   ±1: 0.6 becomes 0.84), looks down at the tablet and reads (eye
///   saccades).
/// - `caret` → straight on, looking down at the composer.
/// - `point(x, y)` with normalized 0..1 screen coordinates.
HeadTarget headTargetFor(GazeTarget gaze, {String? activeTool}) {
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
    GazeCaret() => const HeadTarget(0, kCaretPitch),
    GazePoint(:final double x, :final double y) => HeadTarget(
      ((x.clamp(0.0, 1.0) - 0.5) * 1.2).clamp(-1.0, 1.0),
      ((0.5 - y.clamp(0.0, 1.0)) * 0.6).clamp(-1.0, 1.0),
    ),
  };
}
