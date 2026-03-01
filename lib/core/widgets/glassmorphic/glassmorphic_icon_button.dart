import 'package:flutter/material.dart';

import '../../res/app_colors.dart';

class GlassmorphicIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const GlassmorphicIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<GlassmorphicIconButton> createState() => _GlassmorphicIconButtonState();
}

class _GlassmorphicIconButtonState extends State<GlassmorphicIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              AppColors.glassSurface.withValues(alpha: _isPressed ? 0.2 : 0.1),
              AppColors.glassSurface.withValues(
                alpha: _isPressed ? 0.15 : 0.05,
              ),
            ],
          ),
          border: Border.all(
            color: AppColors.glassBorder.withValues(
              alpha: _isPressed ? 0.5 : 0.3,
            ),
            width: 1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: _isPressed
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.1),
              blurRadius: _isPressed ? 12 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Icon(
          widget.icon,
          size: 22,
          color: _isPressed
              ? AppColors.primary
              : AppColors.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
