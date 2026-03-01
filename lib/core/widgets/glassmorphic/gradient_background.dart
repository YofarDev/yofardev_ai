import 'dart:ui';

import 'package:flutter/material.dart';

import '../../res/app_colors.dart';

/// Animated cosmic gradient mesh background
class GradientBackground extends StatefulWidget {
  const GradientBackground({super.key, this.child, this.useAnimation = true});

  final Widget? child;
  final bool useAnimation;

  @override
  State<GradientBackground> createState() => _GradientBackgroundState();
}

class _GradientBackgroundState extends State<GradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    if (widget.useAnimation) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 20),
      )..repeat();
    }
  }

  @override
  void dispose() {
    if (widget.useAnimation) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Base gradient
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppColors.gradientMesh,
              stops: <double>[0.0, 0.3, 0.7, 1.0],
            ),
          ),
        ),
        // Animated gradient orbs
        if (widget.useAnimation)
          AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _buildGradientOrb(
                    alignment: Alignment(_controller.value * 2 - 1, -0.8),
                    color: AppColors.primary.withValues(alpha: 0.15),
                    size: 400,
                  ),
                  _buildGradientOrb(
                    alignment: Alignment(-_controller.value * 2 + 1, 0.8),
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    size: 350,
                  ),
                  _buildGradientOrb(
                    alignment: Alignment(0.5, _controller.value * 2 - 1),
                    color: AppColors.accent.withValues(alpha: 0.1),
                    size: 300,
                  ),
                ],
              );
            },
          )
        else
          Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _buildGradientOrb(
                alignment: const Alignment(-0.8, -0.8),
                color: AppColors.primary.withValues(alpha: 0.15),
                size: 400,
              ),
              _buildGradientOrb(
                alignment: const Alignment(0.8, 0.8),
                color: AppColors.secondary.withValues(alpha: 0.12),
                size: 350,
              ),
              _buildGradientOrb(
                alignment: const Alignment(0.5, -0.5),
                color: AppColors.accent.withValues(alpha: 0.1),
                size: 300,
              ),
            ],
          ),
        // Noise overlay for texture
        Positioned.fill(
          child: Opacity(
            opacity: 0.03,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
              child: Container(
                decoration: const BoxDecoration(color: Colors.white),
              ),
            ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }

  Widget _buildGradientOrb({
    required Alignment alignment,
    required Color color,
    required double size,
  }) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, Colors.transparent],
            stops: const <double>[0.0, 1.0],
          ),
        ),
      ),
    );
  }
}
