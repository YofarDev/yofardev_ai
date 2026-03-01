import 'dart:ui';

import 'package:flutter/material.dart';

import '../res/app_colors.dart';

/// Modern glassmorphic icon button with hover and press states
class AppIconButton extends StatefulWidget {
  const AppIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.size = 36,
    this.iconSize = 20,
    this.tooltip,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final double size;
  final double iconSize;
  final String? tooltip;

  @override
  State<AppIconButton> createState() => _AppIconButtonState();
}

class _AppIconButtonState extends State<AppIconButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onPressed();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppColors.glassSurface.withValues(
                  alpha: _isPressed
                      ? 0.3
                      : _isHovered
                      ? 0.2
                      : 0.15,
                ),
                AppColors.glassSurface.withValues(
                  alpha: _isPressed
                      ? 0.15
                      : _isHovered
                      ? 0.1
                      : 0.05,
                ),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.glassBorder.withValues(
                alpha: _isPressed
                    ? 0.6
                    : _isHovered
                    ? 0.5
                    : 0.3,
              ),
              width: 1.5,
            ),
            boxShadow: <BoxShadow>[
              if (_isHovered || _isPressed)
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: IconButton(
                onPressed: widget.onPressed,
                icon: Icon(
                  widget.icon,
                  size: widget.iconSize,
                  color: _isHovered ? AppColors.primary : AppColors.onSurface,
                ),
                tooltip: widget.tooltip,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(
                  minWidth: widget.size,
                  minHeight: widget.size,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
