import 'package:flutter/material.dart';

import '../../res/app_colors.dart';
import '../../res/app_constants.dart';

class WorldBorders extends StatelessWidget {
  const WorldBorders({super.key});

  @override
  Widget build(BuildContext context) {
    final double width =
        (MediaQuery.of(context).size.width - AppConstants.maxWidth) / 2;
    return Stack(
      children: <Widget>[
        Positioned.fill(left: null, child: _buildBorder(width)),
        Positioned.fill(right: null, child: _buildBorder(width)),
      ],
    );
  }

  Widget _buildBorder(double width) {
    return Container(
      width: width,
      color: AppColors.background,
    );
  }
}
