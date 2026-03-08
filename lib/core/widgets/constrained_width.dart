import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../res/app_constants.dart';
import '../res/app_colors.dart';
import '../../features/avatar/presentation/bloc/avatar_cubit.dart';
import '../../features/avatar/presentation/bloc/avatar_state.dart';

class ConstrainedWidth extends StatelessWidget {
  final Widget child;
  const ConstrainedWidth({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    return ColoredBox(
      color: AppColors.primary.withValues(alpha: 0.1),
      child: BlocBuilder<AvatarCubit, AvatarState>(
        builder: (BuildContext context, AvatarState state) {
          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double computedAvatarWidth =
                  state.status == AvatarStatus.initial
                  ? AppConstants.avatarWidth
                  : state.baseOriginalWidth * state.scaleFactor;
              final double avatarWidth =
                  computedAvatarWidth.isFinite && computedAvatarWidth > 0
                  ? computedAvatarWidth
                  : AppConstants.avatarWidth;
              final double maxWidth = avatarWidth.clamp(
                0,
                constraints.maxWidth,
              );

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: child,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
