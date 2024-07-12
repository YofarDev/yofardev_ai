import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class ThinkingAnimation extends StatelessWidget {
  const ThinkingAnimation({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).viewInsets.bottom + 350,
      left: 130,
      child: Lottie.asset(
        'assets/lotties/typing.json',
        height: 60,
      ),
    );
  }
}
