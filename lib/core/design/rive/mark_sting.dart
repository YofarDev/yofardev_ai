import 'package:flutter/material.dart';

import '../context_ext.dart';
import 'rive_vm_binding.dart';
import 'ui_kit_artboard.dart';
import 'ui_kit_contract.dart';

/// The app mark (`Mark` artboard), for the splash and onboarding. Call
/// [MarkStingState.play] through a `GlobalKey<MarkStingState>` to play the
/// logo sting once; the Flutter fallback is the static app icon.
class MarkSting extends StatefulWidget {
  const MarkSting({super.key, this.size = 96});

  final double size;

  /// The app icon shown while (or instead of) the Rive mark.
  static const String iconAssetPath = 'assets/icon.png';

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
          fallback: ClipOval(
            child: Image.asset(
              MarkSting.iconAssetPath,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stack) =>
                      ColoredBox(color: accent),
            ),
          ),
        ),
      ),
    );
  }
}
