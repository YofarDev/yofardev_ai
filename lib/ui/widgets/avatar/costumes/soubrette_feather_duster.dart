import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../logic/avatar/avatar_cubit.dart';
import '../../../../logic/avatar/avatar_state.dart';
import '../../../../res/app_constants.dart';
import '../../../../utils/app_utils.dart';

class SoubretteFeatherDuster extends StatefulWidget {
  const SoubretteFeatherDuster({super.key});

  @override
  _SoubretteFeatherDusterState createState() => _SoubretteFeatherDusterState();
}

class _SoubretteFeatherDusterState extends State<SoubretteFeatherDuster>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true, period: const Duration(milliseconds: 3000));

    _animation = Tween<double>(
      begin: 0,
      end: 3.14 / 3,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutCirc,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AvatarCubit, AvatarState>(
      builder: (BuildContext context, AvatarState state) {
        final double scaleFactor = state.scaleFactor;
        return AnimatedBuilder(
          animation: _animation,
          builder: (BuildContext context, Widget? child) {
            return Positioned(
              left: 0,
              bottom: AppConstants.soubretteFeatherDusterY * scaleFactor * -0.5,
              child: Transform(
                alignment:
                    Alignment.bottomCenter, // Align rotation to bottom center
                transform: Matrix4.identity()..rotateZ(_animation.value),
                child: Image.asset(
                  AppUtils.fixAssetsPath(
                    'assets/avatar/costumes/feather_duster.png',
                  ),
                  width: AppConstants.soubretteFeatherDusterWidth * scaleFactor,
                  height:
                      AppConstants.soubretteFeatherDusterHeight * scaleFactor,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
