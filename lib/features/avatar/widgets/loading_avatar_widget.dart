import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class LoadingAvatarWidget extends StatelessWidget {
  const LoadingAvatarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      top: null,
      child: Shimmer.fromColors(
        baseColor: colorScheme.onSurface.withValues(alpha: 0.3),
        highlightColor: colorScheme.primary,
        child: Image.asset('assets/avatar/base.png', fit: BoxFit.contain),
      ),
    );
  }
}
