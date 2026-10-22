import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/res/app_colors.dart';
import '../../../../core/utils/app_utils.dart';

class SingularityCostume extends StatefulWidget {
  final Duration switchDuration;
  final Duration fadeDuration;
  final List<int>? amplitudes;
  final bool isTalking;

  const SingularityCostume({
    super.key,
    this.switchDuration = const Duration(milliseconds: 200),
    this.fadeDuration = const Duration(milliseconds: 200),
    this.amplitudes,
    this.isTalking = false,
  });

  @override
  State<SingularityCostume> createState() => _SingularityCostumeState();
}

class _SingularityCostumeState extends State<SingularityCostume> {
  final int _imagesCount = 4;
  late int _currentImageIndex;
  late Timer _timer;
  double _amplitude = 0;

  @override
  void initState() {
    super.initState();
    _currentImageIndex = 0;
    _startImageSwitching();
  }

  void _startImageSwitching() {
    _timer = Timer.periodic(widget.switchDuration, (Timer timer) {
      setState(() {
        _currentImageIndex = (_currentImageIndex + 1) % _imagesCount;
      });
    });
  }

  @override
  void didUpdateWidget(SingularityCostume oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTalking &&
        (oldWidget.isTalking != widget.isTalking ||
            oldWidget.amplitudes != widget.amplitudes)) {
      _startTalking(widget.amplitudes ?? <int>[]);
    }
  }

  void _startTalking(List<int> amplitudes) async {
    for (int i = 0; i < amplitudes.length; i++) {
      if (!mounted) return;
      setState(() {
        _amplitude = amplitudes[i] * 1;
      });
      await Future<dynamic>.delayed(const Duration(milliseconds: 50));
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 150),
            child: Container(
              width: 1,
              height: 1,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                color: AppColors.warning,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.warning.withValues(alpha: 0.7),
                    blurRadius: 80,
                    spreadRadius: 80 + _amplitude,
                  ),
                ],
              ),
            ),
          ),
        ),
        Image.asset(
          AppUtils.fixAssetsPath(
            'assets/avatar/costumes/singularity/singularity_$_currentImageIndex.png',
          ),
          key: ValueKey<int>(_currentImageIndex),
          fit: BoxFit.cover,
        ),
        AnimatedSwitcher(
          duration: widget.fadeDuration,
          child: Image.asset(
            AppUtils.fixAssetsPath(
              'assets/avatar/costumes/singularity/singularity_$_currentImageIndex.png',
            ),
            key: ValueKey<int>(_currentImageIndex),
            fit: BoxFit.cover,
          ),
        ),
      ],
    );
  }
}

class HaloPainter extends CustomPainter {
  final Color color;
  final double haloSize;

  HaloPainter({required this.color, required this.haloSize});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = haloSize;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      math.min(size.width, size.height) / 2,
      paint,
    );
  }

  @override
  bool shouldRepaint(HaloPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.haloSize != haloSize;
  }
}
