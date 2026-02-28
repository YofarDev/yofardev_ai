import 'package:flutter/material.dart';

import '../../../models/demo_script.dart';
import '../../../services/demo_controller.dart';
import '../../../services/demo_service.dart';

class DemoControls extends StatefulWidget {
  const DemoControls({super.key});

  @override
  State<DemoControls> createState() => _DemoControlsState();
}

class _DemoControlsState extends State<DemoControls> {
  final DemoService _demoService = DemoService();

  @override
  void initState() {
    super.initState();
    _demoService.controller.statusStream.listen((DemoStatus status) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _demoService.deactivateDemo();
    super.dispose();
  }

  Future<void> _startDemo() async {
    await _demoService.activateDemo(
      context: context,
      script: DemoScripts.beachDemo,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    bool isDebug = false;
    assert(() {
      isDebug = true;
      return true;
    }());

    if (!isDebug) return const SizedBox.shrink();

    final DemoStatus status = _demoService.controller.status;

    // Hide everything when demo is active (user is typing naturally)
    if (_demoService.isActive) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 60,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          // Countdown or button
          if (status == DemoStatus.countdown)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${_demoService.controller.countdownValue}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            FloatingActionButton.small(
              onPressed: status == DemoStatus.idle ? _startDemo : null,
              backgroundColor: Colors.blue,
              heroTag: 'demo_btn',
              child: const Icon(
                Icons.play_arrow,
                size: 20,
              ),
            ),
          if (status != DemoStatus.countdown) const SizedBox(height: 8),
          // Status indicator
          if (status != DemoStatus.countdown)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getStatusText(status),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getStatusText(DemoStatus status) {
    switch (status) {
      case DemoStatus.idle:
        return 'Demo';
      case DemoStatus.countdown:
        return 'Démarrage...';
      case DemoStatus.completed:
        return '${_demoService.fakeLlmService.remainingResponses} réponses restantes';
    }
  }
}
