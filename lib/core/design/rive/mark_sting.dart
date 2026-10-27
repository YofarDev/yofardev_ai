import 'package:flutter/material.dart';

import '../context_ext.dart';
import 'rive_vm_binding.dart';
import 'ui_kit_artboard.dart';
import 'ui_kit_contract.dart';

/// The app mark (`Mark` artboard), for the splash and onboarding. Call
/// [MarkStingState.play] through a `GlobalKey<MarkStingState>` to play the
/// logo sting once. The Flutter fallback is a static monogram: a display-font
/// "Y" on an accent disc.
class MarkSting extends StatefulWidget {
  const MarkSting({super.key, this.size = 96});

  final double size;

  /// The letter of the fallback monogram.
  static const String monogram = 'Y';

  @override
  State<MarkSting> createState() => MarkStingState();
}

class MarkStingState extends State<MarkSting> {
  final GlobalKey<UiKitArtboardState> _artboardKey =
      GlobalKey<UiKitArtboardState>();

  /// Plays the logo sting once. Does nothing while the fallback is shown.
  void play() {
    _artboardKey.currentState?.binding?.fireTrigger(UiKitContract.markPropPlay);
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = context.tokens.scene.accent;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: UiKitArtboard(
          key: _artboardKey,
          artboard: UiKitContract.markArtboard,
          apply: (RiveVmBinding binding) {
            binding.setColor(UiKitContract.markPropAccent, accent);
          },
          fallback: _Monogram(size: widget.size, accent: accent),
        ),
      ),
    );
  }
}

/// The static mark: [MarkSting.monogram] in the display font, on an accent
/// disc.
class _Monogram extends StatelessWidget {
  const _Monogram({required this.size, required this.accent});

  final double size;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
      child: Center(
        child: Text(
          MarkSting.monogram,
          textScaler: TextScaler.noScaling,
          style: context.text.displayLarge?.copyWith(
            color: context.tokens.scene.onAccent,
            fontSize: size * 0.56,
            height: 1,
          ),
        ),
      ),
    );
  }
}
