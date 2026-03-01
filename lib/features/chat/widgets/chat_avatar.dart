import 'package:flutter/material.dart';

import '../../../core/res/app_colors.dart';
import '../../../core/utils/app_utils.dart';

class ChatAvatar extends StatelessWidget {
  final double size;
  final double borderWidth;

  const ChatAvatar({super.key, this.size = 36, this.borderWidth = 2});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: <Color>[AppColors.primary, AppColors.secondary],
        ),
        border: Border.all(
          color: AppColors.glassBorder.withValues(alpha: 0.5),
          width: borderWidth,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(borderWidth),
      child: Center(
        child: CircleAvatar(
          radius: (size - borderWidth * 2) / 2,
          backgroundColor: Colors.transparent,
          foregroundImage: AssetImage(
            AppUtils.fixAssetsPath('assets/icon.png'),
          ),
        ),
      ),
    );
  }
}
