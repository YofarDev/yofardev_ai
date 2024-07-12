import 'dart:async';

import 'package:flutter/material.dart';

import '../../../res/app_constants.dart';
import 'scaled_avatar_item.dart';

class BlinkingEyes extends StatefulWidget {
  const BlinkingEyes({
    super.key,
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
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaledAvatarItem(
      path: 'assets/avatar/eyes_closed.png',
      itemX: AppConstants().eyesX,
      itemY: AppConstants().eyesY,
      display: _eyesClosed,
    );
  }
}
