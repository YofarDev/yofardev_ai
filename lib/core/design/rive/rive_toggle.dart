import 'package:flutter/material.dart';

import '../components/interactive_surface.dart';
import '../context_ext.dart';
import '../tokens/app_motion.dart';
import '../tokens/app_radius.dart';
import 'rive_vm_binding.dart';
import 'ui_kit_artboard.dart';
import 'ui_kit_contract.dart';

/// On/off switch (`Toggle` artboard) in a 48 dp hit area. Tap, Enter or
/// Space calls [onChanged] with the opposite of [value]; screen readers see
/// a toggle (optionally named by [semanticLabel]).
class RiveToggle extends StatelessWidget {
  const RiveToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? semanticLabel;

  /// The drawn switch: the artboard (104×64) at half size.
  static const Size visualSize = Size(52, 32);
  static const double hitHeight = 48;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.tokens.scene.accent;
    final Color track = context.colors.outline;
    final Color knob = value
        ? context.tokens.scene.onAccent
        : context.colors.onSurface;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      container: true,
      toggled: value,
      label: semanticLabel,
      child: InteractiveSurface(
        onTap: () => onChanged(!value),
        builder: (BuildContext context, InteractiveStates states) {
          return SizedBox(
            width: visualSize.width,
            height: hitHeight,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: states.focused ? accent : Colors.transparent,
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignOutside,
                  ),
                ),
                child: SizedBox.fromSize(
                  size: visualSize,
                  child: UiKitArtboard(
                    artboard: UiKitContract.toggleArtboard,
                    apply: (RiveVmBinding binding) {
                      binding.setBool(UiKitContract.togglePropValue, value);
                      binding.setColor(UiKitContract.togglePropAccent, accent);
                      binding.setColor(UiKitContract.togglePropTrack, track);
                      binding.setColor(UiKitContract.togglePropKnob, knob);
                    },
                    fallback: _ToggleFallback(
                      value: value,
                      accent: accent,
                      track: track,
                      knob: knob,
                      duration: reduceMotion ? AppMotion.fast : AppMotion.base,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Flutter rendering of the switch: a pill track (accent when on) and a
/// sliding knob.
class _ToggleFallback extends StatelessWidget {
  const _ToggleFallback({
    required this.value,
    required this.accent,
    required this.track,
    required this.knob,
    required this.duration,
  });

  final bool value;
  final Color accent;
  final Color track;
  final Color knob;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    const double inset = 4;
    final double knobSize = RiveToggle.visualSize.height - inset * 2;
    return AnimatedContainer(
      duration: duration,
      curve: AppMotion.standard,
      padding: const EdgeInsets.all(inset),
      decoration: BoxDecoration(
        color: value ? accent : track,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: AnimatedAlign(
        duration: duration,
        curve: AppMotion.standard,
        alignment: value
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: AnimatedContainer(
          duration: duration,
          curve: AppMotion.standard,
          width: knobSize,
          height: knobSize,
          decoration: BoxDecoration(color: knob, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
