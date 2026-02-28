import 'package:flutter/material.dart';

/// Modern glassmorphic page transition with smooth animations
class GlassmorphicPageTransition extends PageRouteBuilder<dynamic> {
  GlassmorphicPageTransition({
    required this.child,
    super.transitionDuration = const Duration(milliseconds: 350),
    super.reverseTransitionDuration = const Duration(milliseconds: 300),
  }) : super(
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) =>
              child,
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            const Curve curve = Curves.easeOutCubic;
            final CurvedAnimation curvedAnimation =
                CurvedAnimation(parent: animation, curve: curve);

            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: FadeTransition(
                opacity: curvedAnimation,
                child: child,
              ),
            );
          },
        );

  final Widget child;
}

/// Fade through page transition
class FadeThroughPageTransition extends PageRouteBuilder<dynamic> {
  FadeThroughPageTransition({
    required this.child,
    super.transitionDuration = const Duration(milliseconds: 250),
  }) : super(
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) =>
              child,
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            return FadeTransition(
              opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
              child: child,
            );
          },
        );

  final Widget child;
}
