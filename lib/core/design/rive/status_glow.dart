import 'package:flutter/material.dart';
import 'package:rive/rive.dart' show Fit;

import '../../models/talking_phase.dart';
import '../context_ext.dart';
import '../tokens/app_motion.dart';
import 'rive_vm_binding.dart';
import 'ui_kit_artboard.dart';
import 'ui_kit_contract.dart';

/// The soft horizontal glow behind the composer (`StatusGlow` artboard),
/// tinted with the scene accent and shaped by the talking [phase].
///
/// Decorative: it ignores pointers and semantics, and fills the bounded box
/// its parent gives it.
class StatusGlow extends StatelessWidget {
  const StatusGlow({super.key, required this.phase});

  final TalkingPhase phase;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.tokens.scene.accent;
    final Color glow = context.tokens.scene.glow;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SizedBox.expand(
          child: UiKitArtboard(
            artboard: UiKitContract.statusGlowArtboard,
            fit: Fit.fill,
            apply: (RiveVmBinding binding) {
              binding.setEnum(
                UiKitContract.glowPropPhase,
                UiKitContract.glowPhaseValues,
                phase.name,
              );
              binding.setColor(UiKitContract.glowPropAccent, accent);
              binding.setBool(UiKitContract.glowPropReduceMotion, reduceMotion);
            },
            fallback: AnimatedOpacity(
              opacity: _opacityFor(phase),
              duration: reduceMotion ? AppMotion.fast : AppMotion.slow,
              curve: AppMotion.standard,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: <Color>[glow, glow.withValues(alpha: 0)],
                    transform: const _StretchToBox(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static double _opacityFor(TalkingPhase phase) => switch (phase) {
    TalkingPhase.idle => 0.35,
    TalkingPhase.waiting => 0.6,
    TalkingPhase.generating => 0.8,
    TalkingPhase.speaking => 1,
    TalkingPhase.error => 0.45,
  };
}

/// Stretches a radial gradient (a circle sized by the box's shortest side)
/// into an ellipse that touches every edge of the box.
class _StretchToBox extends GradientTransform {
  const _StretchToBox();

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    if (bounds.isEmpty) {
      return null;
    }
    final double sx = bounds.width >= bounds.height
        ? bounds.width / bounds.height
        : 1;
    final double sy = bounds.height > bounds.width
        ? bounds.height / bounds.width
        : 1;
    final Offset center = bounds.center;
    return Matrix4.translationValues(center.dx, center.dy, 0)
      ..multiply(Matrix4.diagonal3Values(sx, sy, 1))
      ..multiply(Matrix4.translationValues(-center.dx, -center.dy, 0));
  }
}
