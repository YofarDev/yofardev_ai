import 'package:freezed_annotation/freezed_annotation.dart';

part 'gaze_target.freezed.dart';

/// Where the avatar's gaze is pointing.
@freezed
sealed class GazeTarget with _$GazeTarget {
  /// Looking at the viewer.
  const factory GazeTarget.user() = GazeUser;

  /// Glancing away by [angle], normalized −1..1: the head's `yaw` unit, +1
  /// being a full turn toward the viewer's right and 0.6 a 3/4 view.
  const factory GazeTarget.away(double angle) = GazeAway;

  /// Looking at a screen-space point.
  const factory GazeTarget.point(double x, double y) = GazePoint;

  /// Looking at the text input caret while composing.
  const factory GazeTarget.caret() = GazeCaret;
}
