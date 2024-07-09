import 'dart:async';

import 'package:flutter/material.dart';

class BlinkingEyes extends StatefulWidget {
  final String eyesPath;
  final double eyesX;
  final double eyesY;
  final double eyesWidth;
  final double eyesHeight;

  const BlinkingEyes({
    super.key,
    required this.eyesPath,
    required this.eyesX,
    required this.eyesY,
    required this.eyesWidth,
    required this.eyesHeight,
  });

  @override
  _BlinkingEyesState createState() => _BlinkingEyesState();
}

class _BlinkingEyesState extends State<BlinkingEyes>
    with TickerProviderStateMixin {
  late Timer _timer;
  bool _eyesClosed = false;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      _blinkEyes();
    });
  }

  void _blinkEyes() async {
    setState(() {
      _eyesClosed = true;
    });
    await Future<dynamic>.delayed(const Duration(milliseconds: 100));
    setState(() {
      _eyesClosed = false;
    });
    //   _animationController.reverse();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.eyesX,
      bottom: MediaQuery.of(context).viewInsets.bottom + widget.eyesY,
      child: _eyesClosed ? Image.asset(
        widget.eyesPath,
        fit: BoxFit.cover,
        width: widget.eyesWidth,
        height: widget.eyesHeight,
      ) : Container(),
    );
  }
}
