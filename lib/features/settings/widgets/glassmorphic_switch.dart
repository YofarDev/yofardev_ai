import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/res/app_colors.dart';

/// Modern glassmorphic toggle switch with smooth animations
class GlassmorphicSwitch extends StatefulWidget {
  const GlassmorphicSwitch({
    required this.value,
    required this.onChanged,
    super.key,
    this.activeColor = AppColors.primary,
    this.inactiveColor = AppColors.surface,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;
  final Color inactiveColor;

  @override
  State<GlassmorphicSwitch> createState() => _GlassmorphicSwitchState();
}

class _GlassmorphicSwitchState extends State<GlassmorphicSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _colorAnimation =
        ColorTween(
          begin: widget.inactiveColor,
          end: widget.activeColor.withValues(alpha: 0.8),
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );

    if (widget.value) {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(GlassmorphicSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      if (widget.value) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onChanged(!widget.value),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (BuildContext context, Widget? child) {
          return Container(
            width: 56,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  _colorAnimation.value ?? widget.inactiveColor,
                  widget.value
                      ? widget.activeColor.withValues(alpha: 0.6)
                      : widget.inactiveColor,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.value
                    ? widget.activeColor.withValues(alpha: 0.5)
                    : AppColors.glassBorder.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: <BoxShadow>[
                if (widget.value)
                  BoxShadow(
                    color: widget.activeColor.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Align(
                    alignment: widget.value
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            AppColors.glassSurface,
                            AppColors.glassSurface.withValues(alpha: 0.9),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.surface.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
