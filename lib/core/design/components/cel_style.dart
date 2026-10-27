import 'package:flutter/material.dart';

import '../tokens/app_tokens.dart';
import '../tokens/scene_palette.dart';
import 'interactive_surface.dart';

/// Cel-style helpers shared by the component kit (not exported from
/// `components.dart`).
extension CelStyle on AppTokens {
  /// Whether raised surfaces are drawn flat with an outline and hard shadow.
  bool get isCel => surfaceStyle == AppSurfaceStyle.cel;

  /// The hard offset shadow of a cel surface: no blur, 3 px below it. When
  /// [pressed] the control sinks towards its shadow: the offset shrinks to
  /// `Offset(0, 1)`.
  List<BoxShadow> celShadow({bool pressed = false}) {
    return <BoxShadow>[
      BoxShadow(
        color: shadow.withValues(alpha: 0.6),
        offset: Offset(0, pressed ? 1 : 3),
        blurRadius: 0,
      ),
    ];
  }

  static const double _pressedDarken = 0.15;
  static const double _liftedLighten = 0.08;

  /// The opaque fill of a cel control resting on [base]: darker while pressed,
  /// lighter while hovered or focused.
  Color celFill(Color base, InteractiveStates states) {
    if (states.pressed) {
      return Color.alphaBlend(shadow.withValues(alpha: _pressedDarken), base);
    }
    if (states.hovered || states.focused) {
      return Color.alphaBlend(
        highlight.withValues(alpha: _liftedLighten),
        base,
      );
    }
    return base;
  }

  /// The outline of a cel control: the scene accent while keyboard-focused,
  /// unless the control is already [filled] with the accent, else the plain
  /// outline color.
  Color celBorder(InteractiveStates states, {required bool filled}) {
    return states.focused && !filled ? scene.accent : glassBorder;
  }
}
