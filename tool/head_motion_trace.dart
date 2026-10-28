// Scripted 6 s head-turn scenario at 60 fps for the art critic.
//
//   dart run tool/head_motion_trace.dart > out.json
//
// user (0.8 s) -> away(0.6) with a tool (2.4 s) -> user (1.4 s) -> caret
// (1.4 s). Prints a JSON list of per-frame poses.
import 'dart:convert';
import 'dart:io';

import 'package:yofardev_ai/core/models/performance/gaze_target.dart';
import 'package:yofardev_ai/features/avatar/domain/models/head_pose.dart';
import 'package:yofardev_ai/features/avatar/domain/services/head_motion_solver.dart';
import 'package:yofardev_ai/features/avatar/domain/services/head_target_mapper.dart';

class _Beat {
  const _Beat(this.startS, this.gaze, {this.tool});

  final double startS;
  final GazeTarget gaze;
  final String? tool;
}

void main() {
  const int fps = 60;
  const int frames = 6 * fps;
  const List<_Beat> beats = <_Beat>[
    _Beat(0, GazeTarget.user()),
    _Beat(0.8, GazeTarget.away(0.6), tool: 'web_search'),
    _Beat(3.2, GazeTarget.user()),
    _Beat(4.6, GazeTarget.caret()),
  ];

  final HeadMotionSolver solver = HeadMotionSolver();
  final Duration dt = Duration(microseconds: (1e6 / fps).round());
  final List<Map<String, double>> out = <Map<String, double>>[];
  int beat = 0;
  for (int frame = 0; frame < frames; frame++) {
    final double t = frame / fps;
    while (beat < beats.length && beats[beat].startS <= t + 1e-9) {
      final HeadTarget target = headTargetFor(
        beats[beat].gaze,
        activeTool: beats[beat].tool,
      );
      solver.setTarget(target.yaw, target.pitch);
      beat++;
    }
    final HeadPose pose = solver.step(dt);
    out.add(<String, double>{
      't': _round(t),
      for (final MapEntry<String, double> e in pose.toJson().entries)
        e.key: _round(e.value),
    });
  }
  stdout.writeln(jsonEncode(out));
}

double _round(double v) => (v * 1e5).round() / 1e5;
