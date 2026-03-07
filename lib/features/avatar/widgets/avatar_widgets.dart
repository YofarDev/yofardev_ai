import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/res/app_constants.dart';
import '../../../features/avatar/bloc/avatar_state.dart';
import '../bloc/avatar_cubit.dart';
import 'animated_avatar.dart';

class AvatarWidgets extends StatefulWidget {
  const AvatarWidgets({super.key});

  @override
  AvatarWidgetsState createState() => AvatarWidgetsState();
}

class AvatarWidgetsState extends State<AvatarWidgets>
    with TickerProviderStateMixin {
  late AnimationController _horizontalController;
  late Animation<Offset> _horizontalAnimation;

  late AnimationController _verticalController;
  late Animation<Offset> _verticalAnimation;

  @override
  void initState() {
    super.initState();
    // Horizontal animation (for location changes)
    _horizontalController = AnimationController(
      duration: Duration(seconds: AppConstants.movingAvatarDuration),
      vsync: this,
    );

    _horizontalAnimation =
        Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-1.5, 0), // Slide out to the left
        ).animate(
          CurvedAnimation(
            parent: _horizontalController,
            curve: Curves.easeInOut,
          ),
        );

    // Vertical animation (for clothes changes) - faster
    _verticalController = AnimationController(
      duration: const Duration(milliseconds: 600), // Quicker drop
      vsync: this,
    );

    _verticalAnimation =
        Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0, 1.5), // Slide down out of screen
        ).animate(
          CurvedAnimation(parent: _verticalController, curve: Curves.easeInOut),
        );
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AvatarCubit, AvatarState>(
      builder: (BuildContext context, AvatarState state) {
        return BlocListener<AvatarCubit, AvatarState>(
          listenWhen: (AvatarState previous, AvatarState current) =>
              previous.statusAnimation != current.statusAnimation,
          listener: (BuildContext context, AvatarState state) {
            _handleAnimationChange(state.statusAnimation);
          },
          child: _buildAnimatedAvatar(state),
        );
      },
    );
  }

  void _handleAnimationChange(AvatarStatusAnimation statusAnimation) {
    switch (statusAnimation) {
      case AvatarStatusAnimation.leaving:
        // Horizontal slide out (location change)
        _horizontalController.forward();
      case AvatarStatusAnimation.coming:
        // Horizontal slide in
        _horizontalController.reverse();
      case AvatarStatusAnimation.dropping:
        // Vertical slide down (clothes change)
        _verticalController.forward();
      case AvatarStatusAnimation.rising:
        // Vertical slide up
        _verticalController.reverse();
      case AvatarStatusAnimation.initial:
      case AvatarStatusAnimation.transition:
        // Reset both animations
        _horizontalController.reset();
        _verticalController.reset();
    }
  }

  Widget _buildAnimatedAvatar(AvatarState state) {
    // Use vertical animation for dropping/rising, horizontal for others
    final bool useVertical =
        state.statusAnimation == AvatarStatusAnimation.dropping ||
        state.statusAnimation == AvatarStatusAnimation.rising;

    final Animation<Offset> animation = useVertical
        ? _verticalAnimation
        : _horizontalAnimation;

    return AnimatedAvatar(
      state: state,
      animation: animation,
    );
  }
}
