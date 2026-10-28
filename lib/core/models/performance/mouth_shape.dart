import 'package:freezed_annotation/freezed_annotation.dart';

import 'viseme.dart';

part 'mouth_shape.freezed.dart';

/// The mouth channels a viseme drives, each in [0, 1]. Dart blends these at
/// frame rate and writes them to the avatar's mouth AUs.
@freezed
sealed class MouthShape with _$MouthShape {
  const factory MouthShape({
    @Default(0.0) double jaw,
    @Default(0.0) double pucker,
    @Default(0.0) double stretch,
    @Default(0.0) double press,
    @Default(0.0) double lipTuck,
    @Default(0.0) double tongueUp,
  }) = _MouthShape;

  const MouthShape._();

  /// Relaxed mouth (every channel at zero).
  static const MouthShape rest = MouthShape();

  /// Per-channel linear interpolation towards [to] at [t], clamped to [0, 1].
  MouthShape lerp(MouthShape to, double t) => MouthShape(
    jaw: _mix(jaw, to.jaw, t),
    pucker: _mix(pucker, to.pucker, t),
    stretch: _mix(stretch, to.stretch, t),
    press: _mix(press, to.press, t),
    lipTuck: _mix(lipTuck, to.lipTuck, t),
    tongueUp: _mix(tongueUp, to.tongueUp, t),
  );

  /// The target mouth shape for [v].
  static MouthShape forViseme(Viseme v) => switch (v) {
    Viseme.sil => rest,
    Viseme.pp => const MouthShape(press: 0.6),
    Viseme.ff => const MouthShape(jaw: 0.08, lipTuck: 1),
    Viseme.th => const MouthShape(jaw: 0.25, tongueUp: 1),
    Viseme.dd => const MouthShape(jaw: 0.25, stretch: 0.2, tongueUp: 0.6),
    Viseme.kk => const MouthShape(jaw: 0.3, stretch: 0.1),
    Viseme.ch => const MouthShape(jaw: 0.15, pucker: 0.6),
    // lips parted over clenched teeth
    Viseme.ss => const MouthShape(jaw: 0.12, stretch: 0.5, lipTuck: 0.35),
    Viseme.nn => const MouthShape(jaw: 0.18, tongueUp: 0.7),
    Viseme.rr => const MouthShape(jaw: 0.2, pucker: 0.4),
    Viseme.aa => const MouthShape(jaw: 0.9, stretch: 0.15),
    Viseme.e => const MouthShape(jaw: 0.5, stretch: 0.55),
    Viseme.ih => const MouthShape(jaw: 0.35, stretch: 0.45),
    Viseme.oh => const MouthShape(jaw: 0.6, pucker: 0.6),
    Viseme.ou => const MouthShape(jaw: 0.25, pucker: 0.95),
  };

  /// How strongly [v] wins when neighbouring visemes overlap (coarticulation):
  /// lip seals and labiodentals dominate, open vowels give way.
  static double dominance(Viseme v) => switch (v) {
    Viseme.sil => 0.2,
    Viseme.pp => 1.0,
    Viseme.ff => 0.9,
    Viseme.th || Viseme.ch || Viseme.ss => 0.7,
    Viseme.dd || Viseme.rr || Viseme.ou => 0.6,
    Viseme.kk || Viseme.nn || Viseme.oh => 0.5,
    Viseme.aa || Viseme.e || Viseme.ih => 0.4,
  };
}

double _mix(double a, double b, double t) => (a + (b - a) * t).clamp(0.0, 1.0);
