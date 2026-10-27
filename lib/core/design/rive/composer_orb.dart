import 'package:flutter/material.dart';

import '../context_ext.dart';
import '../tokens/app_motion.dart';
import 'rive_vm_binding.dart';
import 'ui_kit_artboard.dart';
import 'ui_kit_contract.dart';

/// The composer's action orb (`ComposerOrb` artboard): mic, send, listening
/// ring, thinking, stop and error, on the current scene's accent.
///
/// Visual only: the composer owns the 48 dp tap target and its semantics.
/// [level] is the microphone input level (0–1), used while listening.
class ComposerOrb extends StatelessWidget {
  const ComposerOrb({
    super.key,
    required this.state,
    this.level = 0,
    this.size = 48,
  });

  final ComposerOrbState state;
  final double level;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.tokens.scene.accent;
    final Color onAccent = context.tokens.scene.onAccent;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final double clampedLevel = level.clamp(
      UiKitContract.orbLevelMin,
      UiKitContract.orbLevelMax,
    );
    return SizedBox.square(
      dimension: size,
      child: UiKitArtboard(
        artboard: UiKitContract.composerOrbArtboard,
        apply: (RiveVmBinding binding) {
          binding.setEnum(
            UiKitContract.orbPropState,
            UiKitContract.orbStateValues,
            state.name,
          );
          binding.setNumber(UiKitContract.orbPropLevel, clampedLevel);
          binding.setColor(UiKitContract.orbPropAccent, accent);
          binding.setColor(UiKitContract.orbPropOnAccent, onAccent);
          binding.setBool(UiKitContract.orbPropReduceMotion, reduceMotion);
        },
        fallback: _ComposerOrbFallback(
          state: state,
          level: clampedLevel,
          size: size,
          accent: accent,
          onAccent: onAccent,
          reduceMotion: reduceMotion,
        ),
      ),
    );
  }
}

/// Flutter rendering of the orb: an accent disc (a ring while listening)
/// with one icon per state, cross-faded on state changes.
class _ComposerOrbFallback extends StatelessWidget {
  const _ComposerOrbFallback({
    required this.state,
    required this.level,
    required this.size,
    required this.accent,
    required this.onAccent,
    required this.reduceMotion,
  });

  final ComposerOrbState state;
  final double level;
  final double size;
  final Color accent;
  final Color onAccent;
  final bool reduceMotion;

  static IconData iconFor(ComposerOrbState state) => switch (state) {
    ComposerOrbState.idle => Icons.mic,
    ComposerOrbState.typing => Icons.arrow_upward,
    ComposerOrbState.listening => Icons.graphic_eq,
    ComposerOrbState.thinking => Icons.more_horiz,
    ComposerOrbState.speaking => Icons.stop,
    ComposerOrbState.error => Icons.priority_high,
  };

  @override
  Widget build(BuildContext context) {
    final bool listening = state == ComposerOrbState.listening;
    final Duration duration = reduceMotion ? AppMotion.fast : AppMotion.base;
    // The listening ring thickens with the input level (no repeating pulse).
    final double ringWidth = size * (0.06 + 0.06 * level);
    return AnimatedContainer(
      duration: duration,
      curve: AppMotion.standard,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: listening ? Colors.transparent : accent,
        border: Border.all(
          color: accent,
          width: listening ? ringWidth : 0,
          style: listening ? BorderStyle.solid : BorderStyle.none,
        ),
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: AppMotion.standard,
        switchOutCurve: AppMotion.standard,
        child: Icon(
          iconFor(state),
          key: ValueKey<ComposerOrbState>(state),
          size: size * 0.5,
          color: listening ? accent : onAccent,
        ),
      ),
    );
  }
}
