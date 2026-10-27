import 'package:flutter/material.dart';

import '../tokens/app_tokens.dart';
import '../tokens/scene_palette.dart';

/// Cel-style helpers shared by the component kit (not exported from
/// `components.dart`).
extension CelStyle on AppTokens {
  /// Whether raised surfaces are drawn flat with an outline and hard shadow.
  bool get isCel => surfaceStyle == AppSurfaceStyle.cel;

  /// The hard offset shadow of a cel surface: no blur, [dy] below it. A
  /// pressed control sinks towards its shadow.
  List<BoxShadow> celShadow({bool pressed = false}) {
    return <BoxShadow>[
      BoxShadow(
        color: shadow.withValues(alpha: 0.6),
        offset: Offset(0, pressed ? 1 : 3),
        blurRadius: 0,
      ),
    ];
  }
}
