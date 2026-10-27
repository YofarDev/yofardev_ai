import 'package:flutter/material.dart';

import '../context_ext.dart';
import 'rive_vm_binding.dart';
import 'ui_kit_artboard.dart';
import 'ui_kit_contract.dart';

/// The glyph of a running tool (`ToolIcon` artboard), tinted with the
/// surface's content color; it animates while [running] (Rive only — the
/// Flutter fallback is a static Material icon).
///
/// The artboard has no `reduceMotion` property, so when animations are
/// disabled (`MediaQuery.disableAnimationsOf`) the widget writes
/// `running = false`: the glyph holds still instead of looping.
class ToolIcon extends StatelessWidget {
  const ToolIcon({
    super.key,
    required this.kind,
    required this.running,
    this.size = 24,
  });

  final ToolIconKind kind;
  final bool running;
  final double size;

  static IconData fallbackIconFor(ToolIconKind kind) => switch (kind) {
    ToolIconKind.search => Icons.search,
    ToolIconKind.weather => Icons.wb_sunny,
    ToolIconKind.news => Icons.newspaper,
    ToolIconKind.memory => Icons.psychology,
    ToolIconKind.generic => Icons.auto_awesome,
  };

  @override
  Widget build(BuildContext context) {
    final Color tint = context.colors.onSurface;
    final bool animate = running && !MediaQuery.disableAnimationsOf(context);
    return SizedBox.square(
      dimension: size,
      child: UiKitArtboard(
        artboard: UiKitContract.toolIconArtboard,
        ambient: animate,
        apply: (RiveVmBinding binding) {
          binding.setEnum(
            UiKitContract.toolPropKind,
            UiKitContract.toolKindValues,
            kind.name,
          );
          binding.setBool(UiKitContract.toolPropRunning, animate);
          binding.setColor(UiKitContract.toolPropTint, tint);
        },
        fallback: Icon(fallbackIconFor(kind), size: size, color: tint),
      ),
    );
  }
}
