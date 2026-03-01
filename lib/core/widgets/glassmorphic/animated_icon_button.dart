import 'package:flutter/material.dart';

import '../../../res/app_colors.dart';

class AnimatedIconButton extends StatefulWidget {
  final IconData icon;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback? onPressed;

  const AnimatedIconButton({
    super.key,
    required this.icon,
    this.isActive = false,
    this.activeColor,
    this.onPressed,
  });

  @override
  State<AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isActive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (BuildContext context, Widget? child) {
        return Transform.scale(
          scale: widget.isActive ? _pulseAnimation.value : 1.0,
          child: Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isActive
                  ? (widget.activeColor ?? AppColors.primary).withValues(
                      alpha: 0.15,
                    )
                  : Colors.transparent,
            ),
            child: IconButton(
              icon: Icon(
                widget.icon,
                color: widget.isActive
                    ? (widget.activeColor ?? AppColors.primary)
                    : AppColors.onSurface.withValues(alpha: 0.6),
                size: 22,
              ),
              onPressed: widget.onPressed,
            ),
          ),
        );
      },
    );
  }
}
