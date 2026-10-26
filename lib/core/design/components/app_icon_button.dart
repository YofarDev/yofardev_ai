import 'package:flutter/material.dart';

import '../context_ext.dart';
import '../tokens/app_motion.dart';
import '../tokens/app_radius.dart';

/// Glassmorphic icon button: a 36 dp visual inside a 48x48 hit area.
///
/// Pass `onPressed: null` to disable it. [semanticLabel] is always required
/// (screen readers); [tooltip] is the optional visible hover/long-press hint.
class AppIconButton extends StatefulWidget {
  const AppIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.semanticLabel,
    this.tooltip,
    this.iconSize = 20,
    this.active = false,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String semanticLabel;
  final String? tooltip;
  final double iconSize;

  /// Shows the button as toggled on (primary tinted).
  final bool active;

  static const double hitSize = 48;
  static const double visualSize = 36;

  @override
  State<AppIconButton> createState() => _AppIconButtonState();
}

class _AppIconButtonState extends State<AppIconButton> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null;

  void _activate() => widget.onPressed?.call();

  @override
  void didUpdateWidget(AppIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled && (_hovered || _pressed)) {
      _hovered = false;
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final Color glassSurface = context.tokens.glassSurface;
    final Color glassBorder = context.tokens.glassBorder;

    final bool pressed = _enabled && _pressed;
    final bool hovered = _enabled && _hovered;
    final bool focused = _enabled && _focused;
    final bool lifted = hovered || focused;

    final double fillTop = pressed
        ? 0.3
        : lifted
        ? 0.2
        : 0.15;
    final double fillBottom = pressed
        ? 0.15
        : lifted
        ? 0.1
        : 0.05;
    final double borderAlpha = pressed
        ? 0.6
        : lifted
        ? 0.5
        : 0.3;

    final Color iconColor = widget.active || lifted
        ? colors.primary
        : colors.onSurface;
    final Color borderColor = widget.active || focused
        ? colors.primary.withValues(alpha: focused ? 0.9 : 0.6)
        : glassBorder.withValues(alpha: borderAlpha);

    final BorderRadius radius = BorderRadius.circular(AppRadius.md);

    Widget visual = AnimatedContainer(
      duration: AppMotion.base,
      curve: AppMotion.standard,
      width: AppIconButton.visualSize,
      height: AppIconButton.visualSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            widget.active
                ? colors.primary.withValues(alpha: fillTop)
                : glassSurface.withValues(alpha: fillTop),
            widget.active
                ? colors.primary.withValues(alpha: fillBottom)
                : glassSurface.withValues(alpha: fillBottom),
          ],
        ),
        borderRadius: radius,
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: <BoxShadow>[
          if (hovered || pressed)
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Icon(widget.icon, size: widget.iconSize, color: iconColor),
    );

    visual = Opacity(opacity: _enabled ? 1 : 0.4, child: visual);

    Widget button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
      onTap: _enabled ? _activate : null,
      child: SizedBox(
        width: AppIconButton.hitSize,
        height: AppIconButton.hitSize,
        child: Center(child: visual),
      ),
    );

    button = FocusableActionDetector(
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
      child: button,
    );

    final String? tooltip = widget.tooltip;
    if (tooltip != null) {
      // The label is already announced by the Semantics node below.
      button = Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: button,
      );
    }

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      onTap: _enabled ? _activate : null,
      excludeSemantics: true,
      child: button,
    );
  }
}
