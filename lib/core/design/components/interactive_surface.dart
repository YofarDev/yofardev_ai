import 'package:flutter/material.dart';

/// Interaction flags handed to [InteractiveSurface.builder]. They are always
/// all false while the surface is disabled.
typedef InteractiveStates = ({bool hovered, bool pressed, bool focused});

/// Shared interaction plumbing of the component kit (not exported from
/// `components.dart`): hover, pressed and keyboard-focus tracking, tap and
/// Enter/Space activation, and the pointer cursor.
///
/// The surface is disabled when [onTap] is null; going from enabled to
/// disabled mid-interaction resets every flag.
class InteractiveSurface extends StatefulWidget {
  const InteractiveSurface({
    super.key,
    required this.onTap,
    required this.builder,
  });

  final VoidCallback? onTap;
  final Widget Function(BuildContext context, InteractiveStates states) builder;

  @override
  State<InteractiveSurface> createState() => _InteractiveSurfaceState();
}

class _InteractiveSurfaceState extends State<InteractiveSurface> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onTap != null;

  void _activate() => widget.onTap?.call();

  @override
  void didUpdateWidget(InteractiveSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled) {
      _hovered = false;
      _pressed = false;
      _focused = false;
    }
  }

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final InteractiveStates states = (
      hovered: _enabled && _hovered,
      pressed: _enabled && _pressed,
      focused: _enabled && _focused,
    );

    return FocusableActionDetector(
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => _setPressed(true) : null,
        onTapUp: _enabled ? (_) => _setPressed(false) : null,
        onTapCancel: _enabled ? () => _setPressed(false) : null,
        onTap: _enabled ? _activate : null,
        child: widget.builder(context, states),
      ),
    );
  }
}
