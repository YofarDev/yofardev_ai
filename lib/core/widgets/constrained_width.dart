import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A widget that constrains its child's width based on avatar dimensions.
///
/// This widget is designed to work with avatar-based layouts where the content
/// width should match or be constrained by the avatar's visual width.
class ConstrainedWidth extends StatelessWidget {
  const ConstrainedWidth({super.key, required this.child, this.avatarWidth});

  final Widget child;
  final double? avatarWidth;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    final double width = avatarWidth ?? 400.0; // Default width

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: child,
      ),
    );
  }
}
