import 'package:flutter/material.dart';

import '../context_ext.dart';
import 'rive_vm_binding.dart';
import 'ui_kit_artboard.dart';
import 'ui_kit_contract.dart';

/// The glyph of a running tool (`ToolIcon` artboard), tinted with the
/// surface's content color; it animates while [running] (Rive only — the
/// Flutter fallback is a static Material icon).
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
    return SizedBox.square(
      dimension: size,
      child: UiKitArtboard(
        artboard: UiKitContract.toolIconArtboard,
        apply: (RiveVmBinding binding) {
          binding.setEnum(
            UiKitContract.toolPropKind,
            UiKitContract.toolKindValues,
            kind.name,
          );
          binding.setBool(UiKitContract.toolPropRunning, running);
          binding.setColor(UiKitContract.toolPropTint, tint);
        },
        fallback: Icon(fallbackIconFor(kind), size: size, color: tint),
      ),
    );
  }
}
