import 'package:flutter/material.dart';

import '../context_ext.dart';
import '../tokens/app_motion.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';

/// A compact rounded label (filter chip / tag), optionally with an icon.
///
/// The pill itself is 36 dp tall; the tappable area is at least 48 dp tall.
class AppPill extends StatefulWidget {
  const AppPill({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.selected = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool selected;

  static const double height = 36;
  static const double hitHeight = 48;

  @override
  State<AppPill> createState() => _AppPillState();
}

class _AppPillState extends State<AppPill> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onTap != null;

  void _activate() => widget.onTap?.call();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final Color glassSurface = context.tokens.glassSurface;
    final Color glassBorder = context.tokens.glassBorder;

    final bool pressed = _enabled && _pressed;
    final bool lifted = _enabled && (_hovered || _focused);
    final bool selected = widget.selected;

    final Color fill = selected
        ? colors.primary.withValues(alpha: pressed ? 0.3 : 0.2)
        : glassSurface.withValues(
            alpha: pressed
                ? 0.5
                : lifted
                ? 0.35
                : 0.2,
          );
    final Color border = selected
        ? colors.primary.withValues(alpha: lifted || pressed ? 0.9 : 0.7)
        : _focused && _enabled
        ? colors.primary.withValues(alpha: 0.9)
        : glassBorder.withValues(
            alpha: pressed
                ? 0.8
                : lifted
                ? 0.6
                : 0.4,
          );
    final Color foreground = selected ? colors.primary : colors.onSurface;

    final Widget label = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.text.labelLarge?.copyWith(color: foreground),
    );

    final Widget content = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Flexible needs a bounded main axis (an unbounded Row would throw).
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (widget.icon != null) ...<Widget>[
              Icon(widget.icon, size: 16, color: foreground),
              const SizedBox(width: AppSpace.xs),
            ],
            if (constraints.hasBoundedWidth) Flexible(child: label) else label,
          ],
        );
      },
    );

    final Widget pill = AnimatedContainer(
      duration: AppMotion.base,
      curve: AppMotion.standard,
      constraints: const BoxConstraints(minHeight: AppPill.height),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: border, width: 1.5),
      ),
      child: content,
    );

    Widget result = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
      onTap: _enabled ? _activate : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppPill.hitHeight),
        child: Center(widthFactor: 1, child: pill),
      ),
    );

    result = FocusableActionDetector(
      enabled: _enabled,
      mouseCursor: _enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onShowHoverHighlight: (bool value) => setState(() => _hovered = value),
      onShowFocusHighlight: (bool value) => setState(() => _focused = value),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (ActivateIntent _) {
            _activate();
            return null;
          },
        ),
      },
      child: result,
    );

    return Semantics(
      button: _enabled,
      selected: selected,
      enabled: _enabled,
      label: widget.label,
      onTap: _enabled ? _activate : null,
      excludeSemantics: true,
      child: result,
    );
  }
}
