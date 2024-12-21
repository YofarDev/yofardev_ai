import 'dart:async';

import 'package:flutter/material.dart';

import '../../../res/app_constants.dart';
import '../../../utils/app_utils.dart';
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
  String _eyeState = 'open';

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      _blinkEyes();
    });
  }

  void _blinkEyes() async {
    setState(() {
      _eyeState = 'half_closed';
    });
    await Future<dynamic>.delayed(const Duration(milliseconds: 25));
    setState(() {
      _eyeState = 'closed';
    });
    await Future<dynamic>.delayed(const Duration(milliseconds: 100));
    setState(() {
      _eyeState = 'half_closed';
    });
    await Future<dynamic>.delayed(const Duration(milliseconds: 25));
    setState(() {
      _eyeState = 'open';
    });
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
        ScaledAvatarItem(
          path: AppUtils.fixAssetsPath('assets/avatar/half_closed_eyes.png'),
          itemX: AppConstants.eyesX,
          itemY: AppConstants.eyesY,
          display: _eyeState == 'half_closed',
        ),
        ScaledAvatarItem(
          path: AppUtils.fixAssetsPath('assets/avatar/closed_eyes.png'),
          itemX: AppConstants.eyesX,
          itemY: AppConstants.eyesY,
          display: _eyeState == 'closed',
        ),
      ],
    );
  }
}
