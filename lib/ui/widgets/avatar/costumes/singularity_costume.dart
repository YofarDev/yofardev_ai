import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../logic/talking/talking_cubit.dart';
import '../../../../utils/app_utils.dart';
import '../../../../utils/platform_utils.dart';

class SingularityCostume extends StatefulWidget {
  final Duration switchDuration;
  final Duration fadeDuration;

  const SingularityCostume({
    super.key,
    this.switchDuration = const Duration(milliseconds: 200),
    this.fadeDuration = const Duration(milliseconds: 200),
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

  void _fakeTalking() async {
    if (!context.read<TalkingCubit>().state.isTalking) return;
    setState(() {
      _amplitude = math.Random().nextInt(25) * 1;
    });
    await Future<dynamic>.delayed(const Duration(milliseconds: 100));
    _fakeTalking();
  }

  void _startTalking(List<int> ampltiudes) async {
    for (int i = 0; i < ampltiudes.length; i++) {
      setState(() {
        _amplitude = ampltiudes[i] * 1;
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
    return BlocListener<TalkingCubit, TalkingState>(
      listenWhen: (TalkingState previous, TalkingState current) =>
          previous.status != current.status,
      listener: (BuildContext context, TalkingState state) {
        if (state.status == TalkingStatus.success) {
          if (PlatformUtils.checkPlatform() == 'Web') {
            _fakeTalking();
          } else {
            _startTalking(state.answer.amplitudes);
          }
        }
      },
      child: Stack(
        children: <Widget>[
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 150),
              child: Container(
                width: 1,
                height: 1,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  color: Colors.amber[200],
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.amber[100]!,
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
      ),
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
