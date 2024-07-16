import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../logic/avatar/avatar_cubit.dart';
import '../../../logic/avatar/avatar_state.dart';
import '../../../models/avatar.dart';
import '../../../res/app_constants.dart';
import 'glowing_laser.dart';

class Costume extends StatefulWidget {
  const Costume({super.key});

  @override
  State<Costume> createState() => _CostumeState();
}

class _CostumeState extends State<Costume> with SingleTickerProviderStateMixin {
  final int _sizeLaser = 20;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: AppConstants.robocopLaserXLeft,
      end: AppConstants.robocopLaserXRight,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
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
        return Stack(
          children: <Widget>[
            Positioned.fill(
              top: null,
              child: Image.asset(
                'assets/avatar/costumes/${state.avatar.costume.name}.png',
              ),
            ),
            if (state.avatar.costume == AvatarCostume.robocop)
              _buildRobocopEyesAnimation(state.scaleFactor),
          ],
        );
      },
    );
  }

  Widget _buildRobocopEyesAnimation(double scaleFactor) => AnimatedBuilder(
        animation: _animation,
        builder: (BuildContext context, Widget? child) {
          return Positioned(
            bottom: (AppConstants.avatarHeight - AppConstants.robocopLaserY) *
                scaleFactor,
            left: _animation.value * scaleFactor,
            child: CustomPaint(
              size: Size(
                _sizeLaser  * scaleFactor,
                _sizeLaser  * scaleFactor,
              ),
              painter: GlowingLaser(radius: _sizeLaser * scaleFactor),
            ),
          );
        },
      );
}
