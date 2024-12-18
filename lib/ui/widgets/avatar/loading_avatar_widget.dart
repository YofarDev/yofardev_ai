import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../res/app_colors.dart';

class LoadingAvatarWidget extends StatelessWidget {
  const LoadingAvatarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      top: null,
      child: Shimmer.fromColors(
        baseColor: Colors.grey,
        highlightColor: AppColors.pink,
        child: Image.asset(
          'assets/avatar/base.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
